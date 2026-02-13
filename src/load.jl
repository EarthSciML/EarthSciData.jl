export interp!

function download_cache()
    ("EARTHSCIDATADIR" ∈ keys(ENV)) ? ENV["EARTHSCIDATADIR"] :
    @get_scratch!("earthsci_data")
end

"""
An interface for types describing a dataset, potentially comprised of multiple files.

To satisfy this interface, a type must implement the following methods:

  - `relpath(fs::FileSet, t::DateTime)`
  - `url(fs::FileSet, t::DateTime)`
  - `localpath(fs::FileSet, t::DateTime)`
  - `DataFrequencyInfo(fs::FileSet)::DataFrequencyInfo`
  - `loadmetadata(fs::FileSet, varname)::MetaData`
  - `loadslice!(cache::AbstractArray, fs::FileSet, t::DateTime, varname)`
  - `varnames(fs::FileSet)`
"""
abstract type FileSet end

"""
$(SIGNATURES)

Return the URL for the file for the given `DateTime`.
"""
url(fs::FileSet, t::DateTime) = join([fs.mirror, relpath(fs, t)], "/")

"""
$(SIGNATURES)

Return the local path for the file for the given `DateTime`.
"""
function localpath(fs::FileSet, t::DateTime)
    file = relpath(fs, t)
    file = replace(file, ':' => '_')
    joinpath(download_cache(), replace(fs.mirror, "://" => "_"), file)
end

"""
$(SIGNATURES)

Check if the specified file exists locally. If not, download it.
"""
function maybedownload(fs::FileSet, t::DateTime)
    p = localpath(fs, t)
    if isfile(p)
        return p
    end
    if !isdir(dirname(p))
        @info "Creating directory $(dirname(p))"
        mkpath(dirname(p))
    end
    u = url(fs, t)
    try
        prog = Progress(100; desc = "Downloading $(basename(u)):", dt = 0.1)
        Downloads.download(u, p,
            progress = (
                total::Integer, now::Integer) -> begin
                prog.n = total
                ProgressMeter.update!(prog, now)
            end
        )
    catch e # Delete partially downloaded file if an error occurs.
        rm(p, force = true)
        rethrow(e)
    end
    return p
end

"""
Information about a data array.

$(FIELDS)
"""
struct MetaData
    "The locations associated with each data point in the array."
    coords::Vector{Vector{Float64}}
    "Physical units of the data, e.g. m s⁻¹."
    unit_str::AbstractString
    "Description of the data."
    description::AbstractString
    "Dimensions of the data, e.g. (lat, lon, layer)."
    dimnames::AbstractVector
    "Dimension sizes of the data, e.g. (180, 360, 30)."
    varsize::AbstractVector
    "The spatial reference system of the data, e.g. \"+proj=longlat +datum=WGS84 +no_defs\" for lat-lon data."
    native_sr::AbstractString
    "The index number of the x-dimension (e.g. longitude)"
    xdim::Int
    "The index number of the y-dimension (e.g. latitude)"
    ydim::Int
    "The index number of the z-dimension (e.g. vertical level)"
    zdim::Int
    "Grid staggering for each dimension. (true=edge-aligned, false=center-aligned)"
    staggering::NTuple{3, Bool}
end

"""
Information about the temporal frequency of archived data.

$(FIELDS)
"""
struct DataFrequencyInfo
    "Beginning of time of the time series."
    start::DateTime
    "Interval between each record."
    frequency::Union{Dates.Period, Dates.CompoundPeriod}
    "Time representing the temporal center of each record."
    centerpoints::AbstractVector
end

"""
Return the time endpoints corresponding to each centerpoint
"""
function endpoints(t::DataFrequencyInfo)
    [(cp - t.frequency / 2, cp + t.frequency / 2) for cp in t.centerpoints]
end

