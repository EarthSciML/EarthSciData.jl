export GEOSFP, partialderivatives_δPδlev_geosfp

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

function DataFrequencyInfo(fs::GEOSFPFileSet, t::DateTime)::DataFrequencyInfo
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)
        sd = ds.attrib["Start_Date"]
        st = ds.attrib["Start_Time"]
        dt = ds.attrib["Delta_Time"]

        start = DateTime(sd * " " * st, dateformat"yyyymmdd HH:MM:SS.s")
        frequency = Second(parse(Int64, dt[1:2])) * 3600 + Second(parse(Int64, dt[3:4])) * 60 +
                    Second(parse(Int64, dt[5:6]))
        centerpoints = ds["time"][:]
        return DataFrequencyInfo(start, frequency, centerpoints)
    end
end

"""
$(SIGNATURES)

Load the data in place for the given variable name at the given time.
"""
function loadslice!(data::AbstractArray, fs::GEOSFPFileSet, t::DateTime, varname)
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)
        var = loadslice!(data, fs, ds, t, varname, "time") # Load data from NetCDF file.

        scale, _ = to_unitful(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
    end
    nothing
end

"""
$(SIGNATURES)

Load the data for the given variable name at the given time.
"""
function loadslice(fs::GEOSFPFileSet, t::DateTime, varname)
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)
        var, dims, data = loadslice(fs, ds, t, varname, "time") # Load data from NetCDF file.

        scale, units = to_unitful(var.attrib["units"])
        description = var.attrib["long_name"]
        @assert var.attrib["scale_factor"] == 1.0 "Unexpected scale factor."
        if scale != 1
            data .*= scale
        end
        coords = [ds[d][:] for d ∈ dims]

        xdim = findfirst((x) -> x == "lon", dims)
        ydim = findfirst((x) -> x == "lat", dims)
        @assert xdim > 0 "GEOSFP `lon` dimension not found"
        @assert ydim > 0 "GEOSFP `lat` dimension not found"

        return data, MetaData(coords, units, description, dims, "EPSG:4326", xdim, ydim)
    end
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::GEOSFPFileSet, t::DateTime)
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)
        return [setdiff(keys(ds), keys(ds.dim))...]
    end
end

# Hybrid grid parameters from https://wiki.seas.harvard.edu/geos-chem/index.php/GEOS-Chem_vertical_grids
const Ap = DataInterpolations.LinearInterpolation([
        0.000000e+00, 4.804826e-02, 6.593752e+00, 1.313480e+01, 1.961311e+01, 2.609201e+01,
        3.257081e+01, 3.898201e+01, 4.533901e+01, 5.169611e+01, 5.805321e+01, 6.436264e+01,
        7.062198e+01, 7.883422e+01, 8.909992e+01, 9.936521e+01, 1.091817e+02, 1.189586e+02,
        1.286959e+02, 1.429100e+02, 1.562600e+02, 1.696090e+02, 1.816190e+02, 1.930970e+02,
        2.032590e+02, 2.121500e+02, 2.187760e+02, 2.238980e+02, 2.243630e+02, 2.168650e+02,
        2.011920e+02, 1.769300e+02, 1.503930e+02, 1.278370e+02, 1.086630e+02, 9.236572e+01,
        7.851231e+01, 6.660341e+01, 5.638791e+01, 4.764391e+01, 4.017541e+01, 3.381001e+01,
        2.836781e+01, 2.373041e+01, 1.979160e+01, 1.645710e+01, 1.364340e+01, 1.127690e+01,
        9.292942e+00, 7.619842e+00, 6.216801e+00, 5.046801e+00, 4.076571e+00, 3.276431e+00,
        2.620211e+00, 2.084970e+00, 1.650790e+00, 1.300510e+00, 1.019440e+00, 7.951341e-01,
        6.167791e-01, 4.758061e-01, 3.650411e-01, 2.785261e-01, 2.113490e-01, 1.594950e-01,
        1.197030e-01, 8.934502e-02, 6.600001e-02, 4.758501e-02, 3.270000e-02, 2.000000e-02,
        1.000000e-02], 1:73) # hPa

