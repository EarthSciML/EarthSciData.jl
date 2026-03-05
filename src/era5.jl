export ERA5

# ERA5 pressure levels in hPa, ordered from surface (highest pressure) to top (lowest pressure).
# Level index 1 = 1000 hPa, index 37 = 1 hPa.
const ERA5_PRESSURE_LEVELS_HPA = [
    1000, 975, 950, 925, 900, 875, 850, 825, 800, 775, 750,
    700, 650, 600, 550, 500, 450, 400, 350, 300,
    250, 225, 200, 175, 150, 125, 100,
    70, 50, 30, 20, 10, 7, 5, 3, 2, 1
]

# Mapping from CDS API variable names to short names used in NetCDF files.
const ERA5_VARIABLES = Dict(
    "temperature" => "t",
    "u_component_of_wind" => "u",
    "v_component_of_wind" => "v",
    "vertical_velocity" => "w",
    "specific_humidity" => "q",
    "relative_humidity" => "r",
    "geopotential" => "z",
    "divergence" => "d",
    "vorticity" => "vo",
    "ozone_mass_mixing_ratio" => "o3",
    "fraction_of_cloud_cover" => "cc",
    "specific_cloud_ice_water_content" => "ciwc",
    "specific_cloud_liquid_water_content" => "clwc",
    "specific_rain_water_content" => "crwc",
    "specific_snow_water_content" => "cswc",
    "potential_vorticity" => "pv",
)

"""
$(SIGNATURES)

A `FileSet` for ERA5 reanalysis data on pressure levels from the
Copernicus Climate Data Store (CDS).

Data is retrieved via the CDS API (requires an API key in `~/.cdsapirc` or `ENV["CDSAPI_KEY"]`)
or from pre-downloaded local files (set `mirror` to `"file:///path/to/data"`).

For local files, the expected directory structure is:
`{path}/era5_pl_{YYYY}_{MM}.nc` where each file contains all variables for one month.
"""
struct ERA5PressureLevelFileSet <: FileSet
    mirror::AbstractString
    ds::Union{NCDataset, NCDatasets.MFDataset}
    freq_info::DataFrequencyInfo
    varlist::Vector{String}  # Short variable names present in the dataset.

    function ERA5PressureLevelFileSet(domaininfo::DomainInfo;
            mirror::AbstractString=CDS_API_URL,
            variables::Vector{String}=collect(keys(ERA5_VARIABLES)))
        starttime, endtime = get_tspan_datetime(domaininfo)

        # Determine which months to cover (with buffer for CDS API, no buffer for local files).
        if startswith(mirror, "file://")
            t_start = starttime
            t_end = endtime
        else
            t_start = starttime - Hour(3)
            t_end = endtime + Hour(3)
        end

        filepaths = String[]

        if startswith(mirror, "file://")
            # Local pre-downloaded files.
            basedir = replace(mirror, "file://" => "")
            for ym in _month_range(t_start, t_end)
                yr, mo = ym
                fname = "era5_pl_$(yr)_$(lpad(mo, 2, '0')).nc"
                fp = joinpath(basedir, fname)
                if !isfile(fp)
                    error("Expected ERA5 file not found: $(fp)")
                end
                push!(filepaths, fp)
            end
        else
            # CDS API download.
            api_key = cds_api_key()
            lonrange_deg = rad2deg.(extrema(EarthSciMLBase.grid(domaininfo, (false, false, false))[1]))
            latrange_deg = rad2deg.(extrema(EarthSciMLBase.grid(domaininfo, (false, false, false))[2]))
            levrange = EarthSciMLBase.grid(domaininfo, (false, false, false))[3]
            plevels = ERA5_PRESSURE_LEVELS_HPA[round.(Int, levrange)]
            area = [
                ceil(Int, latrange_deg[2] + 1),   # north
                floor(Int, lonrange_deg[1] - 1),   # west
                floor(Int, latrange_deg[1] - 1),   # south
                ceil(Int, lonrange_deg[2] + 1),    # east
            ]

            for ym in _month_range(t_start, t_end)
                yr, mo = ym
                # Figure out which days in this month we need.
                month_start = max(Date(yr, mo, 1), Date(t_start))
                month_end = min(lastdayofmonth(Date(yr, mo, 1)), Date(t_end))
                days = [lpad(d, 2, '0') for d in Dates.day(month_start):Dates.day(month_end)]

                request = Dict(
                    "product_type" => ["reanalysis"],
                    "variable" => variables,
                    "pressure_level" => [string(p) for p in sort(plevels, rev=true)],
                    "year" => [string(yr)],
                    "month" => [lpad(mo, 2, '0')],
                    "day" => days,
                    "time" => [lpad(h, 2, '0') * ":00" for h in 0:23],
                    "data_format" => "netcdf",
                    "download_format" => "unarchived",
                    "area" => area,
                )

                outpath = joinpath(
                    download_cache(),
                    "era5_pressure_levels",
                    "era5_pl_$(yr)_$(lpad(mo, 2, '0')).nc"
                )
                cds_retrieve("reanalysis-era5-pressure-levels", request, outpath; api_key=api_key)
                push!(filepaths, outpath)
            end
        end

        lock(nclock) do
            ds = if length(filepaths) == 1
                NCDataset(filepaths[1])
            else
                NCDataset(filepaths, aggdim="valid_time")
            end

            times = DateTime.(ds["valid_time"][:])
            freq = length(times) > 1 ? times[2] - times[1] : Hour(1)
            dfi = DataFrequencyInfo(times[1], freq, times)

            # Discover which short-name variables are in the file.
            dim_keys = Set(keys(ds.dim))
            coord_keys = Set(["valid_time", "pressure_level", "latitude", "longitude",
                              "number", "expver"])
            varlist = [k for k in keys(ds) if !(k in dim_keys) && !(k in coord_keys)]

            return new(mirror, ds, dfi, varlist)
        end
    end
