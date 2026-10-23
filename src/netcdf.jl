"""
Read the record of `varname` at time `t` into `data`. Without `box`, the full
array is read along every dimension other than `timedim`; with `box` (one index
range per non-time dimension, in file order), only that hyperslab is read and
`data` must have its size.
"""
function loadslice!(
        data::AbstractArray{T},
        fs::FileSet,
        ds::Union{NCDataset, NCDatasets.MFDataset},
        t::DateTime,
        varname::AbstractString,
        timedim::AbstractString,
        box::Union{Nothing, Tuple} = nothing
) where {T <: Number}
    var = ds[varname]
    dims = collect(NCDatasets.dimnames(var))
    @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
    time_index = findfirst(isequal(timedim), dims)
    # Load only one time step, and the full array (or `box`) for everything else.
    slices = repeat(Any[:], length(dims))
    if box !== nothing
        length(box) == length(dims) - 1 || throw(ArgumentError(
            "Read box $box for variable $varname needs one range per non-time dimension $(dims)."))
        slices[setdiff(eachindex(dims), time_index)] .= box
    end
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs), t)

    varsize = box === nothing ? deleteat!(collect(size(var)), time_index) :
              collect(length.(box))
    rightsize = (varsize == collect(size(data)))
    vartype = only(setdiff(Base.uniontypes(eltype(var)), [Missing]))
    righttype = (vartype == T)
    if rightsize && righttype
        # The data is already the correct size and type, so load in place.
        #NCDatasets.load!(var, data, data, slices...)
        data .= var[slices...] # Can't load in place with multi-file dataset.
    elseif rightsize && !righttype
        # The data is not the correct type, but is the correct size,
        # so we load it into a temporary array and then copy it
        #tmp = zeros(vartype, size(data)) # TODO(CT): Figure out how to avoid allocating the temporary array.
        #NCDatasets.load!(var, data, tmp, slices...)
        data .= vartype.(var[slices...]) # Can't load in place with multi-file dataset.
    else
        # The data is not the correct size.
        throw(ArgumentError("Data array is not the correct size for variable $varname."))
    end
    var
end

const nclock = ReentrantLock()
