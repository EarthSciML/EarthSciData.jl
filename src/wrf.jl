
export WRF, partialderivatives_δlevδz, WRFCoupler, ITPWrapper_w

const BASE_DIR = joinpath(homedir(), "WRF_Data")

if !isdir(BASE_DIR)
    mkpath(BASE_DIR)
    println("Created base directory: $BASE_DIR")
end

function get_tspan_datetime(domaininfo::DomainInfo)
    starttime = nothing
    endtime = nothing
    try
        const_ic = domaininfo.icbc[1]
        time_domain = const_ic.indepdomain.domain

        starttime = Dates.unix2datetime(minimum(time_domain))
        endtime   = Dates.unix2datetime(maximum(time_domain))
    catch
        println("Warning: Temporal information missing. Using default times.")
        starttime = DateTime(2023, 8, 15, 0, 0, 0)
        endtime   = DateTime(2023, 8, 15, 2, 59, 59)
    end
    return starttime, endtime
end

function download_wrf_data(url::String, save_dir::String = BASE_DIR)
    function download_with_wget(url::String, save_path::String)
        try
            run(`wget --quiet -O $save_path $url`)
            println("Download completed successfully: $save_path")
        catch e
            println("Error during download: $(e)")
        end
    end

    year, month = basename(url)[19:22], basename(url)[24:25]
    save_dir = joinpath(save_dir, year, month)
    mkpath(save_dir)
    safe_basename = replace(basename(url), ":" => "_")
    filename = joinpath(save_dir, safe_basename)
    if isfile(filename)
        println("File already exists: $filename. Skipping download.")
        return filename
    end
    println("Downloading $url to $filename")
    download_with_wget(url, filename)
    return filename
end

struct WRFFileSet <: EarthSciData.FileSet
    mirror::AbstractString
    domain
    filetype
    ds
    freq_info::DataFrequencyInfo
    function WRFFileSet(domain, filetype, starttime, endtime)
        WRFFileSet("https://data.rda.ucar.edu/d340000/", domain, filetype,
            starttime, endtime)
    end
    function WRFFileSet(mirror, domain, filetype, starttime, endtime)
        check_times = collect((starttime - Hour(1)):Hour(1):(endtime + Hour(1)))
        filepaths = String[]
        fs_temp = new(mirror, domain, filetype, nothing,
            DataFrequencyInfo(starttime, Day(1), check_times))
        for time in check_times
            y = Dates.year(time)
            m = @sprintf("%02d", Dates.month(time))
            d = @sprintf("%02d", Dates.day(time))
            hour = Dates.format(floor(time, Hour), "HH:MM:SS")
            url = string(mirror, "$y$m/", "wrfout_hourly_d01_", "$y-$m-$d", "_", hour, ".nc")
            filepath = download_wrf_data(url)
            if filepath != ""
                push!(filepaths, filepath)
            end
        end
    
        if isempty(filepaths)
            throw(ErrorException("No valid files downloaded for the specified range."))
        end

        lock(nclock) do
            ds = NCDataset(filepaths, aggdim="time")            
            sdt = ds.attrib["START_DATE"]
            sd, st = split(sdt, '_')
            dt = ds.attrib["DT"]
            file_start = DateTime(sd * " " * st, dateformat"yyyy-mm-dd HH:MM:SS")
            frequency = Second(dt);
            times = ds["time"][:]
            dfi = DataFrequencyInfo(file_start, frequency, times)

            return new(mirror, domain, filetype, ds, dfi)
        end
    end

end

DataFrequencyInfo(fs::WRFFileSet)::DataFrequencyInfo = fs.freq_info

function loadslice_w!(data::AbstractArray, fs::WRFFileSet, t::DateTime, varname)
    lock(nclock) do
        var = loadslice_w!(data, fs, fs.ds, t, varname, "time")

        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale
        end
    end
    nothing
end

