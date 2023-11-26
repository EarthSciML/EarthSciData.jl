function loadslice!(data::Array{T}, fs::FileSet, ds::NCDataset, t::DateTime, varname::AbstractString, timedim::AbstractString)::Tuple{Any, Any, Array{T}} where {T<:Number}
    var = ds[varname]
    dims = collect(NCDatasets.dimnames(var))
    @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
    time_index = findfirst(isequal(timedim), dims)
    # Load only one time step, but the full array for everything else.
    slices = repeat(Any[:], length(dims))
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs, t), t)
    # TODO(CT): Attempted to load data in-place, but this is not working.
    # varsize = deleteat!(collect(size(var)), time_index)
    # rightsize = (varsize == collect(size(data)))
    # righttype = (eltype(var) == T)
    # if rightsize && righttype
    #     # The data is already the correct size and type, so 
    #     # load in place.
    #     @info "$varname rightsize && righttype"
    #     NCDatasets.load!(var, data, slices...)
    # elseif rightsize && !righttype
    #     @info "$varname rightsize && !righttype"
    #     # The data is not the correct type, but is the correct size,
    #     # so we load it into a temporary array and then copy it
    #     tmp = var[slices...]
    #     data .= tmp
    # else
    #     @info "$varname !(rightsize)"
    #     # The data is not the correct size, so just overwrite the 
    #     # original array (it is probably just the initial placeholder).
    #     data = var[slices...]
    # end
    data = var[slices...]
    return (var, deleteat!(dims, time_index), data)
end