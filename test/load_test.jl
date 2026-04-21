using EarthSciData
using EarthSciMLBase
using EarthSciMLBase: DomainInfo
using Dates
using Dates: datetime2unix, DateTime, Second, Hour
using Interpolations: scale, interpolate, BSpline, Linear
using Random: randperm
using DynamicQuantities
using DynamicQuantities: @u_str
using Latexify: latexify
using ModelingToolkit
using ModelingToolkit: t, D
using OrdinaryDiffEqTsit5
using SymbolicIndexingInterface: setp, getsym
using Test
using Test: @inferred
using AllocCheck

struct DummyFileSet <: EarthSciData.FileSet
    start::DateTime
    finish::DateTime
end

function EarthSciData.DataFrequencyInfo(
        fs::DummyFileSet,
)::EarthSciData.DataFrequencyInfo
    frequency = Second(3 * 3600)
    centerpoints = collect((fs.start + frequency / 2):frequency:(fs.finish))
    EarthSciData.DataFrequencyInfo(fs.start, frequency, centerpoints)
end

_dummy_tv(fs, t) = (t - fs.start) / (fs.finish - fs.start)

function EarthSciData.loadslice!(
        cache::AbstractArray,
        fs::DummyFileSet,
        t::DateTime,
        varname
)
    dfi = EarthSciData.DataFrequencyInfo(fs)
    tt = dfi.centerpoints[EarthSciData.centerpoint_index(dfi, t)]
    v = _dummy_tv(fs, tt)
    cache[:, 1] .= [v, v * 0.5, v * 2.0]
    cache[:, 2] .= [v, v * 0.5, v * 2.0]
end
function EarthSciData.loadmetadata(fs::DummyFileSet, varname)
    return EarthSciData.MetaData(
        [[0.0, 0.5, 1.0], [0.0, 1.0]],
        "m",
        "description",
        ["x"],
        [3, 2],
        "+proj=longlat +datum=WGS84 +no_defs",
        1,
        2,
        -1,
        (false, false, false)
    )
end

struct BoundaryCacheTestFS <: EarthSciData.FileSet
    start::DateTime
    finish::DateTime
end

function EarthSciData.DataFrequencyInfo(fs::BoundaryCacheTestFS)::EarthSciData.DataFrequencyInfo
    frequency = Hour(1)
    centerpoints = collect(fs.start:frequency:fs.finish)
    EarthSciData.DataFrequencyInfo(fs.start, frequency, centerpoints)
end
function EarthSciData.loadslice!(cache::AbstractArray, fs::BoundaryCacheTestFS, t::DateTime, varname)
    fill!(cache, 1.0)
end
function EarthSciData.loadmetadata(fs::BoundaryCacheTestFS, varname)
    EarthSciData.MetaData(
        [[0.0, 1.0], [0.0, 1.0]],
        "m", "test", ["x", "y"], [2, 2],
        "+proj=longlat +datum=WGS84 +no_defs", 1, 2, -1, (false, false, false)
    )
end

struct SingletonDimFS <: EarthSciData.FileSet
    start::DateTime
    finish::DateTime
end

function EarthSciData.DataFrequencyInfo(
        fs::SingletonDimFS,
)::EarthSciData.DataFrequencyInfo
    frequency = Second(3 * 3600)
    centerpoints = collect((fs.start + frequency / 2):frequency:(fs.finish))
    EarthSciData.DataFrequencyInfo(fs.start, frequency, centerpoints)
end

_singleton_tv(fs, t) = (t - fs.start) / (fs.finish - fs.start)

function EarthSciData.loadslice!(
        cache::AbstractArray,
        fs::SingletonDimFS,
        t::DateTime,
        varname
)
    dfi = EarthSciData.DataFrequencyInfo(fs)
    tt = dfi.centerpoints[EarthSciData.centerpoint_index(dfi, t)]
    v = _singleton_tv(fs, tt)
    cache[:, :, 1] .= v  # Fill all lon/lat with same value, singleton lev
end

function EarthSciData.loadmetadata(fs::SingletonDimFS, varname)
    return EarthSciData.MetaData(
        [[0.0, 0.5, 1.0], [0.0, 1.0], [850.0]],  # 3 coords: lon, lat, lev (singleton)
        "m",
        "description",
        ["lon", "lat", "lev"],
        [3, 2, 1],  # varsize with singleton lev
        "+proj=longlat +datum=WGS84 +no_defs",
        1,  # xdim
        2,  # ydim
        3,  # zdim
        (false, false, false)  # staggering
    )
