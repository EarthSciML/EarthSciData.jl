using EarthSciData
using EarthSciMLBase, ModelingToolkit, DomainSets
using ModelingToolkit: t, D
using NCDatasets, DynamicQuantities, Dates
using OrdinaryDiffEqLowOrderRK, OrdinaryDiffEqTsit5
using Logging
using Test

@testset "NetCDF Output" begin
    @testset "NetCDF Output" begin
        @parameters lev = 1.0
        @parameters y=2.0 [unit = u"kg"]
        @parameters x=1.0 [unit = u"kg", description = "x coordinate"]
        @variables u(t)=1.0 [unit = u"kg", description = "u value"]
        @variables v(t) [unit = u"kg", description = "v value"]
        @constants c=1.0 [unit = u"kg^2"]
        @constants p=1.0 [unit = u"kg/s"]

        eqs = [D(u) ~ p + 1e-20 * lev * p * x * y / c # Need to make sure all coordinates are included in model.
               v ~ (x + y) * lev]

        sys = System(eqs, t; name = :sys)

        domain = DomainInfo(
            DateTime(2000, 1, 1, 0, 0, 0),
            DateTime(2000, 1, 1, 0, 0, 2);
            xrange = -1:0.1:1,
            yrange = -2:0.1:2,
            levrange = 1:3
        )

        file = tempname() * ".nc"

        csys = couple(sys, domain)

        o = NetCDFOutputter(file, 1.0; extra_vars = [sys.v])

        csys = couple(csys, o)

        dt = 0.01
        st = SolverStrangThreads(Tsit5(), dt)
        prob = ODEProblem(csys, st)

        # The Strang solver currently goes unstable here (separate regression
        # being fixed elsewhere) and emits thousands of dt_epsilon /
        # init_NaN warnings per step.  In CI those drown out subsequent
        # subprocess logs by exhausting GitHub's 4 MB live-log cap, so silence
        # them at solve time.
        with_logger(NullLogger()) do
            solve(prob, Euler(), dt = dt)
        end

        ds = NCDataset(file, "r")

        @test size(ds["sys₊u"], 4) == 3
        @test all(isapprox.(ds["sys₊u"][:, :, :, 1], 1.0, atol = 0.011))
        @test sum(abs.(ds["sys₊v"][:, :, :, 1])) ≈ 5754.0f0
        @test all(isapprox.(ds["sys₊u"][:, :, :, 2], 2.0, atol = 0.011))
        @test sum(abs.(ds["sys₊v"][:, :, :, 2])) ≈ 5754.0f0
        @test all(isapprox.(ds["sys₊u"][:, :, :, 3], 3.0, atol = 0.011))
        @test sum(abs.(ds["sys₊v"][:, :, :, 3])) ≈ 5754.0f0
        @test size(ds["sys₊u"]) == (21, 41, 3, 3)

        @test ds["time"][:] == [
            DateTime("2000-01-01T00:00:00"),
            DateTime("2000-01-01T00:00:01"),
            DateTime("2000-01-01T00:00:02")
        ]
        @test ds["x"][:] ≈ -1.0:0.1:1.0
        @test ds["y"][:] ≈ -2.0:0.1:2.0
        @test ds["lev"] ≈ 1:3

        @test ds["x"].attrib["description"] == "East-West Distance"
        @test ds["x"].attrib["units"] == "m"

        @test ds["sys₊u"].attrib["description"] == "u value"
        @test ds["sys₊u"].attrib["units"] == "kg"

        close(ds)

        # The synchronous writer writes the same file.
        @test o.async_write
        file_sync = tempname() * ".nc"
        o_sync = NetCDFOutputter(file_sync, 1.0; extra_vars = [sys.v], async_write = false)
        prob_sync = ODEProblem(couple(couple(sys, domain), o_sync), st)
        with_logger(NullLogger()) do
            solve(prob_sync, Euler(), dt = dt)
        end
        @test read(file_sync) == read(file)

        rm(file, force = true)
        rm(file_sync, force = true)
    end
end

# Background writes: same file as synchronous writes, the simulation does not
# wait for `nclock` held by a data load, and finalize waits for the write in
# flight and reports a failed one.

# Variables whose unit and description the file records.
function out_sys()
    @variables a(t)=1.0 [unit = u"kg", description = "a value"]
    @variables b(t)=2.0 [unit = u"kg", description = "b value"]
    System([D(a) ~ 0, D(b) ~ 0], t; name = :osys)
end

function out_domain()
    DomainInfo(DateTime(2000, 1, 1, 0, 0, 0), DateTime(2000, 1, 1, 0, 0, 4);
        xrange = -1:0.5:1, yrange = -2:0.5:2, levrange = 1:3)
