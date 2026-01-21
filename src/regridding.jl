export regrid!, regrid_from!

# Module-level cache for regridding weights
const _weights_cache = Dict{Any, Any}()
const _weights_cache_lock = ReentrantLock()

"""
Helper function to compute edges from centers
"""
function edges_from_centers(c::AbstractVector{<:Real})
    n = length(c)
    @assert n ≥ 2
    e = similar(c, n+1)
    for i in 1:n-1
        e[i+1] = (c[i] + c[i+1]) / 2
    end
    e[1] = c[1] - (e[2]-c[1])
    e[end] = c[end] + (c[end]-e[end-1])
    if e[2] < e[1]
        reverse!(e)
    end
    return e
end

function get_polygons(d::DomainInfo{T}) where {T}
    x, y = EarthSciMLBase.grid(d, (true, true, true))[1:2] # Get grid edges.
    nx, ny = length(x) - 1, length(y) - 1
    polys = Vector{Vector{NTuple{2, T}}}(undef, nx*ny)
    for i in 1:nx, j in 1:ny
        polys[(i-1)*ny + j] = [(x[i], y[j]), (x[i+1], y[j]), (x[i+1], y[j+1]),
            (x[i], y[j+1]), (x[i], y[j])]
    end
    return polys
end

"""
Convert an N-D array to a 2-D matrix with where the horizontal dimensions are
rows and the vertical dimension is the columns. If the input is 2-D, it is converted
to a vector.
"""
function data2vecormat(d::AbstractArray{T, 3}, xdim, ydim) where {T}
    sz = size(d)
    idxs = 1:length(sz)
    non_horizontal_idxs = filter(i -> i != xdim && i != ydim, idxs)
    d = permutedims(d, vcat(xdim, ydim, non_horizontal_idxs))
    reshape(d, sz[xdim] * sz[ydim], :)
end

function data2vecormat(d::AbstractArray{T, 2}, xdim, ydim) where {T}
    d = permutedims(d, (xdim, ydim))
    reshape(d, :)
end

function horizontal_regridder(fs::FileSet, metadata::MetaData, domain::DomainInfo)
    model_grid = get_polygons(domain)
    ct = proj_trans(metadata, domain)
    for (i, poly) in enumerate(model_grid)
        # Transform model grid to native coordinate system
        # because the other direction doesn't currently work.
        model_grid[i] = ct.(poly)
    end
    data_grid = get_geometry(fs, metadata)
    ConservativeRegridding.Regridder(model_grid, data_grid)
end

function regrid_horizontal!(dst_field, regridder::ConservativeRegridding.Regridder, src_field, mta::MetaData)
    sz = size(dst_field)
    dst_field = reshape(dst_field, sz[1] * sz[2], :)
    src_2d = data2vecormat(src_field, mta.xdim, mta.ydim)
    ConservativeRegridding.regrid!(dst_field, regridder, src_2d)
    reshape(dst_field, sz...)
end

function interpolate_from!(dst::AbstractArray{T, N},
        src::AbstractArray{T, N}, mta::MetaData, model_grid; extrapolate_type = Flat()) where {T, N}
    data_grid = Tuple(knots2range.(mta.coords))
    mta.xdim, mta.ydim
    itp = interpolate!(src, BSpline(Linear()))
    itp = extrapolate(scale(itp, data_grid), extrapolate_type)
    ct = coord_trans(mta, model_grid)
    if N == 3
        for (i, x) in enumerate(model_grid[1])
            for (j, y) in enumerate(model_grid[2])
                for (k, z) in enumerate(model_grid[3])
                    idx = tuple_from_vals(mta.xdim, i,
                        mta.ydim, j, mta.zdim, k)
                    locs = tuple_from_vals(mta.xdim, x,
                        mta.ydim, y, mta.zdim, z)
                    locs = ct(locs)
                    dst[idx...] = itp(locs...)
                end
            end
        end
    elseif N == 2 && mta.zdim <= 0
        for (i, x) in enumerate(model_grid[1])
            for (j, y) in enumerate(model_grid[2])
                idx = tuple_from_vals(mta.xdim, i, mta.ydim, j)
                locs = tuple_from_vals(mta.xdim, x, mta.ydim, y)
                locs = ct(locs)
                dst[idx...] = itp(locs...)
            end
        end
    else
        error("Invalid dimension configuration")
    end
    dst
