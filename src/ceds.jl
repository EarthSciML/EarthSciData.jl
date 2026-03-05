export CEDS

# CEDS sector names, indexed 0-7 in the NetCDF files.
const CEDS_SECTORS = [
    "Agriculture",
    "Energy",
    "Industrial",
    "Transportation",
    "Residential, Commercial, Other",
    "Solvents production and application",
    "Waste",
    "International Shipping",
]

# Default bulk emission species available in CEDS.
const CEDS_SPECIES = [
    "BC", "CH4", "CO", "CO2", "N2O", "NH3", "NMVOC", "NOx", "OC", "SO2",
]

# Time ranges for the gn (native grid) files as (start_year, end_year) pairs.
const CEDS_GN_CHUNKS = [
    (1750, 1799),
    (1800, 1849),
    (1850, 1899),
    (1900, 1949),
    (1950, 1999),
    (2000, 2023),
]

"""
$(SIGNATURES)

Return the CEDS file time chunk (start_year, end_year) that contains the given year.
"""
function _ceds_chunk_for_year(year::Int)
    for (y1, y2) in CEDS_GN_CHUNKS
        if y1 <= year <= y2
            return (y1, y2)
        end
    end
    error("Year $year is outside the CEDS data range (1750-2023).")
end

"""
$(SIGNATURES)

CEDS (Community Emissions Data System) gridded emissions data.

Data is from the CEDS-CMIP release, providing global monthly anthropogenic
emissions at 0.5° × 0.5° resolution. Each file contains one species and
has dimensions `(time, sector, lat, lon)` with units `kg m⁻² s⁻¹`.

Reference: Hoesly et al., 2018, https://doi.org/10.5194/gmd-11-369-2018

`species` specifies which emission species to load (e.g., "SO2").
`sectors` is an optional vector of sector indices (0-7) to include;
`nothing` means sum all sectors (default).
"""
struct CEDSFileSet <: FileSet
    mirror::AbstractString
    species::AbstractString
    version::AbstractString
    data_version::AbstractString
    sectors::Union{Nothing, Vector{Int}}
    ds::Any
    freq_info::DataFrequencyInfo
    lon_perm::Vector{Int}  # Permutation to reorder lon from [0,360) to [-180,180).

    function CEDSFileSet(species, starttime, endtime;
            mirror = "https://esgf-node.ornl.gov/thredds/fileServer/user_pub_work",
            version = "CEDS-CMIP-2025-04-18",
            data_version = "v20250421",
            sectors = nothing)
        # Determine which file chunks we need.
        start_year = Dates.year(starttime)
        end_year = Dates.year(endtime)
        chunk_set = Set{Tuple{Int, Int}}()
        for y in start_year:end_year
            push!(chunk_set, _ceds_chunk_for_year(y))
        end
        # Also include the chunk for the month before starttime for interpolation.
        prev_month = starttime - Month(1)
        push!(chunk_set, _ceds_chunk_for_year(Dates.year(prev_month)))
        # And the chunk for the month after endtime.
        next_month = endtime + Month(1)
        if Dates.year(next_month) <= 2023
            push!(chunk_set, _ceds_chunk_for_year(Dates.year(next_month)))
        end
        chunks = sort(collect(chunk_set))

        # Compute the longitude permutation to reorder from [0,360) to [-180,180).
        # We do this once and store it for use in loadslice!.
        dummy_perm = Int[]  # Placeholder for the temp FileSet.
        check_times = [DateTime(y1, 1, 1) for (y1, _) in chunks]
        fs_temp = new(mirror, species, version, data_version, sectors, nothing,
            DataFrequencyInfo(starttime, Day(1), check_times), dummy_perm)
        filepaths = [maybedownload(fs_temp, DateTime(y1, 1, 1)) for (y1, _) in chunks]

        # Open all files as an aggregated dataset.
        ds = lock(nclock) do
            NCDataset(filepaths, aggdim = "time")
        end

        # Compute longitude reordering permutation.
        lons_deg = Float64.(ds["lon"][:])
        lons_wrapped = [l > 180 ? l - 360 : l for l in lons_deg]
        lon_perm = sortperm(lons_wrapped)

        # Build DataFrequencyInfo from the time dimension.
        # CEDS uses a 365-day (no-leap) calendar, so NCDatasets returns
        # CFTime.DateTimeNoLeap objects. We convert to standard DateTime
        # by extracting year/month/day components. The small calendar
        # differences (no leap days) are acceptable for monthly data.
        cftimes = lock(nclock) do
            ds["time"][:]
        end
        times = [DateTime(Dates.year(ct), Dates.month(ct), Dates.day(ct),
                          Dates.hour(ct), Dates.minute(ct), Dates.second(ct))
                 for ct in cftimes]
        frequency = Month(1)
        dfi = DataFrequencyInfo(times[1], frequency, times)

        new(mirror, species, version, data_version, sectors, ds, dfi, lon_perm)
    end
