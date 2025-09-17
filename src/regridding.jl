using NCDatasets, SparseArrays, JLD2, Dates
using ModelingToolkit, DynamicQuantities

export regrid!

"""
Global cache for regridding weights to avoid loading them multiple times
"""
const REGRID_WEIGHTS_CACHE = Dict{String, Any}()

"""
Load regrid weights from JLD2 format (cached)
"""
function load_regrid_weights_cached(path::AbstractString)
    if !haskey(REGRID_WEIGHTS_CACHE, path)
        @info "Loading regridding weights from $path (first time)"
        REGRID_WEIGHTS_CACHE[path] = load(path, "weights")
    end
    return REGRID_WEIGHTS_CACHE[path]
end

# Find nearest destination cell index to (lon,lat) in radians
nearest_target_index(lon_rad::Real, lat_rad::Real, xc_b_rad, yc_b_rad) = begin
    argmin((xc_b_rad .- lon_rad).^2 .+ (yc_b_rad .- lat_rad).^2)
end

"""
contributors_for_target_index(j, weights) -> (src_idx::Vector{Int}, w_flux::Vector{Float64})
"""
function contributors_for_target_index(j::Integer, weights)
    fb = weights.frac_b[j]
    if fb <= eps()
        return Int[], Float64[]
    end
    sel = findall(==(j), weights.row)
    src_idx = weights.col[sel]
    w_flux  = weights.S[sel] ./ fb
    return src_idx, w_flux
end

"""
contributors_for_lonlat(lon_rad, lat_rad, weights) -> (j, src_idx, w_flux)
"""
function contributors_for_lonlat(lon_rad::Real, lat_rad::Real, weights)
    j = nearest_target_index(lon_rad, lat_rad, weights.xc_b, weights.yc_b)
    src_idx, w_flux = contributors_for_target_index(j, weights)
    return j, src_idx, w_flux
end

"""
RegridDataSetInterpolator - A DataSetInterpolator that uses regridding instead of interpolation
"""
mutable struct RegridDataSetInterpolator{To, N, N2, FT, WT}
    fs::FileSet
    varname::AbstractString
    data::Array{To, N}
    weights::WT  # Regridding weights
    metadata::Any
    domain::Any
    times::Vector{DateTime}
    currenttime::DateTime
    coord_trans::FT
    # Simplified - no async loading
    lock::ReentrantLock
    initialized::Bool

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
        weights = load_regrid_weights_cached(weights_path)
        
        # Simple data structure - just need to hold current data
        data = zeros(To, metadata.varsize..., 1)
        N = ndims(data)
        N2 = N - 1
        times = [DateTime(1, 1, 1)]
        
        coord_trans = (x) -> x
        FT = typeof(coord_trans)
        WT = typeof(weights)

        new{To, N, N2, FT, WT}(
            fs, varname, data, weights, metadata, domain,
            times, DateTime(1, 1, 1), coord_trans,
            ReentrantLock(), false
        )
    end
end

"""
regrid! - Replaces interp! function but uses regridding
"""
function regrid!(rds::RegridDataSetInterpolator{T, N, N2}, t::DateTime, locs::Vararg{T})::T where {T, N, N2}
    # Load data if needed
    regrid_lazyload!(rds, t)
    
    # Extract longitude and latitude coordinates
    # For NEI data (2D), we expect locs to be (lon, lat) or (lon, lat, lev)
    # We only use the first two coordinates for regridding
    if length(locs) < 2
        error("RegridDataSetInterpolator requires at least 2 spatial coordinates (lon, lat)")
    end
    
    # Coordinates come in as radians (EarthSciMLBase uses radians)
    # Regridding weights also use radians, so no conversion needed
    lon_rad = locs[1]  # Longitude in radians
    lat_rad = locs[2]  # Latitude in radians
    
    # Get current data and regrid
    current_data = selectdim(rds.data, N, 1)
    src_flux_vec = vec(current_data)
    
    j, src_idx, w_flux = contributors_for_lonlat(lon_rad, lat_rad, rds.weights)
    
    if isempty(src_idx)
        return T(0.0)
    else
        return T(sum(w_flux .* src_flux_vec[src_idx]))
    end
end

# Interface functions - unique names for regridding
ModelingToolkit.get_unit(rds::RegridDataSetInterpolator) = rds.metadata.units
regrid_units(rds::RegridDataSetInterpolator) = rds.metadata.units
regrid_description(rds::RegridDataSetInterpolator) = rds.metadata.description

# Add regrid_unsafe to match DataSetInterpolator interface (called by ITPWrapper)
# Handle variable number of coordinates - use first two for 2D regridding
function regrid_unsafe(rds::RegridDataSetInterpolator{T, N, N2}, t::DateTime, locs::Vararg{T, N2})::T where {T, N, N2}
    # For 2D NEI data, we only need the first two coordinates (lon, lat)
    # Additional coordinates (like vertical level) are ignored
    if N2 >= 2
        regrid!(rds, t, locs[1], locs[2])
    elseif N2 == 1
        error("RegridDataSetInterpolator requires at least 2 spatial coordinates (lon, lat)")
    else
        error("RegridDataSetInterpolator requires spatial coordinates")
    end
end

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

function regrid_lazyload!(rds::RegridDataSetInterpolator, t::DateTime)
    # For regridding, we just need to ensure data is loaded for the current time
    # No complex caching like DataSetInterpolator since we only store current timestep
    lock(rds.lock) do
        if rds.currenttime != t
            current_data = selectdim(rds.data, ndims(rds.data), 1)
            loadslice!(current_data, rds.fs, t, rds.varname)
            rds.currenttime = t
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