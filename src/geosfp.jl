export GEOSFP

"""
$(SIGNATURES)

GEOS-FP data as archived for use with GEOS-Chem classic.

Domain options (as of 2022-01-30):
- 4x5
- 0.125x0.15625_AS
- 0.125x0.15625_EU
- 0.125x0.15625_NA
- 0.25x0.3125
- 0.25x0.3125_AF
- 0.25x0.3125_AS
- 0.25x0.3125_CH
- 0.25x0.3125_EU
- 0.25x0.3125_ME
- 0.25x0.3125_NA
- 0.25x0.3125_OC
- 0.25x0.3125_RU
- 0.25x0.3125_SA
- 0.5x0.625
- 0.5x0.625_AS
- 0.5x0.625_CH
- 0.5x0.625_EU
- 0.5x0.15625_NA
- 2x2.5
- 4x5
- C180
- C720
- NATIVE
- c720

Possible `filetype`s are:
- `:A1`
- `:A3cld`
- `:A3dyn`
- `:A3mstC`
- `:A3mstE`
- `:I3`


See http://geoschemdata.wustl.edu/ExtData/ for current options.
"""
struct GEOSFPFileSet <: FileSet
    mirror::AbstractString
    domain
    filetype
    GEOSFPFileSet(domain, filetype) = new("http://geoschemdata.wustl.edu/ExtData/", domain, filetype)
end

"""
$(SIGNATURES)

File path on the server relative to the host root; also path on local disk relative to `ENV["ESMLDATADIR"]`.
"""
function relpath(fs::GEOSFPFileSet, t::DateTime)
    year = Dates.format(t, "Y")
    month = @sprintf("%.2d", Dates.month(t))
    day = @sprintf("%.2d", Dates.day(t))
    return joinpath("GEOS_$(fs.domain)/GEOS_FP/$year/$month", "GEOSFP.$(year)$(month)$day.$(fs.filetype).$(fs.domain).nc")
end

"""
$(SIGNATURES)

Return the URL for the GEOS-FP file for the given `DateTime`.

"""
url(fs::GEOSFPFileSet, t::DateTime) = joinpath(fs.mirror, relpath(fs, t))

"""
$(SIGNATURES)

Return the local path for the GEOS-FP file for the given `DateTime`.
"""
localpath(fs::GEOSFPFileSet, t::DateTime) = joinpath(ENV["ESMLDATADIR"], relpath(fs, t))

function DataFrequencyInfo(fs::GEOSFPFileSet, t::DateTime)::DataFrequencyInfo
    filepath = maybedownload(fs, t)
    fid = NetCDF.open(filepath)
    sd = fid.gatts["Start_Date"]
    st = fid.gatts["Start_Time"]
    dt = fid.gatts["Delta_Time"]

    start = DateTime(sd*" "*st, dateformat"yyyymmdd HH:MM:SS.s")
    frequency = Second(parse(Int64, dt[1:2]))*3600 + Second(parse(Int64, dt[3:4]))*60 + 
                        Second(parse(Int64, dt[5:6]))
    centerpoints = start .+ Second.(fid["time"][:]) * 60
    DataFrequencyInfo(start, frequency, centerpoints)
end

"""
$(SIGNATURES)

Load the data for the given variable name at the given time.
"""
function loadslice(fs::GEOSFPFileSet, t::DateTime, varname)::DataArray
    filepath = maybedownload(fs, t)
    fid = NetCDF.open(filepath)
    var = fid[varname]
    dims = Dict{String,Int}()
    dimids = Dict{Int, String}()
    for k in keys(fid.dim)
        dims[k] = fid.dim[k].dimid
        dimids[fid.dim[k].dimid] = k
    end
    dimnames = [dimids[id] for id ∈ var.dimids]
    time_index = findfirst(isequal("time"), dimnames)
    deleteat!(dimnames, time_index) # Remove the time dimension.
    @assert "time" ∈ keys(dims) "File $filepath does not have a dimension named 'time'."  
    # Load only one time step, but the full array for everything else.
    slices = repeat(Any[:], var.ndim)
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs, t), t)
    data = var[slices...]

    units = var.atts["units"]
    description = var.atts["long_name"]
    @assert var.atts["scale_factor"] == 1.0 "Unexpected scale factor."

    DataArray(data, units, description, dimnames)
end

