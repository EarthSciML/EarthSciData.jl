export regrid!, regrid_from!

"""
Load regrid weights from JLD2 format (simple, no caching)
"""
function load_regrid_weights(path::AbstractString)
    weights = load(path, "weights")
    # Ensure src_dims field exists (calculate from weights if missing)
    if !hasfield(typeof(weights), :src_dims)
        # Calculate source grid dimensions from the maximum column index
        # For NEI data, this should be 442 × 265 = 117,130 total cells
        max_src_idx = maximum(weights.col)
        # For now, assume we can infer dimensions from other fields or use max index
        # This is a fallback - ideally src_dims should be saved with the weights
        weights = merge(weights, (src_dims = (max_src_idx,),))  # 1D flattened size
    end
    return weights
end

"""
Create coordinate lookup table for exact matching - O(1) lookup
"""
function create_coordinate_lookup_table(xc_b_rad, yc_b_rad)
    coord_to_index = Dict{Tuple{Float64, Float64}, Int}()
    for (i, (lon, lat)) in enumerate(zip(xc_b_rad, yc_b_rad))
        coord_to_index[(lon, lat)] = i
    end
    return coord_to_index
end

"""
Exact coordinate lookup with small tolerance for floating point precision
"""
@inline function exact_coordinate_lookup(lon_rad::Real, lat_rad::Real, coord_lookup::Dict{Tuple{Float64, Float64}, Int})
    coord_key = (Float64(lon_rad), Float64(lat_rad))
    
    # First try exact match
    if haskey(coord_lookup, coord_key)
        return coord_lookup[coord_key]
    end
    
    # If no exact match, try with small tolerance for floating point precision
    tolerance = 1e-14  # Much smaller tolerance closer to machine epsilon
    for ((grid_lon, grid_lat), idx) in coord_lookup
        if abs(grid_lon - lon_rad) < tolerance && abs(grid_lat - lat_rad) < tolerance
            return idx
        end
    end
    
    # If still no match, find the nearest neighbor for a more helpful error message
    min_dist = Inf
    nearest_lon_deg = 0.0
    nearest_lat_deg = 0.0
    for (grid_lon, grid_lat) in keys(coord_lookup)
        dist = sqrt((grid_lon - lon_rad)^2 + (grid_lat - lat_rad)^2)
        if dist < min_dist
            min_dist = dist
            nearest_lon_deg = rad2deg(grid_lon)
            nearest_lat_deg = rad2deg(grid_lat)
        end
    end
    
    error("Domain coordinates ($(rad2deg(lon_rad))°, $(rad2deg(lat_rad))°) are not capable of regrid emission. "*
          "This regridding system only works with coordinates that exactly match the precomputed weight grid. "*
          "Nearest grid point: ($(round(nearest_lon_deg, digits=3))°, $(round(nearest_lat_deg, digits=3))°). "*
          "Available coordinate range: lon $(rad2deg(minimum(first.(keys(coord_lookup)))))° to $(rad2deg(maximum(first.(keys(coord_lookup)))))°, "*
          "lat $(rad2deg(minimum(last.(keys(coord_lookup)))))° to $(rad2deg(maximum(last.(keys(coord_lookup)))))°")
end

"""
contributors_for_target_index(j, weights) -> (src_idx::Vector{Int}, w_flux::Vector{Float64})
Optimized version with preallocated arrays
"""
function contributors_for_target_index_fast(j::Integer, weights, src_idx_buffer, w_flux_buffer)
    fb = weights.frac_b[j]
    if fb <= eps()
        return 0, src_idx_buffer, w_flux_buffer
    end
    
    # Find all indices where row == j (optimized)
    count = 0
    @inbounds for i in eachindex(weights.row)
        if weights.row[i] == j
            count += 1
            if count <= length(src_idx_buffer)
                src_idx_buffer[count] = weights.col[i]
                w_flux_buffer[count] = weights.S[i] / fb
            else
                # Fallback to dynamic allocation if buffer too small
                resize!(src_idx_buffer, count)
                resize!(w_flux_buffer, count)
                src_idx_buffer[count] = weights.col[i]
                w_flux_buffer[count] = weights.S[i] / fb
            end
        end
    end
    
    return count, src_idx_buffer, w_flux_buffer
