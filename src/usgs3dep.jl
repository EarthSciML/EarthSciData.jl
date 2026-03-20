export USGS3DEP

const USGS3DEP_MIRROR = "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer"

"""
$(SIGNATURES)

A FileSet for USGS 3D Elevation Program (3DEP) data, providing terrain elevation
at approximately 1/3 arc-second (~10m) resolution over the United States.

Data is downloaded from the USGS National Map ImageServer REST API as GeoTIFF files
and read with TiffImages.jl. Because we control the request parameters (bounding box,
output CRS, and pixel dimensions), the coordinates are computed directly from the
request rather than from GeoTIFF metadata tags.

This is a static (time-invariant) dataset.

See https://elevation.nationalmap.gov/ for more information.
"""
struct USGS3DEPFileSet <: FileSet
    mirror::String
    bbox::NTuple{4,Float64}  # (west, south, east, north) in degrees
    width::Int
    height::Int
    freq_info::DataFrequencyInfo
end

"""
$(SIGNATURES)

Create a USGS3DEPFileSet covering the spatial extent of the given domain.

# Arguments
- `domaininfo`: A `DomainInfo` or `GridSpec` providing the spatial domain.
- `resolution`: Target resolution in arc-seconds (default 1/3 ≈ 10m).
  The pixel count is capped at 4000×4000 to avoid excessive download sizes.
"""
function USGS3DEPFileSet(domaininfo; resolution=1 / 3)
    grid = _compute_grid(domaininfo, (false, false, false))
    lon_min, lon_max = rad2deg.(extrema(grid[1]))
    lat_min, lat_max = rad2deg.(extrema(grid[2]))
    # Add a small buffer so the data fully covers the domain edges.
    buffer = resolution / 3600  # one pixel worth of buffer
    bbox = (lon_min - buffer, lat_min - buffer, lon_max + buffer, lat_max + buffer)

    # Compute pixel dimensions from the requested resolution.
    width = ceil(Int, (bbox[3] - bbox[1]) * 3600 / resolution)
    height = ceil(Int, (bbox[4] - bbox[2]) * 3600 / resolution)
    width = clamp(width, 1, 4000)
    height = clamp(height, 1, 4000)

    # Static dataset: use two centerpoints bracketing the domain time range
    # so that any query time within the domain is interpolable.
    starttime, endtime = get_tspan_datetime(domaininfo)
    freq_info = DataFrequencyInfo(
        starttime, endtime - starttime + Day(1), [starttime, endtime + Day(1)])

    USGS3DEPFileSet(USGS3DEP_MIRROR, bbox, width, height, freq_info)
end

function relpath(fs::USGS3DEPFileSet, t::DateTime)
    w, s, e, n = fs.bbox
    "usgs3dep/elevation_$(w)_$(s)_$(e)_$(n)_$(fs.width)x$(fs.height).tif"
end

function url(fs::USGS3DEPFileSet, t::DateTime, varname=nothing)
    w, s, e, n = fs.bbox
    string(
        fs.mirror,
        "/exportImage?",
        "bbox=$w,$s,$e,$n",
        "&bboxSR=4326",
        "&imageSR=4326",
        "&size=$(fs.width),$(fs.height)",
        "&format=tiff",
        "&pixelType=F32",
        "&interpolation=+RSP_BilinearInterpolation",
        "&f=image",
    )
end

DataFrequencyInfo(fs::USGS3DEPFileSet)::DataFrequencyInfo = fs.freq_info

varnames(::USGS3DEPFileSet) = ["elevation"]

function loadmetadata(fs::USGS3DEPFileSet, varname)::MetaData
    @assert varname == "elevation" "USGS3DEPFileSet only provides 'elevation', got '$varname'"
    w, s, e, n = fs.bbox
    # Compute pixel-centre coordinates from the bounding box.
    dx = (e - w) / fs.width
    dy = (n - s) / fs.height
    lons = [w + (i - 0.5) * dx for i in 1:fs.width]
    lats = [s + (j - 0.5) * dy for j in 1:fs.height]  # ascending (south→north)
    # Convert to radians.
    lons_rad = deg2rad.(lons)
    lats_rad = deg2rad.(lats)
    prj = "+proj=longlat +datum=WGS84 +no_defs"
    MetaData(
        [lons_rad, lats_rad],
        "m",
        "Terrain elevation above sea level",
        ["lon", "lat"],
        [length(lons_rad), length(lats_rad)],
        prj,
        1,    # xdim (lon)
        2,    # ydim (lat)
        -1,   # zdim (none)
        (false, false, false),
    )
end

function loadslice!(data::AbstractArray, fs::USGS3DEPFileSet, t::DateTime, varname)
    @assert varname == "elevation" "USGS3DEPFileSet only provides 'elevation', got '$varname'"
    p = maybedownload(fs, t)
    img = TiffImages.load(p)
    # TiffImages returns (rows, cols) = (height, width).
    # Row 1 is the north edge (top of image), row end is the south edge.
    # We need data as (lon, lat) = (cols, rows) with lat ascending (south→north).
    h, w = size(img)
    for col in 1:w
        for row in 1:h
            # Reverse row order: row h (south) → lat index 1, row 1 (north) → lat index h
            data[col, h - row + 1] = Float64(img[row, col])
        end
    end
    nothing
end

# ---- ModelingToolkit integration ---------------------------------------------

struct USGS3DEPCoupler
    sys::Any
end

"""
$(SIGNATURES)

Create a ModelingToolkit `System` that provides terrain elevation data from the
USGS 3D Elevation Program (3DEP).

The system exposes a single variable `elevation` (m) interpolated to the
simulation coordinates.

# Arguments
- `domaininfo`: A `DomainInfo` specifying the spatial and temporal domain.
- `name`: System name (default `:USGS3DEP`).
- `resolution`: Target resolution in arc-seconds (default 1/3 ≈ 10m).
- `stream`: Whether to stream data lazily (default `true`).

# Example
```julia
using EarthSciData, EarthSciMLBase, ModelingToolkit, Dates
domain = DomainInfo(
    DateTime(2018, 11, 8), DateTime(2018, 11, 9);
    lonrange = deg2rad(-121.7):deg2rad(0.01):deg2rad(-121.5),
    latrange = deg2rad(39.7):deg2rad(0.01):deg2rad(39.8),
    levrange = 1:1,
)
elev = USGS3DEP(domain)
```
"""
function USGS3DEP(domaininfo::DomainInfo; name=:USGS3DEP, resolution=1 / 3, stream=true)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = USGS3DEPFileSet(domaininfo; resolution=resolution)

    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)

    dt = eltype(domaininfo)
    itp = DataSetInterpolator{dt}(
        fs, "elevation", starttime, endtime, domaininfo; stream=stream)
    dims = dimnames(itp)
    coords = Num[]
    for dim in dims
        d = Symbol(dim)
        @assert d ∈ keys(pvdict) "USGS3DEP coordinate $d not found in domaininfo coordinates ($(pvs))."
        push!(coords, pvdict[d])
    end
    eq, param = create_interp_equation(itp, "", t, t_ref, coords)

    params = Any[t_ref, param]
    vars = Num[eq.lhs]
    eqs = Equation[eq]

    sys = System(
        eqs, t, vars, params;
        name=name,
        initial_conditions=_itp_defaults(params),
        metadata=Dict(
            CoupleType => USGS3DEPCoupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime),
        ),
    )
    return sys
end