"""
Return the index of the centerpoint closest to the given time.
"""
function centerpoint_index(t_info::DataFrequencyInfo, t::DateTime)
    cpts = t_info.centerpoints
    if t < cpts[begin] || t > cpts[end]
        throw(
            ArgumentError(
            "Time $t is outside the range of the data range ($(cpts[begin]), $(cpts[end])).",
        ),
        )
    end
    diffs = diff(cpts)
    middles = (cpts[1], (cpts[i] + diffs[i] / 2 for i in 1:(length(cpts) - 1))...)
    findlast((x) -> x <= t, middles)
end

"""
$(SIGNATURES)

DataSetInterpolators are used to interpolate data from a `FileSet` to represent a given time and location.
Data is loaded (and downloaded) lazily, so the first time you use it on a for a given
dataset and time period it may take a while to load. Each time step is downloaded and loaded as it is needed
during the simulation and cached on the hard drive at the path specified by the `\\\$EARTHSCIDATADIR`
environment variable, or in a scratch directory if that environment variable has not been specified.
The interpolator will also cache data in memory representing the
data records for the times immediately before and after the current time step.

`varname` is the name of the variable to interpolate. `default_time` is the time to use when initializing
the interpolator. `spatial_ref` is the spatial reference system that the simulation will be using.
`stream` specifies whether the data should be streamed in as needed or loaded all at once.
"""
mutable struct DataSetInterpolator{To, N, N2, FT, ITPT, DomT}
    fs::FileSet
    varname::AbstractString
    # This is the actual data.
    data::Array{To, N}
    # This is buffer that is used to interpolate from.
    interp_cache::Array{To, N}
    itp::ITPT # The interpolator.
    # The buffer that the data is read into from the file.
    # It is separate from `data` so that we can load it asynchronously.
    load_cache::Array{To, N2}
    metadata::MetaData
    domain::DomT
    times::Vector{DateTime}
    currenttime::DateTime
    coord_trans::FT
    loadtask::Task
    lock::ReentrantLock
    initialized::Bool

    function DataSetInterpolator{To}(fs::FileSet, varname::AbstractString,
            starttime::DateTime, endtime::DateTime, domain::DomainInfo;
            stream = true) where {To <: Real}
        metadata = loadmetadata(fs, varname)

        # Check how many time indices we will need.
        dfi = DataFrequencyInfo(fs)
        cache_size = 2
        if !stream
            cache_size = sum(
                (starttime - dfi.frequency) .<=
                dfi.centerpoints .<=
                (endtime + dfi.frequency),
            )
        end

        load_cache = zeros(To, repeat([1], length(metadata.varsize))...)
        data = zeros(To, repeat([2], length(metadata.varsize))..., cache_size) # Add a dimension for time.
        interp_cache = similar(data)
        N = ndims(data)
        N2 = N - 1
        times = [DateTime(0, 1, 1) + Hour(i) for i in 1:cache_size]
        _,
        itp2 = create_interpolator!(
            interp_cache,
            data,
            repeat([0:0.1:0.1], length(metadata.varsize)),
            times
        )
        ITPT = typeof(itp2)

        if domain.spatial_ref == metadata.native_sr
            coord_trans = (x) -> x # No transformation needed.
        else
            t = Proj.Transformation(
                "+proj=pipeline +step " *
                domain.spatial_ref *
                " +step " *
                metadata.native_sr,
            )
            coord_trans = (locs) -> begin
                x, y = t(locs[metadata.xdim], locs[metadata.ydim])
                replace_in_tuple(locs, metadata.xdim, x, metadata.ydim, y)
            end
        end
        FT = typeof(coord_trans)

        td = Threads.@spawn (() -> DateTime(0, 1, 10))() # Placeholder for async loading task.
        itp = new{To, N, N2, FT, ITPT, typeof(domain)}(
            fs,
            varname,
            data,
            interp_cache,
            itp2,
            load_cache,
            metadata,
            domain,
            times,
            DateTime(1, 1, 1),
            coord_trans,
            td,
            ReentrantLock(),
            false
        )
        itp
    end
end