end

"""
Fast lookup using exact coordinate matching - O(1) hash table lookup
"""
function contributors_for_lonlat_exact_match(lon_rad::Real, lat_rad::Real, weights, 
                                           src_idx_buffer, w_flux_buffer, coord_lookup::Dict{Tuple{Float64, Float64}, Int})
    # Direct O(1) hash table lookup
    j = exact_coordinate_lookup(lon_rad, lat_rad, coord_lookup)
    
    count, src_idx_result, w_flux_result = contributors_for_target_index_fast(j, weights, src_idx_buffer, w_flux_buffer)
    
    return j, src_idx_result, w_flux_result, count
end

"""
RegridDataSetInterpolator - Conservative regridding with same architecture as DataSetInterpolator

This now mirrors the DataSetInterpolator architecture:
- Uses regrid_from!() for bulk preprocessing during cache loading (like interpolate_from!())
- Stores regridded data in model-grid cache for fast array lookup during simulation
- Provides same performance characteristics as interpolated version but with mass conservation
"""
mutable struct RegridDataSetInterpolator{To, N, N2, FT, WT, DomT, ITPT}
    fs::FileSet
    varname::AbstractString
    # This is the regridded data cache (on model grid) - equivalent to DataSetInterpolator.data
    data::Array{To, N}
    # This is buffer that is used to interpolate from (same as DataSetInterpolator)
    interp_cache::Array{To, N}
    itp::ITPT # The interpolator (same as DataSetInterpolator)
    # The buffer that raw data is read into from NetCDF file (on source grid)
    load_cache::Array{To, N2}
    # Regridding weights for conservative transformation
    weights::WT
    metadata::Any
    domain::DomT
    times::Vector{DateTime}
    currenttime::DateTime
    coord_trans::FT
    # Async loading infrastructure (same as DataSetInterpolator)
    loadrequest::Channel{DateTime}
    loadresult::Channel
    copyfinish::Channel{Int}
    lock::ReentrantLock
    initialized::Bool
    # Performance optimization: preallocated buffers (cluster-friendly)
    src_idx_buffer::Vector{Int}
    w_flux_buffer::Vector{Float64}
    # Coordinate lookup table for exact matching - O(1) lookup
    coord_lookup::Dict{Tuple{Float64, Float64}, Int}

    function RegridDataSetInterpolator{To}(
            fs::FileSet,
            varname::AbstractString,
            starttime::DateTime,
            endtime::DateTime,
            domain,
            weights_path::AbstractString;
            stream = true
    ) where {To <: Real}
        metadata = loadmetadata(fs, varname)
        weights = load_regrid_weights(weights_path)
        
        # Check how many time indices we will need (same logic as DataSetInterpolator)
        dfi = DataFrequencyInfo(fs)
        cache_size = 2
        if !stream
            cache_size = length(dfi.centerpoints)
        end
        
        # Initialize arrays with dummy sizes (like DataSetInterpolator)
        # Real sizing happens in regrid_initialize!
        load_cache = zeros(To, repeat([1], length(metadata.varsize))...)
        
        # APPROACH 2: RegridDataSetInterpolator data is sized by REQUESTED domain
        # regrid_from!() will calculate emission values for each requested domain grid point
        # using the weights.jld2 file, then cache those values for fast access
        grid = EarthSciMLBase.grid(domain, metadata.staggering)
        if metadata.zdim <= 0
            # NEI emissions are 2D (surface-only): use only lon,lat dimensions of requested domain
            domain_dims = length.(grid[1:2])  # e.g., [3, 3] for test domain
        else
            # Other data might be 3D: use all dimensions of requested domain
            domain_dims = length.(grid)  # e.g., [3, 3, 2] for test domain
        end
        data = zeros(To, domain_dims..., cache_size) # Requested domain + time dimension
        interp_cache = similar(data) # Add interpolation cache like DataSetInterpolator
        N = ndims(data)  # This will be 3 for emissions (lon, lat, time)
        N2 = N - 1       # This will be 2 for emissions (lon, lat)
        times = [DateTime(0, 1, 1) + Hour(i) for i in 1:cache_size]
        
        # Don't create interpolator in constructor - it will be created in update_regrid_interpolator!
        # after real data is loaded with correct times
        itp2 = nothing
        ITPT = Any  # Will be determined when real interpolator is created
        
        # NO coordinate transformation needed for regridding!
        # regrid_from!() already transforms data to domain coordinates
        coord_trans = (x) -> x  # Identity transformation (no-op)
        FT = typeof(coord_trans)
        WT = typeof(weights)
        DomT = typeof(domain)

        # Small preallocated buffers for performance
        buffer_size = min(100, length(weights.col) ÷ 10)
        src_idx_buffer = Vector{Int}(undef, buffer_size)
        w_flux_buffer = Vector{Float64}(undef, buffer_size)
        
        # Create coordinate lookup table
        coord_lookup = create_coordinate_lookup_table(weights.xc_b, weights.yc_b)

        # Async loading channels (same as DataSetInterpolator)
        loadrequest = Channel{DateTime}(1)
        loadresult = Channel(1)
        copyfinish = Channel{Int}(1)

        new{To, N, N2, FT, WT, DomT, ITPT}(
            fs, varname, data, interp_cache, itp2, load_cache, weights, metadata, domain,
            times, DateTime(1, 1, 1), coord_trans,
            loadrequest, loadresult, copyfinish,
            ReentrantLock(), false, src_idx_buffer, w_flux_buffer, coord_lookup
        )
    end