end

"""
Create a regridding function for the given file set, metadata, and domain.
If any dimensions are staggered, use interpolation; otherwise, use conservative regridding.
`extrapolate_type` specifies the extrapolation method for interpolation; it is only used
when interpolation is selected.
"""
function regridder(fs::FileSet, metadata::MetaData, domain::DomainInfo)
    if any(metadata.staggering) # Are any of the dimensions staggered?
        model_grid = EarthSciMLBase.grid(domain, metadata.staggering)
        regrid! = (dst::AbstractArray, src::AbstractArray; extrapolate_type = Flat()) -> begin
            interpolate_from!(dst, src, metadata, model_grid;
                extrapolate_type = extrapolate_type)
        end
    else
        regridder = horizontal_regridder(fs, metadata, domain)
        regrid! = (dst::AbstractArray, src::AbstractArray; extrapolate_type = Flat()) -> begin
            regrid_horizontal!(dst, regridder, src, metadata)
        end
    end
    return regrid!
end

"""
Build source grid polygons from NEI file set attributes
Returns polygons directly in LCC meters (native coordinate system)
"""
function build_source_grid_polygons_from_attributes(
    XORIG::Real, YORIG::Real, XCELL::Real, YCELL::Real,
    NCOLS::Integer, NROWS::Integer, native_sr::AbstractString
)
    x_edges = collect(XORIG : XCELL : XORIG + NCOLS*XCELL)
    y_edges = collect(YORIG : YCELL : YORIG + NROWS*YCELL)
    nx = length(x_edges) - 1
    ny = length(y_edges) - 1

    source_grid = Vector{Vector{Tuple{Float64, Float64}}}()
    for j in 1:ny
        y0, y1 = y_edges[j], y_edges[j+1]
        for i in 1:nx
            x0, x1 = x_edges[i], x_edges[i+1]
            # Keep polygons in LCC meters (native coordinate system)
            polygon = [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]
            push!(source_grid, polygon)
        end
    end

    return source_grid
end

"""
Build target grid polygons from domain coordinates
Converts target grid from lon-lat to LCC for physically correct weight computation.
Returns: target_grid (polygons in LCC), lon_centers_deg, lat_centers_deg (for indexing)
"""
function build_target_grid_polygons(domain_coords::Tuple, native_sr::AbstractString)
    lon_coords_rad, lat_coords_rad = domain_coords[1], domain_coords[2]

    lon_vec = collect(lon_coords_rad)
    lat_vec = collect(lat_coords_rad)

    lon_centers_deg = rad2deg.(lon_vec)
    lat_centers_deg = rad2deg.(lat_vec)

    lon_edges = edges_from_centers(lon_centers_deg)
    lat_edges = edges_from_centers(lat_centers_deg)

    nxi = length(lon_edges) - 1
    nyi = length(lat_edges) - 1

    # Create transformation from lon-lat to LCC
    geo_str = "+proj=longlat +datum=WGS84 +no_defs"
    geo_to_lcc = Proj.Transformation(geo_str, native_sr; always_xy=true)

    # Build target grid polygons in LCC meters (for physically correct weight computation)
    target_grid = Vector{Vector{Tuple{Float64, Float64}}}()
    for j in 1:nyi
        lat0, lat1 = lat_edges[j], lat_edges[j+1]
        for i in 1:nxi
            lon0, lon1 = lon_edges[i], lon_edges[i+1]
            # Project each corner from lon-lat to LCC
            # Note: After projection, the quadrilateral may not be rectangular
            x0, y0 = geo_to_lcc(lon0, lat0)
            x1, y1 = geo_to_lcc(lon1, lat0)
            x2, y2 = geo_to_lcc(lon1, lat1)
            x3, y3 = geo_to_lcc(lon0, lat1)
            # Match the example polygon construction exactly (even though it looks unusual)
            polygon = [(x0, y0), (x1, y0), (x2, y1), (x3, y3), (x0, y0)]
            push!(target_grid, polygon)
        end
    end

    # Compute centers from edges in lon-lat (for indexing/regridding operations)
    dst_lon_center_deg = Vector{Float64}(undef, length(target_grid))
    dst_lat_center_deg = Vector{Float64}(undef, length(target_grid))
    for j in 1:nyi
        for i in 1:nxi
            k = (j-1)*nxi + i
            dst_lon_center_deg[k] = (lon_edges[i] + lon_edges[i+1]) / 2
            dst_lat_center_deg[k] = (lat_edges[j] + lat_edges[j+1]) / 2
        end
    end

    return target_grid, dst_lon_center_deg, dst_lat_center_deg