function loadslice_w!(data::AbstractArray{T}, fs::WRFFileSet, ds::Union{NCDataset,NCDatasets.MFDataset},
    t::DateTime, varname::AbstractString, timedim::AbstractString) where {T<:Number}
    var = ds[varname]
    dims = collect(NCDatasets.dimnames(var))
    @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
    time_index = findfirst(isequal(timedim), dims)
    slices = repeat(Any[:], length(dims))
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs), t)

    varsize = deleteat!(collect(size(var)), time_index)
    rightsize = (varsize == collect(size(data)))

    vartype = only(setdiff(Base.uniontypes(eltype(var)), [Missing]))
    righttype = (vartype == T)
    if rightsize && righttype
        data .= var[slices...]
    elseif rightsize && !righttype
        data .= vartype.(var[slices...])
    else
        ArgumentError("Data array is not the correct size for variable $varname.")
    end
    var
    

end

function loadmetadata_w(fs::WRFFileSet, varname)::Union{MetaData, Nothing}
    lock(nclock) do
        var = fs.ds[varname]
        dims = NCDatasets.dimnames(var)
        if length(dims) < 4
            return nothing
        end
        
        if haskey(var.attrib, "coordinates")
            coord_names = String.(split(var.attrib["coordinates"]))
            if "XTIME" ∉ coord_names
                println("Skipping variable $varname: Dimension 'time' not found.")
                return nothing
            end
            
        else
            println("Skipping variable $varname: No 'coordinates' attribute found.")
            return nothing
        end
        
        time_index = findfirst(isequal("XTIME"), coord_names)
        coord_names = deleteat!(coord_names, time_index)
        varsize = deleteat!(collect(size(var)), time_index)


        zdim_index = findfirst((x) -> occursin("bottom_top", x), dimnames(var))
        if zdim_index !== nothing
            zdim_name = dimnames(var)[zdim_index]
            if zdim_name ∉ coord_names
                push!(coord_names, zdim_name)
            end
        end

        emissions_zdim_index = findfirst((x) -> occursin("emissions_zdim", x), dimnames(var))
        if emissions_zdim_index !== nothing
            emissions_zdim_name = dimnames(var)[emissions_zdim_index]
            if emissions_zdim_name ∉ coord_names
                push!(coord_names, emissions_zdim_name)
            end
        end


        scalar, unit_quantity = to_unit(var.attrib["units"])
        
        description = var.attrib["description"]
        
        scale_factor = get(var.attrib, "scale_factor", 1.0)
        
        coords = []
        for d in coord_names
            if haskey(fs.ds, d)
                push!(coords, Float64.(fs.ds[d][:]))
            else
                dim_index = findfirst(isequal(d), dimnames(var))
                push!(coords, collect(1:size(var, dim_index)))
            end
        end

        xdim = findfirst((x) -> occursin("XLONG", x), coord_names)
        
        ydim = findfirst((x) -> occursin("XLAT", x), coord_names)
        

        zdim_index = findfirst((x) -> occursin("bottom_top", x), dimnames(var))
        

        varsize = deleteat!(collect(size(var)), time_index+1)

        @assert xdim > 0 "WRF `lon` dimension not found"
        @assert ydim > 0 "WRF `lat` dimension not found"
        
        coords[xdim] .= deg2rad.(coords[xdim])
        coords[ydim] .= deg2rad.(coords[ydim])

        # This projection will assume the inputs are radians when used within
        # a Proj pipeline: https://proj.org/en/9.3/operations/pipeline.html
        prj = "+proj=longlat +datum=WGS84 +no_defs"
        return MetaData(coords, unit_quantity, description, coord_names, varsize, prj, xdim, ydim)
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

