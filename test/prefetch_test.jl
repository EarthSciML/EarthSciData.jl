using EarthSciData
using EarthSciMLBase
using EarthSciMLBase: DomainInfo
using Dates
using Dates: datetime2unix
using ModelingToolkit
using Test

# Background prefetch of the next data record, the event path's buffer swap,
# and the two-entry affect cache.
#
# The synthetic `PrefetchFS` returns fields that vary in space and time, so the
# regridder does real arithmetic and `==` between prefetched and synchronously
# loaded windows is a meaningful bit-identity check. It records which task
# performed each load, can hold the load of one record until a gate opens, and
# can make the next loads of one record fail.

struct PrefetchFS <: EarthSciData.FileSet
    start::DateTime
    finish::DateTime
    freq::Dates.Period
    monthly::Bool
    main::Task
    loads::Vector{Tuple{DateTime, Bool}}   # (record, loaded on the main task)
    loads_lock::ReentrantLock
    gate::Base.RefValue{Any}               # `nothing` or `(record, Base.Event)`
    fail_time::Base.RefValue{DateTime}
    fail_left::Threads.Atomic{Int}
end
function PrefetchFS(start, finish; freq = Hour(1), monthly = false)
    PrefetchFS(start, finish, freq, monthly, current_task(), Tuple{DateTime, Bool}[],
        ReentrantLock(), Ref{Any}(nothing), Ref(DateTime(0)), Threads.Atomic{Int}(0))
end

function EarthSciData.DataFrequencyInfo(fs::PrefetchFS)
    if fs.monthly
        starts = collect(fs.start:Month(1):(fs.finish - Month(1)))
        return EarthSciData.DataFrequencyInfo(fs.start, Month(1),
            [t + (t + Month(1) - t) / 2 for t in starts])
    end
    half = Millisecond(Dates.toms(fs.freq) ÷ 2)
    EarthSciData.DataFrequencyInfo(fs.start, fs.freq,
        collect((fs.start + half):(fs.freq):(fs.finish)))
end

_pf_tv(t::DateTime) = Dates.value(t - DateTime(2024, 1, 1)) / 3.6e6

function EarthSciData.loadslice!(cache::AbstractArray, fs::PrefetchFS, t::DateTime, varname)
    lock(fs.loads_lock) do
        push!(fs.loads, (t, current_task() === fs.main))
    end
    g = fs.gate[]
    g !== nothing && g[1] == t && wait(g[2])
    if t == fs.fail_time[] && Threads.atomic_sub!(fs.fail_left, 1) > 0
        error("injected load failure at $t")
    end
    v = _pf_tv(t)
    for j in axes(cache, 2), i in axes(cache, 1)

        cache[i, j] = v * (1 + 0.25 * i) + sin(0.7 * j + v)
    end
    return nothing
end

function EarthSciData.loadmetadata(fs::PrefetchFS, varname)
    EarthSciData.MetaData(
        [[0.0, 0.01, 0.02, 0.03], [0.0, 0.01, 0.02]],
        "m", "test", ["x", "y"], [4, 3],
        "+proj=longlat +datum=WGS84 +no_defs", 1, 2, -1, (false, false, false))
end

sync_loads(fs::PrefetchFS) = lock(() -> [t for (t, m) in fs.loads if m], fs.loads_lock)
function background_loads(fs::PrefetchFS)
    lock(() -> [t for (t, m) in fs.loads if !m], fs.loads_lock)
end

# Wait for an interpolator's outstanding prefetch, if any.
function wait_prefetch(itp)
    pf = itp.cache.prefetch
    pf === nothing || EarthSciData._wait_quietly(pf.task)
end

function pf_domain(start, finish)
    DomainInfo(start, finish;
        lonrange = deg2rad(0.0):deg2rad(0.25):deg2rad(1.5),
        latrange = deg2rad(0.0):deg2rad(0.3):deg2rad(1.0),
        levrange = 1:1)
end

# The event path's two buffers: `lazyload_swap!` never writes `active`.
mutable struct SwapBufs
    active::Any
    spare::Any
