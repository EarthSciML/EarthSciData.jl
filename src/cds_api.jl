"""
Client for the Copernicus Climate Data Store (CDS) API v1.

Handles authentication, request submission, polling, and download for
ERA5 and other CDS datasets.

Authentication is via an API key read from (in order of priority):
1. The `CDSAPI_KEY` environment variable
2. The `~/.cdsapirc` file (format: `url: ...\\nkey: ...`)
"""

const CDS_API_URL = "https://cds.climate.copernicus.eu/api"

"""
$(SIGNATURES)

Read the CDS API key from `ENV["CDSAPI_KEY"]` or `~/.cdsapirc`.
"""
function cds_api_key()
    if haskey(ENV, "CDSAPI_KEY")
        return ENV["CDSAPI_KEY"]
    end
    rc = joinpath(homedir(), ".cdsapirc")
    if isfile(rc)
        for line in eachline(rc)
            m = match(r"^key:\s*(.+)$", line)
            if m !== nothing
                return strip(m.captures[1])
            end
        end
    end
    error("CDS API key not found. Set the CDSAPI_KEY environment variable or create ~/.cdsapirc with 'key: <your-key>'.")
end

"""
$(SIGNATURES)

Submit a CDS API retrieve request and return the job ID.
`dataset` is the CDS dataset identifier (e.g. "reanalysis-era5-pressure-levels").
`request` is a Dict with the request parameters.
"""
function cds_submit(dataset::AbstractString, request::Dict; api_key::AbstractString=cds_api_key())
    url = "$(CDS_API_URL)/retrieve/v1/processes/$(dataset)/execution"
    body = """{"inputs": $(json_encode(request))}"""

    headers = [
        "PRIVATE-TOKEN" => api_key,
        "Content-Type" => "application/json",
    ]
    resp = _cds_http_post(url, body, headers)
    data = _parse_json(resp)

    status = get(data, "status", "")
    if status in ("accepted", "running", "successful")
        return data["jobID"]
    end
    error("CDS API request failed: $(resp)")
end

"""
$(SIGNATURES)

Poll a CDS API job until completion. Returns the download URL.
"""
function cds_wait(job_id::AbstractString; api_key::AbstractString=cds_api_key(),
                  poll_interval::Real=5, timeout::Real=600)
    url = "$(CDS_API_URL)/retrieve/v1/jobs/$(job_id)"
    headers = ["PRIVATE-TOKEN" => api_key]
    start_time = time()

    while true
        resp = _cds_http_get(url, headers)
        data = _parse_json(resp)
        status = get(data, "status", "")

        if status == "successful"
            results_url = "$(url)/results"
            resp2 = _cds_http_get(results_url, headers)
            results = _parse_json(resp2)
            return results["asset"]["value"]["href"]
        elseif status == "failed"
            error("CDS API job $(job_id) failed: $(resp)")
        elseif time() - start_time > timeout
            error("CDS API job $(job_id) timed out after $(timeout) seconds.")
        end

        sleep(poll_interval)
    end
end

"""
$(SIGNATURES)

Submit a CDS API request, wait for completion, and download the result.
Returns the local file path.
"""
function cds_retrieve(dataset::AbstractString, request::Dict, output_path::AbstractString;
                      api_key::AbstractString=cds_api_key())
    if isfile(output_path)
        return output_path
    end
    mkpath(dirname(output_path))

    @info "Submitting CDS API request for $(dataset)..."
    job_id = cds_submit(dataset, request; api_key=api_key)
    @info "CDS API job submitted: $(job_id). Waiting for completion..."

    download_url = cds_wait(job_id; api_key=api_key)
    @info "Downloading from CDS: $(basename(output_path))"

    try
        prog = Progress(100; desc="Downloading $(basename(output_path)):", dt=0.1)
        Downloads.download(download_url, output_path,
            progress=(total::Integer, now::Integer) -> begin
                prog.n = total
                ProgressMeter.update!(prog, now)
            end
        )
    catch e
        rm(output_path, force=true)
        rethrow(e)
    end
    return output_path
end

# Minimal JSON encoding (no external dependency needed)
function json_encode(d::Dict)
    pairs = String[]
    for (k, v) in d
        push!(pairs, "\"$(k)\": $(json_encode(v))")
    end
    return "{" * join(pairs, ", ") * "}"
end
json_encode(v::AbstractVector) = "[" * join(json_encode.(v), ", ") * "]"
json_encode(v::AbstractString) = "\"$(v)\""
json_encode(v::Number) = string(v)
json_encode(v::Bool) = v ? "true" : "false"

