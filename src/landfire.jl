export LANDFIRE

const LANDFIRE_MIRROR = "https://lfps.usgs.gov/arcgis/rest/services"

"""
Compute the WGS84 bounding box `(west, south, east, north)` in **degrees**
for the given domain, handling arbitrary projections.

For longlat domains the grid extrema are converted from radians to degrees.
For projected domains (e.g. LCC) every point along the four edges of the
domain rectangle is transformed to WGS84 and the envelope is returned.
"""
function _domain_bbox_wgs84(domaininfo)
    grid = _compute_grid(domaininfo, (false, false, false))
    sr = _spatial_ref(domaininfo)

    if sr == _LONLAT_SR
        lon_min, lon_max = rad2deg.(extrema(grid[1]))
        lat_min, lat_max = rad2deg.(extrema(grid[2]))
    else
        to_lonlat = Proj.Transformation(
            "+proj=pipeline +step +inv " * sr * " +step " * _LONLAT_SR)
        xs, ys = grid[1], grid[2]
        lon_vals = Float64[]
        lat_vals = Float64[]
        for x in (first(xs), last(xs))
            for y in (first(ys), last(ys))
                lo, la = to_lonlat(x, y)
                push!(lon_vals, rad2deg(lo)); push!(lat_vals, rad2deg(la))
            end
        end
        for x in xs
            lo, la = to_lonlat(x, first(ys))
            push!(lon_vals, rad2deg(lo)); push!(lat_vals, rad2deg(la))
            lo, la = to_lonlat(x, last(ys))
            push!(lon_vals, rad2deg(lo)); push!(lat_vals, rad2deg(la))
        end
        for y in ys
            lo, la = to_lonlat(first(xs), y)
            push!(lon_vals, rad2deg(lo)); push!(lat_vals, rad2deg(la))
            lo, la = to_lonlat(last(xs), y)
            push!(lon_vals, rad2deg(lo)); push!(lat_vals, rad2deg(la))
        end
        lon_min, lon_max = extrema(lon_vals)
        lat_min, lat_max = extrema(lat_vals)
    end
    return (lon_min, lat_min, lon_max, lat_max)
end

"""
$(SIGNATURES)

A FileSet for LANDFIRE (Landscape Fire and Resource Management Planning Tools)
fuel model data, providing Anderson 13 or Scott & Burgan 40 fire behavior fuel
model classifications at 30m resolution over the contiguous United States.

Data is downloaded from the LANDFIRE ImageServer REST API as GeoTIFF files.
This is a static (time-invariant) dataset.

The pixel values are integer fuel model codes (e.g. 1–13 for Anderson 13, or
91=urban/developed, 92=snow/ice, 93=agriculture, 98=water, 99=barren).

See https://landfire.gov/ for more information.
"""
struct LANDFIREFileSet <: FileSet
    mirror::String
    product::String   # e.g. "FBFM13" or "FBFM40"
    version::String   # e.g. "LF2022"
    bbox::NTuple{4, Float64}  # (west, south, east, north) in degrees
    width::Int
    height::Int
    freq_info::DataFrequencyInfo
end

"""
$(SIGNATURES)

Create a LANDFIREFileSet covering the spatial extent of the given domain.

# Arguments

  - `domaininfo`: A `DomainInfo` or `GridSpec` providing the spatial domain.
  - `product`: LANDFIRE product name (default `"FBFM13"` for Anderson 13 fuel models;
    use `"FBFM40"` for Scott & Burgan 40 fuel models).
  - `version`: LANDFIRE version (default `"LF2022"`).
  - `resolution`: Target resolution in arc-seconds (default 1.0 ≈ 30m).
    Note: the LANDFIRE ImageServer limits requests to 4000×4000 pixels.
    For large domains at fine resolution, the image will be silently downsampled.
"""
function LANDFIREFileSet(domaininfo; product = "FBFM13", version = "LF2022", resolution = 1.0)
    lon_min, lat_min, lon_max, lat_max = _domain_bbox_wgs84(domaininfo)
    buffer = resolution / 3600
    bbox = (lon_min - buffer, lat_min - buffer, lon_max + buffer, lat_max + buffer)

    width = ceil(Int, (bbox[3] - bbox[1]) * 3600 / resolution)
    height = ceil(Int, (bbox[4] - bbox[2]) * 3600 / resolution)
    width = clamp(width, 1, 4000)
    height = clamp(height, 1, 4000)

    starttime, endtime = get_tspan_datetime(domaininfo)
    # Static (time-invariant) dataset: create a single-interval DataFrequencyInfo
    # spanning the simulation period so that the temporal cache machinery works.
    freq_info = DataFrequencyInfo(
        starttime, endtime - starttime + Day(1), [starttime, endtime + Day(1)])

    LANDFIREFileSet(LANDFIRE_MIRROR, product, version, bbox, width, height, freq_info)
end

function relpath(fs::LANDFIREFileSet, t::DateTime)
    w, s, e, n = fs.bbox
    return "landfire/$(fs.product)_$(w)_$(s)_$(e)_$(n)_$(fs.width)x$(fs.height).tif"
end

function url(fs::LANDFIREFileSet, t::DateTime, varname = nothing)
    w, s, e, n = fs.bbox
    return string(
        fs.mirror,
        "/Landfire_$(fs.version)/$(fs.version)_$(fs.product)_CONUS/ImageServer",
        "/exportImage?",
        "bbox=$w,$s,$e,$n",
        "&bboxSR=4326",
        "&imageSR=4326",
        "&size=$(fs.width),$(fs.height)",
        "&format=tiff",
        "&pixelType=S16",
        "&interpolation=+RSP_NearestNeighbor",
        "&f=image"
    )
end

Base.close(::LANDFIREFileSet) = nothing