end
SwapBufs(itp) = SwapBufs(EarthSciData.make_data_buffer(itp), nothing)
function swapload!(itp, t, sb::SwapBufs)
    new = EarthSciData.lazyload_swap!(itp, t, sb.active, sb.spare)
    if new !== sb.active
        sb.spare = sb.active
        sb.active = new
    end
    return sb.active
end

# The slots of `buf` that hold `itp`'s current window.
window(itp, buf) = copy(selectdim(buf, ndims(buf), 1:length(itp.cache.times)))

# Points spread over the model grid, in model coordinates.
function sample_points(itp)
    [(itp.grid_starts[1] + a * itp.grid_steps[1] * (itp.grid_size[1] - 1),
         itp.grid_starts[2] + b * itp.grid_steps[2] * (itp.grid_size[2] - 1))
     for a in (0.0, 0.37, 1.0), b in (0.0, 0.61, 1.0)]
end

# Load `times` in order into a synchronous interpolator, a prefetching one used
# in place, and a prefetching one used through `lazyload_swap!`, and check after
# every call that all three hold the same window, bit for bit.
function check_identical_walk(mkfs, start, finish, times)
    domain = pf_domain(start, finish)
    fss = (mkfs(), mkfs(), mkfs())
    itp_s = EarthSciData.DataSetInterpolator{Float64}(fss[1], "X", start, finish, domain;
        prefetch = false)
    itp_p = EarthSciData.DataSetInterpolator{Float64}(fss[2], "X", start, finish, domain;
        prefetch = true)
    itp_w = EarthSciData.DataSetInterpolator{Float64}(fss[3], "X", start, finish, domain;
        prefetch = true)
    buf_s = EarthSciData.make_data_buffer(itp_s)
    buf_p = EarthSciData.make_data_buffer(itp_p)
    sb = SwapBufs(itp_w)
    pts = sample_points(itp_s)
    ok = true
    for t in times
        EarthSciData.lazyload!(itp_s, t, buf_s)
        EarthSciData.lazyload!(itp_p, t, buf_p)
        buf_w = swapload!(itp_w, t, sb)
        ok &= itp_p.cache.times == itp_s.cache.times == itp_w.cache.times
        ok &= window(itp_p, buf_p) == window(itp_s, buf_s)
        ok &= window(itp_w, buf_w) == window(itp_s, buf_s)
        for (x, y) in pts
            v = EarthSciData.interp_unsafe(itp_s, buf_s, t, x, y)
            ok &= EarthSciData.interp_unsafe(itp_p, buf_p, t, x, y) == v
            ok &= EarthSciData.interp_unsafe(itp_w, buf_w, t, x, y) == v
        end
    end
    wait_prefetch(itp_p)
    wait_prefetch(itp_w)
    return ok, fss, (itp_s, itp_p, itp_w)
end

@testset "prefetch: values identical to synchronous loads" begin
    start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
    for (label, freq, step) in (("hourly", Hour(1), Minute(20)),
        ("3-hourly", Hour(3), Minute(50)))
        @testset "$label forward walk" begin
            times = collect((start + Hour(2)):step:(start + Hour(16)))
            ok, fss, itps = check_identical_walk(
                () -> PrefetchFS(start, finish; freq = freq), start, finish, times)
            @test ok
            # Only the first window was read on the solver's task: every later
            # record came from a prefetch.
            itp_p = itps[2]
            @test length(sync_loads(fss[2])) == length(EarthSciData.interp_cache_times!(
                itp_p, first(times)))
            @test length(background_loads(fss[2])) >= 3
            # Each record is read once with or without prefetch, plus at most the
            # one prefetched past the last window.
            @test length(fss[2].loads) <= length(fss[1].loads) + 1
            @test length(sync_loads(fss[3])) == length(sync_loads(fss[2]))
        end
    end

    @testset "monthly (unevenly spaced) forward walk" begin
        ms, mf = DateTime(2024, 1, 1), DateTime(2024, 8, 1)
        s, f = DateTime(2024, 1, 20), DateTime(2024, 7, 10)
        cps = EarthSciData.DataFrequencyInfo(PrefetchFS(ms, mf; monthly = true)).centerpoints
        times = sort(unique(vcat(collect(s:Day(4):f), filter(c -> s <= c <= f, cps))))
        ok, fss, _ = check_identical_walk(
            () -> PrefetchFS(ms, mf; monthly = true), s, f, times)
        @test ok
        @test length(sync_loads(fss[2])) <= 3
    end