function create_interpolator_w!(To, interp_cache, data, metadata::MetaData, times)
    
    longitude = collect(range(first(metadata.coords[metadata.xdim]), stop=last(metadata.coords[metadata.xdim]), length=size(data, 1)))
    latitude = collect(range(first(metadata.coords[metadata.ydim]), stop=last(metadata.coords[metadata.ydim]), length=size(data, 2)))
    
    if length(times) > 1
        time_step = datetime2unix(times[2]) - datetime2unix(times[1])
        time_range = range(datetime2unix(times[1]), stop=datetime2unix(times[end]), step=time_step)
    else
        time_range = range(datetime2unix(times[1]), stop=datetime2unix(times[1]), length=1)
    end

    vertical_levels = range(1, stop=size(data, 3), length=size(data, 3))

    copyto!(interp_cache, data)
    axes_tuple = (longitude, latitude, vertical_levels, time_range)
    itp = interpolate(axes_tuple, interp_cache, Gridded(Linear()))

    return axes_tuple, itp
end

mutable struct DataSetInterpolator_w{To,N,N2,FT,ITPT}
    fs::WRFFileSet
    varname::AbstractString
    data::Array{To,N}
    interp_cache::Array{To,N}
    itp::ITPT
    load_cache::Array{To,N2}
    metadata::MetaData
    times::Vector{DateTime}
    currenttime::DateTime
    coord_trans::FT
    loadrequest::Channel{DateTime}
    loadresult::Channel
    copyfinish::Channel{Int}
    lock::ReentrantLock
    initialized::Bool

    function DataSetInterpolator_w{To}(fs::WRFFileSet, varname::AbstractString,
        starttime::DateTime, endtime::DateTime, spatial_ref; stream=true) where {To<:Real}
        metadata = loadmetadata_w(fs, varname)
        dfi = DataFrequencyInfo(fs)
        cache_size = 2
        if !stream
            cache_size = sum((starttime - dfi.frequency) .<= dfi.centerpoints .<= (endtime + dfi.frequency))
        end

        load_cache = zeros(To, metadata.varsize...)
        data = zeros(To, metadata.varsize..., cache_size)
        interp_cache = similar(data)
        N = ndims(data)
        N2 = N - 1
        times = collect(dfi.centerpoints[1:cache_size])

        _, itp2 = create_interpolator_w!(To, interp_cache, data, metadata, times)
        ITPT = typeof(itp2)

        if spatial_ref == metadata.native_sr
            coord_trans = (x) -> x
        else
            t = Proj.Transformation("+proj=pipeline +step " * spatial_ref * " +step " * metadata.native_sr)
            coord_trans = (locs) -> begin
                x, y = t(locs[metadata.xdim], locs[metadata.ydim])
                replace_in_tuple(locs, metadata.xdim, To(x), metadata.ydim, To(y))
            end
        end
        FT = typeof(coord_trans)

        itp = new{To,N,N2,FT,ITPT}(fs, varname, data, interp_cache, itp2, load_cache,
            metadata, times, DateTime(1, 1, 1), coord_trans,
            Channel{DateTime}(0), Channel(1), Channel{Int}(0),
            ReentrantLock(), false)
        itp
    end
end

dimnames(itp::DataSetInterpolator_w) = itp.metadata.dimnames

units(itp::DataSetInterpolator_w) = itp.metadata.units

description(itp::DataSetInterpolator_w) = itp.metadata.description

mutable struct ITPWrapper_w{ITP}
    itp::ITP
    ITPWrapper_w(itp::ITP) where ITP = new{ITP}(itp)
end

(itp::ITPWrapper_w)(t, locs::Vararg{T,N}) where {T,N} = begin
    result = interp_unsafe_w(itp.itp, t, locs...)
    return result
end

function interp_unsafe_w(itp::DataSetInterpolator_w, t::Real, locs::Vararg{T,N})::T where {T,N}
    interp_unsafe_w(itp, Dates.unix2datetime(t), locs...)
end