end

"""
Compute regridding weights dynamically using ConservativeRegridding
Returns a NamedTuple with: row, col, S, frac_b, xc_b, yc_b, W
"""
function compute_regridding_weights(
    source_grid::Vector{Vector{Tuple{Float64, Float64}}},
    target_grid::Vector{Vector{Tuple{Float64, Float64}}},
    target_lon_centers_deg::Vector{Float64},
    target_lat_centers_deg::Vector{Float64}
)
    @info "Computing regrid weights for $(length(target_grid)) target cells (in LCC coordinates)..."

    # Compute weights in LCC coordinate system (physically correct for area calculations)
    R = ConservativeRegridding.Regridder(target_grid, source_grid; normalize=false)

    # Extract weight matrix (intersection areas in LCC coordinate system)
    W = if hasfield(typeof(R), :A)
        getfield(R, :A)
    else
        # Fallback: scan for SparseMatrixCSC
        fields = fieldnames(typeof(R))
        tmpW = nothing
        for f in fields
            val = getfield(R, f)
            if val isa SparseMatrixCSC
                tmpW = val
                break
            end
        end
        @assert tmpW !== nothing "Could not extract weight matrix from Regridder"
        tmpW
    end
    @assert W isa SparseMatrixCSC "Weight matrix must be sparse"

    row, col, S = findnz(W)
    frac_b = vec(sum(W, dims=2))

    xc_b_rad = deg2rad.(target_lon_centers_deg)
    yc_b_rad = deg2rad.(target_lat_centers_deg)

    @info "Regridder created: $(size(W)) with $(length(row)) non-zero weights"

    return (row=row, col=col, S=S, frac_b=frac_b, xc_b=xc_b_rad, yc_b=yc_b_rad, W=W)
end

"""
Generate a cache key for weights based on file set and domain
"""
function _weights_cache_key(fs::FileSet, domain)
    grid = EarthSciMLBase.grid(domain, (false, false, false))
    if length(grid) >= 2
        grid_hash = hash((grid[1], grid[2]))
        return (objectid(fs), grid_hash)
    else
        return (objectid(fs), hash(domain))
    end
end

"""
Compute regridding weights for a given domain dynamically
Thread-safe: uses double-checked locking to prevent duplicate computations
"""
function compute_weights_for_domain(fs::FileSet, metadata::MetaData, domain)
    cache_key = _weights_cache_key(fs, domain)

    lock(_weights_cache_lock) do
        if haskey(_weights_cache, cache_key)
            @debug "Reusing cached regridding weights"
            return _weights_cache[cache_key]
        end

        weights = lock(nclock) do
            if hasfield(typeof(fs), :ds) && fs.ds !== nothing
                if haskey(fs.ds.attrib, "XORIG") && haskey(fs.ds.attrib, "YORIG") &&
                   haskey(fs.ds.attrib, "XCELL") && haskey(fs.ds.attrib, "YCELL") &&
                   haskey(fs.ds.attrib, "NCOLS") && haskey(fs.ds.attrib, "NROWS")

                    XORIG = fs.ds.attrib["XORIG"]
                    YORIG = fs.ds.attrib["YORIG"]
                    XCELL = fs.ds.attrib["XCELL"]
                    YCELL = fs.ds.attrib["YCELL"]
                    NCOLS = fs.ds.attrib["NCOLS"]
                    NROWS = fs.ds.attrib["NROWS"]
                    native_sr = metadata.native_sr

                    source_grid = build_source_grid_polygons_from_attributes(
                        XORIG, YORIG, XCELL, YCELL, NCOLS, NROWS, native_sr
                    )

                    grid = EarthSciMLBase.grid(domain, (false, false, false))
                    if metadata.zdim <= 0
                        target_coords = (grid[1], grid[2])
                    else
                        target_coords = (grid[1], grid[2])
                    end

                    target_grid, target_lon_centers_deg, target_lat_centers_deg =
                        build_target_grid_polygons(target_coords, native_sr)

                    weights = compute_regridding_weights(
                        source_grid, target_grid, target_lon_centers_deg, target_lat_centers_deg
                    )

                    return weights
                else
                    error("File set does not have required NEI grid attributes")
                end
            else
                error("File set does not have a dataset (ds field) for dynamic weight computation")
            end
        end

        _weights_cache[cache_key] = weights
        return weights
    end