# Minimal JSON parsing (sufficient for CDS API responses)
function _parse_json(s::AbstractString)
    # Use Julia's built-in JSON-like parsing via Meta.parse for simple cases,
    # but we need a proper approach. Let's use a simple recursive descent parser.
    s = strip(s)
    val, _ = _parse_json_value(s, 1)
    return val
end

function _parse_json_value(s, i)
    i = _skip_whitespace(s, i)
    if i > length(s)
        error("Unexpected end of JSON")
    end
    c = s[i]
    if c == '"'
        return _parse_json_string(s, i)
    elseif c == '{'
        return _parse_json_object(s, i)
    elseif c == '['
        return _parse_json_array(s, i)
    elseif c == 't' && startswith(SubString(s, i), "true")
        return true, i + 4
    elseif c == 'f' && startswith(SubString(s, i), "false")
        return false, i + 5
    elseif c == 'n' && startswith(SubString(s, i), "null")
        return nothing, i + 4
    elseif c == '-' || isdigit(c)
        return _parse_json_number(s, i)
    else
        error("Unexpected character '$(c)' at position $(i)")
    end
end

function _skip_whitespace(s, i)
    while i <= length(s) && isspace(s[i])
        i += 1
    end
    return i
end

function _parse_json_string(s, i)
    @assert s[i] == '"'
    i += 1
    buf = IOBuffer()
    while i <= length(s) && s[i] != '"'
        if s[i] == '\\'
            i += 1
            if i <= length(s)
                c = s[i]
                if c == '"' || c == '\\' || c == '/'
                    write(buf, c)
                elseif c == 'n'
                    write(buf, '\n')
                elseif c == 't'
                    write(buf, '\t')
                elseif c == 'r'
                    write(buf, '\r')
                else
                    write(buf, '\\')
                    write(buf, c)
                end
            end
        else
            write(buf, s[i])
        end
        i += 1
    end
    @assert i <= length(s) && s[i] == '"' "Unterminated string"
    return String(take!(buf)), i + 1
end

function _parse_json_object(s, i)
    @assert s[i] == '{'
    i = _skip_whitespace(s, i + 1)
    d = Dict{String, Any}()
    if i <= length(s) && s[i] == '}'
        return d, i + 1
    end
    while true
        key, i = _parse_json_string(s, _skip_whitespace(s, i))
        i = _skip_whitespace(s, i)
        @assert s[i] == ':' "Expected ':' at position $(i)"
        i += 1
        val, i = _parse_json_value(s, i)
        d[key] = val
        i = _skip_whitespace(s, i)
        if i > length(s) || s[i] == '}'
            return d, i + 1
        end
        @assert s[i] == ',' "Expected ',' or '}' at position $(i)"
        i += 1
    end
end

function _parse_json_array(s, i)
    @assert s[i] == '['
    i = _skip_whitespace(s, i + 1)
    arr = Any[]
    if i <= length(s) && s[i] == ']'
        return arr, i + 1
    end
    while true
        val, i = _parse_json_value(s, i)
        push!(arr, val)
        i = _skip_whitespace(s, i)
        if i > length(s) || s[i] == ']'
            return arr, i + 1
        end
        @assert s[i] == ',' "Expected ',' or ']' at position $(i)"
        i += 1
    end
end

function _parse_json_number(s, i)
    start = i
    if s[i] == '-'
        i += 1
    end
    while i <= length(s) && isdigit(s[i])
        i += 1
    end
    is_float = false
    if i <= length(s) && s[i] == '.'
        is_float = true
        i += 1
        while i <= length(s) && isdigit(s[i])
            i += 1
        end
    end
    if i <= length(s) && (s[i] == 'e' || s[i] == 'E')
        is_float = true
        i += 1
        if i <= length(s) && (s[i] == '+' || s[i] == '-')
            i += 1
        end
        while i <= length(s) && isdigit(s[i])
            i += 1
        end
    end
    numstr = SubString(s, start, i - 1)
    if is_float
        return parse(Float64, numstr), i
    else
        return parse(Int64, numstr), i
    end
end

# HTTP helpers using Downloads.jl
function _cds_http_get(url::AbstractString, headers::Vector{<:Pair})
    io = IOBuffer()
    Downloads.request(url; headers=headers, output=io)
    return String(take!(io))
end

function _cds_http_post(url::AbstractString, body::AbstractString, headers::Vector{<:Pair})
    io = IOBuffer()
    input = IOBuffer(body)
    Downloads.request(url; headers=headers, output=io, input=input, method="POST")
    return String(take!(io))
end
