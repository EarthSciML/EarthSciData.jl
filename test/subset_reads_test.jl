using EarthSciData
using EarthSciMLBase
using EarthSciMLBase: DomainInfo
using Dates
using Test
using EarthSciData: DataSetInterpolator, lazyload!, lazyload_swap!, make_data_buffer

# Reading only the index box of the native grid that the domain needs
# (`subset_reads`) must leave every model-grid value identical, bit for bit, to
# reading the full grid. `isequal` tells -0.0 from 0.0, so the elementwise
# comparison below is bitwise up to NaN payloads.
samebits(a, b) = size(a) == size(b) && all(splat(isequal), zip(a, b))

# The slots of `buf` that hold `itp`'s current window.
window(itp, buf) = copy(selectdim(buf, ndims(buf), 1:length(itp.cache.times)))

# The event path's two buffers: `lazyload_swap!` never writes `active`.
mutable struct SwapBufs
    active::Any
    spare::Any
end
SwapBufs(itp) = SwapBufs(make_data_buffer(itp), nothing)
function swapload!(itp, t, sb::SwapBufs)
    new = lazyload_swap!(itp, t, sb.active, sb.spare)
    if new !== sb.active
        sb.spare = sb.active
        sb.active = new
    end
    return sb.active
end

wait_prefetch(itp) = (pf = itp.cache.prefetch; pf === nothing || wait(pf.task))

# A boxed and a full-read interpolator for the same variable; the boxed one also
# prefetches through `lazyload_swap!`, the event path.
function check_identical(fs_box, fs_full, varname, domain, times; extrapolate_type)
    t0, t1 = EarthSciMLBase.get_tspan_datetime(domain)
    a = DataSetInterpolator{Float64}(fs_box, varname, t0, t1, domain;
        subset_reads = true, prefetch = true, extrapolate_type = extrapolate_type)
    b = DataSetInterpolator{Float64}(fs_full, varname, t0, t1, domain;
        subset_reads = false, prefetch = false, extrapolate_type = extrapolate_type)
    @test b.read_box === nothing
    sa, bb = SwapBufs(a), make_data_buffer(b)
    ok = true
    for t in times
        swapload!(a, t, sa)
        lazyload!(b, t, bb)
        ok &= a.cache.times == b.cache.times &&
              samebits(window(a, sa.active), window(b, bb))
    end
    wait_prefetch(a)
    return a, b, ok
end

# --------------------------------------------------------------------------
# A synthetic hourly lon/lat/lev file set that serves boxed reads. Coordinates
# are in radians, like GEOS-FP's. `U`, `V` and `W` are staggered along x, y and
# z, which shifts the model grid the regridder evaluates on; `C` is not.
# --------------------------------------------------------------------------

struct BoxFS <: EarthSciData.FileSet
    lon::Vector{Float64}
    lat::Vector{Float64}
    lev::Vector{Float64}
    start::DateTime
    nrec::Int
    main::Task
    loads::Vector{Tuple{DateTime, Any, Bool}}   # (record, box, loaded on the main task)
    loads_lock::ReentrantLock
end
function BoxFS(lat_deg; lon_deg = -180.0:2.5:177.5, lev = 1.0:1.0:6.0)
    BoxFS(deg2rad.(collect(lon_deg)), deg2rad.(collect(lat_deg)), collect(lev),
        DateTime(2024, 1, 1), 48, current_task(), Tuple{DateTime, Any, Bool}[],
        ReentrantLock())
end
# Uniform axes: the scaled-BSpline regridding path.
uniform_fs() = BoxFS(-90.0:2.0:90.0)
# Half-size polar rows, like GEOS-FP's global latitude: the gridded path (#222).
halfpolar_fs() = BoxFS([-89.5; -88.0:2.0:88.0; 89.5])

function EarthSciData.DataFrequencyInfo(fs::BoxFS)
    EarthSciData.DataFrequencyInfo(fs.start, Hour(1),
        [fs.start + Minute(30) + Hour(i) for i in 0:(fs.nrec - 1)])
end
EarthSciData.varnames(::BoxFS) = ["C", "U", "V", "W"]
EarthSciData.supports_subset_reads(::BoxFS) = true

function EarthSciData.loadmetadata(fs::BoxFS, varname)
    stag = varname == "U" ? (true, false, false) :
           varname == "V" ? (false, true, false) :
           varname == "W" ? (false, false, true) : (false, false, false)
    EarthSciData.MetaData([fs.lon, fs.lat, fs.lev], "m", "test", ["lon", "lat", "lev"],
        [length(fs.lon), length(fs.lat), length(fs.lev)],
        "+proj=longlat +datum=WGS84 +no_defs", 1, 2, 3, stag)
