export interp, interp!, GridSpec

function download_cache()
    ("EARTHSCIDATADIR" ∈ keys(ENV)) ? ENV["EARTHSCIDATADIR"] :
    @get_scratch!("earthsci_data")
end

"""
An interface for types describing a dataset, potentially comprised of multiple files.

To satisfy this interface, a type must implement the following methods:

  - `mirror(::FileSet)` (Return the base URL or path for the dataset)
  - `relpath(::FileSet, ::DateTime, [varname])` (varname is optional, for per-variable file datasets)
  - `url(::FileSet, ::DateTime, [varname])`
  - `localpath(::FileSet, t::DateTime, [varname])`
  - `DataFrequencyInfo(::FileSet)::DataFrequencyInfo`
  - `loadmetadata(::FileSet, varname)::MetaData`
  - `loadslice!(cache::AbstractArray, ::FileSet, ::DateTime, varname)`
  - `varnames(::FileSet)`
  - `get_geometry(::FileSet, ::MetaData)` (Returns the geometry of the data)
"""
abstract type FileSet end

"""
$(SIGNATURES)

Return the base URL or path for the dataset.
"""
mirror(fs::FileSet) = fs.mirror

"""
Default 3-argument `relpath` falls back to the 2-argument version, ignoring `varname`.
Subtypes with per-variable files should override this.
"""
relpath(fs::FileSet, t::DateTime, ::Nothing) = relpath(fs, t)

struct FileSetWithRegridder{FS,RF}
    fs::FS
    regridder::RF
end

"""
A lightweight specification of a model grid, providing an alternative to
`EarthSciMLBase.DomainInfo` for use cases that don't require ModelingToolkit integration.

$(FIELDS)
"""
struct GridSpec
    "Coordinate ranges for each spatial dimension, ordered (x, y, [z])."
    coords::Vector
    "The spatial reference system, e.g. \"+proj=longlat +datum=WGS84 +no_defs\"."
    spatial_ref::String
end

# Internal dispatch: compute the model grid for the given domain/gridspec and staggering.
_compute_grid(domain::DomainInfo, staggering) = EarthSciMLBase.grid(domain, staggering)
_compute_grid(gs::GridSpec, _staggering) = gs.coords

# Internal dispatch: get the spatial reference string.
_spatial_ref(domain::DomainInfo) = domain.spatial_ref
_spatial_ref(gs::GridSpec) = gs.spatial_ref

"""
$(SIGNATURES)

Check that type `T` implements all required `FileSet` interface methods.
Throws an error listing any missing methods. This is an opt-in check
intended for use when implementing a new `FileSet` subtype.

# Example
```julia
struct MyFileSet <: EarthSciData.FileSet ... end
# After defining all methods:
EarthSciData.verify_fileset_interface(MyFileSet)
```
"""
function verify_fileset_interface(::Type{T}) where {T <: FileSet}
    required = [
        (DataFrequencyInfo, Tuple{T}, "DataFrequencyInfo(::$T)"),
        (loadmetadata, Tuple{T, String}, "loadmetadata(::$T, varname::String)"),
        (loadslice!, Tuple{AbstractArray, T, DateTime, String},
            "loadslice!(cache, ::$T, ::DateTime, varname)"),
        (varnames, Tuple{T}, "varnames(::$T)"),
    ]
    missing_methods = String[]
    # relpath must have either a 2-arg or 3-arg method.
    has_relpath_2 = hasmethod(relpath, Tuple{T, DateTime})
    has_relpath_3 = hasmethod(relpath, Tuple{T, DateTime, String})
    if !has_relpath_2 && !has_relpath_3
        push!(missing_methods, "relpath(::$T, ::DateTime) or relpath(::$T, ::DateTime, varname)")
    end
    for (f, argtypes, desc) in required
        if !hasmethod(f, argtypes)
            push!(missing_methods, desc)
        end
    end
    if !isempty(missing_methods)
        error("Type $T is missing required FileSet interface methods:\n  " *
              join(missing_methods, "\n  "))
    end
    return true
end

"""
$(SIGNATURES)

Return the URL for the file for the given `DateTime`.
An optional `varname` can be provided for datasets with per-variable files.
"""
url(fs::FileSet, t::DateTime, varname=nothing) = join([mirror(fs), relpath(fs, t, varname)], "/")

"""
$(SIGNATURES)

Return the local path for the file for the given `DateTime`.
An optional `varname` can be provided for datasets with per-variable files.
"""
function localpath(fs::FileSet, t::DateTime, varname=nothing)
    file = relpath(fs, t, varname)
    file = replace(file, ':' => '_')
    joinpath(download_cache(), replace(mirror(fs), "://" => "_"), file)