end

@testset "prefetch: window boundaries, missing slices and first load" begin
    start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
    # First load in the dataset's first bucket (2-slot window), a dip back
    # inside the window, a jump back past the lookback slot (one missing slot,
    # the in-flight prefetch is not the record needed), a jump forward past
    # the whole window (every slot missing), and a run to the dataset end
    # (window re-anchored, nothing left to prefetch).
    times = [start + Minute(40), start + Minute(50), start + Hour(2), start + Hour(5),
        start + Hour(4) + Minute(40), start + Hour(2) + Minute(20), start + Hour(9),
        start + Hour(9) + Minute(30), start + Hour(13), start + Hour(13),
        finish - Hour(2), finish - Minute(40), finish - Minute(35), finish - Minute(30),
        finish - Minute(30)]
    ok, fss, itps = check_identical_walk(
        () -> PrefetchFS(start, finish; freq = Hour(1)), start, finish, times)
    @test ok
    itp_p = itps[2]
    # The window at the dataset end holds its last record.
    @test itp_p.cache.times[end] == EarthSciData.DataFrequencyInfo(fss[2]).centerpoints[end]
end

@testset "prefetch: reads during a prefetch see the published window" begin
    start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
    domain = pf_domain(start, finish)
    ref_fs = PrefetchFS(start, finish)
    ref = EarthSciData.DataSetInterpolator{Float64}(ref_fs, "X", start, finish, domain;
        prefetch = false)
    ref_buf = EarthSciData.make_data_buffer(ref)

    fs = PrefetchFS(start, finish)
    itp = EarthSciData.DataSetInterpolator{Float64}(fs, "X", start, finish, domain;
        prefetch = true)
    t0 = start + Hour(6) + Minute(10)              # window [05:30, 06:30, 07:30]
    gated = start + Hour(8) + Minute(30)           # the record prefetched next
    gate = Base.Event()
    fs.gate[] = (gated, gate)
    sb = SwapBufs(itp)
    swapload!(itp, t0, sb)
    pf = itp.cache.prefetch
    @test pf !== nothing && pf.time == gated
    @test !istaskdone(pf.task)                     # held at the gate

    published = sb.active
    snapshot = copy(published)
    pts = sample_points(itp)
    read_times = [start + Hour(5) + Minute(45), t0, t0 + Minute(30),
        start + Hour(7) + Minute(29)]
    # The reference holds the same window, so values match exactly.
    expected = Dict{Tuple{DateTime, Int}, Float64}()
    EarthSciData.lazyload!(ref, t0, ref_buf)
    @test ref.cache.times == itp.cache.times
    for t in read_times
        EarthSciData.lazyload!(ref, t, ref_buf)
        for (k, (x, y)) in enumerate(pts)
            expected[(t, k)] = EarthSciData.interp_unsafe(ref, ref_buf, t, x, y)
        end
    end
    # Concurrent readers of the published buffer while the prefetch is held.
    function read_all(n)
        ok = true
        for _ in 1:n, t in read_times

            EarthSciData.lazyload_swap!(itp, t, published, nothing) === published ||
                (ok = false)
            for (k, (x, y)) in enumerate(pts)
                ok &= EarthSciData.interp_unsafe(itp, published, t, x, y) ==
                      expected[(t, k)]
            end
        end
        ok
    end
    readers = [Threads.@spawn read_all(200) for _ in 1:4]
    @test all(fetch.(readers))
    @test !istaskdone(pf.task)

    # A window move waits for the held prefetch; readers keep using the
    # published buffer meanwhile, and it is never written.
    t_adv = start + Hour(7) + Minute(30)
    mover = Threads.@spawn swapload!(itp, t_adv, sb)
    readers = [Threads.@spawn read_all(50) for _ in 1:4]
    @test all(fetch.(readers))
    notify(gate)
    newbuf = fetch(mover)
    @test newbuf !== published
    @test published == snapshot
    EarthSciData.lazyload!(ref, t_adv, ref_buf)
    @test itp.cache.times == ref.cache.times
    @test window(itp, newbuf) == window(ref, ref_buf)
    # The gated record came from the prefetch, not a synchronous reload.
    @test gated ∉ sync_loads(fs)
    wait_prefetch(itp)