end

"""
$(SIGNATURES)

File path on the server relative to the mirror root; also used for local caching.
The `t` parameter determines which 50-year chunk file to select.
"""
function relpath(fs::CEDSFileSet, t::DateTime)
    year = Dates.year(t)
    y1, y2 = _ceds_chunk_for_year(year)
    y1s = lpad(y1, 4, '0')
    y2s = lpad(y2, 4, '0')
    varname = "$(fs.species)_em_anthro"
    filename = "$(fs.species)-em-anthro_input4MIPs_emissions_CMIP_$(fs.version)_gn_$(y1s)01-$(y2s)12.nc"
    return "input4MIPs/CMIP7/CMIP/PNNL-JGCRI/$(fs.version)/atmos/mon/$(varname)/gn/$(fs.data_version)/$(filename)"
end

DataFrequencyInfo(fs::CEDSFileSet) = fs.freq_info

"""
$(SIGNATURES)

Load a time slice from the CEDS dataset, summing across sectors (or filtering by
selected sectors). The result is a 2D (lat, lon) array in kg m⁻² s⁻¹.
"""
function loadslice!(
        data::AbstractArray,
        fs::CEDSFileSet,
        t::DateTime,
        varname
)
    lock(nclock) do
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        time_index = findfirst(isequal("time"), dims)
        ti = centerpoint_index(DataFrequencyInfo(fs), t)

        # Slice out the time dimension.
        slices = repeat(Any[:], length(dims))
        slices[time_index] = ti
        raw = var[slices...]  # e.g. shape (lon, lat, sector)

        # Replace fill values before any processing.
        fill_val = get(var.attrib, "_FillValue", 1.0f20)
        raw[raw .>= fill_val] .= 0

        # Find lon dimension in the sliced array (for permutation).
        lon_dim_orig = findfirst(isequal("lon"), dims)
        lon_dim = lon_dim_orig - (time_index < lon_dim_orig ? 1 : 0)

        # Sum across sectors.
        sector_dim_orig = findfirst(isequal("sector"), dims)
        result = if isnothing(sector_dim_orig)
            raw
        else
            sector_dim = sector_dim_orig - (time_index < sector_dim_orig ? 1 : 0)
            if isnothing(fs.sectors)
                dropdims(sum(raw; dims=sector_dim); dims=sector_dim)
            else
                total = zeros(eltype(raw), [s for (i, s) in enumerate(size(raw)) if i != sector_dim]...)
                for si in fs.sectors
                    total .+= selectdim(raw, sector_dim, si + 1)
                end
                total
            end
        end

        # If sector_dim was before lon_dim, lon_dim shifted down by 1 in result.
        if !isnothing(sector_dim_orig)
            sd = sector_dim_orig - (time_index < sector_dim_orig ? 1 : 0)
            if sd < lon_dim
                lon_dim -= 1
            end
        end

        # Apply longitude permutation to reorder from [0,360) to [-180,180).
        data .= selectdim(result, lon_dim, fs.lon_perm)
    end
    nothing
end

