export OpenAQ, OpenAQCoupler

struct OpenAQCoupler
    sys::Any
end

const OPENAQ_S3_MIRROR = "https://openaq-data-archive.s3.amazonaws.com"
const OPENAQ_API_BASE = "https://api.openaq.org/v3"

# OpenAQ parameter name => (api_id, unit_string, description)
const OPENAQ_PARAMETERS = Dict(
    "pm25" => (id = 2, unit = "ug/m3", description = "Particulate matter (PM2.5)"),
    "pm10" => (id = 1, unit = "ug/m3", description = "Particulate matter (PM10)"),
    "o3" => (id = 3, unit = "ug/m3", description = "Ozone"),
    "no2" => (id = 5, unit = "ug/m3", description = "Nitrogen dioxide"),
    "so2" => (id = 4, unit = "ug/m3", description = "Sulfur dioxide"),
    "co" => (id = 6, unit = "ug/m3", description = "Carbon monoxide"),
    "bc" => (id = 11, unit = "ug/m3", description = "Black carbon"),
    "pm1" => (id = 19, unit = "ug/m3", description = "Particulate matter (PM1)"),
    "no" => (id = 7, unit = "ug/m3", description = "Nitric oxide"),
    "nox" => (id = 8, unit = "ug/m3", description = "Nitrogen oxides")
)

"""
Information about an OpenAQ monitoring station.

$(FIELDS)
"""
struct OpenAQStation
    "OpenAQ location ID"
    id::Int
    "Station name"
    name::String
    "Longitude in radians"
    lon::Float64
    "Latitude in radians"
    lat::Float64
end

"""
$(SIGNATURES)

A `FileSet` for OpenAQ air quality monitoring data.

Data is sourced from the OpenAQ AWS S3 archive (gzip-compressed CSV files).
Station locations within the model domain are discovered via the OpenAQ API
and cached locally. Measurement data is downloaded from S3 (no API key needed
for data download).

Point observations from monitoring stations are mapped to model grid cells by
averaging all stations that fall within each cell. Grid cells with no stations
receive a configurable fill value (default `NaN`).

The `station_filter` function can be used to filter stations, e.g. by name or ID.
It should accept an `OpenAQStation` and return `true` to include the station.
"""
struct OpenAQFileSet <: FileSet
    parameter::String
    stations::Vector{OpenAQStation}
    freq_info::DataFrequencyInfo
    grid_lon_edges::Vector{Float64}
    grid_lat_edges::Vector{Float64}
    fill_value::Float64
    unit_scale::Float64
    # Precomputed mapping: grid_index => [station_indices...]
    cell_stations::Dict{Tuple{Int, Int}, Vector{Int}}
    # Per-instance cache: (location_id, date) => parsed rows for that parameter
    day_cache::Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}
    day_cache_lock::ReentrantLock
end

"""
$(SIGNATURES)

Construct an `OpenAQFileSet` for the given parameter and time range.

`parameter` is the OpenAQ parameter name (e.g. "pm25", "o3", "no2").

`bbox` is a named tuple `(lon_min, lat_min, lon_max, lat_max)` in **degrees**
specifying the bounding box for station discovery.

`api_key` is the OpenAQ API key. Defaults to `ENV["OPENAQ_API_KEY"]`.

`station_filter` is an optional function `f(::OpenAQStation) -> Bool` to filter stations.
Note: station coordinates (`lon`, `lat`) are in radians when the filter is applied.

`fill_value` is used for grid cells with no stations (default `0.0`).
"""
function OpenAQFileSet(
        parameter::AbstractString,
        starttime::DateTime,
        endtime::DateTime,
        bbox::NamedTuple{(:lon_min, :lat_min, :lon_max, :lat_max)};
        grid_lon_edges::AbstractVector{<:Real} = Float64[],
        grid_lat_edges::AbstractVector{<:Real} = Float64[],
        api_key::AbstractString = get(ENV, "OPENAQ_API_KEY", ""),
        station_filter::Function = (_) -> true,
        # TODO: fill_value should be `missing` or `NaN` so downstream code can
        # distinguish cells with measurements from cells without. Currently 0.0
        # because DataSetInterpolator's BSpline propagates NaN to the entire field.
        fill_value::Real = 0.0
)
    @assert !isempty(api_key) "OpenAQ API key is required. Set ENV[\"OPENAQ_API_KEY\"] or pass `api_key`."
    @assert !isempty(grid_lon_edges) "grid_lon_edges must be provided"
    @assert !isempty(grid_lat_edges) "grid_lat_edges must be provided"

    stations = discover_stations(parameter, bbox, api_key, station_filter)
    @info "OpenAQ: found $(length(stations)) stations for parameter '$parameter' in domain"

    # Download data for all stations for the required time range.
    download_station_data(stations, starttime, endtime)

    frequency = Hour(1)
    centerpoints = collect(starttime:frequency:endtime)
    freq_info = DataFrequencyInfo(starttime, frequency, centerpoints)

    lon_edges = collect(Float64, grid_lon_edges)
    lat_edges = collect(Float64, grid_lat_edges)

    cell_stations = _build_cell_station_map(stations, lon_edges, lat_edges)

    unit_scale = 1.0
    if haskey(OPENAQ_PARAMETERS, parameter)
        unit_scale, _ = to_unit(OPENAQ_PARAMETERS[parameter].unit)
    end

    OpenAQFileSet(
        String(parameter),
        stations,
        freq_info,
        lon_edges,
        lat_edges,
        Float64(fill_value),
        Float64(unit_scale),
        cell_stations,
        Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
        ReentrantLock()
    )
