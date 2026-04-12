@testsnippet LoadSetup begin
    using EarthSciMLBase
    using Dates

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
end

@testitem "Load Basics" setup=[LoadSetup] begin
    using Latexify: latexify
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

@testitem "grid" setup=[LoadSetup] begin
    grd = EarthSciData._model_grid(itp)
    length.(grd) == (142, 86, 10)
    grd[1] ≈ deg2rad(-175.0 - 1.25):deg2rad(2.5):deg2rad(175.0 + 1.25)
    grd[2] ≈ deg2rad(-85.0):deg2rad(2):deg2rad(85.0)
    grd[3] ≈ 1:1.0:10
end

@testitem "interpolation" setup=[LoadSetup] begin
    using Random: randperm
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

@testitem "DummyFileSet" begin
    using EarthSciMLBase: DomainInfo
    using Dates: datetime2unix, DateTime, Second, Hour
    using Interpolations: scale, interpolate, BSpline, Linear
    using Random: randperm
    using DynamicQuantities: @u_str

    domain = DomainInfo(
        DateTime(2022, 5, 1),
        DateTime(2022, 5, 3);
        lonrange = deg2rad(-175.0):deg2rad(2.5):deg2rad(175.0),
        latrange = deg2rad(-85.0):deg2rad(2):deg2rad(85.0),
        levrange = 1:10
    )

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

    tv(fs, t) = (t - fs.start) / (fs.finish - fs.start)

    function EarthSciData.loadslice!(
            cache::AbstractArray,
            fs::DummyFileSet,
            t::DateTime,
            varname
    )
        dfi = EarthSciData.DataFrequencyInfo(fs)
        tt = dfi.centerpoints[EarthSciData.centerpoint_index(dfi, t)]
        v = tv(fs, tt)
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

    answerdata = [tv(fs, t) * v for t in dfi.centerpoints, v in [1.0, 0.5, 2.0]]

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
        itp = EarthSciData.DataSetInterpolator{Float64}(fs, "U", t, te, domain)
        tt = DateTime(2022, 5, 1)
        interp!(itp, tt, 1.0, 0.0, 1.0)

        @test begin
            @check_allocs checkf(itp, t, loc1, loc2,
                loc3) = EarthSciData.interp_unsafe(itp, t, loc1, loc2, loc3)

            try
                checkf(itp, tt, 1.0, 0.0, 1.0)
            catch err
                @warn err.errors
                rethrow(err)
            end

            itp2 = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t, te, domain)
            interp!(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
            checkf(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
            true
        end
    end
end

@testitem "Float32 DomainInfo → Float32 data buffer (no Float64 promotion)" begin
    using EarthSciData
    using EarthSciMLBase
    using ModelingToolkit
    using ModelingToolkit: t, D
    using Dates
    using DynamicQuantities
    using OrdinaryDiffEqTsit5
    using SymbolicIndexingInterface: setp, getsym

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

    # The `@discretes`-declared data buffers live in `p.discrete`, split into
    # sub-buffers by symtype (one bucket per distinct concrete
    # `DataBufferType{Array{Float32, N}}` — separate buckets for 2D+t and
    # 3D+t data arrays). After the initialize callback fires, the buffers
    # should be populated with real data, still Float32, no promotion.
    pbuf = integ.p
    found_nonzero_f32 = false
    for buf in pbuf.discrete
        T = eltype(buf)
        T <: EarthSciData.DataBufferType || continue
        for entry in buf
            @test entry.data isa Array{Float32}
            @test eltype(entry.data) === Float32
            if any(!iszero, entry.data)
                found_nonzero_f32 = true
            end
        end
    end
    @test found_nonzero_f32
end

@testitem "interp_cache_times! boundary" begin
    using EarthSciData
    using EarthSciMLBase: DomainInfo
    using Dates: DateTime, Second, Hour

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

@testitem "tuple_from_vals" begin
    @test EarthSciData.tuple_from_vals(1, 1, 2, 2, 3, 3) == (1, 2, 3)
    @test EarthSciData.tuple_from_vals(2, 2, 1, 1, 3, 3) == (1, 2, 3)
    @test EarthSciData.tuple_from_vals(3, 3, 2, 2, 1, 1) == (1, 2, 3)
end

@testitem "knots2range singleton" begin
    r = EarthSciData.knots2range([5.0])
    @test length(r) == 1
    @test first(r) == 5.0
end

@testitem "create_interpolator! with singleton dims" begin
    using EarthSciData
    using Interpolations: BSpline, Linear, interpolate!, scale
    using Dates: DateTime, Hour, datetime2unix

    # 2D spatial with one singleton dim + time
    coords = (0.0:0.1:0.3, 0.0:1.0:0.0)  # dim 2 is singleton (length 1)
    times = [DateTime(2024, 1, 1) + Hour(i) for i in 0:1]
    data = ones(Float32, 4, 1, 2)
    interp_cache = similar(data)

    grid, itp = EarthSciData.create_interpolator!(interp_cache, data, coords, times)
    @test length(grid) == 3
    @test length(grid[2]) == 2  # singleton padded to 2

    # Query should work — value should be 1.0 everywhere
    @test itp(0.1, 0.5, datetime2unix(times[1])) ≈ 1.0f0
end

@testitem "DummyFileSet singleton dim" begin
    using EarthSciMLBase: DomainInfo
    using Dates: datetime2unix, DateTime, Second, Hour
    using Interpolations: scale, interpolate, BSpline, Linear

    domain = DomainInfo(
        DateTime(2022, 5, 1),
        DateTime(2022, 5, 3);
        lonrange = deg2rad(-175.0):deg2rad(2.5):deg2rad(175.0),
        latrange = deg2rad(-85.0):deg2rad(2):deg2rad(85.0),
        levrange = 1:1  # singleton level dimension
    )

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

    tv(fs, t) = (t - fs.start) / (fs.finish - fs.start)

    function EarthSciData.loadslice!(
            cache::AbstractArray,
            fs::SingletonDimFS,
            t::DateTime,
            varname
    )
        dfi = EarthSciData.DataFrequencyInfo(fs)
        tt = dfi.centerpoints[EarthSciData.centerpoint_index(dfi, t)]
        v = tv(fs, tt)
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