end

boxfield(i, j, k, r) = sin(0.37i + 0.11j * r) + 0.01k * cos(0.2j) + 0.1r

function EarthSciData.loadslice!(data::AbstractArray, fs::BoxFS, t::DateTime, varname,
        box = nothing)
    lock(fs.loads_lock) do
        push!(fs.loads, (t, box, current_task() === fs.main))
    end
    r = EarthSciData.centerpoint_index(EarthSciData.DataFrequencyInfo(fs), t)
    rngs = box === nothing ? (eachindex(fs.lon), eachindex(fs.lat), eachindex(fs.lev)) : box
    size(data) == length.(rngs) ||
        throw(DimensionMismatch("buffer $(size(data)), box $rngs"))
    for (kk, k) in enumerate(rngs[3]), (jj, j) in enumerate(rngs[2]),
        (ii, i) in enumerate(rngs[1])
        data[ii, jj, kk] = boxfield(i, j, k, r)
    end
    return nothing
end

deg2rad_range(r) = deg2rad(first(r)):deg2rad(step(r)):deg2rad(last(r))
function box_domain(lon, lat; lev = 1:3, start = DateTime(2024, 1, 1),
        finish = DateTime(2024, 1, 1, 12))
    DomainInfo(start, finish; lonrange = deg2rad_range(lon),
        latrange = deg2rad_range(lat), levrange = lev)
end

const PATHS = (("uniform", uniform_fs), ("half-polar", halfpolar_fs))

const BOX_TIMES = [DateTime(2024, 1, 1, 0, 40), DateTime(2024, 1, 1, 1, 30),
    DateTime(2024, 1, 1, 3, 10), DateTime(2024, 1, 1, 6, 50)]

function check_domain(mkfs, domain; expect_box = true)
    for varname in ("C", "U", "V", "W"), ext in (EarthSciData.Flat(), 0.0)

        a, _, ok = check_identical(mkfs(), mkfs(), varname, domain, BOX_TIMES;
            extrapolate_type = ext)
        @test ok
        @test (a.read_box !== nothing) == expect_box
        if a.read_box !== nothing
            @test size(a.cache.load_cache) == length.(a.read_box)
        end
    end
end