end

"""
Build a mapping from (i, j) grid cell indices to vectors of station indices.
Grid edges are in radians.
"""
function _build_cell_station_map(
        stations::Vector{OpenAQStation},
        lon_edges::Vector{Float64},
        lat_edges::Vector{Float64}
)
    cell_stations = Dict{Tuple{Int, Int}, Vector{Int}}()
    nx = length(lon_edges) - 1
    ny = length(lat_edges) - 1
    for (si, st) in enumerate(stations)
        ix = searchsortedlast(lon_edges, st.lon)
        iy = searchsortedlast(lat_edges, st.lat)
        if 1 <= ix <= nx && 1 <= iy <= ny
            push!(get!(Vector{Int}, cell_stations, (ix, iy)), si)
        end
    end
    cell_stations
end

# --- Station discovery via OpenAQ API ---

"""
$(SIGNATURES)

Discover OpenAQ stations within the given bounding box for the specified parameter.
Uses the OpenAQ v3 API with pagination. Results are cached locally.
`bbox` values are in degrees.
"""
function discover_stations(
        parameter::AbstractString,
        bbox::NamedTuple{(:lon_min, :lat_min, :lon_max, :lat_max)},
        api_key::AbstractString,
        station_filter::Function
)
    cache_dir = joinpath(download_cache(), "openaq_stations")
    mkpath(cache_dir)

    bbox_str = "$(bbox.lon_min)_$(bbox.lat_min)_$(bbox.lon_max)_$(bbox.lat_max)"
    cache_file = joinpath(cache_dir, "$(parameter)_$(bbox_str).json")

    local raw_stations::Vector
    if isfile(cache_file)
        @info "OpenAQ: loading cached station list from $cache_file"
        raw_stations = JSON3.read(read(cache_file, String))
    else
        raw_stations = _fetch_stations_from_api(parameter, bbox, api_key)
        open(cache_file, "w") do io
            JSON3.write(io, raw_stations)
        end
    end

    stations = OpenAQStation[]
    for s in raw_stations
        coords = s["coordinates"]
        st = OpenAQStation(
            s["id"],
            get(s, "name", "unknown"),
            deg2rad(coords["longitude"]),
            deg2rad(coords["latitude"])
        )
        if station_filter(st)
            push!(stations, st)
        end
    end
    stations
end

function _fetch_stations_from_api(
        parameter::AbstractString,
        bbox::NamedTuple{(:lon_min, :lat_min, :lon_max, :lat_max)},
        api_key::AbstractString
)
    all_results = Any[]
    page = 1
    limit = 1000

    while true
        url_str = "$(OPENAQ_API_BASE)/locations?" *
                  "bbox=$(bbox.lon_min),$(bbox.lat_min),$(bbox.lon_max),$(bbox.lat_max)" *
                  "&parameter_id=$(_parameter_id(parameter))" *
                  "&limit=$limit&page=$page"

        @info "OpenAQ: fetching stations page $page"
        body = _api_get(url_str, api_key)
        results = body["results"]
        append!(all_results, results)

        found = get(get(body, "meta", Dict()), "found", 0)
        if length(all_results) >= found || isempty(results)
            break
        end
        page += 1
        sleep(1.1)  # Respect rate limit (60 req/min)
    end
    all_results
end

function _parameter_id(name::AbstractString)
    haskey(OPENAQ_PARAMETERS, name) && return OPENAQ_PARAMETERS[name].id
    error("Unknown OpenAQ parameter: $name. Known parameters: $(join(keys(OPENAQ_PARAMETERS), ", "))")
end

