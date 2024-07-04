export interp!

download_cache = ""
function __init__()
    global download_cache = ("EARTHSCIDATADIR" ∈ keys(ENV)) ? ENV["EARTHSCIDATADIR"] : @get_scratch!("earthsci_data")
end

"""
An interface for types describing a dataset, potentially comprised of multiple files.

To satisfy this interface, a type must implement the following methods:
- `relpath(fs::FileSet, t::DateTime)`
- `url(fs::FileSet, t::DateTime)`
- `localpath(fs::FileSet, t::DateTime)`
- `DataFrequencyInfo(fs::FileSet, t::DateTime)::DataFrequencyInfo`
- `loadslice(fs::FileSet, t::DateTime, varname)::(AbstractArray, MetaData)`
- `loadslice!(cache::AbstractArray, fs::FileSet, t::DateTime, varname)`
- `varnames(fs::FileSet, t::DateTime)`
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
            update!(prog, now)
        end)
    catch e # Delete partially downloaded file if an error occurs.
        rm(p)
        throw(e)
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
    units::Unitful.Unitlike
    "Description of the data."
    description::AbstractString
    "Dimensions of the data, e.g. (lat, lon, layer)."
    dimnames::AbstractVector
    "The spatial reference system of the data, e.g. \"EPSG:4326\" for lat-lon data."
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
    eps = endpoints(t_info)
    t_index = ((ep) -> ep[1] <= t < ep[2]).(eps)
    @assert sum(t_index) == 1 "Expected exactly one time step to match, instead $(sum(t_index)) timesteps match."
    argmax(t_index)
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
"""
mutable struct DataSetInterpolator{To,N,N2,FT}
    fs::FileSet
    varname::AbstractString
    grid::GridInterpolations.RectangleGrid{N}
    gridmin::SVector{N2,To}
    gridmax::SVector{N2,To}
    data::Array{To,N}
    metadata::MetaData
    times::Vector{DateTime}
    currenttime::DateTime
    coord_trans::FT
    lock::ReentrantLock
    initialized::Bool
    kwargs

    function DataSetInterpolator{To}(fs::FileSet, varname::AbstractString, default_time::DateTime; spatial_ref="EPSG:4326", kwargs...) where {To<:Real}
        data, metadata = loadslice(fs, default_time, varname; kwargs...)
        data = cat(data, data, dims=ndims(data) + 1) # Add a dimesion for time.
        N = ndims(data)
        N2 = N - 1
        times = [DateTime(0, 1, 1), DateTime(0, 2, 1)]
        grid = RectangleGrid(metadata.coords..., datetime2unix.(times))
        gridmin = minimum.(grid.cutPoints[1:end-1])
        gridmax = maximum.(grid.cutPoints[1:end-1])

        if spatial_ref == metadata.native_sr
            coord_trans = (x) -> x # No transformation needed.
        else
            t = Proj.Transformation(spatial_ref, metadata.native_sr, always_xy=true)
            coord_trans = (locs) -> begin
                x, y = t(locs[metadata.xdim], locs[metadata.ydim])
                replace_in_tuple(locs, metadata.xdim, To(x), metadata.ydim, To(y))
            end
        end
        FT = typeof(coord_trans)

        new{To,N,N2,FT}(fs, varname, grid, gridmin, gridmax, data, metadata, times,
            DateTime(1, 1, 1), coord_trans, ReentrantLock(), false, kwargs)
    end
end

function replace_in_tuple(t::NTuple{N, T}, index1::Int, v1::T, index2::Int, v2::T) where {T,N}
    ntuple(i -> i == index1 ? v1 : i == index2 ? v2 : t[i], N)
end

function Base.show(io::IO, itp::DataSetInterpolator)
    print(io, "DataSetInterpolator{$(typeof(itp.fs)), $(itp.varname)}")
end

""" Return the units of the data. """
ModelingToolkit.get_unit(itp::DataSetInterpolator) = itp.metadata.units