function replace_in_tuple(t::NTuple{N, T1}, index1::Int, v1::T2,
        index2::Int, v2::T2) where {T1, T2, N}
    ntuple(i -> i == index1 ? T1(v1) : i == index2 ? T1(v2) : t[i], N)
end
function tuple_from_vals(index1::Int, v1::T, index2::Int, v2::T) where {T}
    ntuple(
        i -> i == index1 ? v1 : i == index2 ? v2 : throw(ArgumentError("missing index")),
        2
    )
end
function tuple_from_vals(index1::Int, v1::T, index2::Int, v2::T,
        index3::Int, v3::T) where {T}
    ntuple(
        i -> i == index1 ? v1 :
             i == index2 ? v2 : i == index3 ? v3 : throw(ArgumentError("missing index")),
        3
    )
end

function Base.show(io::IO, itp::DataSetInterpolator)
    print(io, "DataSetInterpolator{$(typeof(itp.fs)), $(itp.varname)}")
end

"""
Return the units of the data.
"""
ModelingToolkit.get_unit(itp::DataSetInterpolator) = units(itp)

"""
Convert a vector of evenly spaced grid points to a range.
The `reltol` parameter specifies the relative tolerance for the grid spacing,
which is necessary to account for different numbers of days in each month
and things like that.
"""
function knots2range(knots, reltol = 0.05)
    dx = diff(knots)
    dx_mean = sum(dx) / length(dx)
    @assert all(abs.(1 .- dx ./ dx_mean) .<= reltol) "Knots ($knots) must be evenly spaced within reltol=$reltol."
    dx = (knots[end] - knots[begin]) / (length(knots) - 1)
    # Need to do weird range creation to avoid rounding errors.
    return knots[begin]:dx:(knots[begin] + dx * (length(knots) - 1))
end

"""
Create a new interpolator, overwriting `interp_cache`.
"""
function create_interpolator!(interp_cache, data, coords, times)
    grid = tuple(coords..., knots2range(datetime2unix.(times)))
    copyto!(interp_cache, data)
    itp = interpolate!(interp_cache, BSpline(Linear()))
    itp = scale(itp, grid)
    return grid, itp
end

function update_interpolator!(itp::DataSetInterpolator{To}) where {To}
    if size(itp.interp_cache) != size(itp.data)
        itp.interp_cache = similar(itp.data)
    end
    coords = _model_grid(itp)
    grid, itp2 = create_interpolator!(itp.interp_cache, itp.data, coords, itp.times)
    @assert all([length(g) for g in grid] .== size(itp.data)) "invalid data size: $([length(g) for g in grid]) != $(size(itp.data))"
    itp.itp = itp2
end

"""
Return the next interpolation time point for this interpolator.
"""
function nexttimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[min(length(ti.centerpoints), ci + 1)]
end

"""
Return the previous interpolation time point for this interpolator.
"""
function prevtimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[max(1, ci - 1)]
end

"""
Return the current interpolation time point for this interpolator.
"""
function currenttimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[ci]
end

"""
Load the time points that should be cached in this interpolator.
"""
function interp_cache_times!(itp::DataSetInterpolator, t::DateTime)
    cache_size = length(itp.times)
    dfi = DataFrequencyInfo(itp.fs)
    ti = centerpoint_index(dfi, t)
    # Currently assuming we're going forwards in time.
    if t < dfi.centerpoints[ti]  # Load data starting with previous time step.
        times = dfi.centerpoints[(ti - 1):(ti + cache_size - 2)]
    else  # Load data starting with previous time step.
        times = dfi.centerpoints[ti:(ti + cache_size - 1)]
    end
    times
end

"""
The time points when integration should be stopped to update the interpolator
(as Unix timestamps).
"""
function get_tstops(itp::DataSetInterpolator, starttime::DateTime)
    dfi = DataFrequencyInfo(itp.fs)
    datetime2unix.(sort([starttime, dfi.centerpoints...]))
end