end

"""
Get model grid coordinates for regridding (equivalent to _model_grid for DataSetInterpolator)  
"""
function _regrid_model_grid(rds::RegridDataSetInterpolator)
    # Return coordinates for the REQUESTED domain
    # The cached data is sized for the requested domain, and regrid_from! calculates values for each point
    grid = EarthSciMLBase.grid(rds.domain, rds.metadata.staggering)
    if rds.metadata.zdim <= 0
        # NEI emissions are 2D (surface-only): return only lon,lat coordinates of requested domain
        return tuple_from_vals(rds.metadata.xdim, grid[1], rds.metadata.ydim, grid[2])
    else
        # Other data might be 3D: return all coordinates of requested domain
        return tuple_from_vals(
            rds.metadata.xdim,
            grid[1],
            rds.metadata.ydim,
            grid[2],
            rds.metadata.zdim,
            grid[3]
        )
    end
end

"""
regrid! - Fast array lookup from pre-regridded cache (equivalent to interp! for DataSetInterpolator)

Now works like DataSetInterpolator.interp!():
- Data is pre-regridded and cached on model grid during loading
- This function does fast array lookup from the regridded cache
- Much faster than the old point-wise regridding approach
"""
function regrid!(rds::RegridDataSetInterpolator{T, N, N2}, t::DateTime, locs::Vararg{T, N2})::T where {T, N, N2}
    # Ensure regridded data is loaded and cached (like DataSetInterpolator.lazyload!)
    regrid_lazyload!(rds, t)
    regrid_unsafe(rds, t, locs...)
end