end

"""
Download a file with a progress bar, deleting the partial file on error.
"""
function _download_with_progress(download_url::AbstractString, path::AbstractString)
    try
        prog = Progress(100; desc = "Downloading $(basename(download_url)):", dt = 0.1)
        Downloads.download(download_url, path,
            progress = (
                total::Integer, now::Integer) -> begin
                prog.n = total
                ProgressMeter.update!(prog, now)
            end
        )
    catch e
        rm(path, force = true)
        rethrow(e)
    end
    return path
end

"""
$(SIGNATURES)

Check if the specified file exists locally. If not, download it.
An optional `varname` can be provided for datasets with per-variable files.
"""
function maybedownload(fs::FileSet, t::DateTime, varname=nothing)
    p = localpath(fs, t, varname)
    if isfile(p)
        return p
    end
    if !isdir(dirname(p))
        @info "Creating directory $(dirname(p))"
        mkpath(dirname(p))
    end
    u = url(fs, t, varname)
    _download_with_progress(u, p)
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
    unit_str::String
    "Description of the data."
    description::String
    "Dimensions of the data, e.g. (lat, lon, layer)."
    dimnames::Vector{String}
    "Dimension sizes of the data, e.g. (180, 360, 30)."
    varsize::Vector{Int}
    "The spatial reference system of the data, e.g. \"+proj=longlat +datum=WGS84 +no_defs\" for lat-lon data."
    native_sr::String
    "The index number of the x-dimension (e.g. longitude)"
    xdim::Int
    "The index number of the y-dimension (e.g. latitude)"
    ydim::Int
    "The index number of the z-dimension (e.g. vertical level)"
    zdim::Int
    "Grid staggering for each dimension. (true=edge-aligned, false=center-aligned)"
    staggering::NTuple{3, Bool}
end

function proj_trans(metadata::MetaData, domain)
    # Pipeline: inverse of domain projection (domain coords → geographic lon/lat),
    # then forward data projection (geographic lon/lat → data native coords).
    Proj.Transformation(
        "+proj=pipeline +step +inv " *
        _spatial_ref(domain) *
        " +step " *
        metadata.native_sr,
    )
end

function coord_trans(metadata::MetaData, domain)
    if _spatial_ref(domain) == metadata.native_sr
        coord_trns = (x) -> x # No transformation needed.
    else
        t = proj_trans(metadata, domain)
        coord_trns = (locs) -> begin
            x, y = t(locs[metadata.xdim], locs[metadata.ydim])
            replace_in_tuple(locs, metadata.xdim, x, metadata.ydim, y)
        end
    end
    return coord_trns
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
    centerpoints::Vector{DateTime}
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
Cache for time-varying interpolation state within a `DataSetInterpolator`.