function _api_get(url_str::AbstractString, api_key::AbstractString)
    headers = ["X-API-Key" => api_key, "Accept" => "application/json"]
    buf = IOBuffer()
    try
        Downloads.download(url_str, buf; headers = headers)
    catch e
        error("OpenAQ API request failed for $url_str: $e")
    end
    body_str = String(take!(buf))
    JSON3.read(body_str)
end

# --- S3 data download ---

"""
$(SIGNATURES)

Download daily CSV.gz files from the OpenAQ S3 archive for the given stations and time range.
"""
function download_station_data(
        stations::Vector{OpenAQStation},
        starttime::DateTime,
        endtime::DateTime
)
    dates = Date(starttime):Day(1):Date(endtime)
    n_total = length(stations) * length(dates)

    tasks = [(st, d) for st in stations for d in dates]
    n_downloaded = Threads.Atomic{Int}(0)
    n_skipped = Threads.Atomic{Int}(0)

    asyncmap(tasks; ntasks = 16) do (st, d)
        p = _s3_localpath(st.id, d)
        if isfile(p)
            Threads.atomic_add!(n_skipped, 1)
            return
        end
        mkpath(dirname(p))
        u = _s3_url(st.id, d)
        try
            Downloads.download(u, p)
            Threads.atomic_add!(n_downloaded, 1)
        catch e
            if e isa Downloads.RequestError
                Threads.atomic_add!(n_skipped, 1)
            else
                @warn "OpenAQ: unexpected error downloading $u" exception=(
                    e, catch_backtrace())
                Threads.atomic_add!(n_skipped, 1)
            end
        end
    end
    nd = n_downloaded[]
    if nd > 0
        @info "OpenAQ: downloaded $nd files ($(n_skipped[]) cached/missing of $n_total total)"
    end
end

function _s3_date_parts(d::Date)
    yr = Dates.year(d)
    mo = lpad(Dates.month(d), 2, '0')
    day_str = Dates.format(d, dateformat"yyyymmdd")
    (yr, mo, day_str)
end

function _s3_url(location_id::Int, d::Date)
    yr, mo, day_str = _s3_date_parts(d)
    "$(OPENAQ_S3_MIRROR)/records/csv.gz/locationid=$(location_id)/year=$(yr)/month=$(mo)/location-$(location_id)-$(day_str).csv.gz"
end

function _s3_localpath(location_id::Int, d::Date)
    yr, mo, day_str = _s3_date_parts(d)
    joinpath(
        download_cache(),
        "openaq_data",
        "locationid=$(location_id)",
        "year=$(yr)",
        "month=$(mo)",
        "location-$(location_id)-$(day_str).csv.gz"
    )
end

# --- FileSet interface implementation ---

DataFrequencyInfo(fs::OpenAQFileSet) = fs.freq_info

function relpath(fs::OpenAQFileSet, t::DateTime)
    yr, mo, day_str = _s3_date_parts(Date(t))
    "openaq/$(fs.parameter)/$(yr)/$(mo)/$(day_str)"
end

function varnames(fs::OpenAQFileSet)
    [fs.parameter]
end

function loadmetadata(fs::OpenAQFileSet, varname)::MetaData
    @assert varname == fs.parameter "OpenAQFileSet only supports parameter '$(fs.parameter)', got '$varname'"

    nx = length(fs.grid_lon_edges) - 1
    ny = length(fs.grid_lat_edges) - 1

    lon_centers = [(fs.grid_lon_edges[i] + fs.grid_lon_edges[i + 1]) / 2 for i in 1:nx]
    lat_centers = [(fs.grid_lat_edges[j] + fs.grid_lat_edges[j + 1]) / 2 for j in 1:ny]

    info = get(OPENAQ_PARAMETERS, varname, (id = 0, unit = "ug/m3", description = varname))
    unit_str = info.unit
    desc = info.description

    MetaData(
        [lon_centers, lat_centers],
        unit_str,
        desc,
        ["lon", "lat"],
        [nx, ny],
        "+proj=longlat +datum=WGS84 +no_defs",
        1,  # xdim
        2,  # ydim
        -1, # zdim (no vertical)
        (false, false, false)
    )
end

function get_geometry(fs::OpenAQFileSet, m::MetaData)
    nx = length(fs.grid_lon_edges) - 1
    ny = length(fs.grid_lat_edges) - 1
    polys = Vector{Vector{NTuple{2, Float64}}}(undef, nx * ny)
    x = fs.grid_lon_edges
    y = fs.grid_lat_edges
    for j in 1:ny, i in 1:nx

        polys[(j - 1) * nx + i] = [
            (x[i], y[j]), (x[i + 1], y[j]), (x[i + 1], y[j + 1]),
            (x[i], y[j + 1]), (x[i], y[j])
        ]
    end
    polys
