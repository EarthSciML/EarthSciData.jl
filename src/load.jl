export interp_unsafe, interp!, GridSpec

const _LONLAT_SR = "+proj=longlat +datum=WGS84 +no_defs"

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

struct FileSetWithRegridder{FS, RF}
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
        (varnames, Tuple{T}, "varnames(::$T)")
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
function url(fs::FileSet, t::DateTime, varname = nothing)
    join([mirror(fs), relpath(fs, t, varname)], "/")
end

"""
$(SIGNATURES)

Return the local path for the file for the given `DateTime`.
An optional `varname` can be provided for datasets with per-variable files.
"""
function localpath(fs::FileSet, t::DateTime, varname = nothing)
    file = relpath(fs, t, varname)
    file = replace(file, ':' => '_')
    joinpath(download_cache(), replace(mirror(fs), "://" => "_"), file)
end

"""
Download a file with a progress bar, deleting the partial file on error.
"""
function _download_with_progress(download_url::AbstractString, path::AbstractString; timeout::Real = 300)
    try
        prog = Progress(100; desc = "Downloading $(basename(download_url)):", dt = 0.1)
        Downloads.download(download_url, path,
            timeout = timeout,
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
function maybedownload(fs::FileSet, t::DateTime, varname = nothing)
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
mutable struct TemporalCache{To, N, N2}
    "Internal buffer holding loaded/regridded data (spatial dims + time). After loading, this is copied to the discrete parameter."
    data_buffer::Array{To, N}
    "Buffer that data is read into from file (separate from `data_buffer` for async loading)."
    load_cache::Array{To, N2}
    "Timestamps corresponding to each time index in `data_buffer`."
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
mutable struct DataSetInterpolator{To, N, N2, FT, DomT, ET, FSRG}
    fs::FSRG
    varname::String
    cache::TemporalCache{To, N, N2}
    metadata::MetaData
    domain::DomT
    extrapolate_type::ET
    lock::ReentrantLock
    # Precomputed spatial grid parameters in data-array dimension order
    # (i.e. reordered by `metadata.xdim`/`ydim`/`zdim`).  Stored as plain
    # `To`-typed scalars so that the `interp_unsafe` hot path computes
    # fractional indices with zero allocation and without Float64 promotion
    # on Float32 (GPU) DSIs.  Previously the hot path recomputed the grid
    # per call via `_compute_grid(domain, staggering)`, which allocated in
    # `endpoints(d::DomainInfo)` → `filter(...)` / `sizehint!(...)`.
    grid_starts::NTuple{N2, To}
    grid_steps::NTuple{N2, To}
    grid_size::NTuple{N2, Int}

    function DataSetInterpolator{To}(fs::FileSet, varname::AbstractString,
            starttime::DateTime, endtime::DateTime, domain;
            stream = true, extrapolate_type = Flat()) where {To <: Real}
        metadata = loadmetadata(fs, varname)
        model_grid = _compute_grid(domain, metadata.staggering)
        regrid_f = (dst::AbstractArray,
            src::AbstractArray;
            extrapolate_type = extrapolate_type) -> begin
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
        data_buffer = zeros(To, repeat([2], length(metadata.varsize))..., cache_size) # Add a dimension for time.
        N = ndims(data_buffer)
        N2 = N - 1
        times = [DateTime(0, 1, 1) + Hour(i) for i in 1:cache_size]

        coord_trns = coord_trans(metadata, domain)
        FT = typeof(coord_trns)

        # Precompute the reordered spatial grid once.  The reordering follows
        # `metadata.xdim`/`ydim`/`zdim` so that `grid_*[i]` aligns with data
        # dimension `i`, matching the `locs[i]` argument order of
        # `interp_unsafe`.
        reordered = _reorder_grid(_compute_grid(domain, metadata.staggering), metadata)
        grid_starts = ntuple(i -> To(first(reordered[i])), N2)
        grid_steps  = ntuple(i -> To(step(reordered[i])),  N2)
        grid_size   = ntuple(i -> Int(length(reordered[i])), N2)

        td = Threads.@spawn (() -> DateTime(0, 1, 10))() # Placeholder for async loading task.
        tc = TemporalCache{To, N, N2}(
            data_buffer, load_cache, times,
            DateTime(1, 1, 1), td, false
        )
        itp = new{To, N, N2, FT, typeof(domain), typeof(extrapolate_type), typeof(fs)}(
            fs,
            String(varname),
            tc,
            metadata,
            domain,
            extrapolate_type,
            ReentrantLock(),
            grid_starts,
            grid_steps,
            grid_size
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
    if length(knots) == 1
        return knots[begin]:one(eltype(knots)):knots[begin]
    end
    dx = diff(knots)
    dx_mean = sum(dx) / length(dx)
    #@assert all(abs.(1 .- dx ./ dx_mean) .<= reltol) "Knots ($knots) must be evenly spaced within reltol=$reltol."
    dx = (knots[end] - knots[begin]) / (length(knots) - 1)
    # Need to do weird range creation to avoid rounding errors.
    return knots[begin]:dx:(knots[begin] + dx * (length(knots) - 1))
end

"""
Pad singleton dimensions in data and coords so that every axis has ≥ 2 elements,
which is required by `BSpline(Linear())`.  Returns `(padded_data, padded_coords)`.
"""
function _pad_singletons(data, coords)
    N = ndims(data)
    needs_pad = ntuple(i -> size(data, i) == 1, N)
    any(needs_pad) || return data, coords
    pad_sizes = ntuple(i -> needs_pad[i] ? 2 : 1, N)
    padded = repeat(data, pad_sizes...)
    padded_coords = ntuple(N) do i
        c = coords[i]
        if needs_pad[i]
            s = one(eltype(c))
            first(c):s:(first(c) + s)
        else
            c
        end
    end
    return padded, padded_coords
end

# create_interpolator! and update_interpolator! have been removed.
# Interpolation is now done by the array-based interp_unsafe functions.

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

# Reorder raw coord ranges (domain-order) into data-array dimension order
# using `metadata.xdim`/`ydim`/`zdim`.  Called exactly once per DSI at
# construction to populate `grid_starts`/`grid_steps`/`grid_size`; the
# hot path never hits this again.
function _reorder_grid(grid, metadata::MetaData)
    if length(metadata.varsize) == 2 && metadata.zdim <= 0
        return tuple_from_vals(metadata.xdim, grid[1], metadata.ydim, grid[2])
    elseif length(metadata.varsize) == 3
        return tuple_from_vals(
            metadata.xdim,
            grid[1],
            metadata.ydim,
            grid[2],
            metadata.zdim,
            grid[3]
        )
    else
        error("Invalid data size")
    end
end

function initialize!(itp::DataSetInterpolator, t::DateTime)
    tc = itp.cache
    tc.load_cache = zeros(eltype(tc.load_cache), itp.metadata.varsize...)
    tc.data_buffer = zeros(eltype(tc.data_buffer), itp.grid_size..., size(tc.data_buffer, ndims(tc.data_buffer))) # Add a dimension for time.
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
    N = ndims(tc.data_buffer)
    if all(idxs_in_cache .> idxs_in_times) && all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(idxs_in_times, idxs_in_cache)
            selectdim(tc.data_buffer, N, new) .= selectdim(tc.data_buffer, N, old)
        end
    elseif all(idxs_in_cache .< idxs_in_times) &&
           all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(reverse(idxs_in_times), reverse(idxs_in_cache))
            selectdim(tc.data_buffer, N, new) .= selectdim(tc.data_buffer, N, old)
        end
    elseif !all(idxs_in_cache .== idxs_in_times)
        error(
            "Unexpected time ordering, can't reorder indexes $(idxs_in_times) to $(idxs_in_cache)",
        )
    end

    # Load the additional times we need
    for idx in idxs_not_in_times
        d = selectdim(tc.data_buffer, N, idx)
        if fetch(tc.loadtask) != times[idx] # Check if correct time is already loaded.
            load_data_for_time!(itp, times[idx]) # Load data if not already loaded.
        end
        # Regrid results into the data buffer.
        itp.fs.regridder(d, tc.load_cache; extrapolate_type = itp.extrapolate_type)
        # Start loading the next time point asynchronously.
        tc.loadtask = Threads.@spawn load_data_for_time!(
            itp, nexttimepoint(itp, times[idx]))
    end
    tc.times = times
    tc.currenttime = t
    @assert issorted(tc.times) "Interpolator times are in wrong order"
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

Interpolate without checking if the data has been correctly loaded for the given time.
This convenience method on `DataSetInterpolator` delegates to the array-based `interp_unsafe`.
"""
function interp_unsafe(
        itp::DataSetInterpolator{T1, N, N2},
        t::DateTime,
        locs::Vararg{T2, N2}
) where {T1, T2, N, N2}
    tc = itp.cache
    t_unix = datetime2unix(t)
    t_start, t_step = get_time_grid_params(itp)
    # Compute fractional 1-based indices from cached grid scalars.  All
    # operands are `T1 = To`, so Float32 DSIs stay in Float32 (no Float64
    # promotion on GPU).
    fit = one(T1) + T1((t_unix - t_start) / t_step)
    fis = ntuple(
        i -> one(T1) +
             T1((locs[i] - itp.grid_starts[i]) / itp.grid_steps[i]), Val(N2))
    extrap = itp.extrapolate_type isa Real ? zero(T1) : one(T1)
    interp_unsafe(tc.data_buffer, fit, fis..., extrap)
end

"""
Interpolation with a unix timestamp.
"""
function interp_unsafe(
        itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    interp_unsafe(itp, Dates.unix2datetime(t), locs...)
end

# Deprecated: use `interp_unsafe` directly.
function interp!(
        itp::DataSetInterpolator{T, N, N2},
        t::DateTime,
        locs::Vararg{T, N2}
)::T where {T, N, N2}
    Base.depwarn("`interp!` is deprecated, use `interp_unsafe` instead.", :interp!)
    lazyload!(itp, t)
    interp_unsafe(itp, t, locs...)
end
function interp!(itp::DataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    Base.depwarn("`interp!` is deprecated, use `interp_unsafe` instead.", :interp!)
    lazyload!(itp, Dates.unix2datetime(t))
    interp_unsafe(itp, t, locs...)
end

"""
Return the time grid parameters `(t_start, t_step)` from the current cache times
as Unix timestamps.
"""
function get_time_grid_params(itp::DataSetInterpolator)
    tc = itp.cache
    t_start = datetime2unix(tc.times[1])
    if length(tc.times) > 1
        t_end = datetime2unix(tc.times[end])
        t_step = (t_end - t_start) / (length(tc.times) - 1)
    else
        t_step = one(t_start)
    end
    return (t_start, t_step)
end

"""
Return the spatial grid parameters as a flat tuple `(s1_start, s1_step, s2_start, s2_step, ...)`.
"""
function get_spatial_grid_params(itp::DataSetInterpolator{To, N, N2}) where {To, N, N2}
    ntuple(
        k -> Float64(isodd(k) ? itp.grid_starts[(k + 1) >> 1] : itp.grid_steps[k >> 1]),
        Val(2 * N2)
    )
end

# --------------------------------------------------------------------------
# Array-based multilinear interpolation functions.
# These operate on plain arrays + fractional 1-based indices and are
# GPU-compatible (pure arithmetic + array indexing, zero allocations).
#
# The `extrap` parameter controls extrapolation:
#   extrap >= 1.0 → Flat (clamp to boundary values)
#   extrap < 1.0  → return zero for out-of-bounds
#
# The data array has spatial dimensions first, time dimension last.
# All index arguments (fit, fi1, ...) are fractional 1-based indices,
# computed as: fi = 1 + (coord - grid_start) / grid_step
# --------------------------------------------------------------------------

# A `fit` (fractional time index) outside `[1, nt]` means the discrete
# update event did not refresh the cache to cover `integrator.t` — this
# indicates a bug in `build_interp_event`'s tstop computation, not a user
# error.  We surface it as an assertion via `@boundscheck` so callers can
# elide the check with `@inbounds` in performance-critical code, and the
# `@noinline` keeps the throw path off the hot path.
#
# The error has no interpolated arguments so the compiler can lift the
# error object to a constant — important on GPUs where constructing an
# Exception with runtime values allocates and may abort kernel compilation.
@noinline _throw_fit_oor() = error(
    "interp_unsafe: time index outside loaded cache range; the discrete " *
    "update event did not refresh the cache for the current integrator time.")

"""
Multilinear interpolation on a 2D array (1 spatial dim + time).
`fit` and `fi1` are fractional 1-based indices.
"""
function interp_unsafe(data::AbstractArray{T, 2}, fit, fi1, extrap) where {T}
    n1, nt = size(data)
    @boundscheck (fit < one(T) || fit > T(nt)) && _throw_fit_oor()

    # Extrapolation check
    if extrap < one(T)
        if fi1 < one(T) || fi1 > T(n1) || fit < one(T) || fit > T(nt)
            return zero(T)
        end
    end

    # Clamp to valid range
    fi1 = clamp(fi1, one(T), T(n1))
    fit = clamp(fit, one(T), T(nt))

    # Floor indices and weights
    i1 = clamp(unsafe_trunc(Int, fi1), 1, n1)
    it = clamp(unsafe_trunc(Int, fit), 1, nt)
    w1 = fi1 - T(i1)
    wt = fit - T(it)

    # Upper indices (clamped)
    j1 = min(i1 + 1, n1)
    jt = min(it + 1, nt)

    # Bilinear interpolation (2D: 4 corners)
    result = (one(T) - w1) * (one(T) - wt) * data[i1, it] +
             w1 * (one(T) - wt) * data[j1, it] +
             (one(T) - w1) * wt * data[i1, jt] +
             w1 * wt * data[j1, jt]
    return result
end

"""
Multilinear interpolation on a 3D array (2 spatial dims + time).
`fit`, `fi1`, `fi2` are fractional 1-based indices.
"""
function interp_unsafe(data::AbstractArray{T, 3}, fit, fi1, fi2, extrap) where {T}
    n1, n2, nt = size(data)
    @boundscheck (fit < one(T) || fit > T(nt)) && _throw_fit_oor()

    # Extrapolation check
    if extrap < one(T)
        if fi1 < one(T) || fi1 > T(n1) || fi2 < one(T) || fi2 > T(n2) ||
           fit < one(T) || fit > T(nt)
            return zero(T)
        end
    end

    # Clamp to valid range
    fi1 = clamp(fi1, one(T), T(n1))
    fi2 = clamp(fi2, one(T), T(n2))
    fit = clamp(fit, one(T), T(nt))

    # Floor indices and weights
    i1 = clamp(unsafe_trunc(Int, fi1), 1, n1)
    i2 = clamp(unsafe_trunc(Int, fi2), 1, n2)
    it = clamp(unsafe_trunc(Int, fit), 1, nt)
    w1 = fi1 - T(i1)
    w2 = fi2 - T(i2)
    wt = fit - T(it)

    # Upper indices (clamped)
    j1 = min(i1 + 1, n1)
    j2 = min(i2 + 1, n2)
    jt = min(it + 1, nt)

    # Trilinear interpolation (3D: 8 corners)
    result = zero(T)
    for (ii1, ww1) in ((i1, one(T) - w1), (j1, w1))
        for (ii2, ww2) in ((i2, one(T) - w2), (j2, w2))
            for (iit, wwt) in ((it, one(T) - wt), (jt, wt))
                result += ww1 * ww2 * wwt * data[ii1, ii2, iit]
            end
        end
    end
    return result
end

"""
Multilinear interpolation on a 4D array (3 spatial dims + time).
`fit`, `fi1`, `fi2`, `fi3` are fractional 1-based indices.
"""
function interp_unsafe(data::AbstractArray{T, 4}, fit, fi1, fi2, fi3, extrap) where {T}
    n1, n2, n3, nt = size(data)
    @boundscheck (fit < one(T) || fit > T(nt)) && _throw_fit_oor()

    # Extrapolation check
    if extrap < one(T)
        if fi1 < one(T) || fi1 > T(n1) || fi2 < one(T) || fi2 > T(n2) ||
           fi3 < one(T) || fi3 > T(n3) || fit < one(T) || fit > T(nt)
            return zero(T)
        end
    end

    # Clamp to valid range
    fi1 = clamp(fi1, one(T), T(n1))
    fi2 = clamp(fi2, one(T), T(n2))
    fi3 = clamp(fi3, one(T), T(n3))
    fit = clamp(fit, one(T), T(nt))

    # Floor indices and weights
    i1 = clamp(unsafe_trunc(Int, fi1), 1, n1)
    i2 = clamp(unsafe_trunc(Int, fi2), 1, n2)
    i3 = clamp(unsafe_trunc(Int, fi3), 1, n3)
    it = clamp(unsafe_trunc(Int, fit), 1, nt)
    w1 = fi1 - T(i1)
    w2 = fi2 - T(i2)
    w3 = fi3 - T(i3)
    wt = fit - T(it)

    # Upper indices (clamped)
    j1 = min(i1 + 1, n1)
    j2 = min(i2 + 1, n2)
    j3 = min(i3 + 1, n3)
    jt = min(it + 1, nt)

    # Quadrilinear interpolation (4D: 16 corners)
    result = zero(T)
    for (ii1, ww1) in ((i1, one(T) - w1), (j1, w1))
        for (ii2, ww2) in ((i2, one(T) - w2), (j2, w2))
            for (ii3, ww3) in ((i3, one(T) - w3), (j3, w3))
                for (iit, wwt) in ((it, one(T) - wt), (jt, wt))
                    result += ww1 * ww2 * ww3 * wwt * data[ii1, ii2, ii3, iit]
                end
            end
        end
    end
    return result
end

# --------------------------------------------------------------------------
# Fast path: time-only interpolation with nearest-neighbour spatial indexing.
#
# Used when the data grid matches the model grid exactly and the caller
# evaluates at grid points. `fi1..fiN` are assumed to be approximately
# integer-valued; we round to the nearest index and perform interpolation
# only in time. This reduces the corner count from 2^(1+dim) to 2.
# --------------------------------------------------------------------------

"""
Nearest-neighbour spatial + linear time interpolation on a 2D array.
`fit` is a fractional 1-based time index; `fi1` is assumed (approximately)
integer-valued at a grid point.
"""
function interp_time_only(data::AbstractArray{T, 2}, fit, fi1, extrap) where {T}
    n1, nt = size(data)
    @boundscheck (fit < one(T) || fit > T(nt)) && _throw_fit_oor()

    # Extrapolation check (zero outside range if extrap < 1)
    if extrap < one(T)
        if fi1 < one(T) || fi1 > T(n1)
            return zero(T)
        end
    end

    i1 = clamp(unsafe_trunc(Int, fi1 + T(0.5)), 1, n1)
    it = clamp(unsafe_trunc(Int, fit), 1, nt)
    wt = fit - T(it)
    jt = min(it + 1, nt)
    return (one(T) - wt) * data[i1, it] + wt * data[i1, jt]
end

"""
Nearest-neighbour spatial + linear time interpolation on a 3D array.
"""
function interp_time_only(data::AbstractArray{T, 3}, fit, fi1, fi2, extrap) where {T}
    n1, n2, nt = size(data)
    @boundscheck (fit < one(T) || fit > T(nt)) && _throw_fit_oor()

    if extrap < one(T)
        if fi1 < one(T) || fi1 > T(n1) || fi2 < one(T) || fi2 > T(n2)
            return zero(T)
        end
    end

    i1 = clamp(unsafe_trunc(Int, fi1 + T(0.5)), 1, n1)
    i2 = clamp(unsafe_trunc(Int, fi2 + T(0.5)), 1, n2)
    it = clamp(unsafe_trunc(Int, fit), 1, nt)
    wt = fit - T(it)
    jt = min(it + 1, nt)
    return (one(T) - wt) * data[i1, i2, it] + wt * data[i1, i2, jt]
end

"""
Nearest-neighbour spatial + linear time interpolation on a 4D array.
"""
function interp_time_only(
        data::AbstractArray{T, 4}, fit, fi1, fi2, fi3, extrap) where {T}
    n1, n2, n3, nt = size(data)
    @boundscheck (fit < one(T) || fit > T(nt)) && _throw_fit_oor()

    if extrap < one(T)
        if fi1 < one(T) || fi1 > T(n1) || fi2 < one(T) || fi2 > T(n2) ||
           fi3 < one(T) || fi3 > T(n3)
            return zero(T)
        end
    end

    i1 = clamp(unsafe_trunc(Int, fi1 + T(0.5)), 1, n1)
    i2 = clamp(unsafe_trunc(Int, fi2 + T(0.5)), 1, n2)
    i3 = clamp(unsafe_trunc(Int, fi3 + T(0.5)), 1, n3)
    it = clamp(unsafe_trunc(Int, fit), 1, nt)
    wt = fit - T(it)
    jt = min(it + 1, nt)
    return (one(T) - wt) * data[i1, i2, i3, it] + wt * data[i1, i2, i3, jt]
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

"""
Map data dimension names to domain coordinate variables.

For lon-lat domains the mapping is direct (lon→lon, lat→lat).
For projected domains where the domain has `x` and `y` variables,
`lon` maps to `x` and `lat` maps to `y`.  The coordinate transform
between the domain CRS and the data CRS is handled by `coord_trans`
inside `DataSetInterpolator`.

Accepts both String and Symbol dimension names.
"""
function _match_domain_coords(dims, pvdict, pvs)
    # Mapping from data dim names to possible domain variable names.
    _DIM_MAP = Dict(:lon => [:lon, :x], :lat => [:lat, :y])
    coords = Num[]
    for dim in dims
        dim_sym = dim isa Symbol ? dim : Symbol(dim)
        candidates = get(_DIM_MAP, dim_sym, [dim_sym])
        matched = findfirst(c -> c ∈ keys(pvdict), candidates)
        if matched === nothing
            error("Data coordinate '$(dim)' could not be matched to any domain " *
                  "coordinate. Domain has: $(pvs). Expected one of: $(candidates).")
        end
        push!(coords, pvdict[candidates[matched]])
    end
    return coords
end
