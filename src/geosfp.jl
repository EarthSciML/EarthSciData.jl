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
  - 0.5x0.625_NA
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
    domain::Any
    filetype::Any
    ds::Any
    freq_info::DataFrequencyInfo
    function GEOSFPFileSet(domain, filetype, starttime, endtime)
        GEOSFPFileSet(
            "https://geos-chem.s3-us-west-2.amazonaws.com",
            domain,
            filetype,
            starttime,
            endtime
        )
    end
    function GEOSFPFileSet(mirror, domain, filetype, starttime, endtime)
        check_times = (starttime - Hour(13)):Day(1):(endtime + Hour(13)) # 13 hours because maybe daylight savings
        fs_temp = new(
            mirror,
            domain,
            filetype,
            nothing,
            DataFrequencyInfo(starttime, Day(1), check_times)
        )
        filepaths = maybedownload.((fs_temp,), check_times)

        lock(nclock) do
            ds = NCDataset(filepaths, aggdim = "time")

            sd = ds.attrib["Start_Date"]
            st = ds.attrib["Start_Time"]
            dt = ds.attrib["Delta_Time"]
            file_start = DateTime(sd * " " * st, dateformat"yyyymmdd HH:MM:SS.s")
            frequency = Second(parse(Int64, dt[1:2])) * 3600 +
                        Second(parse(Int64, dt[3:4])) * 60 +
                        Second(parse(Int64, dt[5:6]))
            times = ds["time"][:]
            dfi = DataFrequencyInfo(file_start, frequency, times)

            return new(mirror, domain, filetype, ds, dfi)
        end
    end
end

"""
$(SIGNATURES)

File path on the server relative to the host root; also path on local disk relative to `ENV["EARTHSCIDATADIR"]`
(or a scratch directory if that environment variable is not set).
"""
function relpath(fs::GEOSFPFileSet, t::DateTime)
    yr = year(t)
    month = @sprintf("%.2d", Dates.month(t))
    day = @sprintf("%.2d", Dates.day(t))
    domain = replace(fs.domain, '.' => "")
    domain = replace(domain, '_' => ".")
    return join(
        [
            "GEOS_$(fs.domain)/GEOS_FP/$yr/$month",
            "GEOSFP.$(yr)$(month)$day.$(fs.filetype).$(domain).nc"
        ],
        "/"
    )
end

DataFrequencyInfo(fs::GEOSFPFileSet)::DataFrequencyInfo = fs.freq_info

"""
$(SIGNATURES)

Load the data in place for the given variable name at the given time.
"""
function loadslice!(data::AbstractArray, fs::GEOSFPFileSet, t::DateTime, varname)
    lock(nclock) do
        var = loadslice!(data, fs, fs.ds, t, varname, "time") # Load data from NetCDF file.

        scale, _ = to_unit(var.attrib["units"])
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
function loadmetadata(fs::GEOSFPFileSet, varname)::MetaData
    lock(nclock) do
        timedim = "time"
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        _, units = to_unit(var.attrib["units"])
        description = var.attrib["long_name"]
        @assert var.attrib["scale_factor"] == 1.0 "Unexpected scale factor."
        coords = [fs.ds[d][:] for d in dims]

        xdim = findfirst((x) -> x == "lon", dims)
        ydim = findfirst((x) -> x == "lat", dims)
        zdim = findfirst((x) -> x == "lev", dims)
        zdim = isnothing(zdim) ? -1 : zdim
        @assert xdim > 0 "GEOSFP `lon` dimension not found"
        @assert ydim > 0 "GEOSFP `lat` dimension not found"
        # Convert from degrees to radians (so we are using SI units)
        coords[xdim] .= deg2rad.(coords[xdim])
        coords[ydim] .= deg2rad.(coords[ydim])

        staggering = geosfp_staggering(fs.filetype, varname)

        # This projection will assume the inputs are radians when used within
        # a Proj pipeline: https://proj.org/en/9.3/operations/pipeline.html
        prj = "+proj=longlat +datum=WGS84 +no_defs"

        return MetaData(
            coords,
            units,
            description,
            dims,
            varsize,
            prj,
            xdim,
            ydim,
            zdim,
            staggering
        )
    end
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::GEOSFPFileSet)
    lock(nclock) do
        return [setdiff(keys(fs.ds), keys(fs.ds.dim))...]
    end
end