end

"""
$(SIGNATURES)

Load OpenAQ measurement data for the given time into `data`.
Data is binned onto the grid by averaging all stations within each cell.
"""
function loadslice!(
        data::AbstractArray,
        fs::OpenAQFileSet,
        t::DateTime,
        varname::String
)
    @assert varname == fs.parameter

    fill!(data, fs.fill_value)

    hour_start = Dates.trunc(t, Hour)
    hour_end = hour_start + Hour(1)
    d = Date(t)

    for ((i, j), station_idxs) in fs.cell_stations
        total = 0.0
        count = 0
        for si in station_idxs
            st = fs.stations[si]
            t_s, c_s = _read_station_hour(fs, st.id, d, hour_start, hour_end)
            total += t_s
            count += c_s
        end
        if count > 0
            data[i, j] = total / count * fs.unit_scale
        end
    end
    nothing
end

"""
Load and cache parsed rows for a station's daily CSV file, filtered to the
FileSet's parameter. Returns a vector of (datetime_utc, value) tuples.
The cache is scoped to the `OpenAQFileSet` instance and protected by a lock.
"""
function _load_station_day(fs::OpenAQFileSet, location_id::Int, d::Date)
    key = (location_id, d)
    lock(fs.day_cache_lock) do
        haskey(fs.day_cache, key) && return fs.day_cache[key]

        rows = Tuple{DateTime, Float64}[]
        path = _s3_localpath(location_id, d)
        if !isfile(path)
            fs.day_cache[key] = rows
            return rows
        end

        try
            csv_data = open(path) do io
                read(GzipDecompressorStream(io), String)
            end
            lines = split(csv_data, '\n')
            if !isempty(lines)
                headers = _split_csv_line(lines[1])
                dt_col = findfirst(==("datetime"), headers)
                param_col = findfirst(==("parameter"), headers)
                val_col = findfirst(==("value"), headers)
                if !isnothing(dt_col) && !isnothing(param_col) && !isnothing(val_col)
                    ncols = max(dt_col, param_col, val_col)
                    for i in 2:length(lines)
                        line = lines[i]
                        isempty(line) && continue
                        fields = _split_csv_line(line)
                        length(fields) < ncols && continue

                        # Filter by parameter at parse time
                        fields[param_col] == fs.parameter || continue

                        row_dt = _parse_openaq_datetime(fields[dt_col])
                        isnothing(row_dt) && continue

                        v = tryparse(Float64, fields[val_col])
                        (!isnothing(v) && v >= 0) || continue

                        push!(rows, (row_dt, v))
                    end
                end
            end
        catch e
            @warn "Failed to read OpenAQ data file $path" exception=(e, catch_backtrace())
        end
        fs.day_cache[key] = rows
        rows
    end
end

"""
Read measurements for a single station for a single hour.
Returns `(total, count)` for computing an average.
Uses cached daily data to avoid repeated decompression.
"""
function _read_station_hour(
        fs::OpenAQFileSet,
        location_id::Int,
        d::Date,
        hour_start::DateTime,
        hour_end::DateTime
)
    rows = _load_station_day(fs, location_id, d)
    total = 0.0
    count = 0
    for (dt, val) in rows
        hour_start <= dt < hour_end || continue
        total += val
        count += 1
    end
    (total, count)
end

function _split_csv_line(line::AbstractString)
    fields = String[]
    i = firstindex(line)
    while i <= lastindex(line)
        if line[i] == '"'
            i = nextind(line, i)
            buf = IOBuffer()
            while i <= lastindex(line)
                if line[i] == '"'
                    ni = nextind(line, i)
                    if ni <= lastindex(line) && line[ni] == '"'
                        write(buf, '"')
                        i = nextind(line, ni)
                    else
                        i = ni
                        break
                    end
                else
                    write(buf, line[i])
                    i = nextind(line, i)
                end
            end
            push!(fields, String(take!(buf)))
            if i <= lastindex(line) && line[i] == ','
                i = nextind(line, i)
            end
        else
            j = findnext(',', line, i)
            if isnothing(j)
                push!(fields, SubString(line, i))
                break
            else
                push!(fields, SubString(line, i, prevind(line, j)))
                i = nextind(line, j)
            end
        end
    end
    fields
end

