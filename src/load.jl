export interp!

download_cache = ("EARTHSCIDATADIR" ∈ keys(ENV)) ? ENV["EARTHSCIDATADIR"] : @get_scratch!("earthsci_data")
function __init__()
    global download_cache = ("EARTHSCIDATADIR" ∈ keys(ENV)) ? ENV["EARTHSCIDATADIR"] : @get_scratch!("earthsci_data")
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
url(fs::FileSet, t::DateTime) = joinpath(fs.mirror, relpath(fs, t))

"""
$(SIGNATURES)

Return the local path for the file for the given `DateTime`.
"""
localpath(fs::FileSet, t::DateTime) = joinpath(download_cache, relpath(fs, t))

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
        prog = Progress(100; desc="Downloading $(basename(u)):", dt=0.1)
        Downloads.download(u, p, progress=(total::Integer, now::Integer) -> begin
            prog.n = total
            ProgressMeter.update!(prog, now)
        end)
    catch e # Delete partially downloaded file if an error occurs.
        rm(p, force=true)
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
    units::DynamicQuantities.AbstractQuantity
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
end

"""
Information about the temporal frequency of archived data.

$(FIELDS)
"""
struct DataFrequencyInfo
    "Beginning of time of the time series."
    start::DateTime
    "Interval between each record."
    frequency::Union{Dates.Period,Dates.CompoundPeriod}
    "Time representing the temporal center of each record."
    centerpoints::AbstractVector
end

"""
Return the time endpoints correcponding to each centerpoint
"""
endpoints(t::DataFrequencyInfo) = [(cp - t.frequency / 2, cp + t.frequency / 2) for cp in t.centerpoints]

"""
Return the index of the centerpoint closest to the given time.
"""
function centerpoint_index(t_info::DataFrequencyInfo, t)
    if t < t_info.centerpoints[begin] || t > t_info.centerpoints[end]
        throw(ArgumentError("Time $t is outside the range of the data range ($(t_info.centerpoints[begin]), $(t_info.centerpoints[end]))."))
    end
    findmin(x->abs(x-t), t_info.centerpoints)[2]
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
mutable struct DataSetInterpolator{To,N,N2,FT,ITPT}
    fs::FileSet
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

    function DataSetInterpolator{To}(fs::FileSet, varname::AbstractString,
        starttime::DateTime, endtime::DateTime, spatial_ref; stream=true) where {To<:Real}
        metadata = loadmetadata(fs, varname)

        # Check how many time indices we will need.
        dfi = DataFrequencyInfo(fs)
        cache_size = 2
        if !stream
            cache_size = sum((starttime-dfi.frequency) .<= dfi.centerpoints .<= (endtime+dfi.frequency))
        end

        load_cache = zeros(To, repeat([1], length(metadata.varsize))...)
        data = zeros(To, repeat([2], length(metadata.varsize))..., cache_size) # Add a dimension for time.
        interp_cache = similar(data)
        N = ndims(data)
        N2 = N - 1
        times = [DateTime(0, 1, 1) + Hour(i) for i ∈ 1:cache_size]
        _, itp2 = create_interpolator!(To, interp_cache, data, metadata, times)
        ITPT = typeof(itp2)

        if spatial_ref == metadata.native_sr
            coord_trans = (x) -> x # No transformation needed.
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

function replace_in_tuple(t::NTuple{N,T}, index1::Int, v1::T, index2::Int, v2::T) where {T,N}
    ntuple(i -> i == index1 ? v1 : i == index2 ? v2 : t[i], N)
end

function Base.show(io::IO, itp::DataSetInterpolator)
    print(io, "DataSetInterpolator{$(typeof(itp.fs)), $(itp.varname)}")
end

""" Return the units of the data. """
ModelingToolkit.get_unit(itp::DataSetInterpolator) = itp.metadata.units

"""
Convert a vector of evenly spaced grid points to a range.
The `reltol` parameter specifies the relative tolerance for the grid spacing,
which is necessary to account for different numbers of days in each month
and things like that.
"""
function knots2range(knots, reltol=0.05)
    dx = diff(knots)
    dx_mean = sum(dx) / length(dx)
    @assert all(abs.(1 .- dx ./ dx_mean) .<= reltol) "Knots ($knots) must be evenly spaced within reltol=$reltol."
    dx = (knots[end] - knots[begin]) / (length(knots) - 1)
    # Need to do weird range creation to avoid rounding errors.
    return knots[begin]:dx:(knots[begin]+dx*(length(knots)-1))
end

"""Create a new interpolator, overwriting `interp_cache`."""
function create_interpolator!(To, interp_cache, data, metadata::MetaData, times)
    # We originally create the interpolator with a small array to avoid
    # unnecessary memory use, so we size the coordinate to match the data size.
    # However, when we're updating the interpolator below me make sure the
    # data size matches the original coordinate size.
    coords = [metadata.coords[i][1:size(data, i)] for i ∈ 1:length(metadata.coords)]

    grid = Tuple(knots2range.([coords..., datetime2unix.(times)]))
    copyto!(interp_cache, data)
    itp = interpolate!(interp_cache, BSpline(Linear()))
    itp = scale(itp, grid)
    return grid, itp
end