$(FIELDS)
"""
mutable struct TemporalCache{To, N, N2, ITPT}
    "The actual data array, with the last dimension being time."
    data::Array{To, N}
    "Buffer used for interpolation."
    interp_cache::Array{To, N}
    "Buffer that data is read into from file (separate from `data` for async loading)."
    load_cache::Array{To, N2}
    "The interpolation object."
    itp::ITPT
    "Timestamps corresponding to each time index in `data`."
    times::Vector{DateTime}
    "The current time that the interpolator has been loaded for."
    currenttime::DateTime
    "Async task for loading the next time step."
    loadtask::Task
    "Whether the cache has been initialized with real data."
    initialized::Bool
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
mutable struct DataSetInterpolator{To, N, N2, FT, ITPT, DomT, ET, FSRG}
    fs::FSRG
    varname::String
    cache::TemporalCache{To, N, N2, ITPT}
    metadata::MetaData
    domain::DomT
    extrapolate_type::ET
    lock::ReentrantLock

    function DataSetInterpolator{To}(fs::FileSet, varname::AbstractString,
            starttime::DateTime, endtime::DateTime, domain;
            stream = true, extrapolate_type = Flat()) where {To <: Real}
        metadata = loadmetadata(fs, varname)
        model_grid = _compute_grid(domain, metadata.staggering)
        regrid_f = (dst::AbstractArray, src::AbstractArray; extrapolate_type = extrapolate_type) -> begin
            interpolate_from!(dst, src, metadata, model_grid, domain;
                extrapolate_type = extrapolate_type)
        end
        fswr = FileSetWithRegridder(fs, regrid_f)
        DataSetInterpolator{To}(fswr, varname, starttime, endtime, domain;
            stream = stream, extrapolate_type = extrapolate_type)
    end

    function DataSetInterpolator{To}(fs::FileSetWithRegridder, varname::AbstractString,
            starttime::DateTime, endtime::DateTime, domain;
            stream = true, extrapolate_type = Flat()) where {To <: Real}
        metadata = loadmetadata(fs.fs, varname)

        # Check how many time indices we will need.
        dfi = DataFrequencyInfo(fs.fs)
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

        coord_trns = coord_trans(metadata, domain)
        FT = typeof(coord_trns)

        td = Threads.@spawn (() -> DateTime(0, 1, 10))() # Placeholder for async loading task.
        tc = TemporalCache{To, N, N2, ITPT}(
            data, interp_cache, load_cache, itp2, times,
            DateTime(1, 1, 1), td, false
        )
        itp = new{To, N, N2, FT, ITPT, typeof(domain), typeof(extrapolate_type), typeof(fs)}(
            fs,
            String(varname),
            tc,
            metadata,
            domain,
            extrapolate_type,
            ReentrantLock(),
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
    print(io, "DataSetInterpolator{$(typeof(itp.fs.fs)), $(itp.varname)}")
end

"""
Convert a vector of evenly spaced grid points to a range.
The `reltol` parameter specifies the relative tolerance for the grid spacing,
which is necessary to account for different numbers of days in each month
and things like that.
"""
function knots2range(knots, reltol = 0.05)
    dx = diff(knots)
    dx_mean = sum(dx) / length(dx)
    #@assert all(abs.(1 .- dx ./ dx_mean) .<= reltol) "Knots ($knots) must be evenly spaced within reltol=$reltol."
    dx = (knots[end] - knots[begin]) / (length(knots) - 1)
    # Need to do weird range creation to avoid rounding errors.
    return knots[begin]:dx:(knots[begin] + dx * (length(knots) - 1))
end

"""
Create a new interpolator, overwriting `interp_cache`.
"""
function create_interpolator!(interp_cache, data, coords, times)
    grid = tuple((knots2range(Float64.(c)) for c in coords)..., knots2range(datetime2unix.(times)))
    copyto!(interp_cache, data)
    itp = interpolate!(interp_cache, BSpline(Linear()))
    itp = scale(itp, grid...)
    return grid, itp
end

function update_interpolator!(itp::DataSetInterpolator{To}) where {To}
    tc = itp.cache
    if size(tc.interp_cache) != size(tc.data)
        tc.interp_cache = similar(tc.data)
    end
    coords = _model_grid(itp)
    grid, itp2 = create_interpolator!(tc.interp_cache, tc.data, coords, tc.times)
    @assert all([length(g) for g in grid] .== size(tc.data)) "invalid data size: $([length(g) for g in grid]) != $(size(tc.data))"
    tc.itp = itp2
end

"""
Return the next interpolation time point for this interpolator.
"""
function nexttimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[min(length(ti.centerpoints), ci + 1)]
end

"""
Return the previous interpolation time point for this interpolator.
"""
function prevtimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[max(1, ci - 1)]
end

"""
Return the current interpolation time point for this interpolator.
"""
function currenttimepoint(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs.fs)
    ci = centerpoint_index(ti, t)
    ti.centerpoints[ci]
end

"""
Load the time points that should be cached in this interpolator.
"""
function interp_cache_times!(itp::DataSetInterpolator, t::DateTime)
    cache_size = length(itp.cache.times)
    dfi = DataFrequencyInfo(itp.fs.fs)
    ti = centerpoint_index(dfi, t)
    n = length(dfi.centerpoints)
    # Currently assuming we're going forwards in time.
    if t < dfi.centerpoints[ti]  # Load data starting with previous time step.
        ti_end = min(n, ti + cache_size - 2)
        ti_start = max(1, ti_end - cache_size + 1)
    else
        ti_end = min(n, ti + cache_size - 1)
        ti_start = max(1, ti_end - cache_size + 1)
    end
    dfi.centerpoints[ti_start:ti_end]
end

"""
The time points when integration should be stopped to update the interpolator
(as Unix timestamps).
"""
function get_tstops(itp::DataSetInterpolator, starttime::DateTime)
    dfi = DataFrequencyInfo(itp.fs.fs)
    datetime2unix.(sort([starttime, dfi.centerpoints...]))
end

# Get the model grid for this interpolator.
function _model_grid(itp::DataSetInterpolator)
    grid = _compute_grid(itp.domain, itp.metadata.staggering)
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
    tc = itp.cache
    tc.load_cache = zeros(eltype(tc.load_cache), itp.metadata.varsize...)
    grid_size = length.(_model_grid(itp))
    tc.data = zeros(eltype(tc.data), grid_size..., size(tc.data, length(size(tc.data)))) # Add a dimension for time.
    tc.initialized = true
end

function load_data_for_time!(itp::DataSetInterpolator, t::DateTime)
    loadslice!(itp.cache.load_cache, itp.fs.fs, t, itp.varname)
    return t
end

function update!(itp::DataSetInterpolator, t::DateTime)
    tc = itp.cache
    @assert tc.initialized "Interpolator has not been initialized"
    times = interp_cache_times!(itp, t) # Figure out which times we need.

    # Figure out the overlap between the times we have and the times we need.
    times_in_cache = intersect(times, tc.times)
    idxs_in_cache = [findfirst(x -> x == times_in_cache[i], tc.times)
                     for i in eachindex(times_in_cache)]
    idxs_in_times = [findfirst(x -> x == times_in_cache[i], times)
                     for i in eachindex(times_in_cache)]
    idxs_not_in_times = setdiff(eachindex(times), idxs_in_times)

    # Move data we already have to where it should be.
    N = ndims(tc.data)
    if all(idxs_in_cache .> idxs_in_times) && all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(idxs_in_times, idxs_in_cache)
            selectdim(tc.data, N, new) .= selectdim(tc.data, N, old)
        end
    elseif all(idxs_in_cache .< idxs_in_times) &&
           all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(reverse(idxs_in_times), reverse(idxs_in_cache))
            selectdim(tc.data, N, new) .= selectdim(tc.data, N, old)
        end
    elseif !all(idxs_in_cache .== idxs_in_times)
        error(
            "Unexpected time ordering, can't reorder indexes $(idxs_in_times) to $(idxs_in_cache)",
        )
    end

    # Load the additional times we need
    for idx in idxs_not_in_times
        d = selectdim(tc.data, N, idx)
        if fetch(tc.loadtask) != times[idx] # Check if correct time is already loaded.
            load_data_for_time!(itp, times[idx]) # Load data if not already loaded.
        end
        # Regrid results into the data array.
        itp.fs.regridder(d, tc.load_cache; extrapolate_type=itp.extrapolate_type)
        # Start loading the next time point asynchronously.
        tc.loadtask = Threads.@spawn load_data_for_time!(
            itp, nexttimepoint(itp, times[idx]))
    end
    tc.times = times
    tc.currenttime = t
    @assert issorted(tc.times) "Interpolator times are in wrong order"
    update_interpolator!(itp)
end

function lazyload!(itp::DataSetInterpolator, t::DateTime)
    lock(itp.lock) do
        tc = itp.cache
        if tc.currenttime == t
            return
        end
        if !tc.initialized # Initialize new interpolator.
            initialize!(itp, t)
            update!(itp, t)
            return
        end
        if t < tc.times[begin] || t >= tc.times[end]
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
function interp(
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
            try
                itp.cache.itp(locs..., datetime2unix(t))
            catch err
                # FIXME(CT): This is needed because ModelingToolkit sometimes
                # calls the interpolator for the beginning of the simulation time period,
                # and we don't have a way to update for that proactively.
                @warn "Interpolation for $(itp.varname) failed at t=$(t), locs=$(locs); trying to update interpolator."
                lazyload!(itp, t)
                itp.cache.itp(locs..., datetime2unix(t))
            end
        end
    else
        throw(ArgumentError("N2 must be equal to N-1"))
    end
end

"""
Interpolation with a unix timestamp.
"""
function interp(itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    interp(itp, Dates.unix2datetime(t), locs...)
end
function interp_unsafe(
        itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    interp_unsafe(itp, Dates.unix2datetime(t), locs...)
end

# Deprecated: use `interp` instead of `interp!`.
function interp!(
        itp::DataSetInterpolator{T, N, N2},
        t::DateTime,
        locs::Vararg{T, N2}
)::T where {T, N, N2}
    Base.depwarn("`interp!` is deprecated, use `interp` instead.", :interp!)
    interp(itp, t, locs...)
end
function interp!(itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    Base.depwarn("`interp!` is deprecated, use `interp` instead.", :interp!)
    interp(itp, t, locs...)
end
# Generic fallback for unit validation (DynamicQuantities.Quantity arguments).
function interp!(args...)
    Base.depwarn("`interp!` is deprecated, use `interp` instead.", :interp!)
    interp(args...)
end


"""
Close resources associated with a FileSet. Default is a no-op.
Concrete subtypes with open file handles should override this.
"""
Base.close(::FileSet) = nothing

"""
Close resources associated with a DataSetInterpolator,
including the underlying FileSet.
"""
Base.close(itp::DataSetInterpolator) = close(itp.fs.fs)

