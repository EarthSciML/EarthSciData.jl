"""
Client for the Copernicus Climate Data Store (CDS) API v1.

Handles authentication, request submission, polling, and download for
ERA5 and other CDS datasets.

Authentication is via an API key read from (in order of priority):
1. The `CDSAPI_KEY` environment variable
2. The `~/.cdsapirc` file (format: `url: ...\\nkey: ...`)
"""

const CDS_API_URL = "https://cds.climate.copernicus.eu/api"
const CDS_POLL_INTERVAL = 5   # seconds between status checks
const CDS_TIMEOUT = 600       # seconds before giving up

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
function cds_submit(dataset::AbstractString, request::Dict; api_key::AbstractString = cds_api_key())
    url = "$(CDS_API_URL)/retrieve/v1/processes/$(dataset)/execution"
    body = JSON3.write(Dict("inputs" => request))

    headers = [
        "PRIVATE-TOKEN" => api_key,
        "Content-Type" => "application/json"
    ]
    resp = _cds_http_post(url, body, headers)
    data = JSON3.read(resp)

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
function cds_wait(job_id::AbstractString; api_key::AbstractString = cds_api_key(),
        poll_interval::Real = CDS_POLL_INTERVAL, timeout::Real = CDS_TIMEOUT)
    url = "$(CDS_API_URL)/retrieve/v1/jobs/$(job_id)"
    headers = ["PRIVATE-TOKEN" => api_key]
    start_time = time()

    while true
        resp = _cds_http_get(url, headers)
        data = JSON3.read(resp)
        status = get(data, "status", "")

        if status == "successful"
            results_url = "$(url)/results"
            resp2 = _cds_http_get(results_url, headers)
            results = JSON3.read(resp2)
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
        api_key::AbstractString = cds_api_key())
    if isfile(output_path)
        return output_path
    end
    mkpath(dirname(output_path))

    @info "Submitting CDS API request for $(dataset)..."
    job_id = cds_submit(dataset, request; api_key = api_key)
    @info "CDS API job submitted: $(job_id). Waiting for completion..."

    download_url = cds_wait(job_id; api_key = api_key)
    @info "Downloading from CDS: $(basename(output_path))"

    _download_with_progress(download_url, output_path)
    return output_path
end

# HTTP helpers using Downloads.jl
function _cds_http_get(url::AbstractString, headers::Vector{<:Pair})
    io = IOBuffer()
    resp = Downloads.request(url; headers = headers, output = io)
    body = String(take!(io))
    resp.status >= 400 && error("CDS API HTTP error $(resp.status): $(body)")
    return body
end

function _cds_http_post(url::AbstractString, body::AbstractString, headers::Vector{<:Pair})
    io = IOBuffer()
    input = IOBuffer(body)
    resp = Downloads.request(
        url; headers = headers, output = io, input = input, method = "POST")
    resp_body = String(take!(io))
    resp.status >= 400 && error("CDS API HTTP error $(resp.status): $(resp_body)")
    return resp_body
end
