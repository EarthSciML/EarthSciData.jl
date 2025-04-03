
export WRF

struct WRFFileSet <: EarthSciData.FileSet
    mirror::AbstractString
    domain
    ds
    freq_info::DataFrequencyInfo
    function WRFFileSet(domain)
        WRFFileSet("https://data.rda.ucar.edu/d340000/", domain)
    end
    function WRFFileSet(mirror, domain)
        starttime, endtime = get_tspan_datetime(domain)
        check_times = collect((starttime-Hour(1)):Hour(1):(endtime+Hour(1)))
        filepaths = String[]
        fs_temp = new(mirror, domain, nothing,
            DataFrequencyInfo(starttime, Day(1), check_times))
        filepaths = maybedownload.((fs_temp,), check_times)

        if isempty(filepaths)
            throw(ErrorException("No valid files downloaded for the specified range."))
        end

        lock(nclock) do
            ds = NCDataset(filepaths, aggdim="time")
            sdt = ds.attrib["START_DATE"]
            sd, st = split(sdt, '_')
            dt = ds.attrib["DT"]
            file_start = DateTime(sd * " " * st, dateformat"yyyy-mm-dd HH:MM:SS")
            frequency = Second(dt)
            times = ds["time"][:]
            dfi = DataFrequencyInfo(file_start, frequency, times)

            return new(mirror, domain, ds, dfi)
        end
    end
end

function relpath(::WRFFileSet, time::DateTime)
    y = Dates.year(time)
    m = @sprintf("%02d", Dates.month(time))
    d = @sprintf("%02d", Dates.day(time))
    hour = Dates.format(floor(time, Hour), "HH:MM:SS")
    string("$y$m/", "wrfout_hourly_d01_", "$y-$m-$d", "_", hour, ".nc")
end

DataFrequencyInfo(fs::WRFFileSet)::DataFrequencyInfo = fs.freq_info

function loadslice!(data::AbstractArray, fs::WRFFileSet, t::DateTime, varname)
    lock(nclock) do
        var = loadslice!(data, fs, fs.ds, t, varname, "time")

        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
    end
    nothing
end

function loadmetadata(fs::WRFFileSet, varname)::MetaData
    lock(nclock) do
        timedim = "time"
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        _, unit_quantity = to_unit(var.attrib["units"])
        description = var.attrib["description"]

        xdim = findfirst(x -> occursin("west_east", x), dims)
        ydim = findfirst(x -> occursin("south_north", x), dims)
        @assert xdim > 0 "WRF x dimension not found"
        @assert ydim > 0 "WRF y dimension not found"

        # Find the z dimension; set to -1 if not found
        zdim = findfirst((x) -> occursin("bottom_top", x), dims)
        zdim = isnothing(zdim) ? findfirst((x) -> occursin("emissions_zdim", x), dims) : zdim
        zdim = isnothing(zdim) ? -1 : zdim

        @assert fs.ds.attrib["MAP_PROJ"] == 1 "Only Lambert Conformal Conic projection is currently supported for WRF data."
        truelat1 = fs.ds.attrib["TRUELAT1"]
        truelat2 = fs.ds.attrib["TRUELAT2"]
        moad_cen_lat = fs.ds.attrib["MOAD_CEN_LAT"]
        stand_lon = fs.ds.attrib["STAND_LON"]
        prj = "+proj=lcc +lat_1=$(truelat1) +lat_2=$(truelat2) +lat_0=$(moad_cen_lat) +lon_0=$(stand_lon) +x_0=0 +y_0=0 +a=6370000 +b=6370000 +to_meter=1"
        @assert moad_cen_lat ≈ fs.ds.attrib["CEN_LAT"] "CEN_LAT must match MOAD_CEN_LAT"
        @assert stand_lon ≈ fs.ds.attrib["CEN_LON"] "CEN_LON must match STAND_LON"

        coords = []
        for d in dims
            if haskey(fs.ds, d)
                push!(coords, Float64.(fs.ds[d][:]))
            elseif occursin("west_east", d)
                nx = fs.ds.dim[d]
                dx = fs.ds.attrib["DX"]
                offset = 0.0 # This would be nonzero if cen_lon != stand_lon
                start = -(nx - 1) / 2.0 * dx + offset
                coord = start:dx:(start+(nx-1)*dx)
                push!(coords, coord)
            elseif occursin("south_north", d)
                ny = fs.ds.dim[d]
                dy = fs.ds.attrib["DY"]
                offset = 0.0 # This would be nonzero if cen_lat != moad_cen_lat
                start = -(ny - 1) / 2.0 * dy + offset
                coord = start:dy:(start+(ny-1)*dy)
                push!(coords, coord)
            else
                push!(coords, 1.0:fs.ds.dim[d])
            end
        end

        staggering = wrf_staggering(dims, xdim, ydim, zdim)

        return MetaData(coords, unit_quantity, description, dims, varsize, prj,
            xdim, ydim, zdim, staggering)
    end
end

function varnames(fs::WRFFileSet)
    lock(nclock) do
        exclude_vars = Set(keys(fs.ds.dim)) ∪ Set(["XLAT", "XLONG", "XLAT_U", "XLAT_V",
            "XLONG_U", "XLONG_V", "Times"])
        return [name for name in keys(fs.ds) if name ∉ exclude_vars]
    end