end

@testset "prefetch: a failed prefetch falls back to a synchronous load" begin
    start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
    domain = pf_domain(start, finish)
    t0 = start + Hour(6) + Minute(10)
    t_adv = start + Hour(7) + Minute(30)
    failing = start + Hour(8) + Minute(30)

    ref = EarthSciData.DataSetInterpolator{Float64}(PrefetchFS(start, finish), "X",
        start, finish, domain; prefetch = false)
    ref_buf = EarthSciData.make_data_buffer(ref)
    EarthSciData.lazyload!(ref, t_adv, ref_buf)

    # Transient: the prefetch fails, the synchronous retry succeeds.
    fs = PrefetchFS(start, finish)
    fs.fail_time[] = failing
    fs.fail_left[] = 1
    itp = EarthSciData.DataSetInterpolator{Float64}(fs, "X", start, finish, domain;
        prefetch = true)
    buf = EarthSciData.make_data_buffer(itp)
    EarthSciData.lazyload!(itp, t0, buf)
    wait_prefetch(itp)
    @test istaskfailed(itp.cache.prefetch.task)
    @test_logs (:warn, r"Background load of X") match_mode=:any EarthSciData.lazyload!(
        itp, t_adv, buf)
    @test failing ∈ sync_loads(fs)
    @test itp.cache.times == ref.cache.times
    @test window(itp, buf) == window(ref, ref_buf)

    # Persistent: the synchronous retry fails too, and its error is thrown.
    fs2 = PrefetchFS(start, finish)
    fs2.fail_time[] = failing
    fs2.fail_left[] = 2
    itp2 = EarthSciData.DataSetInterpolator{Float64}(fs2, "X", start, finish, domain;
        prefetch = true)
    sb = SwapBufs(itp2)
    swapload!(itp2, t0, sb)
    wait_prefetch(itp2)
    err = try
        swapload!(itp2, t_adv, sb)
        nothing
    catch e
        e
    end
    @test err isa ErrorException && occursin("injected load failure", err.msg)
end