end

# An outputter set up by `init_callback` as `couple` + `ODEProblem` would, and its callback.
function out_setup(file; async_write)
    sys, dom = out_sys(), out_domain()
    o = NetCDFOutputter(file, 1.0; async_write = async_write)
    cb = EarthSciMLBase.init_callback(o, couple(sys, dom), sys, nothing, dom,
        EarthSciMLBase.MapBroadcast())
    return o, cb
end

# A stand-in for the integrator at output time `k`, with values that differ
# by variable, cell and time and need rounding to `Float32`.
function out_integ(o, k)
    n = 2 * prod(length.(o.grid))
    return (u = [k + sin(1.3 * i + 0.7 * k) / 3 for i in 1:n], p = nothing, t = Float64(k))
end

# Whether `file` holds the state of `out_integ` at times `0:(n - 1)`.
function holds_records(file, o, n)
    ds = NCDataset(file, "r")
    try
        names = [k for k in keys(ds) if ndims(ds[k]) == 4]  # in the order of the state
        ok = length(names) == 2 && size(ds[names[1]], 4) == n
        for k in 0:(n - 1)
            u = reshape(out_integ(o, k).u, 2, length.(o.grid)...)
            for j in 1:2
                ok &= ds[names[j]][:, :, :, k + 1] == Float32.(u[j, :, :, :])
            end
        end
        ok &= ds["time"][:] == DateTime(2000, 1, 1) .+ Second.(0:(n - 1))
        return ok
    finally
        close(ds)
    end
end

# Hold `nclock` in another task, as a data load does while it reads, until
# `release` is notified.
function hold_nclock()
    held, release = Base.Event(), Base.Event()
    task = Threads.@spawn lock(EarthSciData.nclock) do
        notify(held)
        wait(release)
    end
    wait(held)
    return task, release
end

# Run `f` in a task; whether it finished within `timeout` seconds.
function finishes(f, timeout)
    task = Threads.@spawn f()
    return timedwait(() -> istaskdone(task), timeout) === :ok, task
end

struct FailingVar end
Base.setindex!(::FailingVar, x, I...) = error("injected write failure")

# Hourly records; like the NetCDF loaders it reads under `nclock`, and a read
# on any task but the one that built it (a background prefetch) holds the lock
# until `gate` opens.
struct GatedFS <: EarthSciData.FileSet
    start::DateTime
    finish::DateTime
    main::Task
    entered::Base.Event
    gate::Base.Event
end
GatedFS(start, finish) = GatedFS(start, finish, current_task(), Base.Event(), Base.Event())

function EarthSciData.DataFrequencyInfo(fs::GatedFS)
    EarthSciData.DataFrequencyInfo(fs.start, Hour(1),
        collect((fs.start + Minute(30)):Hour(1):(fs.finish)))
end
function EarthSciData.loadslice!(cache::AbstractArray, fs::GatedFS, t::DateTime, varname)
    lock(EarthSciData.nclock) do
        if current_task() !== fs.main
            notify(fs.entered)
            wait(fs.gate)
        end
        cache .= Dates.value(t - fs.start) / 3.6e6
    end
    return nothing
end
function EarthSciData.loadmetadata(fs::GatedFS, varname)
    EarthSciData.MetaData(
        [[0.0, 0.01, 0.02, 0.03], [0.0, 0.01, 0.02]],
        "m", "test", ["x", "y"], [4, 3],
        "+proj=longlat +datum=WGS84 +no_defs", 1, 2, -1, (false, false, false))
end

