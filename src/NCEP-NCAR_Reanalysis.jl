
export NCEPNCARReanalysis

struct NCEPNCARReanalysisFileSet <: EarthSciData.FileSet
    mirror::AbstractString
    domain::Any
    ds::Dict{Symbol, NCDataset}
    freq_info::DataFrequencyInfo
    function NCEPNCARReanalysisFileSet(mirror, domain)
        starttime, endtime = get_tspan_datetime(domain)
        years = year(starttime):year(endtime)
        vars = ["air", "hgt", "omega", "uwnd", "vwnd"]
        surf_vars = ["hgt_sfc"]
        filepaths = String[]
        fs_temp = new(
            mirror,
            domain,
            Dict{Symbol, NCDataset}(),
            DataFrequencyInfo(starttime, Day(1), DateTime[])
        )

        for v in vars, y in years

            time = DateTime(y, 1, 1)
            rel = relpath(fs_temp, time, v)
            fullpath = startswith(mirror, "file://") ?
                       replace(string(mirror, rel), "file://" => "") :
                       maybedownload(fs_temp, time, v)
            push!(filepaths, fullpath)
        end

        for v in surf_vars
            rel = relpath(fs_temp, starttime, v)
            fullpath = startswith(mirror, "file://") ?
                       replace(string(mirror, rel), "file://" => "") :
                       maybedownload(fs_temp, starttime, v)
            push!(filepaths, fullpath)
        end

        if Sys.iswindows()
            filepaths = replace.(filepaths, r"^/([A-Z]):" => s"\1:")
        end

        isempty(filepaths) && error("No valid NetCDF files found.")

        lock(nclock) do
            datasets = Dict{Symbol, NCDataset}()

            for f in filepaths
                parts = split(basename(f), '.')
                varname = ("sfc" in parts) ? Symbol(parts[1] * "_sfc") : Symbol(parts[1])
                datasets[Symbol(varname)] = NCDataset(f)
            end

            first_ds = datasets[:air]
            hrs = first_ds["time"][:]
            dt = hrs[2] - hrs[1]
            dt_hours = Dates.value(dt) / (1000 * 3600)
            freq = Hour(round(Int, dt_hours))
            file_start = hrs[1]
            dfi = DataFrequencyInfo(file_start, freq, hrs)

            return new(mirror, domain, datasets, dfi)
        end
    end
end

function var_name(varname::AbstractString)
    occursin("_sfc", varname) ? split(varname, "_")[1] : varname
end

function relpath(::NCEPNCARReanalysisFileSet, time::DateTime, var::AbstractString)
    if occursin("sfc", var)
        base = split(var, "_")[1]
        return "surface/$(base).sfc.nc"
    else
        return "pressure/$(var).$(year(time)).nc"
    end
end

DataFrequencyInfo(fs::NCEPNCARReanalysisFileSet)::DataFrequencyInfo = fs.freq_info

function loadslice!(data::AbstractArray, fs::NCEPNCARReanalysisFileSet, t::DateTime,
        varname::String)
    ds = fs.ds[Symbol(varname)]
    vraw = ds[var_name(varname)]
    dims = NCDatasets.dimnames(vraw)

    t_index = 1
    if "time" in dims && !occursin("_sfc", varname)
        time_vec = DateTime.(ds["time"][:])
        tidx = findfirst(==(t), time_vec)
        @assert tidx!==nothing "Time $t not found in $varname"
        t_index = tidx
    end

    idx = [d == "time" ? t_index : Colon() for d in dims]
    slice = vraw[idx...]
    copyto!(data, slice)

    latvals = fs.ds[Symbol(varname)]["lat"][:]
    if latvals[1] > latvals[end]
        data .= reverse(data, dims = 2)
    end

    s, _ = to_unit(vraw.attrib["units"])
    s ≠ 1 && (data .*= s)

    return nothing
end