end

"""
RegridDataSetInterpolator - Conservative regridding with same architecture as DataSetInterpolator
"""
mutable struct RegridDataSetInterpolator{To, N, N2, FT, WT, DomT, ITPT}
    fs::FileSet
    varname::AbstractString
    data::Array{To, N}
    interp_cache::Array{To, N}
    itp::ITPT
    load_cache::Array{To, N2}
    weights::WT
    metadata::MetaData
    domain::DomT
    times::Vector{DateTime}
    currenttime::DateTime
    coord_trans::FT
    loadrequest::Channel{DateTime}
    loadresult::Channel
    copyfinish::Channel{Int}
    lock::ReentrantLock
    initialized::Bool

    function RegridDataSetInterpolator{To}(
            fs::FileSet,
            varname::AbstractString,
            starttime::DateTime,
            endtime::DateTime,
            domain;
            stream = true
    ) where {To <: Real}
        metadata = loadmetadata(fs, varname)
        weights = compute_weights_for_domain(fs, metadata, domain)

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
        grid = EarthSciMLBase.grid(domain, metadata.staggering)
        if metadata.zdim <= 0
            domain_dims = length.(grid[1:2])
        else
            domain_dims = length.(grid)
        end
        # Start with dummy size like DataSetInterpolator, will be resized in initialize!
        data = zeros(To, repeat([2], length(domain_dims))..., cache_size)
        interp_cache = similar(data)
        N = ndims(data)
        N2 = N - 1
        times = [DateTime(0, 1, 1) + Hour(i) for i in 1:cache_size]

        _, itp2 = create_interpolator!(
            interp_cache,
            data,
            repeat([0:0.1:0.1], length(domain_dims)),
            times
        )
        ITPT = typeof(itp2)

        coord_trans = (x) -> x  # No coordinate transformation needed for regridding
        FT = typeof(coord_trans)
        WT = typeof(weights)
        DomT = typeof(domain)

        new{To, N, N2, FT, WT, DomT, ITPT}(
            fs, varname, data, interp_cache, itp2, load_cache, weights, metadata, domain,
            times, DateTime(1, 1, 1), coord_trans,
            Channel{DateTime}(0),
            Channel(1),
            Channel{Int}(0),
            ReentrantLock(), false
        )
    end
end

function Base.show(io::IO, itp::RegridDataSetInterpolator)
    print(io, "RegridDataSetInterpolator{$(typeof(itp.fs)), $(itp.varname)}")
end

ModelingToolkit.get_unit(rds::RegridDataSetInterpolator) = rds.metadata.unit_str
regrid_units(rds::RegridDataSetInterpolator) = rds.metadata.unit_str
regrid_description(rds::RegridDataSetInterpolator) = rds.metadata.description

"""
Get model grid coordinates for regridding (same format as _model_grid in load.jl)
"""
function _regrid_model_grid(rds::RegridDataSetInterpolator)
    grid = EarthSciMLBase.grid(rds.domain, rds.metadata.staggering)
    if length(rds.metadata.varsize) == 2 && rds.metadata.zdim <= 0
        grid_size = tuple_from_vals(rds.metadata.xdim, grid[1], rds.metadata.ydim, grid[2])
    elseif length(rds.metadata.varsize) == 3
        grid_size = tuple_from_vals(
            rds.metadata.xdim,
            grid[1],
            rds.metadata.ydim,
            grid[2],
            rds.metadata.zdim,
            grid[3]
        )
    else
        error("Invalid data size")
    end
    return grid_size
end