@generated function interp_unsafe_w(itp::DataSetInterpolator_w{T,N,N2}, t::DateTime, locs::Vararg{T,N2})::T where {T,N,N2}

    if N2 == N - 1 # Number of locs has to be one less than the number of data dimensions so we can add the time in.
        quote
            locs = itp.coord_trans(locs)
            try
                result = itp.itp(locs..., datetime2unix(t))
                
            catch err
                # FIXME(CT): This is needed because ModelingToolkit sometimes
                # calls the interpolator for the beginning of the simulation time period,
                # and we don't have a way to update for that proactively.
                @warn "Interpolation for $(itp.varname) failed at t=$(t), locs=$(locs); trying to update interpolator."

                lazyload!(itp, t)
                
                itp.itp(locs..., datetime2unix(t))
            end
        end
    else
        throw(ArgumentError("N2 must be equal to N-1"))
    end
end

@register_symbolic interp_unsafe_w(itp::DataSetInterpolator_w, t, loc1, loc2, loc3)
@register_symbolic interp_unsafe_w(itp::DataSetInterpolator_w, t, loc1, loc2) false
@register_symbolic interp_unsafe_w(itp::DataSetInterpolator_w, t, loc1) false

function get_tstops(itp::DataSetInterpolator_w, starttime::DateTime)
    dfi = DataFrequencyInfo(itp.fs)
    datetime2unix.(sort([starttime, dfi.centerpoints...]))
end

function create_interp_equation_w(itp::DataSetInterpolator_w, filename, t, starttime, coords;
    wrapper_f=v -> v)
    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") : Symbol("$(itp.varname)")
    n_p = Symbol(n, "_itp")

    itp = ITPWrapper_w(itp)
    t_itp = typeof(itp)
    p_itp = only(@parameters ($n_p::t_itp)(..) = itp [unit = units(itp.itp),
        description = "Interpolated $(n)"])

    # Create right hand side of equation.
    rhs = wrapper_f(p_itp(t, coords...))
    # Create left hand side of equation.
    desc = description(itp.itp)
    uu = ModelingToolkit.get_unit(rhs)
    lhs = only(@variables $n(t) [unit = uu, description = desc])

    eq = lhs ~ rhs
    event = get_tstops(itp.itp, starttime) => (update_affect!, [], [p_itp], [], itp.itp)
    return eq, event, p_itp
end

function WRF(domain::AbstractString, domaininfo::DomainInfo; name=:WRF, stream=true, kwargs...)
    coord_defaults = get(kwargs, :coord_defaults, Dict())
    dtype = get(kwargs, :dtype, Float64)
    cache_size = get(kwargs, :cache_size, 0)
    starttime, endtime = get_tspan_datetime(domaininfo)

    lon = coord_defaults[:lon]
    lat = coord_defaults[:lat]
    lev = coord_defaults[:lev]
    time = coord_defaults[:time]

    lon_bounds = (-2.2659069376520424, -1.1200319443750113)
    lat_bounds = (0.4136259352284578, 0.9026160669338227)

    coord_defaults[:lon] = lon_bounds
    coord_defaults[:lat] = lat_bounds

    lon_interval = Interval(lon_bounds...)
    lat_interval = Interval(lat_bounds...)
    lev_interval = Interval(extrema(lev)...)

    time_interval = Interval(datetime2unix(starttime), datetime2unix(endtime))

    lon = only(@parameters lon [unit = u"rad", description = "Longitude"])
    lat = only(@parameters lat [unit = u"rad", description = "Latitude"])
    lev = only(@parameters lev [unit = u"1", description = "Vertical Level"])

    boundaries = [
        lon ∈ lon_interval,
        lat ∈ lat_interval,
        lev ∈ lev_interval,
        t ∈ time_interval
    ]

    ic = constIC(0.0u"s", t ∈ time_interval)
    bcs = constBC(0.0u"s", boundaries...)

    domaininfo = EarthSciMLBase.DomainInfo(ic, bcs; dtype=dtype)

    return WRF_2(domain, domaininfo; name=name, stream=stream, coord_defaults=coord_defaults,
               lon=lon, lat=lat, lev=lev)