"""
$(SIGNATURES)

Load the data for the given `DateTime` and variable name as an interpolator
from Interpolations.jl.
"""
function load_interpolator(fs::GEOSFPFileSet, t::DateTime, varname)
    fid = NetCDF.open(maybedownload(fs, t))
    slice = loadslice(fs, t, varname)
    knots = Tuple([fid.vars[d][:] for d ∈ slice.dimnames])
    interpolate(knots, slice.data, Gridded(Linear())), slice
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::GEOSFPFileSet, t::DateTime)
    filepath = maybedownload(fs, t)
    fid = NetCDF.open(filepath)
    [setdiff(keys(fid.vars), keys(fid.dim))...]
end

"""
$(SIGNATURES)

A data loader for GEOS-FP data as archived for use with GEOS-Chem classic.

Domain options (as of 2022-01-30):
- 4x5
- 0.125x0.15625_AS
- 0.125x0.15625_EU
- 0.125x0.15625_NA
- 0.25x0.3125
- 0.25x0.3125_AF
- 0.25x0.3125_AS
- 0.25x0.3125_CH
- 0.25x0.3125_EU
- 0.25x0.3125_ME
- 0.25x0.3125_NA
- 0.25x0.3125_OC
- 0.25x0.3125_RU
- 0.25x0.3125_SA
- 0.5x0.625
- 0.5x0.625_AS
- 0.5x0.625_CH
- 0.5x0.625_EU
- 0.5x0.15625_NA
- 2x2.5
- 4x5
- C180
- C720
- NATIVE
- c720

See http://geoschemdata.wustl.edu/ExtData/ for current options.
"""
struct GEOSFP <: EarthSciMLODESystem
    filsets::Dict{String,GEOSFPFileSet}
    sys::ODESystem
    function GEOSFP(domain, t)
        filesets = Dict{String,GEOSFPFileSet}(
            "A1" => GEOSFPFileSet(domain, "A1"),
            "A3cld" => GEOSFPFileSet(domain, "A3cld"),
            "A3dyn" => GEOSFPFileSet(domain, "A3dyn"),
            "A3mstC" => GEOSFPFileSet(domain, "A3mstC"),
            "A3mstE" => GEOSFPFileSet(domain, "A3mstE"),
            "I3" => GEOSFPFileSet(domain, "I3"))

        sample_time = DateTime(2022, 5, 1) # Dummy time to get variable names and dimensions from data.
        eqs = []
        for (filename, fs) in filesets
            for varname ∈ varnames(fs, sample_time)
                itp = DataSetInterpolator(fs, varname)
                dims = dimnames(itp, sample_time)
                coords = Num[]
                for dim ∈ dims
                    d = Symbol(dim)
                    v = (@parameters $d = 0.0)[1]
                    push!(coords, v)
                end
                desc = description(itp, sample_time)
                uu = units(itp, sample_time)
                n = Symbol("$(filename)₊$(varname)")
                lhs = (@variables $n(t) [unit = uu, description = desc])[1]
                if length(coords) == 3
                    push!(eqs, lhs ~ interp!(itp, t, coords[1], coords[2], coords[3]))
                elseif length(coords) == 2
                    push!(eqs, lhs ~ interp!(itp, t, coords[1], coords[2]))
                elseif length(coords) == 1
                    push!(eqs, lhs ~ interp!(itp, t, coords[1]))
                else
                    error("Unexpected number of coordinates: $(length(coords))")
                end
            end
        end
        sys = ODESystem(eqs, t, name=:GEOSFP)

        new(filesets, sys)
    end
end

function Base.:(+)(mw::EarthSciMLBase.MeanWind, g::GEOSFP)::ComposedEarthSciMLSystem
    eqs = [
        mw.sys.u ~ g.sys.A3dyn₊U
        mw.sys.v ~ g.sys.A3dyn₊V
        mw.sys.w ~ g.sys.A3dyn₊OMEGA
    ]
    ComposedEarthSciMLSystem(AbstractEarthSciMLSystem[ConnectorSystem(
        eqs,
        mw, g,
    )], nothing, [(sys)->prune!(sys, "GEOSFP₊")]) # Prune extra data interpolators before running to save cost.
end
Base.:(+)(g::GEOSFP, mw::EarthSciMLBase.MeanWind)::ComposedEarthSciMLSystem = mw + g