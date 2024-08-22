export NEI2016MonthlyEmis

"""
$(SIGNATURES)

Archived CMAQ emissions data.

Currently, only data for year 2016 is available.
"""
struct NEI2016MonthlyEmisFileSet <: FileSet
    mirror::AbstractString
    sector
    NEI2016MonthlyEmisFileSet(sector) = new("https://gaftp.epa.gov/Air/", sector)
end

"""
$(SIGNATURES)

File path on the server relative to the host root; also path on local disk relative to `ENV["EARTHSCIDATADIR"]`.
"""
function relpath(fs::NEI2016MonthlyEmisFileSet, t::DateTime)
    @assert Dates.year(t) == 2016 "Only 2016 emissions data is available with `NEI2016MonthlyEmis`."
    month = @sprintf("%.2d", Dates.month(t))
    return "emismod/2016/v1/gridded/monthly_netCDF/2016fh_16j_$(fs.sector)_12US1_month_$(month).ncf"
end

function DataFrequencyInfo(fs::NEI2016MonthlyEmisFileSet, t::DateTime)::DataFrequencyInfo
    month = Dates.month(t)
    year = Dates.year(t)
    start = Dates.DateTime(year, month, 1)
    frequency = ((start + Dates.Month(1)) - start)
    centerpoints = [start + frequency / 2]
    return DataFrequencyInfo(start, frequency, centerpoints)
end

"""
$(SIGNATURES)

Load the data in place for the given variable name at the given time.
"""
function loadslice!(data::AbstractArray, fs::NEI2016MonthlyEmisFileSet, t::DateTime, varname)
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)
        var = loadslice!(data, fs, ds, t, varname, "TSTEP")

        Δx = ds.attrib["XCELL"]
        Δy = ds.attrib["YCELL"]
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
function loadmetadata(fs::NEI2016MonthlyEmisFileSet, t::DateTime, varname)::MetaData
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)

        timedim = "TSTEP"
        var = ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        Δx = ds.attrib["XCELL"]
        Δy = ds.attrib["YCELL"]
        _, units = to_unit(var.attrib["units"])
        units /= u"m^2"
        description = var.attrib["var_desc"]

        x₀ = ds.attrib["XORIG"]
        y₀ = ds.attrib["YORIG"]
        Δx = ds.attrib["XCELL"]
        Δy = ds.attrib["YCELL"]
        nx = ds.attrib["NCOLS"]
        ny = ds.attrib["NROWS"]
        xs = x₀ + Δx / 2 .+ Δx .* (0:nx-1)
        ys = y₀ + Δy / 2 .+ Δy .* (0:ny-1)

        coords = [xs, ys, [1.0]]

        p_alp = ds.attrib["P_ALP"]
        p_bet = ds.attrib["P_BET"]
        #p_gam = ds.attrib["P_GAM"] # Don't think this is used for anything.
        x_cent = ds.attrib["XCENT"]
        y_cent = ds.attrib["YCENT"]
        native_sr = "+proj=lcc +lat_1=$(p_alp) +lat_2=$(p_bet) +lat_0=$(y_cent) +lon_0=$(x_cent) +x_0=0 +y_0=0 +a=6370997.000000 +b=6370997.000000 +to_meter=1"

        @assert varsize[3] == 1 "Only 2D data is supported."

        xdim = findfirst((x) -> x == "COL", dims)
        ydim = findfirst((x) -> x == "ROW", dims)
        @assert xdim > 0 "NEI2016 `COL` dimension not found"
        @assert ydim > 0 "NEI2016 `ROW` dimension not found"

        return MetaData(coords, units, description, dims, varsize, native_sr, xdim, ydim)
    end
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::NEI2016MonthlyEmisFileSet, t::DateTime)
    lock(nclock) do
        filepath = maybedownload(fs, t)
        ds = getnc(filepath)
        return [setdiff(keys(ds), ["TFLAG"; keys(ds.dim)])...]
    end
end

struct NEI2016MonthlyEmisCoupler
    sys
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

NOTE: This is an interpolator that returns an emissions value by interpolating between the
centers of the nearest grid cells in the underlying emissions grid, so it may not exactly conserve the total 
emissions mass, especially if the simulation grid is coarser than the emissions grid.
"""
function NEI2016MonthlyEmis(sector, x, y, lev; spatial_ref="EPSG:4326", dtype=Float32, scale=1.0, name=:NEI2016MonthlyEmis, kwargs...)
    fs = NEI2016MonthlyEmisFileSet(sector)
    sample_time = DateTime(2016, 5, 1) # Dummy time to get variable names and dimensions from data.
    eqs = []
    @parameters(
        Δz = 60.0, [unit = u"m", description = "Height of the first vertical grid layer"],
    )
    vars = []
    itps = []
    for varname ∈ varnames(fs, sample_time)
        itp = DataSetInterpolator{dtype}(fs, varname, sample_time; spatial_ref, kwargs...)
        @constants zero_emis = 0 [unit = units(itp, sample_time) / u"m"]
        eq = create_interp_equation(itp, "", t, sample_time, [x, y, 1.0],
            wrapper_f=(eq) -> ifelse(lev < 2, eq / Δz * scale, zero_emis),
        )
        push!(eqs, eq)
        push!(vars, eq.lhs)
        push!(itps, itp)
    end
    sys = ODESystem(eqs, t; name=name,
        metadata=Dict(:coupletype => NEI2016MonthlyEmisCoupler))
    cb = UpdateCallbackCreator(sys, vars, itps)
    return sys, cb
end