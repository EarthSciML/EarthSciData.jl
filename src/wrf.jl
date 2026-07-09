export WRF

struct WRFFileSet <: EarthSciData.FileSet
    mirror::AbstractString
    domain::Any
    ds::Any
    freq_info::DataFrequencyInfo
    function WRFFileSet(domain)
        WRFFileSet("https://data.rda.ucar.edu/d340000/", domain)
    end
    function WRFFileSet(mirror, domain)
        starttime, endtime = get_tspan_datetime(domain)
        check_times = collect((starttime - Hour(1)):Hour(1):(endtime + Hour(1)))
        filepaths = String[]
        fs_temp = new(
            mirror, domain, nothing, DataFrequencyInfo(starttime, Day(1), check_times))
        filepaths = maybedownload.((fs_temp,), check_times)

        if isempty(filepaths)
            throw(ErrorException("No valid files downloaded for the specified range."))
        end

        lock(nclock) do
            ds = NCDataset(filepaths, aggdim = "time")
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

function WRFFileSet(::Val{:local}, filepath::AbstractString, domain)
    isfile(filepath) ||
        throw(ArgumentError("Local WRF file not found: $filepath"))

    lock(nclock) do
        ds = NCDataset(filepath)
        times = vec(ds["XTIME"][:])
        file_start = times[1]
        Δt_ms = Dates.value(times[2] - times[1])
        frequency = Second(round(Int, Δt_ms / 1000))

        return new(
            filepath,
            domain,
            ds,
            DataFrequencyInfo(file_start, frequency, times),
        )
    end
end

function relpath(::WRFFileSet, time::DateTime)
    y = Dates.year(time)
    m = lpad(month(time), 2, '0')
    d = lpad(day(time), 2, '0')
    hour = Dates.format(floor(time, Hour), "HH:MM:SS")
    string("$y$m/", "wrfout_hourly_d01_", "$y-$m-$d", "_", hour, ".nc")
end

DataFrequencyInfo(fs::WRFFileSet)::DataFrequencyInfo = fs.freq_info


function local_wrf_time_bounds(filepath::AbstractString)
    ds = NCDataset(filepath)
    try
        haskey(ds, "XTIME") ||
            error("Local WRF file has no XTIME variable:\n$filepath")
        xtime = vec(ds["XTIME"][:])
        isempty(xtime) &&
            error("Local WRF file has an empty XTIME variable:\n$filepath")
        return minimum(xtime), maximum(xtime)
    finally
        close(ds)
    end
end

function find_local_wrf_file(
    local_root::AbstractString,
    domain;
    prefix::AbstractString = "wrfout_d04_",
)
    starttime, endtime = get_tspan_datetime(domain)
    isdir(local_root) ||
        error("Local WRF directory does not exist:\n$local_root")
    matches = Tuple{String, DateTime, DateTime}[]
    for (dir, _, filenames) in walkdir(local_root)
        for filename in filenames
            startswith(filename, prefix) || continue
            filepath = joinpath(dir, filename)
            try
                file_start, file_end = local_wrf_time_bounds(filepath)
                if file_start <= starttime && endtime <= file_end
                    push!(matches, (filepath, file_start, file_end))
                end
            catch err
                @warn "Skipping unreadable local WRF candidate" filepath exception = (
                    err,
                    catch_backtrace(),
                )
            end
        end
    end

    isempty(matches) && error(
        "No local WRF file covers the requested simulation period.\n" *
        "Requested start: $starttime\n" *
        "Requested end:   $endtime\n" *
        "Searched under:  $local_root",
    )

    sort!(matches; by = item -> item[2], rev = true)
    return first(matches)[1]
end

function wrf_timedim(fs::WRFFileSet)
    if haskey(fs.ds.dim, "time")
        return "time"
    elseif haskey(fs.ds.dim, "Time")
        return "Time"
    else
        error("WRF dataset has neither a time nor Time dimension.")
    end
end


function loadslice!(data::AbstractArray, fs::WRFFileSet, t::DateTime, varname)
    lock(nclock) do
        var = loadslice!(data, fs, fs.ds, t, varname, wrf_timedim(fs))

        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
    end
    nothing
end