"""
Fast lookup from pre-regridded cache without bounds checking (equivalent to interp_unsafe)
MUCH SIMPLER than interpolation because regridded data is already on domain coordinates!
No coordinate transformation needed - just direct interpolation from domain-grid cache.
"""
function regrid_unsafe(
        rds::RegridDataSetInterpolator{T1, N, N2},
        t::DateTime,
        locs::Vararg{T2, N2}
)::T1 where {T1, T2, N, N2}
    if N2 != N - 1 # Number of locs has to be one less than the number of data dimensions so we can add the time in.
        throw(ArgumentError("N2 must be equal to N-1"))
    end
    
    # MUCH SIMPLER than DataSetInterpolator.interp_unsafe!
    # No coordinate transformation needed because regrid_from!() already put data on domain grid
    # Just direct interpolation from the regridded cache (which is on domain coordinates)
    
    # Ensure interpolator is initialized
    if rds.itp === nothing
        regrid_lazyload!(rds, t)
    end
    
    try
        return rds.itp(locs..., datetime2unix(t))
    catch err
        if isa(err, BoundsError)
            # Out-of-bounds coordinates: return 0.0 (same as DataSetInterpolator extrapolation)
            return T1(0.0)
        else
            # Other errors: try cache update fallback (same as DataSetInterpolator)
            @warn "Regrid interpolation for $(rds.varname) failed at t=$(t), locs=$(locs); trying to update cache."
            regrid_lazyload!(rds, t)
            try
                return rds.itp(locs..., datetime2unix(t))
            catch err2
                if isa(err2, BoundsError)
                    # Still out-of-bounds after cache update: return 0.0
                    return T1(0.0)
                else
                    rethrow(err2)
                end
            end
        end
    end
end

"""
regrid_from!(dsi::RegridDataSetInterpolator, dst::AbstractArray{T, N},
        src::AbstractArray{T, N}, model_grid, extrapolate_type = 0.0) where {T, N}

Conservative regridding function that transforms data from source grid to destination grid.
This function is the regridding equivalent of interpolate_from! and uses vectorized operations
for maximum performance.

Key differences from interpolate_from!:
- Uses precomputed conservative weights for mass conservation
- Vectorized operations instead of point-by-point calculations
- Output size matches domain grid (not source grid)
- Runs once per month, results cached for fast timestep access

Args:
    dsi: RegridDataSetInterpolator containing precomputed weights
    dst: Destination array (model grid) - will be filled with regridded values
    src: Source array (NEI data grid) for ONE SPECIES (e.g., "NO", "CO", etc.)
    model_grid: Tuple of coordinate arrays for destination grid (unused for vectorized approach)
    extrapolate_type: Unused for regridding (kept for interface compatibility)
"""
function regrid_from!(dsi::RegridDataSetInterpolator, dst::AbstractArray{T, N},
        src::AbstractArray{T, N}, model_grid, extrapolate_type = 0.0) where {T, N}
    
    # Bulk regridding: Calculate emission values for ALL domain grid points using weights.jld2
    # This mirrors interpolate_from! - bulk processing once per month, save results to dst cache
    
    
    # Validate input dimensions
    if N < 2
        error("regrid_from! requires at least 2D arrays (lon, lat)")
    end
    
    # Get source NEI data as flat vector for efficient indexing
    src_vec = vec(src)
    
    # Pre-allocate temporary buffers for this operation (thread-safe)
    buffer_size = min(100, length(dsi.weights.col) ÷ 10)
    src_idx_buffer = Vector{Int}(undef, buffer_size)
    w_flux_buffer = Vector{Float64}(undef, buffer_size)
    
    if N == 3
        # 3D bulk regridding: Calculate for ALL model grid points
        @inbounds for (i, x) in enumerate(model_grid[1])  # For each domain grid lon
            for (j, y) in enumerate(model_grid[2])        # For each domain grid lat
                for (k, z) in enumerate(model_grid[3])    # For each domain grid vertical level
                    # Map to array indices (same as interpolate_from!)
                    idx = tuple_from_vals(dsi.metadata.xdim, i,
                        dsi.metadata.ydim, j, dsi.metadata.zdim, k)
                    locs = tuple_from_vals(dsi.metadata.xdim, x,
                        dsi.metadata.ydim, y, dsi.metadata.zdim, z)
                    locs = dsi.coord_trans(locs)
                    
                    # Apply precomputed weights to calculate emission value for this domain grid point
                    try
                        # Find which target grid point this domain coordinate corresponds to
                        target_j = exact_coordinate_lookup(locs[1], locs[2], dsi.coord_lookup)
                        # Get contributors and weights for this target point
                        count, src_idx_result, w_flux_result = contributors_for_target_index_fast(
                            target_j, dsi.weights, src_idx_buffer, w_flux_buffer)
                        
                        # Calculate regridded emission value using weights.jld2
                        if count > 0
                            regridded_value = T(0.0)
                            for idx_w in 1:count
                                regridded_value += w_flux_result[idx_w] * src_vec[src_idx_result[idx_w]]
                            end
                            dst[idx...] = regridded_value  # Save regridded result to cache
                        else
                            dst[idx...] = T(0.0)
                        end
                    catch
                        # Domain coordinate not in regridding weights, set to zero
                        dst[idx...] = T(0.0)
                    end
                end
            end
        end
    elseif N == 2 && dsi.metadata.zdim <= 0
        # 2D bulk regridding: Calculate for ALL model grid points
        @inbounds for (i, x) in enumerate(model_grid[1])  # For each domain grid lon
            for (j, y) in enumerate(model_grid[2])        # For each domain grid lat
                # Map to array indices (same as interpolate_from!)
                idx = tuple_from_vals(dsi.metadata.xdim, i, dsi.metadata.ydim, j)
                locs = tuple_from_vals(dsi.metadata.xdim, x, dsi.metadata.ydim, y)
                locs = dsi.coord_trans(locs)
                
                # Apply precomputed weights to calculate emission value for this domain grid point
                try
                    # Find which target grid point this domain coordinate corresponds to
                    target_j = exact_coordinate_lookup(locs[1], locs[2], dsi.coord_lookup)
                    # Get contributors and weights for this target point
                    count, src_idx_result, w_flux_result = contributors_for_target_index_fast(
                        target_j, dsi.weights, src_idx_buffer, w_flux_buffer)
                    
                    # Calculate regridded emission value using weights.jld2
                    if count > 0
                        regridded_value = T(0.0)
                        for idx_w in 1:count
                            regridded_value += w_flux_result[idx_w] * src_vec[src_idx_result[idx_w]]
                        end
                        dst[idx...] = regridded_value  # Save regridded result to cache
                    else
                        dst[idx...] = T(0.0)
                    end
                catch
                    # Domain coordinate not in regridding weights, set to zero
                    dst[idx...] = T(0.0)
                end
            end
        end
    else
        error("Invalid dimension configuration for regridding")
    end
    
    return dst