end

@testset "load" begin
    function setup()
        t = DateTime(2022, 5, 1)
        te = DateTime(2022, 5, 3)
        fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn", t, te)

        domain = DomainInfo(
            t,
            te;
            lonrange = deg2rad(-175.0):deg2rad(2.5):deg2rad(175.0),
            latrange = deg2rad(-85.0):deg2rad(2):deg2rad(85.0),
            levrange = 1:10
        )
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t, te, domain)
        return (; t, te, fs, domain, itp)
    end

    @testset "Load Basics" begin
        (; t, fs, itp) = setup()
        @test EarthSciData.url(fs, t) ==
              "https://geos-chem.s3-us-west-2.amazonaws.com/GEOS_4x5/GEOS_FP/2022/05/GEOSFP.20220501.A3dyn.4x5.nc"

        @test endswith(
            EarthSciData.localpath(fs, t),
            join(["GEOS_4x5", "GEOS_FP", "2022", "05", "GEOSFP.20220501.A3dyn.4x5.nc"], "/")
        )

        ti = EarthSciData.DataFrequencyInfo(fs)
        epp = EarthSciData.endpoints(ti)

        @test epp[begin] == (DateTime("2022-04-30T00:00:00"), DateTime("2022-04-30T03:00:00"))
        @test epp[end] == (DateTime("2022-05-03T21:00:00"), DateTime("2022-05-04T00:00:00"))

        metadata = EarthSciData.loadmetadata(fs, "U")
        @test metadata.varsize == [72, 46, 72]
        @test metadata.dimnames == ["lon", "lat", "lev"]

        @test String(latexify(itp)) == "\$GEOSFPFileSet.U\$"

        @test EarthSciData.dimnames(itp) == ["lon", "lat", "lev"]
        @test issetequal(EarthSciData.varnames(fs), ["U", "OMEGA", "RH", "DTRAIN", "V"])
    end

    @testset "grid" begin
        (; itp) = setup()
        @test itp.grid_size == (142, 86, 10)
        @test itp.grid_starts[1] ≈ deg2rad(-175.0 - 1.25)
        @test itp.grid_steps[1]  ≈ deg2rad(2.5)
        @test itp.grid_starts[2] ≈ deg2rad(-85.0)
        @test itp.grid_steps[2]  ≈ deg2rad(2)
        @test itp.grid_starts[3] ≈ 1.0
        @test itp.grid_steps[3]  ≈ 1.0
    end

    @testset "interpolation" begin
        (; itp) = setup()
        uvals = []
        times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
        for t in times
            push!(uvals, interp!(itp, t, deg2rad(1.0f0), deg2rad(0.0f0), 1.0f0))
        end
        for i in 4:3:(length(uvals) - 1)
            @test uvals[i]≈(uvals[i - 1] + uvals[i + 1]) / 2 atol=1e-2
        end
        want_uvals = [
            -0.07933916f0,
            0.03189625f0,
            0.079422876f0,
            0.06324073f0,
            0.047058582f0,
            -0.044040862f0,
            -0.21005762f0,
            -0.37607434f0,
            -0.53645617f0,
            -0.6912031f0
        ]
        @test uvals[1:10] ≈ want_uvals

        # Test that shuffling the times doesn't change the results.
        uvals2 = []
        idx = randperm(length(times))
        for t in times[idx]
            push!(uvals2, interp!(itp, t, deg2rad(1.0f0), deg2rad(0.0f0), 1.0f0))
        end
        @test uvals2 ≈ uvals[idx]
    end

    @testset "DummyFileSet" begin
        domain = DomainInfo(
            DateTime(2022, 5, 1),
            DateTime(2022, 5, 3);
            lonrange = deg2rad(-175.0):deg2rad(2.5):deg2rad(175.0),
            latrange = deg2rad(-85.0):deg2rad(2):deg2rad(85.0),
            levrange = 1:10
        )

        fs = DummyFileSet(DateTime(2022, 4, 30), DateTime(2022, 5, 4))

        @testset "big cache" begin
            @test_nowarn EarthSciData.DataSetInterpolator{Float32}(
                fs,
                "U",
                DateTime(2022, 5, 1),
                DateTime(2022, 5, 3),
                domain;
                stream = false
            )
        end

        itp = EarthSciData.DataSetInterpolator{Float32}(
            fs,
            "U",
            DateTime(2022, 5, 1),
            DateTime(2022, 5, 3),
            domain;
            stream = true
        )
        dfi = EarthSciData.DataFrequencyInfo(fs)

        answerdata = [_dummy_tv(fs, t) * v for t in dfi.centerpoints, v in [1.0, 0.5, 2.0]]

        grid = Tuple(
            EarthSciData.knots2range.([datetime2unix.(dfi.centerpoints), [0.0, 0.5, 1.0]]),
        )
        answer_itp = scale(interpolate(answerdata, BSpline(Linear())), grid)

        times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
        xs = [0.0f0, 0.25f0, 0.75f0]

        uvals = zeros(Float32, length(times), length(xs))
        answers = zeros(Float32, length(times), length(xs))
        for (i, tt) in enumerate(times)
            for (j, x) in enumerate(xs)
                uvals[i, j] = interp!(itp, tt, (x, x)...)
                answers[i, j] = answer_itp(datetime2unix(tt), x)
            end
        end

        @test uvals ≈ answers

        interp!(itp, times[end], xs[end], xs[end])
        @test length(itp.cache.times) == 2
        @test itp.cache.times ==
              [DateTime("2022-05-02T22:30:00"), DateTime("2022-05-03T01:30:00")]

        uvals = zeros(Float32, length(times), length(xs))
        answers = zeros(Float32, length(times), length(xs))
        for i in randperm(length(times))
            tt = times[i]
            for j in randperm(length(xs))
                x = xs[j]
                uvals[i, j] = interp!(itp, tt, x, x)
                answers[i, j] = answer_itp(datetime2unix(tt), x)
            end
        end
        @test uvals ≈ answers

        @testset "no stream" begin
            itp = EarthSciData.DataSetInterpolator{Float32}(
                fs,
                "U",
                DateTime(2022, 5, 1),
                DateTime(2022, 5, 2),
                domain;
                stream = false
            )

            uvals = zeros(Float32, length(times), length(xs))
            answers = zeros(Float32, length(times), length(xs))
            for (i, tt) in enumerate(times)
                for (j, x) in enumerate(xs)
                    uvals[i, j] = interp!(itp, tt, x, x)
                    answers[i, j] = answer_itp(datetime2unix(tt), x)
                end
            end

            @test uvals ≈ answers
        end
    end

    if !Sys.iswindows() # Allocation tests don't seem to work on windows.
        @testset "allocations" begin
            (; t, te, fs, domain) = setup()
            itp = EarthSciData.DataSetInterpolator{Float64}(fs, "U", t, te, domain)
            tt = DateTime(2022, 5, 1)
            interp!(itp, tt, 1.0, 0.0, 1.0)

            # AllocCheck.jl's safelist was built against pre-1.12 runtime
            # names; Julia 1.12+ emits `jl_get_pgcstack_static` for the GC
            # safepoint retrieval, which the old entry `get_pgcstack` no
            # longer matches.  These calls don't actually heap-allocate, so
            # drop them from the error list before asserting.
            is_real_alloc(e) = !(e isa AllocCheck.AllocatingRuntimeCall &&
                                 occursin("pgcstack", e.name))

            @test begin
                @check_allocs checkf(itp, t, loc1, loc2,
                    loc3) = EarthSciData.interp_unsafe(itp, t, loc1, loc2, loc3)

                real_errors = Any[]
                try
                    checkf(itp, tt, 1.0, 0.0, 1.0)
                catch err
                    append!(real_errors, filter(is_real_alloc, err.errors))
                end

                itp2 = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t, te, domain)
                interp!(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
                try
                    checkf(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
                catch err
                    append!(real_errors, filter(is_real_alloc, err.errors))
                end

                isempty(real_errors) ||
                    @warn "Allocation errors:\n$(real_errors)"
                isempty(real_errors)
            end
        end
    end

    @testset "interp_unsafe / interp_time_only are type-stable and non-allocating" begin
        # The RHS of every MTK-generated simulation calls these functions millions
        # of times per solve.  They must be both type-stable (so the compiler can
        # emit efficient code) and allocation-free (so the GC doesn't thrash).
        #
        # The `DataBufferType` wrapper is the load-bearing part: `interp_unsafe`
        # runs a forward through `data.data`, and if that access ever boxes
        # (because `data::Any` or `data::AbstractArray`) the whole thing becomes
        # dynamic and allocations go up.
        for T in (Float64, Float32)
            # ----- 4D (3 spatial + time) — atmospheric data -----
            data4 = rand(T, 10, 10, 10, 2)
            db4 = EarthSciData.DataBufferType(data4)
            fit = T(1.5)
            fi1, fi2, fi3 = T(5.3), T(5.7), T(5.2)
            extrap = T(1.0)

            # Type stability: @inferred throws if the return type is not concrete.
            @test @inferred(EarthSciData.interp_unsafe(db4, fit, fi1, fi2, fi3, extrap)) isa T
            @test @inferred(EarthSciData.interp_time_only(db4, fit, fi1, fi2, fi3, extrap)) isa
                  T

            # Allocation: zero heap allocations after warmup.
            EarthSciData.interp_unsafe(db4, fit, fi1, fi2, fi3, extrap)  # warmup
            EarthSciData.interp_time_only(db4, fit, fi1, fi2, fi3, extrap)
            @test (@allocated EarthSciData.interp_unsafe(
                db4, fit, fi1, fi2, fi3, extrap)) == 0
            @test (@allocated EarthSciData.interp_time_only(
                db4, fit, fi1, fi2, fi3, extrap)) == 0

            # ----- 3D (2 spatial + time) — emissions -----
            data3 = rand(T, 10, 10, 2)
            db3 = EarthSciData.DataBufferType(data3)
            @test @inferred(EarthSciData.interp_unsafe(db3, fit, fi1, fi2, extrap)) isa T
            @test @inferred(EarthSciData.interp_time_only(db3, fit, fi1, fi2, extrap)) isa T
            EarthSciData.interp_unsafe(db3, fit, fi1, fi2, extrap)
            EarthSciData.interp_time_only(db3, fit, fi1, fi2, extrap)
            @test (@allocated EarthSciData.interp_unsafe(db3, fit, fi1, fi2, extrap)) == 0
            @test (@allocated EarthSciData.interp_time_only(db3, fit, fi1, fi2, extrap)) == 0

            # ----- 2D (1 spatial + time) -----
            data2 = rand(T, 10, 2)
            db2 = EarthSciData.DataBufferType(data2)
            @test @inferred(EarthSciData.interp_unsafe(db2, fit, fi1, extrap)) isa T
            @test @inferred(EarthSciData.interp_time_only(db2, fit, fi1, extrap)) isa T
            EarthSciData.interp_unsafe(db2, fit, fi1, extrap)
            EarthSciData.interp_time_only(db2, fit, fi1, extrap)
            @test (@allocated EarthSciData.interp_unsafe(db2, fit, fi1, extrap)) == 0
            @test (@allocated EarthSciData.interp_time_only(db2, fit, fi1, extrap)) == 0
        end
    end

    @testset "Float32 DomainInfo → Float32 data buffer (no Float64 promotion)" begin
        # DomainInfo with Float32 u_proto — forces the element type through every
        # downstream allocation. This is the CPU-side dress rehearsal for GPU
        # execution: `similar(domain.u_proto, ...)` should preserve element type
        # without promoting to Float64, and the interpolation path should not
        # allocate Float64 intermediates.
        domain = DomainInfo(
            DateTime(2022, 1, 1),
            DateTime(2022, 1, 3);
            latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
            lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
            levrange = 1:73,
            u_proto = zeros(Float32, 0)
        )
        @test eltype(domain.u_proto) === Float32

        geosfp = GEOSFP("4x5", domain)

        # The `getdefault` of every _data parameter should be a Float32 Array
        # (MTK stores the raw default pre-conversion; the conversion to
        # `DataBufferType{Array{Float32,N}}` happens when `MTKParameters` is
        # built — verified below).
        ps = parameters(geosfp)
        data_ps = [p for p in ps if endswith(string(ModelingToolkit.getname(p)), "_data")]
        @test !isempty(data_ps)
        for p in data_ps
            default = ModelingToolkit.getdefault(p)
            @test default isa Array{Float32}
            @test eltype(default) === Float32
        end

        # Build a trivial wrapper system so ODEProblem/init work (GEOSFP alone has
        # no state variables) and verify the initialize callback loads data
        # without promoting the buffer.
        @variables _dummy(t) = 0.0f0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), geosfp)
        compiled = mtkcompile(_sys)
        prob = ODEProblem(compiled, [], (24.0 * 3600, 48.0 * 3600))
        integ = init(prob, Tsit5())

        # The `DataBufferType` parameters are declared with `@parameters
        # ::DataBufferType{...}` (see `_make_array_discrete`).  MTK routes
        # them into `p.nonnumeric` — not `p.discrete` — because their symtype
        # isn't numeric.  Within `nonnumeric` they're split into sub-buffers
        # by concrete type (one bucket per `DataBufferType{Array{Float32, N}}`
        # — separate buckets for 2D+t and 3D+t data arrays).  After the
        # initialize callback fires, the buffers should be populated with
        # real data, still Float32, no promotion.  We also check
        # `p.discrete` defensively in case a future MTK refactor
        # reclassifies.
        function scan_buffers(pbuf)
            all_f32 = true
            found_nonzero_f32 = false
            for bucket_group in (pbuf.nonnumeric, pbuf.discrete)
                for buf in bucket_group
                    T = eltype(buf)
                    T <: EarthSciData.DataBufferType || continue
                    for entry in buf
                        if !(entry.data isa Array{Float32})
                            all_f32 = false
                        end
                        if eltype(entry.data) !== Float32
                            all_f32 = false
                        end
                        if any(!iszero, entry.data)
                            found_nonzero_f32 = true
                        end
                    end
                end
            end
            return all_f32, found_nonzero_f32
        end
        all_f32, found_nonzero_f32 = scan_buffers(integ.p)
        @test all_f32
        @test found_nonzero_f32
    end

    @testset "interp_cache_times! boundary" begin
        domain = DomainInfo(
            DateTime(2024, 1, 1), DateTime(2024, 1, 2);
            lonrange = deg2rad(0.0):deg2rad(1.0):deg2rad(1.0),
            latrange = deg2rad(0.0):deg2rad(1.0):deg2rad(1.0),
            levrange = 1:1
        )
        fs = BoundaryCacheTestFS(DateTime(2024, 1, 1), DateTime(2024, 1, 2))
        itp = EarthSciData.DataSetInterpolator{Float64}(
            fs, "X", DateTime(2024, 1, 1), DateTime(2024, 1, 2), domain)

        # At the last centerpoint, should not throw BoundsError
        times = EarthSciData.interp_cache_times!(itp, DateTime(2024, 1, 2))
        @test length(times) <= length(itp.cache.times)
        @test times[end] == DateTime(2024, 1, 2)

        # At the first centerpoint, should also work
        times_first = EarthSciData.interp_cache_times!(itp, DateTime(2024, 1, 1))
        @test length(times_first) <= length(itp.cache.times)
        @test times_first[1] == DateTime(2024, 1, 1)
    end

    @testset "tuple_from_vals" begin
        @test EarthSciData.tuple_from_vals(1, 1, 2, 2, 3, 3) == (1, 2, 3)
        @test EarthSciData.tuple_from_vals(2, 2, 1, 1, 3, 3) == (1, 2, 3)
        @test EarthSciData.tuple_from_vals(3, 3, 2, 2, 1, 1) == (1, 2, 3)
    end

    @testset "knots2range singleton" begin
        r = EarthSciData.knots2range([5.0])
        @test length(r) == 1
        @test first(r) == 5.0
    end

    @testset "DummyFileSet singleton dim" begin
        domain = DomainInfo(
            DateTime(2022, 5, 1),
            DateTime(2022, 5, 3);
            lonrange = deg2rad(-175.0):deg2rad(2.5):deg2rad(175.0),
            latrange = deg2rad(-85.0):deg2rad(2):deg2rad(85.0),
            levrange = 1:1  # singleton level dimension
        )

        fs = SingletonDimFS(DateTime(2022, 4, 30), DateTime(2022, 5, 4))

        # Should not throw an error during construction
        itp = EarthSciData.DataSetInterpolator{Float32}(
            fs,
            "U",
            DateTime(2022, 5, 1),
            DateTime(2022, 5, 3),
            domain;
            stream = true
        )

        # Should be able to interpolate without error
        val = EarthSciData.interp!(
            itp, DateTime(2022, 5, 1, 1), deg2rad(0.25f0), deg2rad(0.5f0), 1.0f0)
        @test !isnan(val)
        @test isfinite(val)
    end
end