end

function WRF_2(domain::AbstractString, domaininfo::DomainInfo; name=:WRF, stream=true,
    coord_defaults=Dict(), lon, lat, lev)
    starttime, endtime = get_tspan_datetime(domaininfo)
    wrf_fileset = WRFFileSet("https://data.rda.ucar.edu/d340000/", domain, "hourly", starttime, endtime)
    filesets = Dict{String, WRFFileSet}(
        "hourly" => wrf_fileset
    )
    pvdict = Dict(
        :lon => lon,
        :lat => lat,
        :lev => lev,
        :t => t,
        :lon_stag => lon,
        :lat_stag => lat,
        :lev_stag => lev,
        :emissions_zdim => lev
    )
    
    eqs = Equation[]
    params = []
    events = []
    vars = Num[]

    wrf_to_domain_mapping = Dict(
        :XLONG => :lon,
        :XLAT => :lat,
        :XLONG_U => :lon_stag,
        :XLAT_V => :lat_stag,
        :XLONG_V => :lon_stag,
        :XLAT_U => :lat_stag,
        :bottom_top => :lev,
        :bottom_top_stag => :lev_stag,
        :t => :t,
        :emissions_zdim => :emissions_zdim,
        :west_east => :lon,
        :south_north => :lat,
        :west_east_stag => :lon_stag,
        :south_north_stag => :lat_stag
    )
    
    metadata = nothing
    for (filename, fs) in filesets
        for varname ∈ varnames(fs)
            if varname == "Times"
                println("Skipping variable: $varname")
                continue
            end
            try
                metadata = loadmetadata_w(fs, varname)
                
        
                if metadata === nothing
                    continue
                end
            catch e
                println("Error loading metadata for $varname: ", e)
                continue
            end
            dt = EarthSciMLBase.dtype(domaininfo)
            itp = DataSetInterpolator_w{dt}(fs, varname, starttime, endtime,
            domaininfo.spatial_ref; stream=stream)
            dims = itp.metadata.dimnames
            coords = Num[]
            for dim in dims
                d = Symbol(dim)
                translated_dim = get(wrf_to_domain_mapping, d, d)
                if !(translated_dim ∈ keys(pvdict))
                    println("Dimension $d (translated to $translated_dim) is not in the domaininfo coordinates. Ignoring and continuing...")
                    continue
                end
                push!(coords, pvdict[translated_dim])
            end
            
            if any(x -> string(x) == string(lev), coords)
                eq, event, param = create_interp_equation_w(itp, filename, t, starttime, coords)
                push!(eqs, eq)
                push!(events, event)
                push!(params, param)
                push!(vars, eq.lhs)
            else
            end
        end
    end

    @variables P_total(t) [unit = u"Pa", description = "Total pressure"]
    @variables hourly₊P_itp(t) [unit = u"Pa", description = "Interpolated perturbation pressure"]
    @variables hourly₊PB_itp(t) [unit = u"Pa", description = "Interpolated base state pressure"]

    pressure_eq = P_total ~ hourly₊P_itp + hourly₊PB_itp
    push!(vars, hourly₊P_itp, hourly₊PB_itp)
    push!(eqs, pressure_eq)
    push!(vars, P_total)

    @variables δxδlon(t) [unit = u"m/rad", description = "X gradient with respect to longitude"]
    @variables δyδlat(t) [unit = u"m/rad", description = "Y gradient with respect to latitude"]
    @constants lat2meters = 111.32e3 * 180 / π [unit = u"m/rad"]
    @constants lon2m = 40075.0e3 / 2π [unit = u"m/rad"]
    lon_trans = δxδlon ~ lon2m * cos(pvdict[:lat])
    lat_trans = δyδlat ~ lat2meters
    push!(eqs, lon_trans, lat_trans)
    push!(vars, δxδlon, δyδlat)

    @variables δPδlev(t) [unit = u"Pa", description = "Pressure gradient with respect to vertical level"]
    
    sys = ODESystem(
        eqs, 
        t, 
        vars, 
        [pvdict[:lon], pvdict[:lat], pvdict[:lev], params...]; 
        name=name,
        metadata=Dict(
            :coupletype => WRFCoupler,
            :coord_defaults => coord_defaults
        ),
        discrete_events=events
    )
            
    return sys, (lon=lon, lat=lat, lev=lev)
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

