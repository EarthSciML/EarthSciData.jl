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
    year = Dates.format(t, "Y")
    if year != "2016"
        @warn "Only 2016 emissions data is available."
    end
    month = @sprintf("%.2d", Dates.month(t))
    return "emismod/2016/v1/gridded/monthly_netCDF/2016fh_16j_$(fs.sector)_12US1_month_$(month).ncf"
end

# Cache to store data frequency information.
NEI2016MonthlyEmisDataFrequencyInfoCache = Dict{String,DataFrequencyInfo}()

function DataFrequencyInfo(fs::NEI2016MonthlyEmisFileSet, t::DateTime)::DataFrequencyInfo
    filepath = maybedownload(fs, t)
    if haskey(NEI2016MonthlyEmisDataFrequencyInfoCache, filepath)
        return NEI2016MonthlyEmisDataFrequencyInfoCache[filepath]
    end
    month = Dates.month(t)
    start = Dates.DateTime(2016, month, 1)
    frequency = ((start + Dates.Month(1)) - start)
    centerpoints = [start + frequency / 2]
    di = DataFrequencyInfo(start, frequency, centerpoints)
    NEI2016MonthlyEmisDataFrequencyInfoCache[filepath] = di
    return di
end

"""
$(SIGNATURES)

Load the data for the given variable name at the given time.
"""
function loadslice(fs::NEI2016MonthlyEmisFileSet, t::DateTime, varname)::DataArray
    filepath = maybedownload(fs, t)
    fid = NetCDF.open(filepath)
    var = fid[varname]
    dims = Dict{String,Int}()
    dimids = Dict{Int,String}()
    for k in keys(fid.dim)
        dims[k] = fid.dim[k].dimid
        dimids[fid.dim[k].dimid] = k
    end
    dimnames = [dimids[id] for id ∈ var.dimids]
    time_index = findfirst(isequal("TSTEP"), dimnames)
    deleteat!(dimnames, time_index) # Remove the time dimension.
    @assert "TSTEP" ∈ keys(dims) "File $filepath does not have a dimension named 'TSTEP'."
    # Load only one time step, but the full array for everything else.
    slices = repeat(Any[:], var.ndim)
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs, t), t)
    data = var[slices...]

    Δx = fid.gatts["XCELL"]
    Δy = fid.gatts["YCELL"]
    scale, units = to_unitful(var.atts["units"])
    if scale != 1
        data .*= scale / (Δx * Δy)
        units /= u"m^2"
    end
    description = var.atts["var_desc"]

    DataArray(data, units, description, dimnames)
end

"""
$(SIGNATURES)

Load the data for the given `DateTime` and variable name as an interpolator
from Interpolations.jl. `spatial_ref` should be the spatial reference system that 
the simulation will be using.
"""
function load_interpolator(fs::NEI2016MonthlyEmisFileSet, t::DateTime, varname; spatial_ref="EPSG:4326")
    fid = NetCDF.open(maybedownload(fs, t))
    slice = loadslice(fs, t, varname)

    p_alp = fid.gatts["P_ALP"]
    p_bet = fid.gatts["P_BET"]
    #p_gam = fid.gatts["P_GAM"] # Don't think this is used for anything.
    x_cent = fid.gatts["XCENT"]
    y_cent = fid.gatts["YCENT"]
    native_sr = "+proj=lcc +lat_1=$(p_alp) +lat_2=$(p_bet) +lat_0=$(y_cent) +lon_0=$(x_cent) +x_0=0 +y_0=0 +a=6370997.000000 +b=6370997.000000 +to_meter=1"
    trans = Proj.Transformation(spatial_ref, native_sr, always_xy=true)

    x₀ = fid.gatts["XORIG"]
    y₀ = fid.gatts["YORIG"]
    Δx = fid.gatts["XCELL"]
    Δy = fid.gatts["YCELL"]
    nx = fid.gatts["NCOLS"]
    ny = fid.gatts["NROWS"]
    xs = x₀ + Δx / 2 .+ Δx .* (0:nx-1)
    ys = y₀ + Δy / 2 .+ Δy .* (0:ny-1)
    itp = interpolate(slice.data[:, :, 1], BSpline(Constant(Next)))
    itp = scale(itp, (xs, ys))
    itp = extrapolate(itp, 0)
    itp_trans(x, y, z) = begin
        if z >= 2 # We're only considering ground level emissions
            return 0.0
        end
        x, y = trans(x, y)
        itp(x, y)
    end
    itp_trans, slice
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::NEI2016MonthlyEmisFileSet, t::DateTime)
    filepath = maybedownload(fs, t)
    fid = NetCDF.open(filepath)
    [setdiff(keys(fid.vars), ["TFLAG"; keys(fid.dim)])...]
end

"""
$(SIGNATURES)

A data loader for CMAQ-formatted monthly US National Emissions Inventory data for year 2016, 
available from: https://gaftp.epa.gov/Air/emismod/2016/v1/gridded/monthly_netCDF/.
The emissions here are monthly averages, so there is no information about diurnal variation etc.

`spatial_ref` should be the spatial reference system that 
the simulation will be using. `x`, `Δx`, `y`, and `Δy` should be the coordinate variables and grid 
spacing values for the simulation that is going to be run, corresponding to the given x and y 
values of the given `spatial_ref`,
and the `lev` represents the variable for the vertical grid level.
Δx and Δy must be in units of meters, and x and y must be in the same units as `spatial_ref`.

NOTE: This is an interpolator that returns the emissions value of the nearest grid cell 
center for the underlying emissions grid, so it may not exactly conserve the total 
emissions mass, especially if the simulation grid is coarser than the emissions grid.

# Example
``` jldoctest
using EarthSciData, ModelingToolkit, Unitful
@parameters t lat lon lev
@parameters Δz = 60 [unit=u"m"]
emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", t, lon, lat, lev, Δz)
```
"""
struct NEI2016MonthlyEmis <: EarthSciMLODESystem
    fileset::NEI2016MonthlyEmisFileSet
    sys::ODESystem
    function NEI2016MonthlyEmis(sector, t, x, y, lev, Δz; spatial_ref="EPSG:4326")
        fs = NEI2016MonthlyEmisFileSet(sector)
        sample_time = DateTime(2016, 5, 1) # Dummy time to get variable names and dimensions from data.
        eqs = []
        @assert ModelingToolkit.get_unit(Δz) == u"m" "Δz must be in units of meters."
        for varname ∈ varnames(fs, sample_time)
            itp = DataSetInterpolator(fs, varname; spatial_ref)
            push!(eqs, create_interp_equation(itp, sector, t, sample_time, [x, y, lev], 1/Δz))
        end
        sys = ODESystem(eqs, t; name=:NEI2016MonthlyEmis)
        new(fs, sys)
    end
end