"""
$(SIGNATURES)

Load metadata for the given variable in the CEDS dataset.
"""
function loadmetadata(fs::CEDSFileSet, varname)::MetaData
    lock(nclock) do
        var = fs.ds[varname]

        # Get coordinates, convert lon from [0,360) to [-180,180), then to radians.
        # Use the precomputed permutation from the FileSet.
        lons_deg = Float64.(fs.ds["lon"][:])
        lons_wrapped = [l > 180 ? l - 360 : l for l in lons_deg]
        lons = deg2rad.(lons_wrapped[fs.lon_perm])
        lats = deg2rad.(Float64.(fs.ds["lat"][:]))

        # Units and description.
        _, units = to_unit(var.attrib["units"])
        description = var.attrib["long_name"]

        # Dimension info: after removing time and sector, we have (lat, lon).
        dimnames_out = ["lon", "lat"]
        varsize = [length(lons), length(lats)]

        native_sr = "+proj=longlat +datum=WGS84 +no_defs"
        xdim = 1  # lon
        ydim = 2  # lat

        coords = [lons, lats]

        return MetaData(
            coords,
            string(units),
            description,
            dimnames_out,
            varsize,
            native_sr,
            xdim,
            ydim,
            -1,         # No z dimension.
            (false, false, false)
        )
    end
end

"""
$(SIGNATURES)

Return the variable names for this CEDS FileSet.
"""
function varnames(fs::CEDSFileSet)
    ["$(fs.species)_em_anthro"]
end

Base.close(fs::CEDSFileSet) = lock(nclock) do
    close(fs.ds)
end

struct CEDSCoupler
    sys::Any
end

"""
$(SIGNATURES)

A data loader for CEDS (Community Emissions Data System) global gridded
anthropogenic emissions.

CEDS provides monthly emissions at 0.5° × 0.5° resolution from 1750 to 2023
in units of kg m⁻² s⁻¹, with 8 anthropogenic sectors.

Reference: Hoesly et al., 2018, https://doi.org/10.5194/gmd-11-369-2018

Available species: $(join(CEDS_SPECIES, ", ")).

Sectors (0-7): $(join(["$i: $(CEDS_SECTORS[i+1])" for i in 0:7], "; ")).

## Keyword Arguments

- `species`: Vector of species to load. Default is all: `$(CEDS_SPECIES)`.
- `sectors`: Vector of sector indices (0-7) to include, or `nothing` for all (default).
- `mirror`: Base URL for data download. Default is the ORNL ESGF THREDDS server.
- `version`: CEDS source version. Default is `"CEDS-CMIP-2025-04-18"`.
- `data_version`: Data version string. Default is `"v20250421"`.
- `name`: System name. Default is `:CEDS`.
- `stream`: Whether to stream data on demand. Default is `true`.
"""
function CEDS(
        domaininfo::DomainInfo;
        species::AbstractVector{<:AbstractString} = CEDS_SPECIES,
        sectors::Union{Nothing, Vector{Int}} = nothing,
        mirror::AbstractString = "https://esgf-node.ornl.gov/thredds/fileServer/user_pub_work",
        version::AbstractString = "CEDS-CMIP-2025-04-18",
        data_version::AbstractString = "v20250421",
        name = :CEDS,
        stream = true,
)
    starttime, endtime = get_tspan_datetime(domaininfo)

    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :lon in keys(pvdict) "lon must be specified in the domaininfo"
    @assert :lat in keys(pvdict) "lat must be specified in the domaininfo"
    lon = pvdict[:lon]
    lat = pvdict[:lat]

    @parameters t_ref=get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    eqs = Equation[]
    params = Any[t_ref]
    vars = Num[]

    for sp in species
        fs = CEDSFileSet(sp, starttime, endtime;
            mirror = mirror, version = version, data_version = data_version,
            sectors = sectors)
        varname = "$(sp)_em_anthro"
        dt = EarthSciMLBase.eltype(domaininfo)
        itp = DataSetInterpolator{dt}(fs, varname, starttime, endtime, domaininfo;
            stream = stream)
        eq, param = create_interp_equation(itp, "", t, t_ref, [lon, lat])
        push!(eqs, eq)
        push!(params, param)
        push!(vars, eq.lhs)
    end

    sys = System(
        eqs,
        t,
        vars,
        [lon, lat, params...];
        name = name,
        metadata = Dict(CoupleType => CEDSCoupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime))
    )
    return sys
end

function EarthSciMLBase.couple2(c::CEDSCoupler, g::GEOSFPCoupler)
    c, g = c.sys, g.sys
    c = param_to_var(c, :lat, :lon)
    ConnectorSystem([c.lat ~ g.lat, c.lon ~ g.lon], c, g)
end
