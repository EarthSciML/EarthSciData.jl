export USGS3DEP, USGS3DEPCoupler

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
    bbox::NTuple{4, Float64}  # (west, south, east, north) in degrees
    width::Int
    height::Int
    freq_info::DataFrequencyInfo
end

"""
$(SIGNATURES)

Create a USGS3DEPFileSet covering the spatial extent of the given domain.

!!! warning "US coverage only"

    3DEP provides elevation data for the United States (CONUS, Alaska, Hawaii,
    and US territories). Requests for domains outside this coverage will return
    nodata values.

# Arguments

  - `domaininfo`: A `DomainInfo` or `GridSpec` providing the spatial domain.
  - `resolution`: Target resolution in arc-seconds (default 1/3 ≈ 10m).
    The pixel count is capped at 1000×1000 to avoid excessive download sizes
    and API timeouts.
"""
function USGS3DEPFileSet(domaininfo; resolution = 1 / 3)
    grid = _compute_grid(domaininfo, (false, false, false))

    # Convert domain grid coordinates to lon-lat degrees for the API request.
    domain_sr = _spatial_ref(domaininfo)
    if domain_sr == _LONLAT_SR
        # Domain is already in lon-lat radians.
        lon_min, lon_max = rad2deg.(extrema(grid[1]))
        lat_min, lat_max = rad2deg.(extrema(grid[2]))
    else
        # Domain uses a projected CRS — transform corners to lon-lat.
        # Use +inv on the domain step to go from projected coords → geographic.
        to_lonlat = Proj.Transformation(
            "+proj=pipeline +step +inv " * domain_sr * " +step " * _LONLAT_SR)
        xs, ys = grid[1], grid[2]
        # Transform all corner combinations to handle rotated grids.
        lon_vals = Float64[]
        lat_vals = Float64[]
        for x in (first(xs), last(xs))
            for y in (first(ys), last(ys))
                lo, la = to_lonlat(x, y)
                push!(lon_vals, rad2deg(lo))
                push!(lat_vals, rad2deg(la))
            end
        end
        # Also sample edges to capture curvature for large domains.
        for x in xs
            lo, la = to_lonlat(x, first(ys))
            push!(lon_vals, rad2deg(lo));
            push!(lat_vals, rad2deg(la))
            lo, la = to_lonlat(x, last(ys))
            push!(lon_vals, rad2deg(lo));
            push!(lat_vals, rad2deg(la))
        end
        for y in ys
            lo, la = to_lonlat(first(xs), y)
            push!(lon_vals, rad2deg(lo));
            push!(lat_vals, rad2deg(la))
            lo, la = to_lonlat(last(xs), y)
            push!(lon_vals, rad2deg(lo));
            push!(lat_vals, rad2deg(la))
        end
        lon_min, lon_max = extrema(lon_vals)
        lat_min, lat_max = extrema(lat_vals)
    end

    # Warn if domain falls outside approximate US coverage bounds.
    if lon_max < -180 || lon_min > -60 || lat_max < 17 || lat_min > 72
        @warn "Domain appears to be outside USGS 3DEP coverage (US only). " *
              "Elevation data may be unavailable or filled with nodata values."
    end
    # Add a small buffer so the data fully covers the domain edges.
    buffer = resolution / 3600  # one pixel worth of buffer
    bbox = (lon_min - buffer, lat_min - buffer, lon_max + buffer, lat_max + buffer)

    # Compute pixel dimensions from the requested resolution.
    width = ceil(Int, (bbox[3] - bbox[1]) * 3600 / resolution)
    height = ceil(Int, (bbox[4] - bbox[2]) * 3600 / resolution)
    width = clamp(width, 1, 1000)
    height = clamp(height, 1, 1000)

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

