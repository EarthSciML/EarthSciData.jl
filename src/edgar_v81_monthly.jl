export EDGARv81MonthlyEmis

const EDGAR_V81_SUBSTANCES = [
    "BC", "CO", "NH3", "NMVOC", "NOx", "OC", "PM10", "PM2.5", "SO2"
]

const EDGAR_V81_MIRROR = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/EDGAR/datasets/v81_FT2022_AP_new/monthly"

# Internal: compute relative path for the EDGAR zip file (flux data).
function _edgar_zip_relpath(substance, sector)
    "$(substance)/bkl_$(sector)/bkl_$(sector)_flx_nc.zip"
end

# Internal: parse year from an EDGAR NC filename.
# Matches a 4-digit year surrounded by underscores (e.g. _2020_) to avoid
# matching "2022" in the version string "FT2022".
function _parse_edgar_nc_year(filepath)
    fname = basename(filepath)
    for m in eachmatch(r"_(\d{4})_", fname)
        year = parse(Int, m[1])
        if 2000 <= year <= 2030
            return year
        end
    end
    return nothing
end

# Internal: find NC files in extract_dir filtered by year range, sorted by year.
function _find_edgar_nc_files(extract_dir, start_year, end_year)
    all_files = filter(f -> endswith(f, ".nc"), readdir(extract_dir, join = true))
    result = String[]
    for f in all_files
        yr = _parse_edgar_nc_year(f)
        isnothing(yr) && continue
        if start_year <= yr <= end_year
            push!(result, f)
        end
    end
    sort!(result, by = f -> _parse_edgar_nc_year(f))
    return result
end

# Internal: download zip and extract NC files if not already done.
function _edgar_ensure_extracted(zip_url, zip_local, extract_dir)
    if isdir(extract_dir) && !isempty(filter(f -> endswith(f, ".nc"), readdir(extract_dir)))
        return
    end
    if !isfile(zip_local)
        mkpath(dirname(zip_local))
        @info "Downloading EDGAR data from $zip_url"
        try
            prog = Progress(100; desc = "Downloading $(basename(zip_url)):", dt = 0.1)
            Downloads.download(zip_url, zip_local,
                progress = (total::Integer, now::Integer) -> begin
                    prog.n = total
                    ProgressMeter.update!(prog, now)
                end
            )
        catch e
            rm(zip_local, force = true)
            rethrow(e)
        end
    end
    mkpath(extract_dir)
    @info "Extracting EDGAR NC files to $extract_dir"
    _extract_edgar_zip(zip_local, extract_dir)
end

# Internal: extract .nc files from a zip archive.
function _extract_edgar_zip(zip_path, extract_dir)
    r = ZipFile.Reader(zip_path)
    try
        for f in r.files
            fname = basename(f.name)
            if endswith(fname, ".nc") && !startswith(fname, ".")
                outpath = joinpath(extract_dir, fname)
                if !isfile(outpath)
                    write(outpath, read(f))
                end
            end
        end
    finally
        close(r)
    end
end

"""
$(SIGNATURES)

EDGAR v8.1 monthly air pollutant emissions data.
Global 0.1°×0.1° gridded flux data for 2000-2022.

Substances: $(join(EDGAR_V81_SUBSTANCES, ", "))

Available from: https://edgar.jrc.ec.europa.eu/dataset_ap81
"""
struct EDGARv81MonthlyEmisFileSet <: FileSet
    mirror::AbstractString
    substance::AbstractString
    sector::AbstractString
    ds::Any
    freq_info::DataFrequencyInfo
    extract_dir::AbstractString

    function EDGARv81MonthlyEmisFileSet(substance, sector, starttime, endtime)
        EDGARv81MonthlyEmisFileSet(EDGAR_V81_MIRROR, substance, sector, starttime, endtime)
    end

    function EDGARv81MonthlyEmisFileSet(mirror, substance, sector, starttime, endtime)
        @assert substance in EDGAR_V81_SUBSTANCES "Invalid EDGAR substance '$substance'. Valid: $(EDGAR_V81_SUBSTANCES)"

        # Download and extract zip
        zip_rpath = _edgar_zip_relpath(substance, sector)
        zip_url = join([mirror, zip_rpath], "/")
        zip_local = joinpath(download_cache(), replace(mirror, "://" => "_"),
            replace(zip_rpath, ':' => '_'))
        extract_dir = zip_local * "_extracted"

        _edgar_ensure_extracted(zip_url, zip_local, extract_dir)

        # Determine needed year range with buffer for interpolation
        floormonth(t) = DateTime(Dates.year(t), Dates.month(t))
        buffer_start = floormonth(starttime - Day(45))
        buffer_end = floormonth(endtime + Day(45))
        start_year = max(2000, Dates.year(buffer_start))
        end_year = min(2022, Dates.year(buffer_end))

        nc_files = _find_edgar_nc_files(extract_dir, start_year, end_year)
        @assert length(nc_files)>0 "No EDGAR NC files found for years $start_year-$end_year in $extract_dir"

        lock(nclock) do
            ds = NCDataset(nc_files, aggdim = "time")

            # Build centerpoints from the time variable in the aggregated dataset.
            raw_times = ds["time"][:]
            centerpoints = sort([DateTime(t) for t in raw_times])

            start = floormonth(starttime)
            frequency = (start + Month(1)) - start
            dfi = DataFrequencyInfo(start, frequency, centerpoints)

            new(mirror, substance, sector, ds, dfi, extract_dir)
        end
    end
end