const Bp = DataInterpolations.LinearInterpolation([
        1.000000e+00, 9.849520e-01, 9.634060e-01, 9.418650e-01, 9.203870e-01, 8.989080e-01,
        8.774290e-01, 8.560180e-01, 8.346609e-01, 8.133039e-01, 7.919469e-01, 7.706375e-01,
        7.493782e-01, 7.211660e-01, 6.858999e-01, 6.506349e-01, 6.158184e-01, 5.810415e-01,
        5.463042e-01, 4.945902e-01, 4.437402e-01, 3.928911e-01, 3.433811e-01, 2.944031e-01,
        2.467411e-01, 2.003501e-01, 1.562241e-01, 1.136021e-01, 6.372006e-02, 2.801004e-02,
        6.960025e-03, 8.175413e-09, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00,
        0.000000e+00], 1:73)

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
function GEOSFP(domain, t; coord_defaults=Dict{Symbol,Number}(), spatial_ref="EPSG:4326", dtype=Float32, kwargs...)
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
            itp = DataSetInterpolator{dtype}(fs, varname, sample_time; spatial_ref, kwargs...)
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

    # Implement hybrid grid pressure: https://wiki.seas.harvard.edu/geos-chem/index.php/GEOS-Chem_vertical_grids
    @constants P_unit = 1.0 [unit = u"hPa", description = "Unit pressure"]
    @variables P(t) [unit = u"hPa", description = "Pressure"]
    @variables I3₊PS(t) [unit = u"hPa", description = "Pressure at the surface"]
    d = :lev
    if d ∈ keys(coord_defaults) # Set a default value for this coordinate.
        lev = (@parameters $d = coord_defaults[d])[1]
    else # No default value.
        lev = (@parameters $d)[1]
    end
    pressure_eq = P ~ P_unit * Ap(lev) + Bp(lev) * I3₊PS
    push!(eqs, pressure_eq)

    ODESystem(eqs, t, name=:EarthSciData₊GEOSFP)
end

@parameters t # TODO(CT) Remove when updating to MTK v9.
EarthSciMLBase.register_coupling(EarthSciMLBase.MeanWind(t), GEOSFP("4x5", t)) do mw, g
    eqs = [mw.v_lon ~ g.A3dyn₊U]
    # Only add the number of dimensions present in the mean wind system.
    length(states(mw)) > 1 ? push!(eqs, mw.v_lat ~ g.A3dyn₊V) : nothing
    length(states(mw)) > 2 ? push!(eqs, mw.v_lev ~ g.A3dyn₊OMEGA) : nothing

    ConnectorSystem(
        eqs,
        mw, g,
    )
end

"""
$(SIGNATURES)

Return a function to calculate coefficients to multiply the 
`δ(u)/δ(lev)` partial derivative operator by
to convert a variable named `u` from δ(u)/δ(lev)` to `δ(u)/δ(P)`,
i.e. from vertical level number to pressure in hPa.
The return format is `coordinate_index => conversion_factor`.
"""
function partialderivatives_δPδlev_geosfp(geosfp; default_lev=1.0)
    # Find index for surface pressure.
    ii = findfirst((x) -> x == :I3₊PS, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    # Get interpolator for surface pressure.
    ps = equations(geosfp)[ii].rhs
    @constants P_unit = 1.0 [unit = u"hPa", description = "Unit pressure"]
    @constants Pa_per_hPa = 100 [unit = u"Pa/hPa", description = "Conversion factor from hPa to Pa"]
    P(levx) = (P_unit * Ap(levx) + Bp(levx) * ps) * Pa_per_hPa # Function to calculate pressure at a given level in the hybrid grid.

    (pvars::AbstractVector) -> begin
        levindex = EarthSciMLBase.varindex(pvars, :lev)
        if !isnothing(levindex)
            lev = pvars[levindex]
        else
            lev = default_lev
        end

        δPδlev = 0.5 / (P(Num(lev) + 0.5) - P(Num(lev))) # d(u) / d(P) = d(u) / d(lev) / ( d(P) / d(lev) )

        return Dict(levindex => δPδlev)
    end
end