@testset "affect: concurrent t0/tf calls, correct results, lock-free hits" begin
    start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
    # The event requires the records to cover the simulation span.
    dstart, dfinish = start + Hour(2), finish - Hour(2)
    domain = pf_domain(dstart, dfinish)
    @parameters pa_data pa_tstart pa_tstep pb_data pb_tstart pb_tstep
    fs_a = PrefetchFS(start, finish; freq = Hour(1))
    fs_b = PrefetchFS(start, finish; freq = Hour(3))
    itp_a = EarthSciData.DataSetInterpolator{Float64}(fs_a, "X", dstart, dfinish, domain)
    itp_b = EarthSciData.DataSetInterpolator{Float64}(fs_b, "X", dstart, dfinish, domain)
    mkinfo(d, ts, tst, itp, n) = (data_sym = d, tstart_sym = ts, tstep_sym = tst,
        itp = itp, var_sym = n, data_eltype = Float64, live = Ref(true),
        preloaded_buf = Ref{Any}(nothing))
    infos = [mkinfo(pa_data, pa_tstart, pa_tstep, itp_a, :PA),
        mkinfo(pb_data, pb_tstart, pb_tstep, itp_b, :PB)]
    aff = EarthSciData.build_interp_event(infos, dstart).affect
    f, ctx = aff.f, aff.ctx
    cache = getfield(f, :affect_cache)
    call(t) = f(nothing, nothing, ctx, (; t = datetime2unix(t) - datetime2unix(dstart),
        f = nothing))
    call(dstart)  # first fire: allocates and loads the buffers

    # Exact reference values from separate synchronous interpolators.
    refs = [EarthSciData.DataSetInterpolator{Float64}(PrefetchFS(start, finish; freq = fr),
                "X", dstart, dfinish, domain; prefetch = false)
            for fr in (Hour(1), Hour(3))]
    ref_bufs = [EarthSciData.make_data_buffer(r) for r in refs]
    pts = sample_points(itp_a)
    function reference(t)
        [begin
             EarthSciData.lazyload!(refs[k], t, ref_bufs[k])
             [EarthSciData.interp_unsafe(refs[k], ref_bufs[k], t, x, y) for (x, y) in pts]
         end
         for k in 1:2]
    end
    # Values that a solver reading the parameters of `nt` sees at time `t`.
    function seen(nt, t)
        tu = datetime2unix(t)
        [[begin
              data, ts, tst = nt[3k - 2].data, nt[3k - 1], nt[3k]
              fis = (1 + (x - itps.grid_starts[1]) / itps.grid_steps[1],
                  1 + (y - itps.grid_starts[2]) / itps.grid_steps[2])
              EarthSciData.interp_unsafe(data, 1 + (tu - ts) / tst, fis..., 1.0)
          end
          for (x, y) in pts]
         for (k, itps) in ((1, itp_a), (2, itp_b))]
    end

    dt = Minute(20)
    ntasks = 8
    all_correct = true
    hits_lock_free = true
    hits_cached = true
    swaps = 0
    for t0 in dstart:dt:(dstart + Hour(9))
        tf = t0 + dt
        before = (copy(infos[1].preloaded_buf[]), copy(infos[2].preloaded_buf[]))
        bufs_before = (infos[1].preloaded_buf[], infos[2].preloaded_buf[])
        # Threads at the step start and at the step end, interleaved.
        results = fetch.([Threads.@spawn begin
                              out = Tuple{DateTime, Any}[]
                              for j in 1:6
                                  t = isodd(i + j) ? t0 : tf
                                  push!(out, (t, call(t)))
                              end
                              out
                          end
                          for i in 1:ntasks])
        ref0, reff = reference(t0), reference(tf)
        for out in results, (t, nt) in out

            exp = t == t0 ? ref0 : reff
            got = seen(nt, t)
            all_correct &= all(isapprox.(got[1], exp[1]; rtol = 1e-12)) &&
                           all(isapprox.(got[2], exp[2]; rtol = 1e-12))
        end
        # A buffer that was swapped out keeps its contents.
        for k in 1:2
            if infos[k].preloaded_buf[] !== bufs_before[k]
                swaps += 1
                all_correct &= bufs_before[k] == before[k]
            end
        end
        # Both times are now cached: with the build lock held elsewhere, repeat
        # calls must still return, with the cached results.
        n0, nf = call(t0), call(tf)
        lock(cache.lock)
        try
            hit_tasks = [Threads.@spawn [call(isodd(j) ? t0 : tf) for j in 1:20]
                         for _ in 1:ntasks]
            hits_lock_free &= timedwait(() -> all(istaskdone, hit_tasks), 60.0) === :ok
            if hits_lock_free
                for r in fetch.(hit_tasks), (j, nt) in enumerate(r)

                    hits_cached &= nt === (isodd(j) ? n0 : nf)
                end
            end
        finally
            unlock(cache.lock)
        end
    end
    @test all_correct
    @test hits_lock_free
    @test hits_cached
    @test swaps >= 10   # hourly records crossed at 03:30…10:30, 3-hourly at 04:30, 07:30, 10:30
    # After warm-up, records came from prefetches, not synchronous loads.
    @test length(sync_loads(fs_a)) <= 3
    @test length(sync_loads(fs_b)) <= 3
end

