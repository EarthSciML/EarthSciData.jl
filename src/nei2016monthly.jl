export NEI2016MonthlyEmis

# Diurnal scale factors for 24 hours (0-23) for UTC-0
const DIURNAL_FACTORS = [0.45, 0.45, 0.6, 0.6, 0.6, 0.6, 1.45, 1.45, 1.45, 1.45, 1.4, 1.4, 1.4, 1.4, 1.45, 1.45, 1.45, 1.45, 0.65, 0.65, 0.65, 0.65, 0.45, 0.45]
const DIURNAL_FACTORS_NOx = [0.39598674, 0.31852847, 0.30128068, 0.29590213, 0.33177775, 0.43871498, 0.9094625, 1.5850095, 1.6223788, 1.3429453, 1.2265036, 1.1937649, 1.254314, 1.3282939, 1.331211, 1.4135737, 1.6848333, 1.710925, 1.3491899, 1.0586671, 0.84439224, 0.761263, 0.72693235, 0.5741503]
const DIURNAL_FACTORS_ISOP =[0,0,0,0,0,0, 0.2376,0.7224,1.2048,1.656,2.0496,2.3616,2.5728,2.6616,2.6184,2.4408,2.1288,1.6896,1.1448,0.5136, 0,0,0,0]

const DayofWeekFactors_NOx = [1.0706,1.0706,1.0706,1.0706,1.0706,0.863,0.784]
const DayofWeekFactors_CO = [1.076,1.1076,1.0706,1.0706,1.0706,0.779,0.683]

# Load and create interpolator for delp_dry_surface
const DELP_DRY_SURFACE_ITP = let
    # Load the delp_dry_surface data
    delp_data = load(joinpath(@__DIR__, "mean_domian_delp_dry_surface.jld2"), "mean_domian_delp_dry_surface")

    # Define the grid coordinates
    domain_lon = collect(-125.0:0.625:-66.875)
    domain_lat = collect(25.0:0.5:49.0)

    # Create 2D interpolator with flat extrapolation (use boundary values for out-of-bounds)
    # Note: delp_data should be (lon, lat) ordered to match (domain_lon, domain_lat)
    itp = interpolate((domain_lon, domain_lat), delp_data, Gridded(Linear()))
    extrapolate(itp, Flat())
end

"""
$(SIGNATURES)

Interpolate the delp_dry_surface field at a given longitude and latitude.
Returns the dry pressure thickness value in Pa.
"""
function delp_dry_surface_itp(lon, lat)
    # Convert from radians to degrees if needed
    lon_deg = rad2deg(lon)
    lat_deg = rad2deg(lat)

    # The interpolator now handles out-of-bounds automatically with Flat() extrapolation
    return DELP_DRY_SURFACE_ITP(lon_deg, lat_deg)
end

"""
$(SIGNATURES)

Diurnal interpolation function that returns the scale factor for a given time.
Returns different emission scaling factors based on the hour of day.
"""
function diurnal_itp(t, lon)
    ut = Dates.unix2datetime(t)

    # Convert radians to degrees for timezone calculation
    lon_deg = rad2deg(lon)
    dt = floor(lon_deg / 15) # in hours (timezone offset)
    t_local = t + dt * 3600 # in seconds
    ut_local = Dates.unix2datetime(t_local)
    hour_of_day = Dates.hour(ut_local) + 1  # +1 for 1-based indexing

    return DIURNAL_FACTORS[hour_of_day]
end

function diurnal_itp_NOx(t, lon)
    ut = Dates.unix2datetime(t)

    # Convert radians to degrees for timezone calculation
    lon_deg = rad2deg(lon)
    dt = floor(lon_deg / 15) # in hours (timezone offset)
    t_local = t + dt * 3600 # in seconds
    ut_local = Dates.unix2datetime(t_local)
    hour_of_day = Dates.hour(ut_local) + 1  # +1 for 1-based indexing

    return DIURNAL_FACTORS_NOx[hour_of_day]
end

function diurnal_itp_ISOP(t, lon)
    ut = Dates.unix2datetime(t)

    # Convert radians to degrees for timezone calculation
    lon_deg = rad2deg(lon)
    dt = floor(lon_deg / 15) # in hours (timezone offset)
    t_local = t + dt * 3600 # in seconds
    ut_local = Dates.unix2datetime(t_local)
    hour_of_day = Dates.hour(ut_local) + 1  # +1 for 1-based indexing

    return DIURNAL_FACTORS_ISOP[hour_of_day]