"""
Conservative regridding function that transforms data from source grid to destination grid.
Uses vectorized operations with precomputed weights for maximum performance.
"""
function regrid_from!(dsi::RegridDataSetInterpolator, dst::AbstractArray{T, N},
        src::AbstractArray{T, N}, model_grid, extrapolate_type = 0.0) where {T, N}

    src_vec = vec(src)
    W = dsi.weights.W
    frac_b = dsi.weights.frac_b

    # Vectorized regridding: W * src_vec / frac_b
    dst_vec = (W * src_vec) ./ max.(frac_b, eps())

    # Reshape to destination dimensions
    if N == 3
        nxi, nyi = length(model_grid[1]), length(model_grid[2])
        dst_2d = reshape(dst_vec, nxi, nyi)
        for (i, x) in enumerate(model_grid[1])
            for (j, y) in enumerate(model_grid[2])
                idx = tuple_from_vals(dsi.metadata.xdim, i, dsi.metadata.ydim, j)
                for (k, z) in enumerate(model_grid[3])
                    idx_full = tuple_from_vals(dsi.metadata.xdim, i,
                        dsi.metadata.ydim, j, dsi.metadata.zdim, k)
                    dst[idx_full...] = dst_2d[idx[1], idx[2]]
                end
            end
        end
    elseif N == 2 && dsi.metadata.zdim <= 0
        nxi, nyi = length(model_grid[1]), length(model_grid[2])
        dst_2d = reshape(dst_vec, nxi, nyi)
        for (i, x) in enumerate(model_grid[1])
            for (j, y) in enumerate(model_grid[2])
                idx = tuple_from_vals(dsi.metadata.xdim, i, dsi.metadata.ydim, j)
                dst[idx...] = dst_2d[i, j]
            end
        end
    else
        error("Invalid dimension configuration for regridding")
    end

    return dst
end

function initialize!(rds::RegridDataSetInterpolator, t::DateTime)
    rds.load_cache = zeros(eltype(rds.load_cache), rds.metadata.varsize...)
    grid_size = length.(_regrid_model_grid(rds))
    rds.data = zeros(eltype(rds.data), grid_size..., size(rds.data, length(size(rds.data))))
    Threads.@spawn regrid_async_loader(rds)
    rds.initialized = true
end

function regrid_async_loader(rds::RegridDataSetInterpolator)
    try
        while true
            t = take!(rds.loadrequest)
            if t != DateTime(0, 1, 10)
                try
                    loadslice!(rds.load_cache, rds.fs, t, rds.varname)
                catch err
                    @error err
                    put!(rds.loadresult, err)
                    rethrow(err)
                end
            end
            put!(rds.loadresult, 0)
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

function update!(rds::RegridDataSetInterpolator, t::DateTime)
    @assert rds.initialized "Regridding interpolator has not been initialized"
    if isready(rds.loadresult)
        take!(rds.loadresult)
        put!(rds.copyfinish, 0)
    end
    times = regrid_cache_times!(rds, t)

    times_in_cache = intersect(times, rds.times)
    idxs_in_cache = [findfirst(x -> x == times_in_cache[i], rds.times)
                     for i in eachindex(times_in_cache)]
    idxs_in_times = [findfirst(x -> x == times_in_cache[i], times)
                     for i in eachindex(times_in_cache)]
    idxs_not_in_times = setdiff(eachindex(times), idxs_in_times)

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

    model_grid = EarthSciMLBase.grid(rds.domain, rds.metadata.staggering)
    for idx in idxs_not_in_times
        d = selectdim(rds.data, N, idx)
        put!(rds.loadrequest, times[idx])
        r = take!(rds.loadresult)
        if r != 0
            throw(r)
        end
        regrid_from!(rds, d, rds.load_cache, model_grid)
        put!(rds.copyfinish, 0)
    end
    rds.times = times
    rds.currenttime = t
    @assert issorted(rds.times) "Regridding interpolator times are in wrong order"
    update_regrid_interpolator!(rds)
end

function update_regrid_interpolator!(rds::RegridDataSetInterpolator{To}) where {To}
    if size(rds.interp_cache) != size(rds.data)
        rds.interp_cache = similar(rds.data)
    end
    coords = _regrid_model_grid(rds)
    grid, itp2 = create_interpolator!(rds.interp_cache, rds.data, coords, rds.times)
    @assert all([length(g) for g in grid] .== size(rds.data)) "invalid data size: $([length(g) for g in grid]) != $(size(rds.data))"
    rds.itp = itp2