@testset "subset reads" begin
    @testset "interior domain, $name path" for (name, mkfs) in PATHS
        domain = box_domain(-124.3:0.5:-67.3, 25.3:0.5:48.8)
        check_domain(mkfs, domain)
        itp = DataSetInterpolator{Float64}(mkfs(), "C", DateTime(2024, 1, 1),
            DateTime(2024, 1, 1, 12), domain)
        box = itp.read_box
        # One native cell beyond the cells holding the domain, on each side.
        fs = mkfs()
        @test fs.lon[first(box[1]) + 1] < deg2rad(-124.3) < fs.lon[first(box[1]) + 2]
        @test fs.lon[last(box[1]) - 2] < deg2rad(-67.3) < fs.lon[last(box[1]) - 1]
        @test fs.lat[first(box[2]) + 1] < deg2rad(25.3) < fs.lat[first(box[2]) + 2]
        @test fs.lat[last(box[2]) - 2] < deg2rad(48.8) < fs.lat[last(box[2]) - 1]
        @test length(box[3]) < length(fs.lev)   # the vertical is trimmed too
    end

    @testset "domain touching the grid edge, $name path" for (name, mkfs) in PATHS
        n_lat = length(mkfs().lat)
        # West edge and the north pole; staggered U/V edges fall outside the grid.
        nw = box_domain(-180.0:0.5:-150.0, 70.0:0.5:90.0)
        check_domain(mkfs, nw)
        box = DataSetInterpolator{Float64}(mkfs(), "V", DateTime(2024, 1, 1),
            DateTime(2024, 1, 1, 12), nw).read_box
        @test first(box[1]) == 1 && last(box[2]) == n_lat
        # The south pole, and past the east edge of the -180..177.5 grid (the
        # dateline): the box runs to the last longitude.
        se = box_domain(160.0:0.5:185.0, -90.0:0.5:-70.0)
        check_domain(mkfs, se)
        box = DataSetInterpolator{Float64}(mkfs(), "U", DateTime(2024, 1, 1),
            DateTime(2024, 1, 1, 12), se).read_box
        @test last(box[1]) == length(mkfs().lon) && first(box[2]) == 1
        # A domain spanning the whole grid reads the full grid.
        check_domain(mkfs, box_domain(-180.0:2.5:177.5, -90.0:2.0:90.0; lev = 1:6);
            expect_box = false)
    end

    @testset "projected domain" begin
        lcc = "+proj=lcc +lat_0=38 +lon_0=-97 +lat_1=33 +lat_2=45 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
        domain = DomainInfo(DateTime(2024, 1, 1), DateTime(2024, 1, 1, 12);
            xrange = -2.0e6:2.0e5:2.0e6, yrange = -1.4e6:2.0e5:1.4e6, levrange = 1:3,
            spatial_ref = lcc)
        check_domain(halfpolar_fs, domain)
    end

    @testset "prefetch path" begin
        domain = box_domain(-125.0:0.5:-67.0, 25.0:0.5:49.0;
            finish = DateTime(2024, 1, 1, 20))
        fa, fb = halfpolar_fs(), halfpolar_fs()
        times = [DateTime(2024, 1, 1, 0, 40) + Minute(20) * i for i in 0:49]
        a, b, ok = check_identical(fa, fb, "V", domain, times;
            extrapolate_type = EarthSciData.Flat())
        @test ok
        # Every read, in the background or not, was boxed; the full-read
        # interpolator read the full grid.
        @test count(l -> !l[3], fa.loads) >= 10
        @test all(l -> l[2] == a.read_box, fa.loads)
        @test all(l -> l[2] === nothing, fb.loads)
        @test size(a.cache.load_cache) == length.(a.read_box)
        @test size(a.cache.staging) == (a.grid_size..., 1)
        @test prod(length.(a.read_box)) < prod(size(b.cache.load_cache)) / 10
    end

    @testset "off switch and custom regridders" begin
        domain = box_domain(-125.0:0.5:-67.0, 25.0:0.5:49.0)
        t0, t1 = DateTime(2024, 1, 1), DateTime(2024, 1, 1, 12)
        withenv("EARTHSCIDATA_SUBSET_READS" => "0") do
            itp = DataSetInterpolator{Float64}(halfpolar_fs(), "C", t0, t1, domain)
            @test itp.read_box === nothing
            lazyload!(itp, t0 + Hour(1), make_data_buffer(itp))
            @test size(itp.cache.load_cache) == Tuple(itp.metadata.varsize)
        end
        withenv("EARTHSCIDATA_SUBSET_READS" => nothing) do
            @test DataSetInterpolator{Float64}(halfpolar_fs(), "C", t0, t1, domain).read_box !==
                  nothing
        end
        # A caller-supplied regridder expects the full grid.
        copy_rg = (dst, src; extrapolate_type = nothing) -> dst
        @test DataSetInterpolator{Float64}(halfpolar_fs(), "C", t0, t1, domain;
            regrid_f = copy_rg).read_box === nothing
    end

    @testset "boxed source guards" begin
        b = EarthSciData._BoxedArray(reshape(1.0:12.0, 3, 4), (3:5, 2:5), (9, 9))
        @test size(b) == (9, 9)
        @test b[3, 2] == 1.0 && b[5, 5] == 12.0
        @test first(b) == 1.0
        @test_throws BoundsError b[2, 2]
        @test_throws BoundsError b[6, 5]
        @test_throws DimensionMismatch EarthSciData._BoxedArray(
            zeros(2, 2), (3:5, 2:5), (9, 9))
    end

    # Real GEOS-FP files: NetCDF hyperslab reads of 2-D (A1), 3-D (A3dyn, I3)
    # and edge-level (A3mstE, 73 levels) fields over a CONUS domain, with the
    # staggered A3dyn winds and OMEGA's zero extrapolation.
    @testset "GEOS-FP 4x5 $ft" for ft in ("A1", "A3dyn", "I3", "A3mstE")
        t0, t1 = DateTime(2022, 5, 1), DateTime(2022, 5, 1, 12)
        domain = DomainInfo(t0, t1; lonrange = deg2rad_range(-125.0:0.625:-66.875),
            latrange = deg2rad_range(25.0:0.5:49.0), levrange = 1:72)
        fs = EarthSciData.GEOSFPFileSet("4x5", ft, t0, t1)
        times = [t0 + Minute(30), t0 + Hour(2), t0 + Hour(4) + Minute(10), t0 + Hour(7)]
        for varname in EarthSciData.varnames(fs)
            ext = varname == "OMEGA" ? 0.0 : EarthSciData.Flat()
            a, b, ok = check_identical(fs, fs, varname, domain, times;
                extrapolate_type = ext)
            @test ok
            @test a.read_box !== nothing
            @test size(a.cache.load_cache) == length.(a.read_box)
            @test prod(size(a.cache.load_cache)) < prod(size(b.cache.load_cache)) / 10
        end
    end
end