# The event rebuilt over the live interpolators (what the convert-time factory
# puts in place of the loader's own event) must leave the same parameter values
# in place as the event over all interpolators, at every time, although it no
# longer fires at the time stops only a pruned interpolator had.
@testset "live event: same buffers as the event over all interpolators" begin
    start, finish = DateTime(2024, 1, 1), DateTime(2024, 1, 2)
    dstart, dfinish = start + Hour(3), finish - Hour(3)
    domain = pf_domain(dstart, dfinish)
    t_ref = datetime2unix(dstart)
    # PA hourly and PB 3-hourly stay live; PC (2-hourly, stops at odd hours that
    # neither of the others has) is pruned.
    names = (:PA, :PB, :PC)
    freqs = (Hour(1), Hour(3), Hour(2))
    sfx = ("_data", "_tstart", "_tstep")
    function mkinfos(prefetch)
        infos = Any[]
        for (n, fr) in zip(names, freqs)
            p = lowercase(string(n))
            d, ts, tst = [only(@parameters $(Symbol(p, s))) for s in sfx]
            itp = EarthSciData.DataSetInterpolator{Float64}(
                PrefetchFS(start, finish; freq = fr), "X", dstart, dfinish, domain;
                prefetch = prefetch)
            push!(infos,
                (data_sym = d, tstart_sym = ts, tstep_sym = tst, itp = itp,
                    var_sym = n, data_eltype = Float64, live = Ref(true),
                    preloaded_buf = Ref{Any}(nothing), mask_settled = Ref(false)))
        end
        infos[3].live[] = false
        EarthSciData._settle_mask!(infos)
        return infos
    end
    keys_of(n) = Tuple(Symbol(lowercase(string(n)), s) for s in sfx)
    stops(infos) = sort(unique(vcat([EarthSciData.get_tstops(i.itp, dstart)
                                     for i in infos]...))) .- t_ref
    call(aff, t) = aff.f(nothing, nothing, aff.ctx, (; t = t, f = nothing))

    for prefetch in (true, false)
        @testset "prefetch = $prefetch" begin
            full_infos, live_infos = mkinfos(prefetch), mkinfos(prefetch)
            full = EarthSciData.build_interp_event(full_infos, dstart)
            ev = EarthSciData.live_interp_event(live_infos, dstart)
            @test ev isa ModelingToolkit.SymbolicDiscreteCallback

            # Only PA and PB appear: modified parameters, context, keys, stops.
            aff = ev.affect
            @test aff.mod_syms == collect((keys_of(:PA)..., keys_of(:PB)...))
            @test length(full.affect.mod_syms) == 9
            @test keys(aff.ctx) == (:itp_PA, :itp_PB)
            @test aff.ctx.itp_PA === live_infos[1].itp
            @test getfield(aff.f, :per_interp_keys) == [keys_of(:PA), keys_of(:PB)]
            @test sort(ev.conditions) == stops(live_infos[1:2])
            @test sort(full.conditions) == stops(full_infos)
            pc_only = setdiff(stops(live_infos[3:3]), stops(live_infos[1:2]))
            @test !isempty(pc_only) && isempty(intersect(pc_only, ev.conditions))
            @test ev.initialize === aff

            # Each event fires at its own stops (and at 0, the initialize fire);
            # at every query time the parameters each one last wrote must agree
            # bit for bit.
            span = datetime2unix(dfinish) - t_ref
            fire_full = sort(filter(s -> 0 < s <= span, full.conditions))
            fire_live = sort(filter(s -> 0 < s <= span, ev.conditions))
            nt_full, nt_live = call(full.affect, 0.0), call(aff, 0.0)
            identical = true
            nchecked = 0
            for q in 0.0:600.0:span
                while !isempty(fire_full) && first(fire_full) <= q
                    nt_full = call(full.affect, popfirst!(fire_full))
                end
                while !isempty(fire_live) && first(fire_live) <= q
                    nt_live = call(aff, popfirst!(fire_live))
                end
                identical &= keys(nt_live) == keys(nt_full) ==
                             (keys_of(:PA)..., keys_of(:PB)...)
                for k in keys(nt_live)
                    a, b = nt_full[k], nt_live[k]
                    identical &= a isa EarthSciData.DataBufferType ?
                                 a.data == b.data : a === b
                end
                nchecked += 1
            end
            @test identical
            @test nchecked > 100
            # The pruned interpolator was never loaded by either event.
            @test full_infos[3].preloaded_buf[] === nothing
            @test live_infos[3].preloaded_buf[] === nothing
            @test !full_infos[3].itp.cache.initialized
            @test !live_infos[3].itp.cache.initialized
            foreach(i -> wait_prefetch(i.itp), vcat(full_infos, live_infos))
        end
    end

    # Nothing to rebuild when every interpolator is live, or none is.
    infos = mkinfos(false)
    @test EarthSciData.live_interp_event(infos[1:2], dstart) === nothing
    foreach(i -> i.live[] = false, infos)
    @test EarthSciData.live_interp_event(infos, dstart) === nothing
