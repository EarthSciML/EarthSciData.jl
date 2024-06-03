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

File path on the server relative to the host root; also path on local disk relative to `ENV["EARTHSCIDATADIR"]` 
(or a scratch directory if that environment variable is not set).
"""
function relpath(fs::GEOSFPFileSet, t::DateTime)
    year = Dates.format(t, "Y")
    month = @sprintf("%.2d", Dates.month(t))
    day = @sprintf("%.2d", Dates.day(t))
    domain = replace(fs.domain, '.' => "")
    domain = replace(domain, '_' => ".")
    return joinpath("GEOS_$(fs.domain)/GEOS_FP/$year/$month", "GEOSFP.$(year)$(month)$day.$(fs.filetype).$(domain).nc")
end

# Cache to store data frequency information.
GEOSFPDataFrequencyInfoCache = Dict{String,DataFrequencyInfo}()

function DataFrequencyInfo(fs::GEOSFPFileSet, t::DateTime)::DataFrequencyInfo
    filepath = maybedownload(fs, t)
    if haskey(GEOSFPDataFrequencyInfoCache, filepath)
        return GEOSFPDataFrequencyInfoCache[filepath]
    end
    ds = NCDataset(filepath)
    sd = ds.attrib["Start_Date"]
    st = ds.attrib["Start_Time"]
    dt = ds.attrib["Delta_Time"]

    start = DateTime(sd * " " * st, dateformat"yyyymmdd HH:MM:SS.s")
    frequency = Second(parse(Int64, dt[1:2])) * 3600 + Second(parse(Int64, dt[3:4])) * 60 +
                Second(parse(Int64, dt[5:6]))
    centerpoints = ds["time"][:]
    di = DataFrequencyInfo(start, frequency, centerpoints)
    GEOSFPDataFrequencyInfoCache[filepath] = di
    return di
end

"""
$(SIGNATURES)

Load the data for the given variable name at the given time.
"""
function loadslice!(data::Array{T}, fs::GEOSFPFileSet, t::DateTime, varname)::DataArray{T} where {T<:Number}
    filepath = maybedownload(fs, t)
    ds = NCDataset(filepath)
    var, dims, data = loadslice!(data, fs, ds, t, varname, "time")

    scale, units = to_unitful(var.attrib["units"])
    description = var.attrib["long_name"]
    @assert var.attrib["scale_factor"] == 1.0 "Unexpected scale factor."
    if scale != 1
        data .*= scale
    end

    DataArray{T, ndims(data)}(data, units, description, dims)
end

"""Convert a vector of evenly spaced grid points to a range."""
function knots2range(knots)
    dx = [knots[i+1] - knots[i] for i ∈ 1:length(knots)-1]
    @assert all(dx .≈ dx[1]) "Knots must be evenly spaced."
    return knots[1]:dx[1]:knots[end]
end

"""
$(SIGNATURES)

Load the data for the given `DateTime` and variable name as an interpolator
from Interpolations.jl.
"""
function load_interpolator!(cache::Array{T}, fs::GEOSFPFileSet, t::DateTime, varname) where {T<:Number}
    ds = NCDataset.(maybedownload(fs, t))
    slice = loadslice!(cache, fs, t, varname)
    knots = Tuple([knots2range(ds[d][:]) for d ∈ slice.dimnames])
    itp = interpolate!(slice.data, BSpline(Linear())) # This destroys slice.data.
    itp = scale(itp, knots)
    itp, slice
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::GEOSFPFileSet, t::DateTime)
    filepath = maybedownload(fs, t)
    ds = NCDataset(filepath)
    [setdiff(keys(ds), keys(ds.dim))...]
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

`coord_defaults` can be used to provide default values for the coordinates of the
domain. For example if we want to perform a 2D simulation with a vertical dimension,
we can set `coord_defaults = Dict(:lev => 1)`.

`dtype` represents the desired data type of the interpolated values. The native data type
for this dataset is Float32.

See http://geoschemdata.wustl.edu/ExtData/ for current options.
"""
    function GEOSFP(domain, t; coord_defaults=Dict{Symbol,Number}(), dtype=Float32)
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
                itp = DataSetInterpolator{dtype}(fs, varname, sample_time)
                dims = dimnames(itp, sample_time)
                coords = Num[]
                for dim ∈ dims
                    d = Symbol(dim)
                    if d ∈ keys(coord_defaults) # Set a default value for this coordinate.
                        v = (@parameters $d = coord_defaults[d])[1]
                    else # No default value.
                        v = (@parameters $d)[1]
                    end
                    push!(coords, v)
                end
                push!(eqs, create_interp_equation(itp, filename, t, sample_time, coords))
            end
        end
        ODESystem(eqs, t, name=:EarthSciData₊GEOSFP)
end

@parameters t # TODO(CT) Remove when updating to MTK v9.
EarthSciMLBase.register_coupling(EarthSciMLBase.MeanWind(t), GEOSFP("4x5", t)) do mw, g
    eqs = [mw.v_lon ~ g.A3dyn₊U]
    # Only add the number of dimensions present in the mean wind system.
    length(states(mw.sys)) > 1 ? push!(eqs, mw.v_lat ~ g.A3dyn₊V) : nothing
    length(states(mw.sys)) > 2 ? push!(eqs, mw.v_lev ~ g.A3dyn₊OMEGA) : nothing

    ConnectorSystem(
            eqs,
            mw, g,
    )
end