end

"""
$(SIGNATURES)

Day of week interpolation function that returns the scale factor for a given time.
Returns different emission scaling factors based on the day of week.
"""
function dayofweek_itp_CO(t, lon)
    ut = Dates.unix2datetime(t)

    # Convert radians to degrees for timezone calculation
    lon_deg = rad2deg(lon)
    dt = floor(lon_deg / 15) # in hours (timezone offset)
    t_local = t + dt * 3600 # in seconds
    ut_local = Dates.unix2datetime(t_local)
    day_of_week = Dates.dayofweek(ut_local)

    return DayofWeekFactors_CO[day_of_week]
end

function dayofweek_itp_NOx(t, lon)
    ut = Dates.unix2datetime(t)

    # Convert radians to degrees for timezone calculation
    lon_deg = rad2deg(lon)
    dt = floor(lon_deg / 15) # in hours (timezone offset)
    t_local = t + dt * 3600 # in seconds
    ut_local = Dates.unix2datetime(t_local)
    day_of_week = Dates.dayofweek(ut_local)

    return DayofWeekFactors_NOx[day_of_week]
end

# Register the symbolic function
@register_symbolic diurnal_itp(t, lon)
@register_symbolic diurnal_itp_NOx(t, lon)
@register_symbolic diurnal_itp_ISOP(t, lon)
@register_symbolic dayofweek_itp_CO(t, lon)
@register_symbolic dayofweek_itp_NOx(t, lon)
@register_symbolic delp_dry_surface_itp(lon, lat)

# Dummy function for unit validation. ModelingToolkit will call this function
# with a DynamicQuantities.Quantity to get information about the type and units of the output.
diurnal_itp(t::DynamicQuantities.Quantity, lon) = 1.0
diurnal_itp_NOx(t::DynamicQuantities.Quantity, lon) = 1.0
diurnal_itp_ISOP(t::DynamicQuantities.Quantity, lon) = 1.0
dayofweek_itp_CO(t::DynamicQuantities.Quantity, lon) = 1.0
dayofweek_itp_NOx(t::DynamicQuantities.Quantity, lon) = 1.0
delp_dry_surface_itp(lon::DynamicQuantities.Quantity, lat::DynamicQuantities.Quantity) = 1.0

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

Load the NEI data for the given variable name at the given time.
This loads data in kg/s/m^2 units on the NEI source grid for regridding.
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

        # Step 1: Apply unit conversion from the file (typically tons/day to kg/s)
        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale  # Now data is in kg/s per grid cell
        end

        # Step 2: Convert from kg/s per grid cell to kg/s/m² for conservative regridding
        # This is the flux density that can be conservatively regridded
        Δx = fs.ds.attrib["XCELL"]  # Cell width in meters
        Δy = fs.ds.attrib["YCELL"]  # Cell height in meters
        data ./= (Δx * Δy)  # Now data is in kg/s/m²
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
            string(units),
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

function get_geometry(fs::NEI2016MonthlyEmisFileSet, m::MetaData)
    x₀,y₀,Δx,Δy,nx,ny = lock(nclock) do
        x₀ = fs.ds.attrib["XORIG"]
        y₀ = fs.ds.attrib["YORIG"]
        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        nx = fs.ds.attrib["NCOLS"]
        ny = fs.ds.attrib["NROWS"]
        x₀,y₀,Δx,Δy,nx,ny
    end
    # Create edges (nx+1 and ny+1 points) so we get nx*ny cells
    x = range(start=x₀, step=Δx, length=nx+1)
    y = range(start=y₀, step=Δy, length=ny+1)
    # Use column-major (x-fastest) ordering to match vec() on data arrays
    polys = Vector{Vector{NTuple{2, Float64}}}(undef, nx*ny)
    for j in 1:ny, i in 1:nx
        polys[(j-1)*nx + i] = [(x[i], y[j]), (x[i+1], y[j]), (x[i+1], y[j+1]),
            (x[i], y[j+1]), (x[i], y[j])]
    end
    return polys
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

The emissions are returned as mixing ratios in units of kg/kg/s by converting from the
native flux density (kg/m²/s) using:

    mixing_ratio = flux / (g0_100 * delp_dry_surface)

where g0_100 ≈ 10.197 kg/m² and delp_dry_surface is the dry pressure thickness (physically unit in hPa, but here is unitless)
that varies spatially across the domain.

`scale` is a scaling factor to apply to the emissions data. The default value is 1.0.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.