function partialderivatives_δlevδz(wrf)
    coord_defaults = wrf.metadata[:coord_defaults]
    lon_val = coord_defaults[:lon]
    lat_val = coord_defaults[:lat]
    time_val = datetime2unix(coord_defaults[:time])

    param_symbols = Symbolics.tosymbol.(wrf.ps)
    idx_ph  = findfirst(x -> occursin("hourly₊PH_itp",  string(x)), param_symbols)
    idx_phb = findfirst(x -> occursin("hourly₊PHB_itp", string(x)), param_symbols)
    if idx_ph === nothing || idx_phb === nothing
        error("Could not find PH or PHB interpolators in the WRF system parameters.")
    end

    ph_itp_param  = wrf.ps[idx_ph]
    phb_itp_param = wrf.ps[idx_phb]

    function PH_total_numeric(levx)
        if typeof(levx) <: Symbolics.BasicSymbolic
            try
                levx_numeric = ph_itp_param(time_val, lon_val, lat_val, coord_defaults[:lev])
                @info "Dynamic lev value retrieved: $levx_numeric"
            catch e
                println("Error retrieving dynamic lev: ", e)
                throw(e)
            end
        else
            levx_numeric = levx
        end
    
        try
            ph_val  = ph_itp_param(time_val, lon_val, lat_val, levx_numeric)
            phb_val = phb_itp_param(time_val, lon_val, lat_val, levx_numeric)
            return ph_val + phb_val
        catch e
            println("Error in PH_total_numeric: ", e)
            throw(e)
        end
    end
    
    return (pvars::AbstractVector) -> begin
        levindex = EarthSciMLBase.matching_suffix_idx(pvars, :lev)
        if isempty(levindex)
            error("No `lev` parameter found in `pvars`. Cannot calculate derivative.")
        end

        lev = pvars[only(levindex)]

        try
            delta_level = 1.0
            PH_top = PH_total_numeric(lev + delta_level)
            PH_bot = PH_total_numeric(lev)
            delta_z = (PH_top - PH_bot) / 9.81
            δlev_δz = delta_level / delta_z

            return Dict(only(levindex) => δlev_δz)
        catch e
            println("Error in calculating δlev_δz: ", e)
            return Dict()
        end
    end
end

function interp_cache_times!(itp::DataSetInterpolator_w, t::DateTime)
    cache_size = length(itp.times)
    dfi = DataFrequencyInfo(itp.fs)
    ti = centerpoint_index(dfi, t)
    # Currently assuming we're going forwards in time.
    if t < dfi.centerpoints[ti]  # Load data starting with previous time step.
        times = dfi.centerpoints[(ti-1):(ti+cache_size-2)]
    else  # Load data starting with previous time step.
        times = dfi.centerpoints[ti:(ti+cache_size-1)]
    end
    times
end

function update_interpolator!(itp::DataSetInterpolator_w{To}) where {To}
    if size(itp.interp_cache) != size(itp.data)
        itp.interp_cache = similar(itp.data)
    end
    domain_tuple, itp2 = create_interpolator_w!(To, itp.interp_cache, itp.data, itp.metadata, itp.times)

    itp.itp = itp2
end

