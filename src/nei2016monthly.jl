export NEI2016MonthlyEmis

"""
$(SIGNATURES)

Archived CMAQ emissions data.

Currently, only data for year 2016 is available.
"""
struct NEI2016MonthlyEmisFileSet <: FileSet
    mirror::AbstractString
    sector::Any
    ds::Any
    freq_info::DataFrequencyInfo
    function NEI2016MonthlyEmisFileSet(sector, starttime, endtime)
        NEI2016MonthlyEmisFileSet("https://gaftp.epa.gov/Air/", sector, starttime, endtime)
    end
    function NEI2016MonthlyEmisFileSet(mirror, sector, starttime, endtime)
        floormonth(t) = DateTime(Dates.year(t), Dates.month(t))
        check_times = (floormonth(starttime - Day(16))):Month(1):(endtime + Day(16))
        fs = new(mirror, sector, nothing, DataFrequencyInfo(starttime, Day(1), check_times))
        filepaths = maybedownload.((fs,), check_times)

        start = floormonth(starttime)
        frequency = ((start + Dates.Month(1)) - start) # Only true for the first month.
        centerpoints = [t + Second(t + Month(1) - t) / 2 for t in check_times]
        dfi = DataFrequencyInfo(start, frequency, centerpoints)

        lock(nclock) do
            ds = NCDataset(filepaths, aggdim = "TSTEP")
            new(mirror, sector, ds, dfi)
        end
    end
end

"""
$(SIGNATURES)

File path on the server relative to the host root; also path on local disk relative to `ENV["EARTHSCIDATADIR"]`.
"""
function relpath(fs::NEI2016MonthlyEmisFileSet, t::DateTime)
    @assert Dates.year(t)==2016 "Only 2016 emissions data is available with `NEI2016MonthlyEmis`."
    month = lpad(Dates.month(t), 2, '0')
    return "emismod/2016/v1/gridded/monthly_netCDF/2016fh_16j_$(fs.sector)_12US1_month_$(month).ncf"
end

DataFrequencyInfo(fs::NEI2016MonthlyEmisFileSet) = fs.freq_info

"""
$(SIGNATURES)

Load the data in place for the given variable name at the given time.
"""
function loadslice!(
        data::AbstractArray,
        fs::NEI2016MonthlyEmisFileSet,
        t::DateTime,
        varname
)
    lock(nclock) do
        data = reshape(data, size(data)..., 1)
        var = loadslice!(data, fs, fs.ds, t, varname, "TSTEP")

        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
        data ./= (Δx * Δy)
    end
    nothing
end

"""
$(SIGNATURES)

Load the data for the given variable name at the given time.
"""
function loadmetadata(fs::NEI2016MonthlyEmisFileSet, varname)::MetaData
    lock(nclock) do
        timedim = "TSTEP"
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)
        @assert varsize[end]==1 "Only 2D data is supported."
        varsize = varsize[1:(end - 1)] # Last dimension is 1.

        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        _, units = to_unit(var.attrib["units"])
        units /= u"m^2"
        description = var.attrib["var_desc"]

        x₀ = fs.ds.attrib["XORIG"]
        y₀ = fs.ds.attrib["YORIG"]
        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        nx = fs.ds.attrib["NCOLS"]
        ny = fs.ds.attrib["NROWS"]
        xs = x₀ + Δx / 2 .+ Δx .* (0:(nx - 1))
        ys = y₀ + Δy / 2 .+ Δy .* (0:(ny - 1))

        coords = [xs, ys]

        p_alp = fs.ds.attrib["P_ALP"]
        p_bet = fs.ds.attrib["P_BET"]
        #p_gam = fs.ds.attrib["P_GAM"] # Don't think this is used for anything.
        x_cent = fs.ds.attrib["XCENT"]
        y_cent = fs.ds.attrib["YCENT"]
        native_sr = "+proj=lcc +lat_1=$(p_alp) +lat_2=$(p_bet) +lat_0=$(y_cent) +lon_0=$(x_cent) +x_0=0 +y_0=0 +a=6370997.000000 +b=6370997.000000 +to_meter=1"

        xdim = findfirst((x) -> x == "COL", dims)
        ydim = findfirst((x) -> x == "ROW", dims)
        @assert xdim>0 "NEI2016 `COL` dimension not found"
        @assert ydim>0 "NEI2016 `ROW` dimension not found"

        return MetaData(
            coords,
            units,
            description,
            dims,
            varsize,
            native_sr,
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
function varnames(fs::NEI2016MonthlyEmisFileSet)
    lock(nclock) do
        return [setdiff(keys(fs.ds), ["TFLAG"; keys(fs.ds.dim)])...]
    end
end

struct NEI2016MonthlyEmisCoupler
    sys::Any
end

"""
$(SIGNATURES)

A data loader for CMAQ-formatted monthly US National Emissions Inventory data for year 2016,
available from: https://gaftp.epa.gov/Air/emismod/2016/v1/gridded/monthly_netCDF/.
The emissions here are monthly averages, so there is no information about diurnal variation etc.

`spatial_ref` should be the spatial reference system that
the simulation will be using. `x` and `y`, and should be the coordinate variables and grid
spacing values for the simulation that is going to be run, corresponding to the given x and y
values of the given `spatial_ref`,
and the `lev` represents the variable for the vertical grid level.
x and y must be in the same units as `spatial_ref`.

`dtype` represents the desired data type of the interpolated values. The native data type
for this dataset is Float32.

`scale` is a scaling factor to apply to the emissions data. The default value is 1.0.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.

NOTE: This is an interpolator that returns an emissions value by interpolating between the
centers of the nearest grid cells in the underlying emissions grid, so it may not exactly conserve the total
emissions mass, especially if the simulation grid is coarser than the emissions grid.
"""
function NEI2016MonthlyEmis(
        sector::AbstractString,
        domaininfo::DomainInfo;
        scale = 1.0,
        name = :NEI2016MonthlyEmis,
        stream = true
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = NEI2016MonthlyEmisFileSet(sector, starttime, endtime)
    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :x in keys(pvdict)||:lon in keys(pvdict) "x or lon must be specified in the domaininfo"
    @assert :y in keys(pvdict)||:lat in keys(pvdict) "y or lat must be specified in the domaininfo"
    @assert :lev in keys(pvdict) "lev must be specified in the domaininfo"
    x = :x in keys(pvdict) ? pvdict[:x] : pvdict[:lon]
    y = :y in keys(pvdict) ? pvdict[:y] : pvdict[:lat]
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
        zero_emis = ModelingToolkit.unwrap(zero_emis) # Unsure why this is necessary.
        eq, param = create_interp_equation(itp, "", t, t_ref, [x, y];
            wrapper_f = (eq) -> ifelse(lev < 2, eq / Δz * scale, zero_emis))
        push!(eqs, eq)
        push!(params, param, zero_emis)
        push!(vars, eq.lhs)
    end
    sys = System(
        eqs,
        t,
        vars,
        [x, y, lev, Δz, params...];
        name = name,
        metadata = Dict(CoupleType => NEI2016MonthlyEmisCoupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime))
    )
    return sys
end