# Get the model grid for this interpolator.
function _model_grid(itp::DataSetInterpolator)
    grid = EarthSciMLBase.grid(itp.domain, itp.metadata.staggering)
    if length(itp.metadata.varsize) == 2 && itp.metadata.zdim <= 0
        grid_size = tuple_from_vals(itp.metadata.xdim, grid[1], itp.metadata.ydim, grid[2])
    elseif length(itp.metadata.varsize) == 3
        grid_size = tuple_from_vals(
            itp.metadata.xdim,
            grid[1],
            itp.metadata.ydim,
            grid[2],
            itp.metadata.zdim,
            grid[3]
        )
    else
        error("Invalid data size")
    end
end

function initialize!(itp::DataSetInterpolator, t::DateTime)
    itp.load_cache = zeros(eltype(itp.load_cache), itp.metadata.varsize...)
    grid_size = length.(_model_grid(itp))
    itp.data = zeros(eltype(itp.data), grid_size..., size(itp.data, length(size(itp.data)))) # Add a dimension for time.
    itp.initialized = true
end

function load_data_for_time!(itp::DataSetInterpolator, t::DateTime)
    loadslice!(itp.load_cache, itp.fs, t, itp.varname)
    return t
end

function update!(itp::DataSetInterpolator, t::DateTime)
    @assert itp.initialized "Interpolator has not been initialized"
    times = interp_cache_times!(itp, t) # Figure out which times we need.

    # Figure out the overlap between the times we have and the times we need.
    times_in_cache = intersect(times, itp.times)
    idxs_in_cache = [findfirst(x -> x == times_in_cache[i], itp.times)
                     for i in eachindex(times_in_cache)]
    idxs_in_times = [findfirst(x -> x == times_in_cache[i], times)
                     for i in eachindex(times_in_cache)]
    idxs_not_in_times = setdiff(eachindex(times), idxs_in_times)

    # Move data we already have to where it should be.
    N = ndims(itp.data)
    if all(idxs_in_cache .> idxs_in_times) && all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(idxs_in_times, idxs_in_cache)
            selectdim(itp.data, N, new) .= selectdim(itp.data, N, old)
        end
    elseif all(idxs_in_cache .< idxs_in_times) &&
           all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(reverse(idxs_in_times), reverse(idxs_in_cache))
            selectdim(itp.data, N, new) .= selectdim(itp.data, N, old)
        end
    elseif !all(idxs_in_cache .== idxs_in_times)
        error(
            "Unexpected time ordering, can't reorder indexes $(idxs_in_times) to $(idxs_in_cache)",
        )
    end

    model_grid = EarthSciMLBase.grid(itp.domain, itp.metadata.staggering)
    # Load the additional times we need
    for idx in idxs_not_in_times
        d = selectdim(itp.data, N, idx)
        if fetch(itp.loadtask) != times[idx] # Check if correct time is already loaded.
            load_data_for_time!(itp, times[idx]) # Load data if not already loaded.
        end
        interpolate_from!(itp, d, itp.load_cache, model_grid) # Copy results to correct location
        # Start loading the next time point asynchronously.
        itp.loadtask = Threads.@spawn load_data_for_time!(
            itp, nexttimepoint(itp, times[idx]))
    end
    itp.times = times
    itp.currenttime = t
    @assert issorted(itp.times) "Interpolator times are in wrong order"
    update_interpolator!(itp)
end