function EarthSciData.loadmetadata(fs::NCEPNCARReanalysisFileSet, varname)::MetaData
    lock(nclock) do
        timedim = "time"
        var_ds = fs.ds[Symbol(varname)]
        var = var_ds[var_name(varname)]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)

        unit_str = var.attrib["units"]
        description = var.attrib["long_name"]

        xdim = findfirst(x -> occursin("lon", x), dims)
        ydim = findfirst(x -> occursin("lat", x), dims)
        zdim = findfirst(x -> occursin("level", x), dims)
        zdim = isnothing(zdim) ? -1 : zdim

        @assert xdim>0 "Longitude (x) dimension not found."
        @assert ydim>0 "Latitude (y) dimension not found."

        prj = "+proj=longlat +datum=WGS84 +no_defs"

        coords = []
        vardim_sizes = size(var)
        for (i, d) in enumerate(dims)
            if d == "level"
                push!(coords, 1:vardim_sizes[i])
            elseif d in keys(var_ds)
                vals = Float64.(var_ds[d][:])
                if occursin("lon", d) || occursin("lat", d)
                    vals = deg2rad.(vals)
                end
                push!(coords, vals)
            else
                push!(coords, 1.0:vardim_sizes[i])
            end
        end

        if coords[ydim][1] > coords[ydim][end]
            reverse!(coords[ydim])
        end

        staggering = ncepncarstaggering(varname)

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

function varnames(fs::NCEPNCARReanalysisFileSet)
    return collect(keys(fs.ds))
end

function get_geometry(::NCEPNCARReanalysisFileSet, m::MetaData)
    # Coordinates are stored in radians; convert to degrees for the native longlat CRS.
    lon = rad2deg.(m.coords[m.xdim])
    lat = rad2deg.(m.coords[m.ydim])
    # Compute cell edges from cell centers.
    dlon = (lon[2] - lon[1]) / 2
    dlat = (lat[2] - lat[1]) / 2
    lon_edges = [lon[1] - dlon; [lon[i] + dlon for i in 1:length(lon)]]
    lat_edges = [lat[1] - dlat; [lat[j] + dlat for j in 1:length(lat)]]
    nx, ny = length(lon), length(lat)
    polys = Vector{Vector{NTuple{2, Float64}}}(undef, nx * ny)
    for j in 1:ny, i in 1:nx
        polys[(j - 1) * nx + i] = [
            (lon_edges[i], lat_edges[j]),
            (lon_edges[i + 1], lat_edges[j]),
            (lon_edges[i + 1], lat_edges[j + 1]),
            (lon_edges[i], lat_edges[j + 1]),
            (lon_edges[i], lat_edges[j]),
        ]
    end
    return polys
end

function Base.close(fs::NCEPNCARReanalysisFileSet)
    lock(nclock) do
        for ds in values(fs.ds)
            close(ds)
        end
    end
end

struct NCEPNCARReanalysisCoupler
    sys::Any
end