function url(fs::USGS3DEPFileSet, t::DateTime, varname = nothing)
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
        "&f=image"
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
    MetaData(
        [lons_rad, lats_rad],
        "m",
        "Terrain elevation above sea level",
        ["lon", "lat"],
        [length(lons_rad), length(lats_rad)],
        _LONLAT_SR,
        1,    # xdim (lon)
        2,    # ydim (lat)
        -1,   # zdim (none)
        (false, false, false)
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

# ---- Slope computation -------------------------------------------------------

# Earth radius constants for coordinate conversion (matching EarthSciMLBase.coord_trans)
const _LON2M = 40075.0e3 / 2π   # m/rad – equatorial circumference / 2π
const _LAT2M = 111.32e3 * 180 / π  # m/rad – meridional arc length per radian

"""
$(SIGNATURES)

A FileSet that computes terrain slope from USGS 3DEP elevation data.

Wraps a [`USGS3DEPFileSet`](@ref) and computes the dimensionless elevation
gradient in either the x (east) or y (north) direction using central finite
differences on the elevation grid, with coordinate conversion from lon/lat
to metric distances.

The `component` field selects which gradient to compute: `:dzdx` or `:dzdy`.
"""
struct USGS3DEPSlopeFileSet <: FileSet
    parent::USGS3DEPFileSet
    component::Symbol  # :dzdx or :dzdy
end

mirror(fs::USGS3DEPSlopeFileSet) = mirror(fs.parent)
relpath(fs::USGS3DEPSlopeFileSet, t::DateTime) = relpath(fs.parent, t)
url(fs::USGS3DEPSlopeFileSet, t::DateTime, varname = nothing) = url(fs.parent, t, varname)
DataFrequencyInfo(fs::USGS3DEPSlopeFileSet)::DataFrequencyInfo = DataFrequencyInfo(fs.parent)
varnames(fs::USGS3DEPSlopeFileSet) = [string(fs.component)]

function loadmetadata(fs::USGS3DEPSlopeFileSet, varname)::MetaData
    elev_md = loadmetadata(fs.parent, "elevation")
    desc = fs.component == :dzdx ?
           "Terrain slope in x (east) direction (dimensionless, rise/run)" :
           "Terrain slope in y (north) direction (dimensionless, rise/run)"
    MetaData(
        elev_md.coords, "1", desc,
        elev_md.dimnames, elev_md.varsize, elev_md.native_sr,
        elev_md.xdim, elev_md.ydim, elev_md.zdim, elev_md.staggering
    )
end

function loadslice!(data::AbstractArray, fs::USGS3DEPSlopeFileSet, t::DateTime, varname)
    nlon, nlat = size(data)
    # Load elevation into a temporary array.
    elev = zeros(Float64, nlon, nlat)
    loadslice!(elev, fs.parent, t, "elevation")

    # Get pixel-centre coordinates (radians) from metadata.
    md = loadmetadata(fs.parent, "elevation")
    lons_rad = md.coords[1]
    lats_rad = md.coords[2]

    if fs.component == :dzdx
        for j in 1:nlat
            # Metric scale factor for this latitude row.
            dx_per_rad = _LON2M * cos(lats_rad[j])  # m/rad
            for i in 1:nlon
                if i == 1
                    dz = elev[2, j] - elev[1, j]
                    dlon = lons_rad[2] - lons_rad[1]
                elseif i == nlon
                    dz = elev[nlon, j] - elev[nlon - 1, j]
                    dlon = lons_rad[nlon] - lons_rad[nlon - 1]
                else
                    dz = elev[i + 1, j] - elev[i - 1, j]
                    dlon = lons_rad[i + 1] - lons_rad[i - 1]
                end
                data[i, j] = dz / (dlon * dx_per_rad)
            end
        end
    else  # :dzdy
        for j in 1:nlat
            for i in 1:nlon
                if j == 1
                    dz = elev[i, 2] - elev[i, 1]
                    dlat = lats_rad[2] - lats_rad[1]
                elseif j == nlat
                    dz = elev[i, nlat] - elev[i, nlat - 1]
                    dlat = lats_rad[nlat] - lats_rad[nlat - 1]
                else
                    dz = elev[i, j + 1] - elev[i, j - 1]
                    dlat = lats_rad[j + 1] - lats_rad[j - 1]
                end
                data[i, j] = dz / (dlat * _LAT2M)
            end
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

Create a ModelingToolkit `System` that provides terrain elevation and slope data
from the USGS 3D Elevation Program (3DEP).

The system exposes three variables interpolated to the simulation coordinates:

  - `elevation` (m): terrain elevation above sea level
  - `dzdx` (dimensionless): terrain slope in the x (east) direction (rise/run)
  - `dzdy` (dimensionless): terrain slope in the y (north) direction (rise/run)

Slopes are computed from the elevation grid using central finite differences
with coordinate conversion from lon/lat to metric distances.

The domain may use any coordinate reference system (lon-lat, UTM, Lambert
Conformal Conic, etc.). The domain bounding box is automatically reprojected
to WGS84 for the USGS API request, and coordinate transforms between the
domain CRS and the data's native lon-lat grid are handled by the interpolation
infrastructure.

Note that 3DEP coverage is limited to the United States
(CONUS, Alaska, Hawaii, and US territories).

# Arguments

  - `domaininfo`: A `DomainInfo` specifying the spatial and temporal domain.
  - `name`: System name (default `:USGS3DEP`).
  - `resolution`: Target resolution in arc-seconds (default 1/3 ≈ 10m).
  - `stream`: Whether to stream data lazily (default `true`).
  - `spatial_interp = :linear` (default) does full multilinear interpolation; `:nearest` does
    spatial nearest-neighbour + time-only linear interpolation for ~8x speedup when queries
    are always at grid points.

# Example

```julia
using EarthSciData, EarthSciMLBase, ModelingToolkit, Dates
domain = DomainInfo(
    DateTime(2018, 11, 8), DateTime(2018, 11, 9);
    lonrange = deg2rad(-121.7):deg2rad(0.01):deg2rad(-121.5),
    latrange = deg2rad(39.7):deg2rad(0.01):deg2rad(39.8),
    levrange = 1:1
)
elev = USGS3DEP(domain)
```
"""
function USGS3DEP(domaininfo::DomainInfo; name = :USGS3DEP, resolution = 1 / 3,
        stream = true, spatial_interp::Symbol = :linear)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = USGS3DEPFileSet(domaininfo; resolution = resolution)

    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)

    dt = eltype(domaininfo)

    # Build coordinate list. The data is always in lon-lat, but the domain
    # may use x/y (projected CRS). Map domain coordinate names to the data
    # dimension names so the interpolator can apply coord_trans automatically.
    elev_itp = DataSetInterpolator{dt}(
        fs, "elevation", starttime, endtime, domaininfo; stream = stream)
    dims = dimnames(elev_itp)  # ["lon", "lat"] from the data metadata
    coords = _match_domain_coords(dims, pvdict, pvs)

    # Elevation equation.
    eq_elev, discretes_e,
    constants_e,
    info_e = create_interp_equation(
        elev_itp, "", t, t_ref, coords;
        spatial_interp = spatial_interp)
    params = Any[t_ref]
    all_discretes = Any[discretes_e...]
    all_constants = Any[constants_e...]
    interp_infos = Any[info_e]
    lhs_vars = Num[eq_elev.lhs]
    eqs = Equation[eq_elev]

    # Slope equations (dzdx and dzdy).
    for component in (:dzdx, :dzdy)
        slope_fs = USGS3DEPSlopeFileSet(fs, component)
        slope_itp = DataSetInterpolator{dt}(
            slope_fs, string(component), starttime, endtime, domaininfo; stream = stream)
        eq_slope, discretes_s,
        constants_s,
        info_s = create_interp_equation(
            slope_itp, "", t, t_ref, coords;
            spatial_interp = spatial_interp)
        push!(eqs, eq_slope)
        push!(lhs_vars, eq_slope.lhs)
        append!(all_discretes, discretes_s)
        append!(all_constants, constants_s)
        push!(interp_infos, info_s)
    end

    all_params = Any[t_ref, all_constants..., all_discretes...]
    sys = System(
        eqs, t, lhs_vars, all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        discrete_events = [build_interp_event(interp_infos, starttime)],
        metadata = Dict(
            CoupleType => USGS3DEPCoupler,
            SysDomainInfo => domaininfo
        )
    )
    return sys
end

# _match_domain_coords is defined in load.jl and shared across data sources.