function update_interpolator!(itp::DataSetInterpolator{To}) where {To}
    if size(itp.interp_cache) != size(itp.data)
        itp.interp_cache = similar(itp.data)
    end
    grid, itp2 = create_interpolator!(To, itp.interp_cache, itp.data, itp.metadata, itp.times)
    @assert all([length(g) for g in grid] .== size(itp.data)) "invalid data size: $([length(g) for g in grid]) != $(size(itp.data))"
    itp.itp = itp2
end

" Return the next interpolation time point for this interpolator. "
function nexttimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[min(length(ti.centerpoints), ci+1)]
end

" Return the previous interpolation time point for this interpolator. "
function prevtimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[max(1, ci-1)]
end

" Return the current interpolation time point for this interpolator. "
function currenttimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[ci]
end

" Load the time points that should be cached in this interpolator. "
function interp_cache_times!(itp::DataSetInterpolator, t::DateTime)
    cache_size = length(itp.times)
    dfi = DataFrequencyInfo(itp.fs)
    ti = centerpoint_index(dfi, t)
    # Currently assuming we're going forwards in time.
    if t < dfi.centerpoints[ti]  # Load data starting with previous time step.
        return @view dfi.centerpoints[(ti-1):(ti+cache_size-2)]
    else  # Load data starting with previous time step.
        return @view dfi.centerpoints[ti:(ti+cache_size-1)]
    end
end

" Asynchronously load data, anticipating which time will be requested next. "
function async_loader(itp::DataSetInterpolator)
    tt = DateTime(0, 1, 10)
    for t ∈ itp.loadrequest
        if t != tt
            try
                loadslice!(itp.load_cache, itp.fs, t, itp.varname)
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
            loadslice!(itp.load_cache, itp.fs, tt, itp.varname)
        catch err
            @error err
            rethrow(err)
        end
    end
end

function initialize!(itp::DataSetInterpolator, t::DateTime)
    itp.load_cache = zeros(eltype(itp.load_cache), itp.metadata.varsize...)
    itp.data = zeros(eltype(itp.data), itp.metadata.varsize..., size(itp.data, length(size(itp.data)))) # Add a dimension for time.
    Threads.@spawn async_loader(itp)
    itp.initialized = true
end

function update!(itp::DataSetInterpolator, t::DateTime)
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

    # Load the additional times we need
    for idx in idxs_not_in_times
        d = selectdim(itp.data, N, idx)
        put!(itp.loadrequest, times[idx]) # Request next data
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
        if t <= itp.times[begin] || t > itp.times[end]
            update!(itp, t)
        end
    end
end
lazyload!(itp::DataSetInterpolator, t::AbstractFloat) = lazyload!(itp, Dates.unix2datetime(t))

"""
$(SIGNATURES)

Return the dimension names associated with this interpolator.
"""
dimnames(itp::DataSetInterpolator) = itp.metadata.dimnames

"""
$(SIGNATURES)

Return the units of the data associated with this interpolator.
"""
units(itp::DataSetInterpolator) = itp.metadata.units

"""
$(SIGNATURES)

Return the description of the data associated with this interpolator.
"""
description(itp::DataSetInterpolator) = itp.metadata.description

"""
$(SIGNATURES)

Return the value of the given variable from the given dataset at the given time and location.
"""
function interp!(itp::DataSetInterpolator{T,N,N2}, t::DateTime, locs::Vararg{T,N2})::T where {T,N,N2}
    lazyload!(itp, t)
    interp_unsafe(itp, t, locs...)
end

"""
Interpolate without checking if the data has been correctly loaded for the given time.
"""
@generated function interp_unsafe(itp::DataSetInterpolator{T,N,N2}, t::DateTime, locs::Vararg{T,N2})::T where {T,N,N2}
    if N2 == N - 1 # Number of locs has to be one less than the number of data dimensions so we can add the time in.
        quote
            locs = itp.coord_trans(locs)
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

"""
Interpolation with a unix timestamp.
"""
function interp!(itp::DataSetInterpolator, t::Real, locs::Vararg{T,N})::T where {T,N}
    interp!(itp, Dates.unix2datetime(t), locs...)
end
function interp_unsafe(itp::DataSetInterpolator, t::Real, locs::Vararg{T,N})::T where {T,N}
    interp_unsafe(itp, Dates.unix2datetime(t), locs...)
end

# Dummy function for unit validation. Basically ModelingToolkit
# will call the function with a DynamicQuantities.Quantity or an integer to
# get information about the type and units of the output.
interp!(itp::Union{DynamicQuantities.AbstractQuantity,Real}, t, locs...) = itp
interp_unsafe(itp::Union{DynamicQuantities.AbstractQuantity,Real}, t, locs...) = itp

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
function create_interp_equation(itp::DataSetInterpolator, filename, t, coords; wrapper_f=v -> v)
    # Create right hand side of equation.
    if length(coords) == 3
        rhs = wrapper_f(interp!(itp, t, coords[1], coords[2], coords[3]))
    elseif length(coords) == 2
        rhs = wrapper_f(interp!(itp, t, coords[1], coords[2]))
    elseif length(coords) == 1
        rhs = wrapper_f(interp!(itp, t, coords[1]))
    else
        error("Unexpected number of coordinates: $(length(coords))")
    end

    # Create left hand side of equation.
    desc = description(itp)
    uu = ModelingToolkit.get_unit(rhs)
    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") : Symbol("$(itp.varname)")
    lhs = only(@variables $n(t) [unit = uu, description = desc])
    lhs ~ rhs
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(split(string(typeof(itp.fs)), ".")[end]).$(itp.varname)"
end