end

function _month_range(t_start::Union{DateTime, Date}, t_end::Union{DateTime, Date})
    ym_start = (year(t_start), month(t_start))
    ym_end = (year(t_end), month(t_end))
    result = Tuple{Int, Int}[]
    y, m = ym_start
    while (y, m) <= ym_end
        push!(result, (y, m))
        m += 1
        if m > 12
            m = 1
            y += 1
        end
    end
    return result
end

function relpath(fs::ERA5PressureLevelFileSet, t::DateTime)
    yr = year(t)
    mo = lpad(month(t), 2, '0')
    return "era5_pressure_levels/era5_pl_$(yr)_$(mo).nc"
end

DataFrequencyInfo(fs::ERA5PressureLevelFileSet)::DataFrequencyInfo = fs.freq_info

function loadslice!(data::AbstractArray, fs::ERA5PressureLevelFileSet, t::DateTime, varname)
    lock(nclock) do
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))

        time_index = findfirst(isequal("valid_time"), dims)
        @assert time_index !== nothing "Variable $varname does not have a 'valid_time' dimension."
        ti = centerpoint_index(DataFrequencyInfo(fs), t)
        slices = [d == "valid_time" ? ti : Colon() for d in dims]

        raw = var[slices...]

        # ERA5 latitude is stored in decreasing order (90 to -90); reverse to ascending.
        lat_idx = findfirst(isequal("latitude"), dims)
        if lat_idx !== nothing
            lat_idx_notimedim = lat_idx > time_index ? lat_idx - 1 : lat_idx
            raw = reverse(raw, dims=lat_idx_notimedim)
        end

        # ERA5 pressure levels may be stored in decreasing order; reverse to match
        # our index ordering (index 1 = highest pressure = surface).
        plev_idx = findfirst(isequal("pressure_level"), dims)
        if plev_idx !== nothing
            plev_idx_notimedim = plev_idx > time_index ? plev_idx - 1 : plev_idx
            plevs = Float64.(fs.ds["pressure_level"][:])
            if length(plevs) > 1 && plevs[1] < plevs[end]
                # Pressure levels are in ascending order (low to high pressure);
                # reverse to match our descending pressure (surface-up) convention.
                raw = reverse(raw, dims=plev_idx_notimedim)
            end
        end

        # ERA5 longitude is 0..360; shift to -180..180.
        lon_idx = findfirst(isequal("longitude"), dims)
        if lon_idx !== nothing
            lon_idx_notimedim = lon_idx > time_index ? lon_idx - 1 : lon_idx
            lon_vals = fs.ds["longitude"][:]
            shift = findfirst(x -> x >= 180.0, lon_vals)
            if shift !== nothing && shift <= length(lon_vals)
                raw = circshift(raw, ntuple(
                    i -> i == lon_idx_notimedim ? length(lon_vals) - shift + 1 : 0,
                    ndims(raw)
                ))
            end
        end

        copyto!(data, raw)

        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
    end
    nothing