DataFrequencyInfo(fs::LANDFIREFileSet)::DataFrequencyInfo = fs.freq_info

varnames(::LANDFIREFileSet) = ["fuel_model"]

function loadmetadata(fs::LANDFIREFileSet, varname)::MetaData
    @assert varname == "fuel_model" "LANDFIREFileSet only provides 'fuel_model', got '$varname'"
    w, s, e, n = fs.bbox
    dx = (e - w) / fs.width
    dy = (n - s) / fs.height
    lons = [w + (i - 0.5) * dx for i in 1:(fs.width)]
    lats = [s + (j - 0.5) * dy for j in 1:(fs.height)]
    lons_rad = deg2rad.(lons)
    lats_rad = deg2rad.(lats)
    prj = "+proj=longlat +datum=WGS84 +no_defs"
    return MetaData(
        [lons_rad, lats_rad],
        "1",
        "Fire behavior fuel model (Anderson 13)",
        ["lon", "lat"],
        [length(lons_rad), length(lats_rad)],
        prj,
        1,    # xdim (lon)
        2,    # ydim (lat)
        -1,   # zdim (none)
        (false, false, false)
    )
end

function loadslice!(data::AbstractArray, fs::LANDFIREFileSet, t::DateTime, varname)
    @assert varname == "fuel_model" "LANDFIREFileSet only provides 'fuel_model', got '$varname'"
    p = maybedownload(fs, t)
    img = TiffImages.load(p)
    # TiffImages reads S16 as Q0f15 fixed-point.
    # Multiply by 2^15 = 32768 to recover the original integer fuel model codes.
    h, w = size(img)
    for col in 1:w
        for row in 1:h
            data[col, h - row + 1] = round(Float64(img[row, col]) * 32768)
        end
    end
    nothing
end

# ---- Nearest-neighbour interpolation for categorical data --------------------

"""
Nearest-neighbour version of `interpolate_from!`, suitable for categorical
(integer-valued) data such as fuel model codes.  Uses `BSpline(Constant())`
instead of `BSpline(Linear())`.
"""
function _nearest_interpolate_from!(dst::AbstractArray{T, 2},
        src::AbstractArray{T, 2}, mta::MetaData, model_grid, domain;
        extrapolate_type = Flat()) where {T}
    data_grid = Tuple(knots2range.(mta.coords))
    itp = interpolate!(src, BSpline(Constant()))
    itp = extrapolate(scale(itp, data_grid), extrapolate_type)
    ct = coord_trans(mta, domain)
    for (i, x) in enumerate(model_grid[1])
        for (j, y) in enumerate(model_grid[2])
            idx = tuple_from_vals(mta.xdim, i, mta.ydim, j)
            locs = tuple_from_vals(mta.xdim, x, mta.ydim, y)
            locs = ct(locs)
            dst[idx...] = itp(locs...)
        end
    end
    dst
end

# ---- ModelingToolkit integration ---------------------------------------------

struct LANDFIRECoupler
    sys::Any
end

"""
$(SIGNATURES)

Create a ModelingToolkit `System` that provides fuel model data from LANDFIRE.

The system exposes a single variable `fuel_model` (dimensionless) interpolated
to the simulation coordinates using nearest-neighbour interpolation (appropriate
for categorical data).

# Arguments

  - `domaininfo`: A `DomainInfo` specifying the spatial and temporal domain.
  - `name`: System name (default `:LANDFIRE`).
  - `product`: LANDFIRE product (default `"FBFM13"` for Anderson 13 fuel models).
  - `version`: LANDFIRE version (default `"LF2022"`).
  - `resolution`: Target resolution in arc-seconds (default 1.0 ≈ 30m).
  - `stream`: Whether to stream data lazily (default `true`).

# Example

```julia
using EarthSciData, EarthSciMLBase, ModelingToolkit, Dates
domain = DomainInfo(
    DateTime(2018, 11, 8), DateTime(2018, 11, 9);
    lonrange = deg2rad(-121.7):deg2rad(0.01):deg2rad(-121.5),
    latrange = deg2rad(39.7):deg2rad(0.01):deg2rad(39.8),
    levrange = 1:1
)
fuel = LANDFIRE(domain)
```
"""
function LANDFIRE(domaininfo::DomainInfo; name = :LANDFIRE,
        product = "FBFM13", version = "LF2022", resolution = 1.0, stream = true)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = LANDFIREFileSet(domaininfo; product = product, version = version,
        resolution = resolution)

    @parameters t_ref=get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)

    # Use nearest-neighbour interpolation for categorical fuel model data.
    metadata = loadmetadata(fs, "fuel_model")
    model_grid = _compute_grid(domaininfo, metadata.staggering)
    regrid_f = (dst::AbstractArray, src::AbstractArray;
        extrapolate_type = Flat()) -> begin
        _nearest_interpolate_from!(dst, src, metadata, model_grid, domaininfo;
            extrapolate_type = extrapolate_type)
    end
    fswr = FileSetWithRegridder(fs, regrid_f)

    dt = eltype(domaininfo)
    itp = DataSetInterpolator{dt}(
        fswr, "fuel_model", starttime, endtime, domaininfo; stream = stream)
    dims = dimnames(itp)
    coords = _match_domain_coords(dims, pvdict, pvs)
    eq, param = create_interp_equation(itp, "", t, t_ref, coords)

    params = Any[t_ref, param]
    vars = Num[eq.lhs]
    eqs = Equation[eq]

    sys = System(
        eqs, t, vars, params;
        name = name,
        initial_conditions = _itp_defaults(params),
        metadata = Dict(
            CoupleType => LANDFIRECoupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime),
            SysDomainInfo => domaininfo,
        )
    )
    return sys
end