"""
$(SIGNATURES)

File path on the server relative to the host root.
For EDGAR, this returns the zip file path (all times are in one archive).
"""
function relpath(fs::EDGARv81MonthlyEmisFileSet, t::DateTime)
    yr = Dates.year(t)
    @assert 2000<=yr<=2022 "EDGAR v8.1 data is only available for years 2000-2022, got $yr."
    return _edgar_zip_relpath(fs.substance, fs.sector)
end

DataFrequencyInfo(fs::EDGARv81MonthlyEmisFileSet) = fs.freq_info

"""
$(SIGNATURES)

Load the data in place for the given variable name at the given time.
"""
function loadslice!(
        data::AbstractArray,
        fs::EDGARv81MonthlyEmisFileSet,
        t::DateTime,
        varname
)
    lock(nclock) do
        var = loadslice!(data, fs, fs.ds, t, varname, "time")

        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
    end
    nothing
end

"""
$(SIGNATURES)

Load metadata for the given variable.
"""
function loadmetadata(fs::EDGARv81MonthlyEmisFileSet, varname)::MetaData
    lock(nclock) do
        timedim = "time"
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        unit_str = haskey(var.attrib, "units") ? var.attrib["units"] : "kg m-2 s-1"
        description = if haskey(var.attrib, "long_name")
            var.attrib["long_name"]
        elseif haskey(var.attrib, "standard_name")
            var.attrib["standard_name"]
        else
            varname
        end

        coords = [fs.ds[d][:] for d in dims]

        xdim = findfirst(x -> x in ("lon", "longitude"), dims)
        ydim = findfirst(x -> x in ("lat", "latitude"), dims)
        @assert !isnothing(xdim) "EDGAR longitude dimension not found in dims: $dims"
        @assert !isnothing(ydim) "EDGAR latitude dimension not found in dims: $dims"

        # Convert from degrees to radians (SI)
        coords[xdim] .= deg2rad.(coords[xdim])
        coords[ydim] .= deg2rad.(coords[ydim])

        prj = "+proj=longlat +datum=WGS84 +no_defs"

        return MetaData(
            coords,
            unit_str,
            description,
            dims,
            varsize,
            prj,
            xdim,
            ydim,
            -1,
            (false, false, false)
        )
    end
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::EDGARv81MonthlyEmisFileSet)
    lock(nclock) do
        dimkeys = Set(keys(fs.ds.dim))
        all_keys = keys(fs.ds)
        # Exclude dimension variables and common auxiliary variables
        exclude = union(dimkeys, Set(["time_bnds", "lat_bnds", "lon_bnds", "crs"]))
        return [k for k in all_keys if !(k in exclude)]
    end
end

Base.close(fs::EDGARv81MonthlyEmisFileSet) = lock(nclock) do; close(fs.ds); end

struct EDGARv81MonthlyEmisCoupler
    sys::Any
end

"""
$(SIGNATURES)

A data loader for EDGAR v8.1 monthly global air pollutant emissions data at 0.1°×0.1° resolution.
Data spans 2000-2022 and is available from: https://edgar.jrc.ec.europa.eu/dataset_ap81

`substance` is the pollutant name (one of: $(join(EDGAR_V81_SUBSTANCES, ", "))).

`sector` is the emission sector (e.g. "POWER_INDUSTRY", "TRANSPORT", "AGRICULTURE", etc.).

`domaininfo` should specify lon, lat, and lev coordinate variables.

`scale` is a scaling factor to apply to the emissions data.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.

Note: emissions are applied only at the surface level (lev < 2) and converted from
flux (kg m⁻² s⁻¹) to volumetric rate (kg m⁻³ s⁻¹) by dividing by the first-layer height Δz.
"""
function EDGARv81MonthlyEmis(
        substance::AbstractString,
        sector::AbstractString,
        domaininfo::DomainInfo;
        scale = 1.0,
        name = :EDGARv81MonthlyEmis,
        stream = true
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = EDGARv81MonthlyEmisFileSet(substance, sector, starttime, endtime)
    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :lon in keys(pvdict) "lon must be specified in the domaininfo"
    @assert :lat in keys(pvdict) "lat must be specified in the domaininfo"
    @assert :lev in keys(pvdict) "lev must be specified in the domaininfo"
    lon = pvdict[:lon]
    lat = pvdict[:lat]
    lev = pvdict[:lev]
    @parameters(Δz=60.0,
        [unit = u"m", description = "Height of the first vertical grid layer"],)
    @parameters t_ref=get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    eqs = Equation[]
    params = Any[t_ref]
    vars = Num[]
    for varname in varnames(fs)
        dt = EarthSciMLBase.eltype(domaininfo)
        itp = DataSetInterpolator{dt}(fs, varname, starttime, endtime, domaininfo;
            stream = stream)
        ze_name = Symbol(:zero_, varname)
        zero_emis = only(@constants $(ze_name)=0 [unit = units(itp) / u"m"])
        zero_emis = ModelingToolkit.unwrap(zero_emis)
        wrapper_f = (eq) -> ifelse(lev < 2, eq / Δz * scale, zero_emis)
        eq, param = create_interp_equation(itp, "", t, t_ref, [lon, lat];
            wrapper_f = wrapper_f)
        push!(eqs, eq)
        push!(params, param, zero_emis)
        push!(vars, eq.lhs)
    end
    all_params = [lon, lat, lev, Δz, params...]
    sys = System(
        eqs,
        t,
        vars,
        all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        metadata = Dict(CoupleType => EDGARv81MonthlyEmisCoupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime))
    )
    return sys
end