# Hybrid grid parameters from https://wiki.seas.harvard.edu/geos-chem/index.php/GEOS-Chem_vertical_grids
const Ap = DataInterpolations.LinearInterpolation(
    [
        0.000000e+00,
        4.804826e-02,
        6.593752e+00,
        1.313480e+01,
        1.961311e+01,
        2.609201e+01,
        3.257081e+01,
        3.898201e+01,
        4.533901e+01,
        5.169611e+01,
        5.805321e+01,
        6.436264e+01,
        7.062198e+01,
        7.883422e+01,
        8.909992e+01,
        9.936521e+01,
        1.091817e+02,
        1.189586e+02,
        1.286959e+02,
        1.429100e+02,
        1.562600e+02,
        1.696090e+02,
        1.816190e+02,
        1.930970e+02,
        2.032590e+02,
        2.121500e+02,
        2.187760e+02,
        2.238980e+02,
        2.243630e+02,
        2.168650e+02,
        2.011920e+02,
        1.769300e+02,
        1.503930e+02,
        1.278370e+02,
        1.086630e+02,
        9.236572e+01,
        7.851231e+01,
        6.660341e+01,
        5.638791e+01,
        4.764391e+01,
        4.017541e+01,
        3.381001e+01,
        2.836781e+01,
        2.373041e+01,
        1.979160e+01,
        1.645710e+01,
        1.364340e+01,
        1.127690e+01,
        9.292942e+00,
        7.619842e+00,
        6.216801e+00,
        5.046801e+00,
        4.076571e+00,
        3.276431e+00,
        2.620211e+00,
        2.084970e+00,
        1.650790e+00,
        1.300510e+00,
        1.019440e+00,
        7.951341e-01,
        6.167791e-01,
        4.758061e-01,
        3.650411e-01,
        2.785261e-01,
        2.113490e-01,
        1.594950e-01,
        1.197030e-01,
        8.934502e-02,
        6.600001e-02,
        4.758501e-02,
        3.270000e-02,
        2.000000e-02,
        1.000000e-02
    ] .* 100,
    1:73
) # Pa

# Handle units
ModelingToolkit.get_unit(::typeof(Ap)) = 1.0
ModelingToolkit.get_unit(::typeof(DataInterpolations.derivative), args) = 1.0
Latexify.@latexrecipe function f(itp::typeof(Ap))
    return "$(nameof(itp))_interp"
end

const Bp = DataInterpolations.LinearInterpolation(
    [
        1.000000e+00,
        9.849520e-01,
        9.634060e-01,
        9.418650e-01,
        9.203870e-01,
        8.989080e-01,
        8.774290e-01,
        8.560180e-01,
        8.346609e-01,
        8.133039e-01,
        7.919469e-01,
        7.706375e-01,
        7.493782e-01,
        7.211660e-01,
        6.858999e-01,
        6.506349e-01,
        6.158184e-01,
        5.810415e-01,
        5.463042e-01,
        4.945902e-01,
        4.437402e-01,
        3.928911e-01,
        3.433811e-01,
        2.944031e-01,
        2.467411e-01,
        2.003501e-01,
        1.562241e-01,
        1.136021e-01,
        6.372006e-02,
        2.801004e-02,
        6.960025e-03,
        8.175413e-09,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00,
        0.000000e+00
    ],
    1:73
)

struct GEOSFPCoupler
    sys::Any
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
  - 0.5x0.625_NA
  - 2x2.5
  - 4x5
  - C180
  - C720
  - NATIVE
  - c720

The native data type for this dataset is Float32.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.