function interpolate_from!(dsi::DataSetInterpolator, dst::AbstractArray{T, N},
        src::AbstractArray{T, N}, model_grid, extrapolate_type = Flat()) where {T, N}
    data_grid = Tuple(knots2range.(dsi.metadata.coords))
    dsi.metadata.xdim, dsi.metadata.ydim
    itp = interpolate!(src, BSpline(Linear()))
    itp = extrapolate(scale(itp, data_grid), extrapolate_type)
    if N == 3
        for (i, x) in enumerate(model_grid[1])
            for (j, y) in enumerate(model_grid[2])
                for (k, z) in enumerate(model_grid[3])
                    idx = tuple_from_vals(dsi.metadata.xdim, i,
                        dsi.metadata.ydim, j, dsi.metadata.zdim, k)
                    locs = tuple_from_vals(dsi.metadata.xdim, x,
                        dsi.metadata.ydim, y, dsi.metadata.zdim, z)
                    locs = dsi.coord_trans(locs)
                    dst[idx...] = itp(locs...)
                end
            end
        end
    elseif N == 2 && dsi.metadata.zdim <= 0
        for (i, x) in enumerate(model_grid[1])
            for (j, y) in enumerate(model_grid[2])
                idx = tuple_from_vals(dsi.metadata.xdim, i, dsi.metadata.ydim, j)
                locs = tuple_from_vals(dsi.metadata.xdim, x, dsi.metadata.ydim, y)
                locs = dsi.coord_trans(locs)
                dst[idx...] = itp(locs...)
            end
        end
    else
        error("Invalid dimension configuration")
    end
    dst
end

function lazyload!(itp::DataSetInterpolator, t::DateTime)
    lock(itp.lock) do
        if itp.currenttime == t
            return
        end
        if !itp.initialized # Initialize new interpolator.
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
function lazyload!(itp::DataSetInterpolator, t::AbstractFloat)
    lazyload!(itp, Dates.unix2datetime(t))
end

"""
$(SIGNATURES)

Return the dimension names associated with this interpolator.
"""
dimnames(itp::DataSetInterpolator) = itp.metadata.dimnames

"""
$(SIGNATURES)

Return the units of the data associated with this interpolator.
"""
units(itp::DataSetInterpolator) = to_unit(itp.metadata.unit_str)[2]

"""
$(SIGNATURES)

Return the description of the data associated with this interpolator.
"""
description(itp::DataSetInterpolator) = itp.metadata.description

"""
$(SIGNATURES)

Return the value of the given variable from the given dataset at the given time and location.
"""
function interp!(
        itp::DataSetInterpolator{T, N, N2},
        t::DateTime,
        locs::Vararg{T, N2}
)::T where {T, N, N2}
    lazyload!(itp, t)
    interp_unsafe(itp, t, locs...)
end

"""
Interpolate without checking if the data has been correctly loaded for the given time.
"""
@generated function interp_unsafe(
        itp::DataSetInterpolator{T1, N, N2},
        t::DateTime,
        locs::Vararg{T2, N2}
) where {T1, T2, N, N2}
    if N2 == N - 1 # Number of locs has to be one less than the number of data dimensions so we can add the time in.
        quote
            #locs = itp.coord_trans(locs)
            try
                itp.itp(locs..., datetime2unix(t))
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

mutable struct ITPWrapper{ITP}
    itp::ITP
    ITPWrapper(itp::ITP) where {ITP} = new{ITP}(itp)
end

(itp::ITPWrapper)(t, locs::Vararg{T, N}) where {T, N} = interp_unsafe(itp.itp, t, locs...)