end

# Real data: GEOS-FP (A1 hourly, A3dyn 3-hourly averages, I3 3-hourly
# instantaneous) and NEI 2016 monthly emissions. Prefetched windows must equal
# synchronously loaded ones bit for bit across consecutive data times.
function real_identical_walk(mkitp, times)
    itp_s = mkitp(false)
    itp_w = mkitp(true)
    buf_s = EarthSciData.make_data_buffer(itp_s)
    sb = SwapBufs(itp_w)
    ok = true
    nswap = 0
    for t in times
        EarthSciData.lazyload!(itp_s, t, buf_s)
        old = sb.active
        buf_w = swapload!(itp_w, t, sb)
        nswap += buf_w !== old
        ok &= itp_w.cache.times == itp_s.cache.times
        ok &= window(itp_w, buf_w) == window(itp_s, buf_s)
    end
    wait_prefetch(itp_w)
    return ok, nswap
end

@testset "prefetch: GEOS-FP windows identical with and without prefetch" begin
    start, finish = DateTime(2016, 5, 1), DateTime(2016, 5, 2, 6)
    domain = DomainInfo(start, finish;
        lonrange = deg2rad(-130.0):deg2rad(2.5):deg2rad(-60.0),
        latrange = deg2rad(20.0):deg2rad(2):deg2rad(56.0),
        levrange = 1:10)
    times = collect((start + Hour(1)):Minute(30):(finish - Hour(1)))
    for (filetype, varname) in (("A1", "PBLH"), ("A3dyn", "U"), ("I3", "T"))
        @testset "$filetype $varname" begin
            fs = EarthSciData.GEOSFPFileSet("4x5", filetype, start, finish)
            mk(pf) = EarthSciData.DataSetInterpolator{Float64}(fs, varname, start, finish,
                domain; prefetch = pf)
            ok, nswap = real_identical_walk(mk, times)
            @test ok
            @test nswap >= (filetype == "A1" ? 25 : 7)
        end
    end
end

@testset "prefetch: NEI monthly windows identical with and without prefetch" begin
    start, finish = DateTime(2016, 2, 1), DateTime(2016, 5, 31)
    domain = DomainInfo(start, finish;
        lonrange = deg2rad(-125.0):deg2rad(2.5):deg2rad(-65.0),
        latrange = deg2rad(25.0):deg2rad(2):deg2rad(50.0),
        levrange = 1:2)
    fs = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", start, finish)
    rg = EarthSciData.regridder(fs, EarthSciData.loadmetadata(fs, "NOX"), domain)
    mk(pf) = EarthSciData.DataSetInterpolator{Float64}(fs, "NOX", start, finish, domain;
        regrid_f = rg, prefetch = pf)
    cps = EarthSciData.DataFrequencyInfo(fs).centerpoints
    times = sort(unique(vcat(collect((start + Day(1)):Day(5):(finish - Day(1))),
        filter(c -> start < c < finish, cps))))
    ok, nswap = real_identical_walk(mk, times)
    @test ok
    @test nswap >= 3
end