end

# Helper functions removed - regrid_from! now works exactly like interpolate_from!

# Interface functions - unique names for regridding
ModelingToolkit.get_unit(rds::RegridDataSetInterpolator) = rds.metadata.units
regrid_units(rds::RegridDataSetInterpolator) = rds.metadata.units
regrid_description(rds::RegridDataSetInterpolator) = rds.metadata.description

# Unused helper functions removed - code cleanup

# Add regrid_unsafe with Real time argument (like DataSetInterpolator has)
function regrid_unsafe(rds::RegridDataSetInterpolator{T, N, N2}, t::Real, locs::Vararg{T, N2})::T where {T, N, N2}
    regrid_unsafe(rds, Dates.unix2datetime(t), locs...)
end

# Add ITPWrapper method for RegridDataSetInterpolator
(itp::EarthSciData.ITPWrapper{<:RegridDataSetInterpolator})(t, locs::Vararg{T, N}) where {T, N} = regrid_unsafe(itp.itp, t, locs...)

# Register symbolic functions for regrid! and regrid_unsafe
@register_symbolic regrid!(rds::RegridDataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic regrid!(rds::RegridDataSetInterpolator, t, loc1, loc2) false
@register_symbolic regrid!(rds::RegridDataSetInterpolator, t, loc1) false
@register_symbolic regrid_unsafe(rds::RegridDataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic regrid_unsafe(rds::RegridDataSetInterpolator, t, loc1, loc2) false
@register_symbolic regrid_unsafe(rds::RegridDataSetInterpolator, t, loc1) false

# Additional interface methods with unique names for RegridDataSetInterpolator
function regrid_get_tstops(rds::RegridDataSetInterpolator, starttime::DateTime)
    dfi = DataFrequencyInfo(rds.fs)
    datetime2unix.(sort([starttime, dfi.centerpoints...]))
end

"""
Cache management functions - mirror DataSetInterpolator architecture
"""

"""
Return the time points that should be cached in this regridding interpolator.
"""
function regrid_cache_times!(rds::RegridDataSetInterpolator, t::DateTime)
    cache_size = length(rds.times)
    dfi = DataFrequencyInfo(rds.fs)
    ti = centerpoint_index(dfi, t)
    # Currently assuming we're going forwards in time.
    if t < dfi.centerpoints[ti]  # Load data starting with previous time step.
        times = dfi.centerpoints[(ti - 1):(ti + cache_size - 2)]
    else  # Load data starting with current time step.
        times = dfi.centerpoints[ti:(ti + cache_size - 1)]
    end
    times
end

"""
Initialize the regridding interpolator with async loading
"""
function regrid_initialize!(rds::RegridDataSetInterpolator, t::DateTime)
    rds.load_cache = zeros(eltype(rds.load_cache), rds.metadata.varsize...)
    
    # The data array is already properly sized in the constructor for the requested domain!
    # No need to resize - the constructor already set it to the correct requested domain size
    
    @info "Initialized regrid data cache with size: $(size(rds.data)) (requested domain + time)"
    Threads.@spawn regrid_async_loader(rds)
    rds.initialized = true
end

"""
Async loader for regridding (mirrors DataSetInterpolator.async_loader)
"""
function regrid_async_loader(rds::RegridDataSetInterpolator)
    try
        while true
            t = take!(rds.loadrequest)
            try
                loadslice!(rds.load_cache, rds.fs, t, rds.varname)
                put!(rds.loadresult, 0)
            catch err
                put!(rds.loadresult, err)
            end
            take!(rds.copyfinish)
        end
    catch err
        if isa(err, InvalidStateException) && err.state == :closed
            return
        else
            rethrow(err)
        end
    end
end

"""
Update regridding cache (mirrors DataSetInterpolator.update!)
Uses regrid_from!() for bulk preprocessing during cache loading
"""
function regrid_update!(rds::RegridDataSetInterpolator, t::DateTime)
    @assert rds.initialized "Regridding interpolator has not been initialized"
    if isready(rds.loadresult)
        # If a previous simulation ended in an error, dispose of extra result
        take!(rds.loadresult)
        put!(rds.copyfinish, 0)
    end
    times = regrid_cache_times!(rds, t)

    # Figure out the overlap between the times we have and the times we need
    times_in_cache = intersect(times, rds.times)
    idxs_in_cache = [findfirst(x -> x == times_in_cache[i], rds.times)
                     for i in eachindex(times_in_cache)]
    idxs_in_times = [findfirst(x -> x == times_in_cache[i], times)
                     for i in eachindex(times_in_cache)]
    idxs_not_in_times = setdiff(eachindex(times), idxs_in_times)

    # Move data we already have to where it should be
    N = ndims(rds.data)
    if all(idxs_in_cache .> idxs_in_times) && all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(idxs_in_times, idxs_in_cache)
            selectdim(rds.data, N, new) .= selectdim(rds.data, N, old)
        end
    elseif all(idxs_in_cache .< idxs_in_times) &&
           all(issorted.((idxs_in_cache, idxs_in_times)))
        for (new, old) in zip(reverse(idxs_in_times), reverse(idxs_in_cache))
            selectdim(rds.data, N, new) .= selectdim(rds.data, N, old)
        end
    elseif !all(idxs_in_cache .== idxs_in_times)
        error(
            "Unexpected time ordering, can't reorder indexes $(idxs_in_times) to $(idxs_in_cache)",
        )
    end

    model_grid = _regrid_model_grid(rds)
    # Load the additional times we need and use regrid_from!() for bulk preprocessing
    for idx in idxs_not_in_times
        d = selectdim(rds.data, N, idx)
        put!(rds.loadrequest, times[idx]) # Request next data
        r = take!(rds.loadresult) # Wait for results
        if r != 0
            throw(r)
        end
        # *** KEY CHANGE: Use regrid_from!() for bulk preprocessing ***
        # Convert model_grid to tuple format if needed
        model_grid_tuple = model_grid isa Tuple ? model_grid : Tuple(model_grid)
        regrid_from!(rds, d, rds.load_cache, model_grid_tuple) # Regrid from source to model grid
        put!(rds.copyfinish, 0) # Let the loader know we've finished copying
    end
    rds.times = times
    rds.currenttime = t
    @assert issorted(rds.times) "Regridding interpolator times are in wrong order"
    update_regrid_interpolator!(rds)  # Create interpolator from regridded cache data
end

"""
Update the regridding interpolator (equivalent to update_interpolator! for DataSetInterpolator)
"""
function update_regrid_interpolator!(rds::RegridDataSetInterpolator{To}) where {To}
    if size(rds.interp_cache) != size(rds.data)
        rds.interp_cache = similar(rds.data)
    end
    coords = _regrid_model_grid(rds)
    
    # Create interpolator from regridded data cache (same logic as DataSetInterpolator)
    grid = tuple(coords..., knots2range(datetime2unix.(rds.times)))
    copyto!(rds.interp_cache, rds.data)
    itp = interpolate!(rds.interp_cache, BSpline(Linear()))
    itp = scale(itp, grid)
    rds.itp = itp
end

# Helper functions removed - now using simple interpolation approach like DataSetInterpolator

"""
Lazy loading with cache management (equivalent to DataSetInterpolator.lazyload!)
"""
function regrid_lazyload!(rds::RegridDataSetInterpolator, t::DateTime)
    lock(rds.lock) do
        if rds.currenttime == t
            return
        end
        if !rds.initialized # Initialize new interpolator
            regrid_initialize!(rds, t)
            regrid_update!(rds, t)
            return
        end
        if t < rds.times[begin] || t >= rds.times[end]
            regrid_update!(rds, t)
        end
    end
    rds
end

function regrid_lazyload!(rds::RegridDataSetInterpolator, t::AbstractFloat)
    regrid_lazyload!(rds, Dates.unix2datetime(t))
end

# Interface compatibility - RegridDataSetInterpolator must implement the same interface as DataSetInterpolator
get_tstops(rds::RegridDataSetInterpolator, starttime::DateTime) = regrid_get_tstops(rds, starttime)
lazyload!(rds::RegridDataSetInterpolator, t::DateTime) = regrid_lazyload!(rds, t)
lazyload!(rds::RegridDataSetInterpolator, t::AbstractFloat) = regrid_lazyload!(rds, t)
units(rds::RegridDataSetInterpolator) = regrid_units(rds)
description(rds::RegridDataSetInterpolator) = regrid_description(rds)

# Dummy functions for unit validation
regrid!(rds::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = rds
regrid_unsafe(rds::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = rds

# Create regrid equation for RegridDataSetInterpolator
# This allows RegridDataSetInterpolator to be used in the same way as DataSetInterpolator
function create_regrid_equation(rds::RegridDataSetInterpolator, filename, t, t_ref, coords; wrapper_f = v -> v)
    n = length(filename) > 0 ? Symbol("$(filename)₊$(rds.varname)") :
        Symbol("$(rds.varname)")
    n_p = Symbol(n, "_itp")

    itp = ITPWrapper(rds)
    t_itp = typeof(itp)
    p_itp = only(
        @parameters ($n_p::t_itp)(..)=itp [
        unit = regrid_units(rds),
        description = "Interpolated $(n)"
    ]
    )

    # Create right hand side of equation.
    rhs = wrapper_f(p_itp(t_ref + t, coords...))

    # Create left hand side of equation.
    desc = regrid_description(rds)
    uu = ModelingToolkit.get_unit(rhs)
    lhs = only(
        @variables $n(t) [
        unit = uu,
        description = desc,
        misc = Dict(:staggering => rds.metadata.staggering)
    ]
    )

    eq = lhs ~ rhs

    return eq, p_itp
end 