end

function regrid_cache_times!(rds::RegridDataSetInterpolator, t::DateTime)
    cache_size = length(rds.times)
    dfi = DataFrequencyInfo(rds.fs)
    ti = centerpoint_index(dfi, t)
    if t < dfi.centerpoints[ti]
        times = dfi.centerpoints[(ti - 1):(ti + cache_size - 2)]
    else
        times = dfi.centerpoints[ti:(ti + cache_size - 1)]
    end
    times
end

function lazyload!(rds::RegridDataSetInterpolator, t::DateTime)
    lock(rds.lock) do
        if rds.currenttime == t
            return
        end
        if !rds.initialized
            initialize!(rds, t)
            update!(rds, t)
            return
        end
        if t < rds.times[begin] || t >= rds.times[end]
            update!(rds, t)
        end
    end
    rds
end
function lazyload!(rds::RegridDataSetInterpolator, t::AbstractFloat)
    lazyload!(rds, Dates.unix2datetime(t))
end

function regrid!(
        rds::RegridDataSetInterpolator{T, N, N2},
        t::DateTime,
        locs::Vararg{T, N2}
)::T where {T, N, N2}
    lazyload!(rds, t)
    regrid_unsafe(rds, t, locs...)
end

@generated function regrid_unsafe(
        rds::RegridDataSetInterpolator{T1, N, N2},
        t::DateTime,
        locs::Vararg{T2, N2}
) where {T1, T2, N, N2}
    if N2 == N - 1
        quote
            try
                rds.itp(locs..., datetime2unix(t))
            catch err
                @warn "Regridding for $(rds.varname) failed at t=$(t), locs=$(locs); trying to update interpolator."
                lazyload!(rds, t)
                rds.itp(locs..., datetime2unix(t))
            end
        end
    else
        throw(ArgumentError("N2 must be equal to N-1"))
    end
end

function regrid!(rds::RegridDataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    regrid!(rds, Dates.unix2datetime(t), locs...)
end
function regrid_unsafe(
        rds::RegridDataSetInterpolator, t::Real, locs::Vararg{T, N})::T where {T, N}
    regrid_unsafe(rds, Dates.unix2datetime(t), locs...)
end

regrid!(rds::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = rds
regrid_unsafe(rds::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = rds

@register_symbolic regrid!(rds::RegridDataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic regrid!(rds::RegridDataSetInterpolator, t, loc1, loc2) false
@register_symbolic regrid!(rds::RegridDataSetInterpolator, t, loc1) false
@register_symbolic regrid_unsafe(rds::RegridDataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic regrid_unsafe(rds::RegridDataSetInterpolator, t, loc1, loc2) false
@register_symbolic regrid_unsafe(rds::RegridDataSetInterpolator, t, loc1) false

function get_tstops(rds::RegridDataSetInterpolator, starttime::DateTime)
    dfi = DataFrequencyInfo(rds.fs)
    datetime2unix.(sort([starttime, dfi.centerpoints...]))
end

units(rds::RegridDataSetInterpolator) =  to_unit(regrid_units(rds))[2]
description(rds::RegridDataSetInterpolator) = regrid_description(rds)

# Add method for RegridDataSetInterpolator to existing ITPWrapper from load.jl
(itp::ITPWrapper{<:RegridDataSetInterpolator})(t, locs::Vararg{T, N}) where {T, N} = regrid_unsafe(itp.itp, t, locs...)

function create_regrid_equation(rds::RegridDataSetInterpolator, filename, t, t_ref, coords; wrapper_f = v -> v)
    n = length(filename) > 0 ? Symbol("$(filename)₊$(rds.varname)") :
        Symbol("$(rds.varname)")
    n_p = Symbol(n, "_itp")

    itp = ITPWrapper(rds)
    t_itp = typeof(itp)
    p_itp = only(
        @parameters ($n_p::t_itp)(..)=itp [
        unit = units(rds),
        description = "Regridded $(n)"
    ]
    )

    rhs = wrapper_f(p_itp(t_ref + t, coords...))

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