"""
Interpolation with a unix timestamp.
"""
function interp!(itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    interp!(itp, Dates.unix2datetime(t), locs...)
end
function interp_unsafe(
        itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    interp_unsafe(itp, Dates.unix2datetime(t), locs...)
end

# Dummy functions for unit validation. Basically ModelingToolkit
# will call the function with a DynamicQuantities.Quantity or an integer to
# get information about the type and units of the output.
interp!(itp::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = itp
interp_unsafe(itp::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = itp

# Symbolic tracing, for different numbers of dimensions (up to three dimensions).
@register_symbolic interp!(itp::DataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic interp!(itp::DataSetInterpolator, t, loc1, loc2) false
@register_symbolic interp!(itp::DataSetInterpolator, t, loc1) false
@register_symbolic interp_unsafe(itp::DataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic interp_unsafe(itp::DataSetInterpolator, t, loc1, loc2) false
@register_symbolic interp_unsafe(itp::DataSetInterpolator, t, loc1) false

"""
$(SIGNATURES)

Create an equation that interpolates the given dataset at the given time and location.
`filename` is an identifier for the dataset, and `t` is the time variable.
`wrapper_f` can specify a function to wrap the interpolated value, for example `eq -> eq / 2`
to divide the interpolated value by 2.
"""
function create_interp_equation(itp::DataSetInterpolator, filename, t, t_ref, coords;
        wrapper_f = v -> v)
    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") :
        Symbol("$(itp.varname)")
    n_p = Symbol(n, "_itp")

    itp = ITPWrapper(itp)
    t_itp = typeof(itp)
    p_itp = only(
        @parameters ($n_p::t_itp)(..)=itp [
        unit = units(itp.itp),
        description = "Interpolated $(n)"
    ]
    )

    # Create right hand side of equation.
    rhs = wrapper_f(p_itp(t_ref + t, coords...))

    # Create left hand side of equation.
    desc = description(itp.itp)
    uu = ModelingToolkit.get_unit(rhs)
    lhs = only(
        @variables $n(t) [
        unit = uu,
        description = desc,
        misc = Dict(:staggering => itp.itp.metadata.staggering)
    ]
    )

    eq = lhs ~ rhs

    return eq, p_itp
end

# In MTK v11, parameter defaults set via `@parameters x = val` are stored as
# metadata on the symbolic variable but are NOT included in `initial_conditions(sys)`.
# This function extracts ITPWrapper defaults from a list of parameters so they
# can be passed to the System constructor via the `initial_conditions` kwarg.
function _itp_defaults(params)
    dflts = Pair[]
    for p in params
        if ModelingToolkit.hasdefault(p) && ModelingToolkit.getdefault(p) isa ITPWrapper
            push!(dflts, p => ModelingToolkit.getdefault(p))
        end
    end
    return dflts
end

# Utility function to get the variables that are needed to solve a
# system.
function needed_vars(sys)
    exprs = [eq.rhs for eq in equations(sys)]
    needed_eqs = vcat(equations(sys),
        observed(sys)[ModelingToolkit.observed_equations_used_by(sys, exprs)])
    needed_vars = unique(vcat(get_variables.(needed_eqs)...))
    EarthSciMLBase.var2symbol.(needed_vars)
end

# Create a "system event" (https://base.earthsci.dev/dev/system_events/)
# to update the interpolators associated with the given parameters.
function create_updater_sys_event(name, params, starttime::DateTime)
    pnames = Symbol.((name,), (:₊,), EarthSciMLBase.var2symbol.(params))
    t_ref = datetime2unix(starttime)
    function sys_event(sys::ModelingToolkit.AbstractSystem)
        needed = needed_vars(sys)
        psyms = []
        params_to_update = []
        for p in parameters(sys) # Figure out which parameters need to be updated.
            psym = EarthSciMLBase.var2symbol(p)
            if (psym in pnames) && (psym in needed) && ModelingToolkit.hasdefault(p) && ModelingToolkit.getdefault(p) isa ITPWrapper
                push!(psyms, psym)
                push!(params_to_update, p)
            end
        end
        params_to_update = NamedTuple{Tuple(psyms)}(params_to_update)
        all_tstops = []
        for p_itp in params_to_update
            itp = ModelingToolkit.getdefault(p_itp).itp
            push!(all_tstops, get_tstops(itp, starttime)...)
        end
        all_tstops = unique(all_tstops) .- t_ref
        function update_itps!(modified, observed, ctx, integ)
            function loadf(p_itp)
                p_itp.itp = lazyload!(p_itp.itp, integ.t + t_ref)
                return p_itp
            end
            NamedTuple((k => loadf(v) for (k, v) in pairs(modified)))
        end
        if length(params_to_update) == 0
            return nothing
        end
        all_tstops => (update_itps!, params_to_update, NamedTuple())
    end
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(split(string(typeof(itp.fs)), ".")[end]).$(itp.varname)"
end

function _get_staggering(var)
    misc = getmisc(var)
    @assert :staggering in keys(misc) "Staggering is not specified for variable $(var)."
    return misc[:staggering]
end