" Return the next interpolation time point for this interpolator. "
function nexttimepoint(itp::DataSetInterpolator_w, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[min(length(ti.centerpoints), ci + 1)]
end

function async_loader(itp::DataSetInterpolator_w)
    tt = DateTime(0, 1, 10)
    for t ∈ itp.loadrequest
        if t != tt
            try
                loadslice_w!(itp.load_cache, itp.fs, t, itp.varname)
                tt = t
            catch err
                @error err
                put!(itp.loadresult, err)
                rethrow(err)
            end
        end
        put!(itp.loadresult, 0) # Let the requestor know that we've finished.
        # Anticipate what the next request is going to be for and load that data.
        take!(itp.copyfinish)
        try
            tt = nexttimepoint(itp, tt)

            loadslice_w!(itp.load_cache, itp.fs, tt, itp.varname)
        catch err
            @error err
            rethrow(err)
        end
    end
end

function initialize!(itp::DataSetInterpolator_w{To,N,N2,FT,ITPT}, t::DateTime) where {To,N,N2,FT,ITPT}
    itp.load_cache = zeros(eltype(itp.load_cache), itp.metadata.varsize...)
    itp.data = zeros(eltype(itp.data),
                     itp.metadata.varsize...,
                     size(itp.data, ndims(itp.data)))  # Add a dimension for time.
    Threads.@spawn async_loader(itp)
    itp.initialized = true
end

function update!(itp::DataSetInterpolator_w, t::DateTime)
    @assert itp.initialized "Interpolator has not been initialized"
    times = interp_cache_times!(itp, t) # Figure out which times we need.
    # Figure out the overlap between the times we have and the times we need.
    times_in_cache = intersect(times, itp.times)
    idxs_in_cache = [findfirst(x -> x == times_in_cache[i], itp.times) for i in eachindex(times_in_cache)]
    idxs_in_times = [findfirst(x -> x == times_in_cache[i], times) for i in eachindex(times_in_cache)]
    idxs_not_in_times = setdiff(eachindex(times), idxs_in_times)

    # Move data we already have to where it should be.
    N = ndims(itp.data)
    if all(idxs_in_cache .> idxs_in_times) && all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(idxs_in_times, idxs_in_cache)
            selectdim(itp.data, N, new) .= selectdim(itp.data, N, old)
        end
    elseif all(idxs_in_cache .< idxs_in_times) && all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(reverse(idxs_in_times), reverse(idxs_in_cache))
            selectdim(itp.data, N, new) .= selectdim(itp.data, N, old)
        end
    elseif !all(idxs_in_cache .== idxs_in_times)
        error("Unexpected time ordering, can't reorder indexes $(idxs_in_times) to $(idxs_in_cache)")
    end

    itp.times = times
    # Load the additional times we need
    for idx in 1:2
        t_needed = times[idx]
        d = selectdim(itp.data, N, idx)
        put!(itp.loadrequest, t_needed)
        r = take!(itp.loadresult) # Wait for results
        if r != 0
            throw(r)
        end
        d .= itp.load_cache # Copy results to correct location
        put!(itp.copyfinish, 0) # Let the loader know we've finished copying
    end
    itp.times = times
    itp.currenttime = t
    @assert issorted(itp.times) "Interpolator times are in wrong order"
    update_interpolator!(itp)
end

function lazyload!(itp::DataSetInterpolator_w{To,N,N2,FT,ITPT}, t::DateTime) where {To,N,N2,FT,ITPT}
    lock(itp.lock) do
        if itp.currenttime == t
            return
        end
        if !itp.initialized
            initialize!(itp, t)
            update!(itp, t)
            return
        end
        if t < itp.times[begin] || t >= itp.times[end]
            update!(itp, t)
        end
    end
    itp
end

lazyload!(itp::DataSetInterpolator_w{To,N,N2,FT,ITPT}, t::AbstractFloat) where {To,N,N2,FT,ITPT} =
    lazyload!(itp, Dates.unix2datetime(t))