end

struct WRFCoupler
    sys
end

function WRF(domaininfo::DomainInfo; name=:WRF, stream=true)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = WRFFileSet("https://data.rda.ucar.edu/d340000/", domaininfo)

    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)

    eqs = Equation[]
    params = []
    events = []
    vars = Num[]

    xdim = :x in keys(pvdict) ? :x : :lon
    ydim = :y in keys(pvdict) ? :y : :lat
    coord_map = Dict(
        :bottom_top => :lev,
        :bottom_top_stag => :lev,
        :emissions_zdim => :lev,  # For emissions vertical dimension
        :west_east => xdim,
        :west_east_stag => xdim,
        :south_north => ydim,
        :south_north_stag => ydim,
    )

    z_params = Dict()
    for varname ∈ varnames(fs)
        dt = EarthSciMLBase.dtype(domaininfo)
        itp = DataSetInterpolator{dt}(fs, varname, starttime, endtime,
            domaininfo; stream=stream)
        dims = dimnames(itp)
        coords = Num[]
        for dim in dims
            d = Symbol(dim)
            translated_dim = get(coord_map, d, d)
            @assert translated_dim ∈ keys(pvdict) "Dimension $d (translated to $translated_dim) is not in the domaininfo coordinates ($(pvs))."
            push!(coords, pvdict[translated_dim])
        end
        eq, event, param = create_interp_equation(itp, "", t, starttime, coords)
        push!(eqs, eq)
        push!(events, event)
        push!(params, param)
        push!(vars, eq.lhs)
        if varname ∈ ["PH", "PHB"]
            # Special handling for PH and PHB to calculate the total pressure
            # as they are needed for geopotential height calculation.
            z_params[varname] = param
            z_params[varname*"_coords"] = coords
        end
    end

    # Total Pressure
    @variables P_total(t) [unit = u"Pa", description = "Total pressure"]
    P = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :P, eqs)].rhs
    PB = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :PB, eqs)].rhs
    pressure_eq = P_total ~ P + PB
    push!(eqs, pressure_eq)
    push!(vars, P_total)

    # Horizontal coordinate transforms
    if :lat in keys(pvdict)
        @variables δxδlon(t) [unit = u"m/rad", description = "X gradient with respect to longitude"]
        @variables δyδlat(t) [unit = u"m/rad", description = "Y gradient with respect to latitude"]
        @constants lat2meters = 111.32e3 * 180 / π [unit = u"m/rad"]
        @constants lon2m = 40075.0e3 / 2π [unit = u"m/rad"]
        lon_trans = δxδlon ~ lon2m * cos(pvdict[:lat])
        lat_trans = δyδlat ~ lat2meters
        push!(eqs, lon_trans, lat_trans)
        push!(vars, δxδlon, δyδlat)
    end

    # Layer height
    @variables z(t) [unit = u"m", description = "Geopotential height"]
    PH = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :PH, eqs)].rhs
    PHB = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :PHB, eqs)].rhs
    @constants g = 9.80665 [unit = u"m/s^2", description = "Acceleration due to gravity"]
    z_expr = (PH + PHB) / g
    push!(eqs, z ~ z_expr)
    push!(vars, z)

    # Height per level
    @variables δzδlev(t) [unit = u"m", description = "Height derivative with respect to vertical level"]
    ph = z_params["PH"]
    phb = z_params["PHB"]
    phc = z_params["PH_coords"]
    phbc = z_params["PHB_coords"]
    Δph = ph(t, phc[1], phc[2], phc[3] + 1) - ph(t, phc...)
    Δphb = phb(t, phbc[1], phbc[2], phbc[3] + 1) - phb(t, phbc...)
    lev_trans = δzδlev ~ (Δph + Δphb) / g
    push!(eqs, lev_trans)
    push!(vars, δzδlev)

    sys = ODESystem(eqs, t, vars,
        [pvdict[xdim], pvdict[ydim], pvdict[:lev], params...];
        name=name,
        metadata=Dict(
            :coupletype => WRFCoupler,
        ),
        discrete_events=events
    )
    return sys
end

function couple2(mw::EarthSciMLBase.MeanWindCoupler, w::WRFCoupler)
    mw, w = mw.sys, w.sys
    eqs = []
    push!(eqs, mw.v_lon ~ w.hourly₊U)
    length(unknowns(mw)) > 1 ? push!(eqs, mw.v_lat ~ w.hourly₊V) : nothing
    length(unknowns(mw)) > 2 ? push!(eqs, mw.v_lev ~ w.hourly₊W) : nothing
    ConnectorSystem(
        eqs,
        mw, w,
    )
end

# Return grid staggering for the given variable,
# true for edge-aligned and false for center-aligned.
# It should always be a triple of booleans for the
# x, y, and z dimensions, respectively, regardless
# of the dimensions of the variable.
function wrf_staggering(dims, xdim, ydim, zdim)::NTuple{3,Bool}
    if zdim < 1
        return (
            occursin("_stag", dims[xdim]),
            occursin("_stag", dims[ydim]),
            false
        )
    end
    return (
        occursin("_stag", dims[xdim]),
        occursin("_stag", dims[ydim]),
        occursin("_stag", dims[zdim])
    )
end
