function get_polygons(d::DomainInfo{T}) where {T}
    x, y = EarthSciMLBase.grid(d, (true, true, true))[1:2] # Get grid edges.
    nx, ny = length(x) - 1, length(y) - 1
    # Use column-major (x-fastest) ordering to match vec() on data arrays
    polys = Vector{Vector{NTuple{2, T}}}(undef, nx*ny)
    for j in 1:ny, i in 1:nx

        polys[(j - 1) * nx + i] = [(x[i], y[j]), (x[i + 1], y[j]), (x[i + 1], y[j + 1]),
            (x[i], y[j + 1]), (x[i], y[j])]
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
        src::AbstractArray{T, N}, mta::MetaData, model_grid, domain;
        extrapolate_type = Flat()) where {T, N}
    data_grid = Tuple(knots2range.(mta.coords))
    padded_src, padded_grid = _pad_singletons(src, data_grid)
    itp = interpolate!(padded_src, BSpline(Linear()))
    itp = extrapolate(scale(itp, padded_grid), extrapolate_type)
    ct = coord_trans(mta, domain)
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
Callable regridder for staggered grids that interpolates a source field onto
the model grid. Typed fields keep the per-timestep call site statically
dispatched; the earlier closure-based implementation could capture its
variables with abstract types.
"""
struct InterpolatingRegridder{MT, MG, DT}
    metadata::MT
    model_grid::MG
    domain::DT
end

function (r::InterpolatingRegridder)(dst::AbstractArray, src::AbstractArray;
        extrapolate_type = Flat())
    interpolate_from!(dst, src, r.metadata, r.model_grid, r.domain;
        extrapolate_type = extrapolate_type)
end

"""
Callable regridder for non-staggered grids that uses `ConservativeRegridding`.
`extrapolate_type` is accepted for a uniform call signature but is unused here.
"""
struct ConservativeRegridderCallable{RG, MT}
    regridder::RG
    metadata::MT
end

function (r::ConservativeRegridderCallable)(dst::AbstractArray, src::AbstractArray;
        extrapolate_type = Flat())
    regrid_horizontal!(dst, r.regridder, src, r.metadata)
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
        return InterpolatingRegridder(metadata, model_grid, domain)
    else
        rg = horizontal_regridder(fs, metadata, domain)
        return ConservativeRegridderCallable(rg, metadata)
    end
end