function initialize!(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs, t)
    centerpoint = ti.centerpoints[centerpoint_index(ti, t)]
    N = ndims(itp.data)
    if t < centerpoint # Load data for current and previous time step.
        itp.times[2] = ti.centerpoints[centerpoint_index(ti, t)]
        if itp.times[2] == itp.times[1]
            selectdim(itp.data, N, 2) .= selectdim(itp.data, N, 1)
        else
            d = selectdim(itp.data, N, 2)
            loadslice!(d, itp.fs, t, itp.varname; itp.kwargs...)
        end
        ti_minus = DataFrequencyInfo(itp.fs, t - ti.frequency)
        itp.times[1] = ti_minus.centerpoints[centerpoint_index(ti_minus, t - ti.frequency)]
        d = selectdim(itp.data, N, 1)
        loadslice!(d, itp.fs, t - ti.frequency, itp.varname; itp.kwargs...)
    else # Load data for current and next time step.
        itp.times[1] = ti.centerpoints[centerpoint_index(ti, t)]
        if itp.times[1] == itp.times[2]
            selectdim(itp.data, N, 1) .= selectdim(itp.data, N, 2)
        else
            d = selectdim(itp.data, N, 1)
            loadslice!(d, itp.fs, t, itp.varname; itp.kwargs...)
        end
        ti_plus = DataFrequencyInfo(itp.fs, t + ti.frequency)
        d = selectdim(itp.data, N, 2)
        loadslice!(d, itp.fs, t + ti.frequency, itp.varname; itp.kwargs...)
        itp.times[2] = ti_plus.centerpoints[centerpoint_index(ti_plus, t + ti.frequency)]
    end
    itp.grid = RectangleGrid(itp.metadata.coords..., datetime2unix.(itp.times))
    @assert issorted(itp.times) "Interpolator times are in wrong order"
end

function lazyload!(itp::DataSetInterpolator, t::DateTime)
    lock(itp.lock) do
        if itp.currenttime == t
            return
        end
        itp.currenttime = t
        if !itp.initialized # Initialize new interpolator.
            initialize!(itp, t)
            itp.initialized = true
            return
        end
        if t <= itp.times[1] || t > itp.times[2]
            # @info "Updating data loader for $(itp.varname) for t = $t"
            initialize!(itp, t)
        end
    end
end
lazyload!(itp::DataSetInterpolator, t::Float64) = lazyload!(itp, Dates.unix2datetime(t))

"""
$(SIGNATURES)

Return the dimension names associated with this interpolator.
"""
function dimnames(itp::DataSetInterpolator, t::DateTime)
    lazyload!(itp, t)
    itp.metadata.dimnames
end

"""
$(SIGNATURES)

Return the units of the data associated with this interpolator.
"""
function units(itp::DataSetInterpolator, t::DateTime)
    lazyload!(itp, t)
    itp.metadata.units
end

"""
$(SIGNATURES)

Return the description of the data associated with this interpolator.
"""
function description(itp::DataSetInterpolator, t::DateTime)
    lazyload!(itp, t)
    itp.metadata.description
end

"""
$(SIGNATURES)

Return the value of the given variable from the given dataset at the given time and location.
"""
function interp!(itp::DataSetInterpolator{T,N,N2,FT}, t::DateTime, locs::Vararg{T,N2})::T where {T,N,N2,FT}
    lazyload!(itp, t)
    interp_unsafe(itp, t, locs...)
end

"""
Interpolate without checking if the data has been correctly loaded for the given time.
"""
@generated function interp_unsafe(itp::DataSetInterpolator{T,N,N2,FT}, t::DateTime, locs::Vararg{T,N2})::T where {T,N,N2,FT}
    if N2 == N - 1 # Number of locs has to be one less than the number of data dimensions so we can add the time in.
        quote
            locs = itp.coord_trans(locs)
            if any(locs .< itp.gridmin) || any(locs .> itp.gridmax)
                # Return zero if extrapolating.
                return zero(eltype(itp.data))
            end
            locs = SVector{N,T}(locs..., datetime2unix(t)) # Add time to the location.
            interpolate(itp.grid, itp.data, locs)
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
# will call the function with a Unitful.Quantity or an integer to 
# get information about the type and units of the output.
interp!(itp::Union{Unitful.Quantity,Real}, t, locs...) = itp

# Symbolic tracing, for different numbers of dimensions (up to three dimensions).
@register_symbolic interp!(itp::DataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic interp!(itp::DataSetInterpolator, t, loc1, loc2) false
@register_symbolic interp!(itp::DataSetInterpolator, t, loc1) false

"""
$(SIGNATURES)

Create an equation that interpolates the given dataset at the given time and location.
`filename` is an identifier for the dataset, and `t` is the time variable. 
`wrapper_f` can specify a function to wrap the interpolated value, for example `eq -> eq / 2`
to divide the interpolated value by 2.
"""
function create_interp_equation(itp::DataSetInterpolator, filename, t, sample_time, coords; wrapper_f=v -> v)
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
    desc = description(itp, sample_time)
    uu = ModelingToolkit.get_unit(rhs)
    n = Symbol("$(filename)₊$(itp.varname)")
    lhs = only(@variables $n(t) [unit = uu, description = desc])
    lhs ~ rhs
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(typeof(itp.fs))ₓ$(itp.varname)_interp"
end