"""
Parse an OpenAQ datetime string, converting timezone offsets to UTC.
Supports formats: "2024-01-15T12:00:00+00:00", "2024-01-15T12:00:00Z",
"2024-01-15T12:00:00".
"""
function _parse_openaq_datetime(s::AbstractString)
    try
        # Check for timezone offset like +05:30 or -05:00
        m_offset = match(r"([+-])(\d{2}):(\d{2})$", s)
        if !isnothing(m_offset)
            dt_str = SubString(s, 1, prevind(s, m_offset.offset))
            dt = DateTime(dt_str, dateformat"yyyy-mm-ddTHH:MM:SS")
            sign = m_offset.captures[1] == "+" ? -1 : 1
            hours = parse(Int, m_offset.captures[2])
            mins = parse(Int, m_offset.captures[3])
            return dt + Minute(sign * (hours * 60 + mins))
        end

        # Check for Z suffix (already UTC)
        if endswith(s, 'Z')
            dt_str = SubString(s, 1, prevind(s, lastindex(s)))
            return DateTime(dt_str, dateformat"yyyy-mm-ddTHH:MM:SS")
        end

        # No timezone info, assume UTC
        return DateTime(s, dateformat"yyyy-mm-ddTHH:MM:SS")
    catch e
        e isa InterruptException && rethrow()
        nothing
    end
end

# --- Constructor with DomainInfo integration ---

"""
$(SIGNATURES)

Create a ModelingToolkit `System` that provides interpolated OpenAQ air quality
observations for the given parameter.

`parameter` is the OpenAQ parameter name (e.g. "pm25", "o3", "no2").

`domaininfo` is a `DomainInfo` specifying the model domain and time span.

`api_key` defaults to `ENV["OPENAQ_API_KEY"]`.

`station_filter` is a function `f(::OpenAQStation) -> Bool` to filter stations.

`fill_value` is used for grid cells with no stations (default `0.0`).

`stream` specifies whether data should be streamed or loaded all at once.
"""
function OpenAQ(
        parameter::AbstractString,
        domaininfo::DomainInfo;
        api_key::AbstractString = get(ENV, "OPENAQ_API_KEY", ""),
        station_filter::Function = (_) -> true,
        # TODO: fill_value should be `missing` or `NaN` so downstream code can
        # distinguish cells with measurements from cells without. Currently 0.0
        # because DataSetInterpolator's BSpline propagates NaN to the entire field.
        fill_value::Real = 0.0,
        name::Symbol = :OpenAQ,
        stream::Bool = true
)
    starttime, endtime = get_tspan_datetime(domaininfo)

    grid_edges = EarthSciMLBase.grid(domaininfo, (true, true, true))
    lon_edges = collect(Float64, grid_edges[1])
    lat_edges = collect(Float64, grid_edges[2])

    bbox = (
        lon_min = rad2deg(minimum(lon_edges)),
        lat_min = rad2deg(minimum(lat_edges)),
        lon_max = rad2deg(maximum(lon_edges)),
        lat_max = rad2deg(maximum(lat_edges))
    )

    fs = OpenAQFileSet(
        parameter, starttime, endtime, bbox;
        grid_lon_edges = lon_edges,
        grid_lat_edges = lat_edges,
        api_key = api_key,
        station_filter = station_filter,
        fill_value = fill_value
    )

    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :lon in keys(pvdict) || :x in keys(pvdict) "lon or x must be in domaininfo"
    @assert :lat in keys(pvdict) || :y in keys(pvdict) "lat or y must be in domaininfo"
    x = :lon in keys(pvdict) ? pvdict[:lon] : pvdict[:x]
    y = :lat in keys(pvdict) ? pvdict[:lat] : pvdict[:y]

    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]

    dt = EarthSciMLBase.eltype(domaininfo)
    # OpenAQ data is already on the model grid (same lon/lat edges), so bypass
    # BSpline regridding and just copy.
    # TODO: fill_value should be `missing` or `NaN` so downstream code can
    # distinguish cells with measurements from cells without. Currently we use
    # 0.0 because the DataSetInterpolator builds a BSpline over the data array
    # and NaN in any cell propagates to the entire interpolated field.
    copy_regridder = (dst, src; extrapolate_type = nothing) -> copyto!(dst, src)
    fswr = FileSetWithRegridder(fs, copy_regridder)
    itp = DataSetInterpolator{dt}(fswr, parameter, starttime, endtime, domaininfo;
        stream = stream)

    eq, discretes, constants, info = create_interp_equation(
        itp, "", t, t_ref, [x, y])

    vars = [eq.lhs]

    all_params = [x, y, t_ref, constants..., discretes...]
    interp_infos = [info]
    sys = System(
        [eq],
        t,
        vars,
        all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        discrete_events = [build_interp_event(interp_infos, starttime)],
        metadata = Dict(
            CoupleType => OpenAQCoupler,
            SysDomainInfo => domaininfo
        )
    )
    return sys
end