end

function loadmetadata(fs::ERA5PressureLevelFileSet, varname)::MetaData
    lock(nclock) do
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))

        time_index = findfirst(isequal("valid_time"), dims)
        @assert time_index !== nothing "Variable $varname does not have a 'valid_time' dimension."
        dims_notime = deleteat!(copy(dims), time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        unit_str = var.attrib["units"]
        description = get(var.attrib, "long_name", varname)

        xdim = findfirst(isequal("longitude"), dims_notime)
        ydim = findfirst(isequal("latitude"), dims_notime)
        zdim = findfirst(isequal("pressure_level"), dims_notime)
        zdim = isnothing(zdim) ? -1 : zdim
        @assert xdim > 0 "ERA5 longitude dimension not found for $varname"
        @assert ydim > 0 "ERA5 latitude dimension not found for $varname"

        coords = Vector{Vector{Float64}}()
        for d in dims_notime
            if d == "pressure_level"
                # Map pressure levels to integer indices for interpolation.
                plevs_hpa = Float64.(fs.ds["pressure_level"][:])
                # Sort from highest to lowest pressure (surface up).
                plevs_sorted = sort(plevs_hpa, rev=true)
                # Map each to its index in ERA5_PRESSURE_LEVELS_HPA.
                indices = Float64[]
                for p in plevs_sorted
                    idx = findfirst(isequal(round(Int, p)), ERA5_PRESSURE_LEVELS_HPA)
                    @assert idx !== nothing "Pressure level $(p) hPa not in ERA5_PRESSURE_LEVELS_HPA"
                    push!(indices, Float64(idx))
                end
                push!(coords, indices)
                varsize[zdim] = length(indices)
            elseif d == "latitude"
                lat_vals = Float64.(fs.ds["latitude"][:])
                sort!(lat_vals)  # Ensure ascending order.
                lat_vals .= deg2rad.(lat_vals)
                push!(coords, lat_vals)
            elseif d == "longitude"
                lon_vals = Float64.(fs.ds["longitude"][:])
                # Shift from 0..360 to -180..180.
                lon_vals = [v >= 180.0 ? v - 360.0 : v for v in lon_vals]
                sort!(lon_vals)
                lon_vals .= deg2rad.(lon_vals)
                push!(coords, lon_vals)
            else
                push!(coords, Float64.(fs.ds[d][:]))
            end
        end

        prj = "+proj=longlat +datum=WGS84 +no_defs"
        staggering = (false, false, false)  # ERA5 is on a regular, center-aligned grid.

        return MetaData(
            coords, unit_str, description, dims_notime, varsize,
            prj, xdim, ydim, zdim, staggering
        )
    end
end

function varnames(fs::ERA5PressureLevelFileSet)
    return fs.varlist
end

# Module-level interpolator mapping level index to pressure in hPa.
const era5_P_itp = DataInterpolations.LinearInterpolation(
    Float64.(ERA5_PRESSURE_LEVELS_HPA), 1:length(ERA5_PRESSURE_LEVELS_HPA)
)

struct ERA5Coupler
    sys::Any
end

"""
$(SIGNATURES)

A data loader for ERA5 reanalysis data on pressure levels from the
Copernicus Climate Data Store (CDS).

ERA5 is the fifth generation ECMWF atmospheric reanalysis of the global climate,
covering 1940 to present with hourly temporal resolution and 0.25deg x 0.25deg spatial resolution
on 37 pressure levels.

**Authentication**: Requires a CDS API key. Either:
- Set `ENV["CDSAPI_KEY"]`
- Create `~/.cdsapirc` with `url: https://cds.climate.copernicus.eu/api` and `key: <your-key>`

**Pre-downloaded data**: Pass `mirror="file:///path/to/data"` to use local NetCDF files.
Expected filenames: `era5_pl_YYYY_MM.nc` containing all variables for that month.

Available variables (all on pressure levels):
temperature, u/v wind, vertical velocity, specific/relative humidity, geopotential,
divergence, vorticity, ozone, cloud fractions, potential vorticity.

The native data type for this dataset is Float32.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.
"""
function ERA5(
        domaininfo::DomainInfo;
        name=:ERA5,
        mirror::AbstractString=CDS_API_URL,
        variables::Vector{String}=collect(keys(ERA5_VARIABLES)),
        stream=true,
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = ERA5PressureLevelFileSet(domaininfo; mirror=mirror, variables=variables)

    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)

    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    eqs = Equation[]
    params = Any[t_ref]
    vars = Num[]

    # Map ERA5 dimension names to DomainInfo coordinate names.
    coord_map = Dict("longitude" => :lon, "latitude" => :lat, "pressure_level" => :lev)

    for varname in varnames(fs)
        dt = EarthSciMLBase.dtype(domaininfo)
        itp = DataSetInterpolator{dt}(
            fs, varname, starttime, endtime, domaininfo; stream=stream
        )
        dims = dimnames(itp)
        coords = Num[]
        for dim in dims
            mapped = get(coord_map, dim, Symbol(dim))
            @assert mapped ∈ keys(pvdict) "ERA5 dimension $(dim) (mapped to $(mapped)) not in domaininfo coordinates ($(pvs))."
            push!(coords, pvdict[mapped])
        end
        eq, param = create_interp_equation(itp, "pl", t, t_ref, coords)
        push!(eqs, eq)
        push!(params, param)
        push!(vars, eq.lhs)
    end

    syms = EarthSciMLBase.var2symbol.(vars)
    getvar(sym::Symbol) = begin
        i = findfirst(isequal(sym), syms)
        @assert !isnothing(i) "ERA5 variable $(sym) not found!"
        vars[i]
    end

    # Pressure from level index.
    # ERA5 is on pressure levels, so P is directly available from the level index.
    @constants hPa2Pa = 100.0 [unit = u"Pa", description = "Conversion hPa to Pa"]
    @variables P(t) [unit = u"Pa", description = "Pressure"]
    lev = pvdict[:lev]
    push!(eqs, P ~ hPa2Pa * era5_P_itp(lev))
    push!(vars, P)

    # Coordinate transforms.
    if :lat in keys(pvdict)
        @variables δxδlon(t) [unit = u"m/rad", description = "X gradient with respect to longitude"]
        @variables δyδlat(t) [unit = u"m/rad", description = "Y gradient with respect to latitude"]
        @constants lat2meters = 111.32e3 * 180 / π [unit = u"m/rad"]
        @constants lon2m = 40075.0e3 / 2π [unit = u"m/rad"]
        push!(eqs, δxδlon ~ lon2m * cos(pvdict[:lat]))
        push!(eqs, δyδlat ~ lat2meters)
        push!(vars, δxδlon, δyδlat)
    end

    # Vertical coordinate transform: δPδlev (change in pressure per level index).
    if :lev in keys(pvdict)
        @variables δPδlev(t) [unit = u"Pa", description = "Pressure gradient with respect to level index"]
        push!(eqs, δPδlev ~ hPa2Pa * DataInterpolations.derivative(era5_P_itp, lev))
        push!(vars, δPδlev)
    end

    all_params = [
        get(pvdict, :lon, nothing),
        get(pvdict, :lat, nothing),
        get(pvdict, :lev, nothing),
        hPa2Pa, lat2meters, lon2m,
        params...
    ]
    filter!(!isnothing, all_params)

    sys = System(
        eqs, t, vars, all_params;
        name=name,
        metadata=Dict(
            CoupleType => ERA5Coupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime),
        ),
    )
    return sys
end

function EarthSciMLBase.couple2(mw::EarthSciMLBase.MeanWindCoupler, e::ERA5Coupler)
    mw, e = mw.sys, e.sys
    eqs = [mw.v_lon ~ e.pl₊u]
    length(unknowns(mw)) > 1 ? push!(eqs, mw.v_lat ~ e.pl₊v) : nothing
    length(unknowns(mw)) > 2 ? push!(eqs, mw.v_lev ~ e.pl₊w) : nothing
    ConnectorSystem(eqs, mw, e)
end

function EarthSciMLBase.couple2(e::NEI2016MonthlyEmisCoupler, g::ERA5Coupler)
    e, g = e.sys, g.sys
    e = param_to_var(e, :lat, :lon, :lev)
    ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon, e.lev ~ g.lev], e, g)
end