See http://geoschemdata.wustl.edu/ExtData/ for current data domain options.
"""
function GEOSFP(
        domain::AbstractString,
        domaininfo::DomainInfo;
        name = :GEOSFP,
        stream = true
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    filesets = Dict{String, GEOSFPFileSet}(
        "A1" => GEOSFPFileSet(domain, "A1", starttime, endtime),
        "A3cld" => GEOSFPFileSet(domain, "A3cld", starttime, endtime),
        "A3dyn" => GEOSFPFileSet(domain, "A3dyn", starttime, endtime),
        "A3mstC" => GEOSFPFileSet(domain, "A3mstC", starttime, endtime),
        "A3mstE" => GEOSFPFileSet(domain, "A3mstE", starttime, endtime),
        "I3" => GEOSFPFileSet(domain, "I3", starttime, endtime)
    )

    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)
    eqs = Equation[]
    params = []
    vars = Num[]
    for (filename, fs) in filesets
        for varname in varnames(fs)
            dt = EarthSciMLBase.dtype(domaininfo)
            itp = DataSetInterpolator{dt}(
                fs,
                varname,
                starttime,
                endtime,
                domaininfo;
                stream = stream
            )
            dims = dimnames(itp)
            coords = Num[]
            for dim in dims
                d = Symbol(dim)
                @assert d ∈ keys(pvdict) "GEOSFP coordinate $d not found in domaininfo coordinates ($(pvs))."
                push!(coords, pvdict[d])
            end
            eq, param = create_interp_equation(itp, filename, t, starttime, coords)
            push!(eqs, eq)
            push!(params, param)
            push!(vars, eq.lhs)
        end
    end

    # Implement hybrid grid pressure: https://wiki.seas.harvard.edu/geos-chem/index.php/GEOS-Chem_vertical_grids
    @constants P_unit = 1.0 [unit = u"Pa", description = "Unit pressure"]
    @variables P(t) [unit = u"Pa", description = "Pressure"]
    i3ps = vars[findfirst(isequal(:I3₊PS), EarthSciMLBase.var2symbol.(vars))]
    @assert :lev in keys(pvdict) "GEOSFP coordinate :lev not found in domaininfo coordinates ($(pvs))."
    lev = pvdict[:lev]
    pressure_eq = P ~ P_unit * Ap(lev) + Bp(lev) * i3ps
    push!(eqs, pressure_eq)
    push!(vars, P)

    # Coordinate transforms.
    @variables δxδlon(t) [
        unit = u"m/rad",
        description = "X gradient with respect to longitude"
    ]
    @variables δyδlat(t) [
        unit = u"m/rad",
        description = "Y gradient with respect to latitude"
    ]
    @variables δPδlev(t) [
        unit = u"Pa",
        description = "Pressure gradient with respect to hybrid grid level"
    ]
    @constants lat2meters = 111.32e3 * 180 / π [unit = u"m/rad"]
    @constants lon2m = 40075.0e3 / 2π [unit = u"m/rad"]
    lon_trans = δxδlon ~ lon2m * cos(pvdict[:lat])
    lat_trans = δyδlat ~ lat2meters
    lev_trans = δPδlev ~ expand_derivatives(Differential(lev)(pressure_eq.rhs))
    push!(eqs, lon_trans, lat_trans, lev_trans)
    push!(vars, δxδlon, δyδlat, δPδlev)

    sys = ODESystem(
        eqs,
        t,
        vars,
        [pvdict[:lon], pvdict[:lat], lev, params...];
        name = name,
        metadata = Dict(:coupletype => GEOSFPCoupler,
            :sys_discrete_event => create_updater_sys_event(name, params, starttime)),
    )
    return sys
end

function EarthSciMLBase.couple2(mw::EarthSciMLBase.MeanWindCoupler, g::GEOSFPCoupler)
    mw, g = mw.sys, g.sys
    eqs = [mw.v_lon ~ g.A3dyn₊U]
    # Only add the number of dimensions present in the mean wind system.
    length(unknowns(mw)) > 1 ? push!(eqs, mw.v_lat ~ g.A3dyn₊V) : nothing
    length(unknowns(mw)) > 2 ? push!(eqs, mw.v_lev ~ g.A3dyn₊OMEGA) : nothing

    ConnectorSystem(eqs, mw, g)
end

"""
$(SIGNATURES)

Return a function to calculate coefficients to multiply the
`δ(u)/δ(lev)` partial derivative operator by
to convert a variable named `u` from δ(u)/δ(lev)`to`δ(u)/δ(P)`, i.e. from vertical level number to pressure in hPa. The return format is `coordinate_index => conversion_factor`.
"""
function partialderivatives_δPδlev_geosfp(geosfp; default_lev = 1.0)
    # Find index for surface pressure.
    ii = findfirst(
        (x) -> x == :I3₊PS,
        [Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(geosfp)]
    )
    # Get interpolator for surface pressure.
    ps_eq = ModelingToolkit.namespace_equation(equations(geosfp)[ii], geosfp)
    ps = ps_eq.rhs
    @constants P_unit = 1.0 [unit = u"Pa", description = "Unit pressure"]
    # Function to calculate pressure at a given level in the hybrid grid.
    # This is on a staggered grid so level=1 is the grid bottom.
    P(levx) = (P_unit * Ap(levx) + Bp(levx) * ps)

    (pvars::AbstractVector) -> begin
        levindex = EarthSciMLBase.matching_suffix_idx(pvars, :lev)
        if length(levindex) > 1
            throw(
                error(
                "Multiple variables with suffix :lev found in pvars: $(pvars[levindex])",
            ),
            )
        end
        if length(levindex) > 0
            lev = pvars[only(levindex)]
        else
            lev = default_lev
        end

        # d(u) / d(P) = d(u) / d(lev) / ( d(P) / d(lev) )
        δPδlev = 0.5 / (P(Num(lev) + 0.5) - P(Num(lev)))

        return Dict(only(levindex) => δPδlev)
    end
end

# Return grid staggering for the given variable,
# true for edge-aligned and false for center-aligned.
# It should always be a triple of booleans for the
# x, y, and z dimensions, respectively, regardless
# of the dimensions of the variable.
function geosfp_staggering(filename, varname)::NTuple{3, Bool}
    if filename == "A3dyn"
        if varname == "U"
            return (true, false, false)
        elseif varname == "V"
            return (false, true, false)
        elseif varname == "OMEGA"
            return (false, false, true)
        end
    end
    return (false, false, false)
end
