function loadslice!(data::AbstractArray{T}, fs::FileSet, ds::NCDataset, t::DateTime, varname::AbstractString, timedim::AbstractString) where {T<:Number}
    var = ds[varname]
    dims = collect(NCDatasets.dimnames(var))
    @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
    time_index = findfirst(isequal(timedim), dims)
    # Load only one time step, but the full array for everything else.
    slices = repeat(Any[:], length(dims))
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs, t), t)

    varsize = deleteat!(collect(size(var)), time_index)
    rightsize = (varsize == collect(size(data)))
    vartype = only(setdiff(Base.uniontypes(eltype(var)), [Missing]))
    righttype = (vartype == T)
    if rightsize && righttype
        # The data is already the correct size and type, so 
        # load in place.
        NCDatasets.load!(var, data, data, slices...)
    elseif rightsize && !righttype
        # The data is not the correct type, but is the correct size,
        # so we load it into a temporary array and then copy it
        tmp = zeros(vartype, size(data)) # TODO(CT): Figure out how to avoid allocating the temporary array.
        NCDatasets.load!(var, data, tmp, slices...)
    else
        # The data is not the correct size.
        ArgumentError("Data array is not the correct size for variable $varname.")
    end
    var
end

function loadslice(fs::FileSet, ds::NCDataset, t::DateTime, varname::AbstractString, timedim::AbstractString)::Tuple{Any,Any,Array}
    var = ds[varname]
    dims = collect(NCDatasets.dimnames(var))
    @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
    time_index = findfirst(isequal(timedim), dims)
    # Load only one time step, but the full array for everything else.
    slices = repeat(Any[:], length(dims))
    slices[time_index] = centerpoint_index(DataFrequencyInfo(fs, t), t)
    data = var[slices...]
    return (var, deleteat!(dims, time_index), data)
end

const ncfiledict = Dict{String,NCDataset}()
const ncfilelist = Vector{String}()
const nclock = ReentrantLock()

" Get the NCDataset for the given file path, caching the last 20 files. "
function getnc(filepath::String)::NCDataset
    lock(nclock) do
        if haskey(ncfiledict, filepath)
            return ncfiledict[filepath]
        else
            ds = NCDataset(filepath)
            push!(ncfilelist, filepath)
            ncfiledict[filepath] = ds
            # if length(ncfilelist) > 20 #TODO(CT): Tests fail when this is uncommented, don't know why.
            #     fname = popfirst!(ncfilelist)
            #     close(ncfiledict[fname])
            #     delete!(ncfiledict, fname)
            # end
            return ds
        end
    end
end