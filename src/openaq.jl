export OpenAQ

const OPENAQ_S3_MIRROR = "https://openaq-data-archive.s3.amazonaws.com"
const OPENAQ_API_BASE = "https://api.openaq.org/v3"

# OpenAQ parameter name => (unit_string, description)
const OPENAQ_PARAMETERS = Dict(
    "pm25" => ("ug/m3", "Particulate matter (PM2.5)"),
    "pm10" => ("ug/m3", "Particulate matter (PM10)"),
    "o3" => ("ug/m3", "Ozone"),
    "no2" => ("ug/m3", "Nitrogen dioxide"),
    "so2" => ("ug/m3", "Sulfur dioxide"),
    "co" => ("ug/m3", "Carbon monoxide"),
    "bc" => ("ug/m3", "Black carbon"),
    "pm1" => ("ug/m3", "Particulate matter (PM1)"),
    "no" => ("ug/m3", "Nitric oxide"),
    "nox" => ("ug/m3", "Nitrogen oxides"),
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
    mirror::String
    parameter::String
    stations::Vector{OpenAQStation}
    freq_info::DataFrequencyInfo
    grid_lon_edges::Vector{Float64}
    grid_lat_edges::Vector{Float64}
    fill_value::Float64
    # Precomputed mapping: grid_index => [station_indices...]
    cell_stations::Dict{Tuple{Int,Int}, Vector{Int}}
end

"""
$(SIGNATURES)

Construct an `OpenAQFileSet` for the given parameter and time range.

`parameter` is the OpenAQ parameter name (e.g. "pm25", "o3", "no2").

`bbox` is a named tuple `(lon_min, lat_min, lon_max, lat_max)` in **degrees**
specifying the bounding box for station discovery.

`api_key` is the OpenAQ API key. Defaults to `ENV["OPENAQ_API_KEY"]`.

`station_filter` is an optional function `f(::OpenAQStation) -> Bool` to filter stations.

`fill_value` is used for grid cells with no stations (default `NaN`).
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
    fill_value::Real = NaN,
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

    OpenAQFileSet(
        OPENAQ_S3_MIRROR,
        String(parameter),
        stations,
        freq_info,
        lon_edges,
        lat_edges,
        Float64(fill_value),
        cell_stations,
    )
end

"""
Build a mapping from (i, j) grid cell indices to vectors of station indices.
Grid edges are in radians.
"""
function _build_cell_station_map(
    stations::Vector{OpenAQStation},
    lon_edges::Vector{Float64},
    lat_edges::Vector{Float64},
)
    cell_stations = Dict{Tuple{Int,Int}, Vector{Int}}()
    nx = length(lon_edges) - 1
    ny = length(lat_edges) - 1
    for (si, st) in enumerate(stations)
        ix = searchsortedlast(lon_edges, st.lon)
        iy = searchsortedlast(lat_edges, st.lat)
        if 1 <= ix <= nx && 1 <= iy <= ny
            key = (ix, iy)
            if haskey(cell_stations, key)
                push!(cell_stations[key], si)
            else
                cell_stations[key] = [si]
            end
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
    station_filter::Function,
)
    cache_dir = joinpath(download_cache(), "openaq_stations")
    mkpath(cache_dir)

    bbox_str = "$(bbox.lon_min)_$(bbox.lat_min)_$(bbox.lon_max)_$(bbox.lat_max)"
    cache_file = joinpath(cache_dir, "$(parameter)_$(bbox_str).json")

    local raw_stations::Vector{Dict{String,Any}}
    if isfile(cache_file)
        @info "OpenAQ: loading cached station list from $cache_file"
        raw_stations = _parse_json_file(cache_file)
    else
        raw_stations = _fetch_stations_from_api(parameter, bbox, api_key)
        _write_json_file(cache_file, raw_stations)
    end

    stations = OpenAQStation[]
    for s in raw_stations
        coords = s["coordinates"]
        st = OpenAQStation(
            s["id"],
            get(s, "name", "unknown"),
            deg2rad(coords["longitude"]),
            deg2rad(coords["latitude"]),
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
    api_key::AbstractString,
)
    all_results = Dict{String,Any}[]
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

# Known OpenAQ v3 parameter IDs.
const _OPENAQ_PARAM_IDS = Dict(
    "pm25" => 2, "pm10" => 1, "o3" => 3, "no2" => 5,
    "so2" => 4, "co" => 6, "bc" => 11, "pm1" => 19,
    "no" => 7, "nox" => 8,
)

function _parameter_id(name::AbstractString)
    haskey(_OPENAQ_PARAM_IDS, name) && return _OPENAQ_PARAM_IDS[name]
    error("Unknown OpenAQ parameter: $name. Known parameters: $(join(keys(_OPENAQ_PARAM_IDS), ", "))")
end

function _api_get(url_str::AbstractString, api_key::AbstractString)
    headers = ["X-API-Key" => api_key, "Accept" => "application/json"]
    buf = IOBuffer()
    try
        Downloads.download(url_str, buf; headers=headers)
    catch e
        error("OpenAQ API request failed for $url_str: $e")
    end
    body_str = String(take!(buf))
    _parse_json_string(body_str)
end

# --- Minimal JSON parsing (no external dependency) ---

function _parse_json_string(s::AbstractString)
    _json_parse(s, firstindex(s))[1]
end

function _parse_json_file(path::AbstractString)
    s = read(path, String)
    _parse_json_string(s)
end

function _write_json_file(path::AbstractString, data)
    open(path, "w") do io
        _json_write(io, data)
    end
end

function _json_skip_whitespace(s, i)
    while i <= lastindex(s) && isspace(s[i])
        i = nextind(s, i)
    end
    i
end

function _json_parse(s, i)
    i = _json_skip_whitespace(s, i)
    i > lastindex(s) && error("Unexpected end of JSON")
    c = s[i]
    if c == '"'
        _json_parse_string(s, i)
    elseif c == '{'
        _json_parse_object(s, i)
    elseif c == '['
        _json_parse_array(s, i)
    elseif c == 't'
        @assert SubString(s, i, i+3) == "true"
        (true, i + 4)
    elseif c == 'f'
        @assert SubString(s, i, i+4) == "false"
        (false, i + 5)
    elseif c == 'n'
        @assert SubString(s, i, i+3) == "null"
        (nothing, i + 4)
    else
        _json_parse_number(s, i)
    end
end

function _json_parse_string(s, i)
    @assert s[i] == '"'
    i = nextind(s, i)
    buf = IOBuffer()
    while i <= lastindex(s)
        c = s[i]
        if c == '\\'
            i = nextind(s, i)
            c2 = s[i]
            if c2 == '"' || c2 == '\\' || c2 == '/'
                write(buf, c2)
            elseif c2 == 'n'
                write(buf, '\n')
            elseif c2 == 't'
                write(buf, '\t')
            elseif c2 == 'r'
                write(buf, '\r')
            elseif c2 == 'b'
                write(buf, '\b')
            elseif c2 == 'f'
                write(buf, '\f')
            elseif c2 == 'u'
                hex = SubString(s, i+1, i+4)
                write(buf, Char(parse(UInt16, hex; base=16)))
                i += 4
            end
        elseif c == '"'
            return (String(take!(buf)), nextind(s, i))
        else
            write(buf, c)
        end
        i = nextind(s, i)
    end
    error("Unterminated JSON string")
end

function _json_parse_number(s, i)
    j = i
    while j <= lastindex(s) && (isdigit(s[j]) || s[j] in ('-', '+', '.', 'e', 'E'))
        j = nextind(s, j)
    end
    num_str = SubString(s, i, prevind(s, j))
    if occursin('.', num_str) || occursin('e', num_str) || occursin('E', num_str)
        (parse(Float64, num_str), j)
    else
        (parse(Int, num_str), j)
    end
end

function _json_parse_object(s, i)
    @assert s[i] == '{'
    i = nextind(s, i)
    d = Dict{String,Any}()
    i = _json_skip_whitespace(s, i)
    if s[i] == '}'
        return (d, nextind(s, i))
    end
    while true
        i = _json_skip_whitespace(s, i)
        key, i = _json_parse_string(s, i)
        i = _json_skip_whitespace(s, i)
        @assert s[i] == ':'
        i = nextind(s, i)
        val, i = _json_parse(s, i)
        d[key] = val
        i = _json_skip_whitespace(s, i)
        if s[i] == '}'
            return (d, nextind(s, i))
        end
        @assert s[i] == ','
        i = nextind(s, i)
    end
end

function _json_parse_array(s, i)
    @assert s[i] == '['
    i = nextind(s, i)
    arr = Any[]
    i = _json_skip_whitespace(s, i)
    if s[i] == ']'
        return (arr, nextind(s, i))
    end
    while true
        val, i = _json_parse(s, i)
        push!(arr, val)
        i = _json_skip_whitespace(s, i)
        if s[i] == ']'
            return (arr, nextind(s, i))
        end
        @assert s[i] == ','
        i = nextind(s, i)
    end
end

function _json_write(io::IO, d::Dict)
    print(io, '{')
    first = true
    for (k, v) in d
        first || print(io, ',')
        first = false
        _json_write(io, k)
        print(io, ':')
        _json_write(io, v)
    end
    print(io, '}')
end

function _json_write(io::IO, arr::AbstractVector)
    print(io, '[')
    for (i, v) in enumerate(arr)
        i > 1 && print(io, ',')
        _json_write(io, v)
    end
    print(io, ']')
end

function _json_write(io::IO, s::AbstractString)
    print(io, '"')
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        else
            print(io, c)
        end
    end
    print(io, '"')
end

_json_write(io::IO, n::Number) = print(io, n)
_json_write(io::IO, b::Bool) = print(io, b ? "true" : "false")
_json_write(io::IO, ::Nothing) = print(io, "null")

# --- S3 data download ---

"""
$(SIGNATURES)

Download daily CSV.gz files from the OpenAQ S3 archive for the given stations and time range.
"""
function download_station_data(
    stations::Vector{OpenAQStation},
    starttime::DateTime,
    endtime::DateTime,
)
    dates = Date(starttime):Day(1):Date(endtime)
    n_total = length(stations) * length(dates)
    n_downloaded = 0
    n_skipped = 0
    for st in stations
        for d in dates
            p = _s3_localpath(st.id, d)
            if isfile(p)
                n_skipped += 1
                continue
            end
            mkpath(dirname(p))
            u = _s3_url(st.id, d)
            try
                Downloads.download(u, p)
                n_downloaded += 1
            catch
                # File may not exist (station had no data that day). That's OK.
                n_skipped += 1
            end
        end
    end
    if n_downloaded > 0
        @info "OpenAQ: downloaded $n_downloaded files ($n_skipped cached/missing of $n_total total)"
    end
end

function _s3_url(location_id::Int, d::Date)
    yr = Dates.year(d)
    mo = lpad(Dates.month(d), 2, '0')
    day_str = Dates.format(d, dateformat"yyyy-mm-dd")
    "$(OPENAQ_S3_MIRROR)/records/csv.gz/locationid=$(location_id)/year=$(yr)/month=$(mo)/location-$(location_id)-$(day_str).csv.gz"
end

function _s3_localpath(location_id::Int, d::Date)
    yr = Dates.year(d)
    mo = lpad(Dates.month(d), 2, '0')
    day_str = Dates.format(d, dateformat"yyyy-mm-dd")
    joinpath(
        download_cache(),
        "openaq_data",
        "locationid=$(location_id)",
        "year=$(yr)",
        "month=$(mo)",
        "location-$(location_id)-$(day_str).csv.gz",
    )
end

# --- FileSet interface implementation ---

DataFrequencyInfo(fs::OpenAQFileSet) = fs.freq_info

function relpath(fs::OpenAQFileSet, t::DateTime)
    d = Date(t)
    yr = Dates.year(d)
    mo = lpad(Dates.month(d), 2, '0')
    day_str = Dates.format(d, dateformat"yyyy-mm-dd")
    "openaq/$(fs.parameter)/$(yr)/$(mo)/$(day_str)"
end

function varnames(fs::OpenAQFileSet)
    [fs.parameter]
end

function loadmetadata(fs::OpenAQFileSet, varname)::MetaData
    @assert varname == fs.parameter "OpenAQFileSet only supports parameter '$(fs.parameter)', got '$varname'"

    nx = length(fs.grid_lon_edges) - 1
    ny = length(fs.grid_lat_edges) - 1

    lon_centers = [(fs.grid_lon_edges[i] + fs.grid_lon_edges[i+1]) / 2 for i in 1:nx]
    lat_centers = [(fs.grid_lat_edges[j] + fs.grid_lat_edges[j+1]) / 2 for j in 1:ny]

    unit_str = haskey(OPENAQ_PARAMETERS, varname) ? OPENAQ_PARAMETERS[varname][1] : "ug/m3"
    desc = haskey(OPENAQ_PARAMETERS, varname) ? OPENAQ_PARAMETERS[varname][2] : varname

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
        (false, false, false),
    )
end

function get_geometry(fs::OpenAQFileSet, m::MetaData)
    nx = length(fs.grid_lon_edges) - 1
    ny = length(fs.grid_lat_edges) - 1
    polys = Vector{Vector{NTuple{2, Float64}}}(undef, nx * ny)
    x = fs.grid_lon_edges
    y = fs.grid_lat_edges
    for j in 1:ny, i in 1:nx
        polys[(j-1)*nx + i] = [
            (x[i], y[j]), (x[i+1], y[j]), (x[i+1], y[j+1]),
            (x[i], y[j+1]), (x[i], y[j]),
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
    varname::String,
)
    @assert varname == fs.parameter

    nx = length(fs.grid_lon_edges) - 1
    ny = length(fs.grid_lat_edges) - 1
    fill!(data, fs.fill_value)

    hour_start = DateTime(Dates.year(t), Dates.month(t), Dates.day(t), Dates.hour(t))
    hour_end = hour_start + Hour(1)
    d = Date(t)

    for j in 1:ny, i in 1:nx
        key = (i, j)
        haskey(fs.cell_stations, key) || continue
        station_idxs = fs.cell_stations[key]

        total = 0.0
        count = 0
        for si in station_idxs
            st = fs.stations[si]
            vals = _read_station_hour(st.id, d, fs.parameter, hour_start, hour_end)
            if !isempty(vals)
                total += sum(vals)
                count += length(vals)
            end
        end
        if count > 0
            data[i, j] = total / count
            # Apply unit conversion
            if haskey(OPENAQ_PARAMETERS, fs.parameter)
                scale, _ = to_unit(OPENAQ_PARAMETERS[fs.parameter][1])
                if scale != 1
                    data[i, j] *= scale
                end
            end
        end
    end
    nothing
end

"""
Read measurements for a single station for a single hour.
Returns a vector of Float64 values (may be empty if no data).
"""
function _read_station_hour(
    location_id::Int,
    d::Date,
    parameter::AbstractString,
    hour_start::DateTime,
    hour_end::DateTime,
)
    path = _s3_localpath(location_id, d)
    isfile(path) || return Float64[]

    values = Float64[]
    try
        # Decompress gzip using external gzip command.
        csv_data = read(`gzip -dc $path`, String)
        lines = split(csv_data, '\n')
        isempty(lines) && return values

        headers = _split_csv_line(lines[1])
        dt_col = findfirst(==("datetime"), headers)
        param_col = findfirst(==("parameter"), headers)
        val_col = findfirst(==("value"), headers)
        (isnothing(dt_col) || isnothing(param_col) || isnothing(val_col)) && return values

        ncols = max(dt_col, param_col, val_col)
        for i in 2:length(lines)
            line = lines[i]
            isempty(line) && continue
            fields = _split_csv_line(line)
            length(fields) < ncols && continue
            fields[param_col] != parameter && continue

            row_dt = _parse_openaq_datetime(fields[dt_col])
            isnothing(row_dt) && continue

            if hour_start <= row_dt < hour_end
                v = tryparse(Float64, fields[val_col])
                !isnothing(v) && v >= 0 && push!(values, v)
            end
        end
    catch
        # Corrupted or unreadable file; skip.
    end
    values
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

function _parse_openaq_datetime(s::AbstractString)
    try
        dt_str = s
        for pat in (r"[+-]\d{2}:\d{2}$", r"Z$")
            m = match(pat, dt_str)
            if !isnothing(m)
                dt_str = SubString(dt_str, 1, prevind(dt_str, m.offset))
                break
            end
        end
        DateTime(dt_str, dateformat"yyyy-mm-ddTHH:MM:SS")
    catch
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

`fill_value` is used for grid cells with no stations (default `NaN`).

`stream` specifies whether data should be streamed or loaded all at once.
"""
function OpenAQ(
    parameter::AbstractString,
    domaininfo::DomainInfo;
    api_key::AbstractString = get(ENV, "OPENAQ_API_KEY", ""),
    station_filter::Function = (_) -> true,
    fill_value::Real = NaN,
    name::Symbol = :OpenAQ,
    stream::Bool = true,
)
    starttime, endtime = get_tspan_datetime(domaininfo)

    grid_edges = EarthSciMLBase.grid(domaininfo, (true, true, true))
    lon_edges = collect(Float64, grid_edges[1])
    lat_edges = collect(Float64, grid_edges[2])

    bbox = (
        lon_min = rad2deg(minimum(lon_edges)),
        lat_min = rad2deg(minimum(lat_edges)),
        lon_max = rad2deg(maximum(lon_edges)),
        lat_max = rad2deg(maximum(lat_edges)),
    )

    fs = OpenAQFileSet(
        parameter, starttime, endtime, bbox;
        grid_lon_edges = lon_edges,
        grid_lat_edges = lat_edges,
        api_key = api_key,
        station_filter = station_filter,
        fill_value = fill_value,
    )

    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :lon in keys(pvdict) || :x in keys(pvdict) "lon or x must be in domaininfo"
    @assert :lat in keys(pvdict) || :y in keys(pvdict) "lat or y must be in domaininfo"
    x = :lon in keys(pvdict) ? pvdict[:lon] : pvdict[:x]
    y = :lat in keys(pvdict) ? pvdict[:lat] : pvdict[:y]

    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]

    dt = EarthSciMLBase.eltype(domaininfo)
    itp = DataSetInterpolator{dt}(fs, parameter, starttime, endtime, domaininfo;
        stream = stream)

    eq, param = create_interp_equation(itp, "", t, t_ref, [x, y])

    params = Any[t_ref, param]
    vars = [eq.lhs]

    all_params = [x, y, params...]
    sys = System(
        [eq],
        t,
        vars,
        all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        metadata = Dict(
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime),
        ),
    )
    return sys
end