function NCEPNCARReanalysis(
        mirror::String,
        domaininfo::DomainInfo;
        name = :NCEPNCARReanalysis,
        stream = true,
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = NCEPNCARReanalysisFileSet(mirror, domaininfo)

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
    coord_map = Dict(:lon => xdim, :lat => ydim, :level => :lev)

    z_params = Dict()
    for varname in varnames(fs)
        dt = eltype(domaininfo)
        itp = DataSetInterpolator{dt}(
            fs,
            String(varname),
            starttime,
            endtime,
            domaininfo;
            stream = stream,
            # Use zero extrapolation for vertical velocity to avoid mass transport
            # through the ground.
            extrapolate_type = varname == :omega ? 0.0 : Flat()
        )
        dims = dimnames(itp)
        coords = Num[]
        for dim in dims
            d = Symbol(dim)
            translated_dim = get(coord_map, d, d)
            @assert translated_dim ∈ keys(pvdict) "Dimension $d (translated to $translated_dim) is not in the domaininfo coordinates ($(pvs))."
            push!(coords, pvdict[translated_dim])
        end
        eq, discretes, constants, info = create_interp_equation(
            itp, "", t, t_ref, coords)
        push!(eqs, eq)
        append!(all_discretes, discretes)
        append!(all_constants, constants)
        push!(interp_infos, info)
        push!(lhs_vars, eq.lhs)

        if varname == :hgt
            z_params["hgt"] = info
            z_params["hgt_coords"] = coords
        end
    end

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
    end

    if :lev in keys(pvdict)
        @variables p(t) [unit = u"Pa", description = "Pressure at level"]
        @constants hPa2Pa=100.0 [unit = u"Pa", description = "Conversion from hPa to Pa"]

        p_expr = p ~ hPa2Pa * build_pressure_expr(pvdict[:lev])
        push!(eqs, p_expr)
        push!(lhs_vars, p)
    end

    @constants Rd=287.05 [unit = u"J/(kg*K)"]
    @constants g=9.80665 [unit = u"m/s^2"]
    @variables wwnd(t) [unit = u"m/s", description = "Vertical wind velocity"]
    T = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :air, eqs)].rhs
    omega = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :omega, eqs)].rhs
    p_val = hPa2Pa * build_pressure_expr(pvdict[:lev])
    w_expr = wwnd ~ -omega / (p_val / (Rd * T) * g)
    push!(eqs, w_expr)
    push!(lhs_vars, wwnd)

    if haskey(z_params, "hgt")
        @variables δzδlev(t) [
            unit = u"m",
            description = "Height derivative with respect to vertical level"
        ]
        hgt_info = z_params["hgt"]
        hgtc = z_params["hgt_coords"]

        Δhgt = build_interp_expr(hgt_info, t + t_ref, [hgtc[1], hgtc[2], hgtc[3] + 1]) -
               build_interp_expr(hgt_info, t + t_ref, hgtc)

        lev_trans = δzδlev ~ Δhgt
        push!(eqs, lev_trans)
        push!(lhs_vars, δzδlev)
    end

    all_params = [
        pvdict[xdim], pvdict[ydim], pvdict[:lev],
        (:lat in keys(pvdict) ? [lat2meters, lon2m] : [])...,
        hPa2Pa, Rd, g,
        all_constants..., all_discretes..., params...
    ]
    sys = System(
        eqs,
        t,
        lhs_vars,
        all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        discrete_events = [build_interp_event(interp_infos, starttime)],
        metadata = Dict(CoupleType => NCEPNCARReanalysisCoupler,
            SysDomainInfo => domaininfo)
    )
    return sys
end

function couple2(mw::EarthSciMLBase.MeanWindCoupler, w::NCEPNCARReanalysisCoupler)
    mw, w = mw.sys, w.sys
    _couple_meanwind(mw, w, w.uwnd, w.vwnd, w.wwnd)
end

function build_pressure_expr(lev)
    return (
        1.7137337776322714e-07 * lev^12 - 2.0305117688120587e-05 * lev^11 +
        1.0673735408761183e-03 * lev^10 - 3.2792021944090553e-02 * lev^9 +
        6.5283701951376538e-01 * lev^8 - 8.8255983921036876e+00 * lev^7 +
        8.2545784326593719e+01 * lev^6 - 5.3402339274572921e+02 * lev^5 +
        2.3490038846206135e+03 * lev^4 - 6.7673771816438984e+03 * lev^3 +
        1.1922907152559059e+04 * lev^2 - 1.1382718486210386e+04 * lev +
        5.3378676414996389e+03
    )
end

# Return grid staggering for the given variable,
# true for edge-aligned and false for center-aligned.
# It should always be a triple of booleans for the
# x, y, and z dimensions, respectively, regardless
# of the dimensions of the variable.
function ncepncarstaggering(varname)::NTuple{3, Bool}
    if varname == "uwnd"
        return (true, false, false)
    elseif varname == "vwnd"
        return (false, true, false)
    elseif varname == "omega"
        return (false, false, true)
    end
    return (false, false, false)
end