function loadmetadata(fs::WRFFileSet, varname)::MetaData
    lock(nclock) do
        timedim = wrf_timedim(fs)
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        unit_str = var.attrib["units"]
        description = var.attrib["description"]

        xdim = findfirst(x -> occursin("west_east", x), dims)
        ydim = findfirst(x -> occursin("south_north", x), dims)
        @assert xdim>0 "WRF x dimension not found"
        @assert ydim>0 "WRF y dimension not found"

        # Find the z dimension; set to -1 if not found
        zdim = findfirst((x) -> occursin("bottom_top", x), dims)
        zdim = isnothing(zdim) ? findfirst((x) -> occursin("emissions_zdim", x), dims) :
               zdim
        zdim = isnothing(zdim) ? -1 : zdim

        @assert fs.ds.attrib["MAP_PROJ"]==1 "Only Lambert Conformal Conic projection is currently supported for WRF data."
        truelat1 = fs.ds.attrib["TRUELAT1"]
        truelat2 = fs.ds.attrib["TRUELAT2"]
        cen_lat = Float64(fs.ds.attrib["CEN_LAT"])
        cen_lon = Float64(fs.ds.attrib["CEN_LON"])
        prj = "+proj=lcc +lat_1=$(truelat1) +lat_2=$(truelat2) +lat_0=$(cen_lat) +lon_0=$(cen_lon) +x_0=0 +y_0=0 +a=6370000 +b=6370000 +to_meter=1"

        coords = []
        for d in dims
            if haskey(fs.ds, d)
                push!(coords, Float64.(fs.ds[d][:]))
            elseif occursin("west_east", d)
                nx = fs.ds.dim[d]
                dx = fs.ds.attrib["DX"]
                offset = 0.0 # This would be nonzero if cen_lon != stand_lon
                start = -(nx - 1) / 2.0 * dx + offset
                coord = range(start, step = dx, length = nx)
                push!(coords, coord)
            elseif occursin("south_north", d)
                ny = fs.ds.dim[d]
                dy = fs.ds.attrib["DY"]
                offset = 0.0 # This would be nonzero if cen_lat != moad_cen_lat
                start = -(ny - 1) / 2.0 * dy + offset
                coord = range(start, step = dy, length = ny)
                push!(coords, coord)
            else
                push!(coords, 1.0:fs.ds.dim[d])
            end
        end

        staggering = wrf_staggering(var)
        for i in 1:length(coords)
            staggered = staggering[i]
            if staggered && (length(coords[i]) == varsize[i] + 1)
                coords[i] = 0.5 .* (coords[i][1:(end - 1)] .+ coords[i][2:end])
            end
        end

        return MetaData(
            coords,
            unit_str,
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

function varnames(fs::WRFFileSet)
    lock(nclock) do
        exclude_vars = Set(keys(fs.ds.dim)) ∪
                       Set([
            "XLAT", "XLONG", "XLAT_U", "XLAT_V", "XLONG_U", "XLONG_V", "Times", "XTIME"])
        return [name for name in keys(fs.ds) if name ∉ exclude_vars]
    end
end

Base.close(fs::WRFFileSet) =
    lock(nclock) do ;
        close(fs.ds);
    end

struct WRFCoupler
    sys::Any
end

"""
$(SIGNATURES)

A data loader for WRF output data.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.

`spatial_interp = :linear` (default) does full multilinear interpolation; `:nearest` does
spatial nearest-neighbour + time-only linear interpolation for ~8x speedup when queries
are always at grid points.
"""

function WRF(domaininfo::DomainInfo; name = :WRF, stream = true, spatial_interp::Symbol = :linear, 
    filepath = nothing, local_root = nothing, local_prefix = "wrfout_d04_", requested_vars = nothing)
    starttime, endtime = get_tspan_datetime(domaininfo)

    if !isnothing(filepath) && !isnothing(local_root)
        error(
            "Pass either filepath or local_root to WRF(...), not both.",
        )
    end

    fs = if !isnothing(filepath)
        WRFFileSet(
            Val(:local),
            filepath,
            domaininfo,
        )

    elseif !isnothing(local_root)
        selected_filepath = find_local_wrf_file(
            local_root,
            domaininfo;
            prefix = local_prefix,
        )

        WRFFileSet(
            Val(:local),
            selected_filepath,
            domaininfo,
        )

    else
        WRFFileSet(
            "https://data.rda.ucar.edu/d340000/",
            domaininfo,
        )
    end

    selected_varnames = isnothing(requested_vars) ?
                        varnames(fs) :
                        String.(requested_vars)

    required_vars = ["P", "PB", "PH", "PHB"]

    missing_required = setdiff(required_vars, selected_varnames)

    isempty(missing_required) || error(
        "WRF requested_vars must include: " *
        join(missing_required, ", "),
    )

    available_vars = String.(collect(keys(fs.ds.group[:vars])))
    missing_in_file = setdiff(selected_varnames, available_vars)

    isempty(missing_in_file) || error(
        "Requested WRF variables missing from file: " *
        join(missing_in_file, ", "),
    )

    pvs = EarthSciMLBase.pvars(domaininfo)
    pvdict = Dict([Symbol(v) => v for v in pvs]...)

    @parameters t_ref=get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    eqs = Equation[]
    params = Any[t_ref]
    all_discretes = Any[]
    all_constants = Any[]
    interp_infos = []
    lhs_vars = Num[]

    xdim = :x in keys(pvdict) ? :x : :lon
    ydim = :y in keys(pvdict) ? :y : :lat
    coord_map = Dict(
        :bottom_top => :lev,
        :bottom_top_stag => :lev,
        :emissions_zdim => :lev,  # For emissions vertical dimension
        :west_east => xdim,
        :west_east_stag => xdim,
        :south_north => ydim,
        :south_north_stag => ydim
    )

    z_params = Dict()
    for varname in selected_varnames
        dt = eltype(domaininfo)
        itp = DataSetInterpolator{dt}(
            fs,
            varname,
            starttime,
            endtime,
            domaininfo;
            stream = stream,
            # Use zero extrapolation for vertical velocity to avoid mass transport
            # through the ground.
            extrapolate_type = varname == "W" ? 0.0 : Flat()
        )
        dims = dimnames(itp)
        coords = Num[]
        for dim in dims
            d = Symbol(dim)
            translated_dim = get(coord_map, d, d)
            @assert translated_dim ∈ keys(pvdict) "Dimension $d (translated to $translated_dim) is not in the domaininfo coordinates ($(pvs))."
            push!(coords, pvdict[translated_dim])
        end
        eq, discretes,
        constants,
        info = create_interp_equation(
            itp, "", t, t_ref, coords;
            spatial_interp = spatial_interp)
        push!(eqs, eq)
        append!(all_discretes, discretes)
        append!(all_constants, constants)
        push!(interp_infos, info)
        push!(lhs_vars, eq.lhs)
        if varname ∈ ["PH", "PHB"]
            # Special handling for PH and PHB to calculate the total pressure
            # as they are needed for geopotential height calculation.
            z_params[varname] = info
            z_params[varname * "_coords"] = coords
        end
    end

    # Total Pressure
    @variables P_total(t) [unit = u"Pa", description = "Total pressure"]
    P = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :P, eqs)].rhs
    PB = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :PB, eqs)].rhs
    pressure_eq = P_total ~ P + PB
    push!(eqs, pressure_eq)
    push!(lhs_vars, P_total)

    # Horizontal coordinate transforms
    if :lat in keys(pvdict)
        @variables δxδlon(t) [
            unit = u"m/rad",
            description = "X gradient with respect to longitude"
        ]
        @variables δyδlat(t) [
            unit = u"m/rad",
            description = "Y gradient with respect to latitude"
        ]
        @constants lat2meters=111.32e3 * 180 / π [unit = u"m/rad"]
        @constants lon2m=40075.0e3 / 2π [unit = u"m/rad"]
        lon_trans = δxδlon ~ lon2m * cos(pvdict[:lat])
        lat_trans = δyδlat ~ lat2meters
        push!(eqs, lon_trans, lat_trans)
        push!(lhs_vars, δxδlon, δyδlat)
        push!(params, lon2m, lat2meters)
    end

    # Layer height
    @variables z(t) [unit = u"m", description = "Geopotential height"]
    PH = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :PH, eqs)].rhs
    PHB = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :PHB, eqs)].rhs
    @constants g=9.80665 [unit = u"m/s^2", description = "Acceleration due to gravity"]
    z_expr = (PH + PHB) / g
    push!(eqs, z ~ z_expr)
    push!(lhs_vars, z)
    push!(params, g)

    # Height per level
    @variables δzδlev(t) [
        unit = u"m",
        description = "Height derivative with respect to vertical level"
    ]
    ph_info = z_params["PH"]
    phb_info = z_params["PHB"]
    phc = z_params["PH_coords"]
    phbc = z_params["PHB_coords"]
    Δph = build_interp_expr(ph_info, t + t_ref, [phc[1], phc[2], phc[3] + 1]) -
          build_interp_expr(ph_info, t + t_ref, phc)
    Δphb = build_interp_expr(phb_info, t + t_ref, [phbc[1], phbc[2], phbc[3] + 1]) -
           build_interp_expr(phb_info, t + t_ref, phbc)
    lev_trans = δzδlev ~ (Δph + Δphb) / g
    push!(eqs, lev_trans)
    push!(lhs_vars, δzδlev)

    all_params = [pvdict[xdim], pvdict[ydim], pvdict[:lev],
        all_constants..., all_discretes..., params...]
    sys = System(eqs, t, lhs_vars, all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        discrete_events = [build_interp_event(interp_infos, starttime)],
        metadata = Dict(CoupleType => WRFCoupler,
            SysDomainInfo => domaininfo,
            InterpInfos => interp_infos,
            SysDiscreteEvent => make_prune_factory(interp_infos))
    )
    return sys
end

function couple2(mw::EarthSciMLBase.MeanWindCoupler, w::WRFCoupler)
    mw, w = mw.sys, w.sys
    _couple_meanwind(mw, w, w.U, w.V, w.W)
end

# Return grid staggering for the given variable,
# true for edge-aligned and false for center-aligned.
# It should always be a triple of booleans for the
# x, y, and z dimensions, respectively, regardless
# of the dimensions of the variable.
function wrf_staggering(var)::NTuple{3, Bool}
    stag = get(var.attrib, "stagger", "")
    return (occursin("X", stag), occursin("Y", stag), occursin("Z", stag))
end