@testset "NetCDF Output: background writes" begin
    @testset "files identical, background vs synchronous vs direct writes" begin
        files = [tempname() * ".nc" for _ in 1:3]
        n = 5
        o_async, cb_async = out_setup(files[1]; async_write = true)
        o_sync, cb_sync = withenv("EARTHSCIDATA_ASYNC_OUTPUT" => "0") do
            out_setup(files[2]; async_write = EarthSciData._async_output_default())
        end
        @test o_async.async_write && !o_sync.async_write
        o_direct, cb_direct = out_setup(files[3]; async_write = false)
        for k in 0:(n - 1)
            integ = out_integ(o_async, k)
            cb_async.affect!(integ)
            cb_sync.affect!(integ)
            # What the writer did before buffering: write each state variable's
            # `Float64` values straight to the file.
            u = reshape(integ.u, 2, length.(o_direct.grid)...)
            lock(EarthSciData.nclock) do
                for j in 1:2
                    o_direct.vars[j][:, :, :, k + 1] = u[j, :, :, :]
                end
                o_direct.tvar[k + 1] = integ.t + o_direct.tref
            end
        end
        @test o_sync.pending === nothing
        for (o, cb) in ((o_async, cb_async), (o_sync, cb_sync), (o_direct, cb_direct))
            cb.finalize(cb, nothing, 0.0, nothing)
        end
        @test holds_records(files[1], o_async, n)
        @test read(files[1]) == read(files[2]) == read(files[3])
        foreach(f -> rm(f, force = true), files)
    end

    @testset "a write overlapping a data load does not block the caller" begin
        file = tempname() * ".nc"
        o, cb = out_setup(file; async_write = true)
        cb.affect!(out_integ(o, 0))
        wait(o.pending)
        holder, release = hold_nclock()
        done, _ = finishes(() -> cb.affect!(out_integ(o, 1)), 30.0)
        @test done
        @test o.pending !== nothing && !istaskdone(o.pending)  # waiting for `nclock`
        notify(release)
        wait(holder)
        cb.affect!(out_integ(o, 2))  # waits for the previous write first
        cb.finalize(cb, nothing, 0.0, nothing)
        @test holds_records(file, o, 3)
        rm(file, force = true)

        # The synchronous writer waits for the data load.
        o, cb = out_setup(file; async_write = false)
        holder, release = hold_nclock()
        done, task = finishes(() -> cb.affect!(out_integ(o, 0)), 0.5)
        @test !done
        notify(release)
        wait(holder)
        wait(task)
        cb.finalize(cb, nothing, 0.0, nothing)
        @test holds_records(file, o, 1)
        rm(file, force = true)
    end

    @testset "a write overlapping a background prefetch read" begin
        file = tempname() * ".nc"
        o, cb = out_setup(file; async_write = true)

        start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
        fs = GatedFS(start, finish)
        dom = DomainInfo(start, finish; lonrange = deg2rad(0.0):deg2rad(0.25):deg2rad(1.5),
            latrange = deg2rad(0.0):deg2rad(0.3):deg2rad(1.0), levrange = 1:1)
        itp = EarthSciData.DataSetInterpolator{Float64}(fs, "X", start, finish, dom;
            prefetch = true)
        buf = EarthSciData.make_data_buffer(itp)
        EarthSciData.lazyload!(itp, start + Minute(70), buf)
        @test itp.cache.prefetch.time == itp.cache.times[end] + Hour(1)
        wait(fs.entered)  # the prefetch is reading under `nclock`

        done, _ = finishes(() -> cb.affect!(out_integ(o, 0)), 30.0)
        @test done
        @test !istaskdone(o.pending)
        notify(fs.gate)
        wait(itp.cache.prefetch.task)
        cb.affect!(out_integ(o, 1))
        cb.finalize(cb, nothing, 0.0, nothing)
        @test holds_records(file, o, 2)
        @test !istaskfailed(itp.cache.prefetch.task)
        rm(file, force = true)
    end

    @testset "finalize with a write in flight" begin
        file = tempname() * ".nc"
        o, cb = out_setup(file; async_write = true)
        cb.affect!(out_integ(o, 0))
        wait(o.pending)
        holder, release = hold_nclock()
        cb.affect!(out_integ(o, 1))
        done, fin = finishes(() -> cb.finalize(cb, nothing, 0.0, nothing), 0.5)
        @test !done  # waiting for the write
        notify(release)
        wait(holder)
        wait(fin)
        @test !isopen(o.file)
        @test holds_records(file, o, 2)
        rm(file, force = true)
    end

    @testset "a failed write surfaces at finalize" begin
        file = tempname() * ".nc"
        o, cb = out_setup(file; async_write = true)
        cb.affect!(out_integ(o, 0))
        wait(o.pending)
        o.vars = Any[FailingVar(), o.vars[2]]
        cb.affect!(out_integ(o, 1))
        err = try
            cb.finalize(cb, nothing, 0.0, nothing)
            nothing
        catch e
            e
        end
        @test err isa TaskFailedException
        @test err.task.exception.msg == "injected write failure"
        @test !isopen(o.file)
        rm(file, force = true)
    end

    @testset "a failed write surfaces at the next output time" begin
        file = tempname() * ".nc"
        o, cb = out_setup(file; async_write = true)
        o.vars = Any[FailingVar(), o.vars[2]]
        cb.affect!(out_integ(o, 0))
        @test_throws TaskFailedException cb.affect!(out_integ(o, 1))
        cb.finalize(cb, nothing, 0.0, nothing)  # already reported
        @test !isopen(o.file)
        rm(file, force = true)
    end
end