Conservative regridding (via ConservativeRegridding.jl) is used by default to map emissions
from the native NEI Lambert Conformal Conic grid to the simulation domain grid, preserving
total emissions mass.
"""
function NEI2016MonthlyEmis(
        sector::AbstractString,
        domaininfo::DomainInfo;
        scale = 1.0,
        name = :NEI2016MonthlyEmis,
        stream = true
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    _fs = NEI2016MonthlyEmisFileSet(sector, starttime, endtime)
    fs = FileSetWithRegridder(_fs,
        regridder(_fs, loadmetadata(_fs, first(varnames(_fs))), domaininfo))
    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :x in keys(pvdict)||:lon in keys(pvdict) "x or lon must be specified in the domaininfo"
    @assert :y in keys(pvdict)||:lat in keys(pvdict) "y or lat must be specified in the domaininfo"
    @assert :lev in keys(pvdict) "lev must be specified in the domaininfo"
    x = :x in keys(pvdict) ? pvdict[:x] : pvdict[:lon]
    y = :y in keys(pvdict) ? pvdict[:y] : pvdict[:lat]
    lev = pvdict[:lev]
    @parameters(Δz=1.0,
        [description = "Couldn't remove Δz without getting errors, so I set it to 1.0 without units"],)
    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    # Conversion constant: g0_100 = 100 hPa / g0 where g0 = 9.80665 m/s²
    @parameters g0_100 = 100.0 / 9.80665 [unit = u"kg/m^2"]
    eqs = Equation[]
    params = Any[t_ref, g0_100]
    vars = Num[]

    for varname in varnames(fs.fs)
        dt = EarthSciMLBase.eltype(domaininfo)
        itp = DataSetInterpolator{dt}(fs, varname, starttime, endtime, domaininfo;
            stream = stream)

        # Don't pre-declare units - let ModelingToolkit infer from the actual equation
        # The conversion formula divides flux (kg/m²/s) by (g0_100 * delp), giving kg/kg/s
        # But we need zero_emis to match the units of the converted result
        converted_units = units(itp) / u"kg/m^2"  # = 1/s (same as kg/kg/s for emissions)
        ze_name = Symbol(:zero_, varname)
        zero_emis = only(@constants $(ze_name)=0 [unit = converted_units])
        zero_emis = ModelingToolkit.unwrap(zero_emis) # Unsure why this is necessary.
        push!(params, zero_emis)

        # Apply diurnal scaling and mixing ratio conversion to certain chemical species
        # The conversion is: mixing_ratio = flux / (g0_100 * delp_dry_surface(x, y))
        if varname in ["CO"]
            wrapper_f = (eq) -> ifelse(lev < 2,
                eq / Δz * scale * dayofweek_itp_CO(t + t_ref, x) * diurnal_itp(t + t_ref, x) / (g0_100 * delp_dry_surface_itp(x, y)),
                zero_emis)
        elseif varname in ["FORM"]
            wrapper_f = (eq) -> ifelse(lev < 2,
                eq / Δz * scale * diurnal_itp(t + t_ref, x) / (g0_100 * delp_dry_surface_itp(x, y)),
                zero_emis)
        elseif varname in ["ISOP"]
            wrapper_f = (eq) -> ifelse(lev < 2,
                eq / Δz * scale * diurnal_itp_ISOP(t + t_ref, x) / (g0_100 * delp_dry_surface_itp(x, y)),
                zero_emis)
        elseif varname in ["NO2", "NO"]
            wrapper_f = (eq) -> ifelse(lev < 2,
                eq / Δz * scale * dayofweek_itp_NOx(t + t_ref, x) * diurnal_itp_NOx(t + t_ref, x) / (g0_100 * delp_dry_surface_itp(x, y)),
                zero_emis)
        else
            wrapper_f = (eq) -> ifelse(lev < 2, eq / Δz * scale / (g0_100 * delp_dry_surface_itp(x, y)), zero_emis)
        end

        eq, param = create_interp_equation(itp, "", t, t_ref, [x, y];
            wrapper_f = wrapper_f)
        push!(eqs, eq)
        push!(params, param)
        push!(vars, eq.lhs)
    end
    sys = System(
        eqs,
        t,
        vars,
        [x; y; lev; Δz; params];
        name = name,
        metadata = Dict(CoupleType => NEI2016MonthlyEmisCoupler,
            SysDiscreteEvent => create_updater_sys_event(name, params, starttime))
    )
    return sys
end

