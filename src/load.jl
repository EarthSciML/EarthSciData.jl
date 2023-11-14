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
- `localpath(fs::GEOSFPFileSet, t::DateTime)`
- `DataFrequencyInfo(fs::GEOSFPFileSet, t::DateTime)::DataFrequencyInfo`
- `loadslice(fs::GEOSFPFileSet, t::DateTime, varname)::DataArray`
- `load_interpolator(fs::GEOSFPFileSet, t::DateTime, varname)`
- `varnames(fs::GEOSFPFileSet, t::DateTime)`
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
An array of data.

$(FIELDS)
"""
struct DataArray
    "The data."
    data::AbstractArray
    "Physical units of the data, e.g. m s⁻¹."
    units::Unitful.Unitlike
    "Description of the data."
    description::AbstractString
    "Dimensions of the data, e.g. (lat, lon, layer)."
    dimnames::AbstractVector
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
    @assert sum(t_index) == 1 "Expected exactly one time step to match."
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
"""
mutable struct DataSetInterpolator
    fs::FileSet
    varname
    itp1
    data1
    time1
    itp2
    data2
    time2
    @atomic currenttime
    lock::ReentrantLock
    kwargs

    DataSetInterpolator(fs::FileSet, varname; kwargs...) = new(fs, varname, nothing, nothing,
        nothing, nothing, nothing, nothing, nothing, ReentrantLock(), kwargs)
end

function Base.show(io::IO, itp::DataSetInterpolator)
    print(io, "DataSetInterpolator{$(typeof(itp.fs)), $(itp.varname)}")
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(typeof(itp.fs))ₓ$(itp.varname)_interp"
end

""" Return the units of the data. """
ModelingToolkit.get_unit(itp::DataSetInterpolator) = itp.data1.units

function initialize!(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs, t)
    centerpoint = ti.centerpoints[centerpoint_index(ti, t)]
    if t < centerpoint # Load data for current and previous time step.
        itp.time2 = ti.centerpoints[centerpoint_index(ti, t)]
        if itp.time2 == itp.time1
            itp.itp2, itp.data2 = itp.itp1, itp.data1
        else
            itp.itp2, itp.data2 = load_interpolator(itp.fs, t, itp.varname; itp.kwargs...)
        end
        ti_minus = DataFrequencyInfo(itp.fs, t - ti.frequency)
        itp.time1 = ti_minus.centerpoints[centerpoint_index(ti_minus, t - ti.frequency)]
        itp.itp1, itp.data1 = load_interpolator(itp.fs, t - ti.frequency, itp.varname; itp.kwargs...)
    else # Load data for current and next time step.
        itp.time1 = ti.centerpoints[centerpoint_index(ti, t)]
        if itp.time1 == itp.time2
            itp.itp1, itp.data1 = itp.itp2, itp.data2
        else
            itp.itp1, itp.data1 = load_interpolator(itp.fs, t, itp.varname; itp.kwargs...)
        end
        ti_plus = DataFrequencyInfo(itp.fs, t + ti.frequency)
        itp.itp2, itp.data2 = load_interpolator(itp.fs, t + ti.frequency, itp.varname; itp.kwargs...)
        itp.time2 = ti_plus.centerpoints[centerpoint_index(ti_plus, t + ti.frequency)]
    end
    @assert itp.time1 < itp.time2 "Interpolator times are in wrong order"
end

function lazyload!(itp::DataSetInterpolator, t::DateTime)
    lock(itp.lock) do
        if itp.currenttime == t
            return
        end
        @atomic itp.currenttime = t
        if itp.itp1 === nothing # Initialize new interpolator.
            initialize!(itp, t)
            return
        end
        if t <= itp.time1 || t > itp.time2
            @info "Updating data loader for $(itp.varname) for t = $t"
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
    itp.data1.dimnames
end

"""
$(SIGNATURES)

Return the units of the data associated with this interpolator.
"""
function units(itp::DataSetInterpolator, t::DateTime)
    lazyload!(itp, t)
    itp.data1.units
end

"""
$(SIGNATURES)

Return the description of the data associated with this interpolator.
"""
function description(itp::DataSetInterpolator, t::DateTime)
    lazyload!(itp, t)
    itp.data1.description
end

"""
$(SIGNATURES)

Return the value of the given variable from the given dataset at the given time and location.
"""
function interp!(itp::DataSetInterpolator, t::DateTime, locs...)
    lazyload!(itp, t)
    interp_unsafe(itp, t, locs...)
end

"""
Interpolate without checking if the data has been correctly loaded for the given time.
"""
function interp_unsafe(itp::DataSetInterpolator, t::DateTime, locs...)
    t_frac = (t - itp.time1) / (itp.time2 - itp.time1)
    val = itp.itp2(locs...) * t_frac + itp.itp1(locs...) * (1 - t_frac)
end

"""
Interpolation with a unix timestamp.
"""
interp!(itp::DataSetInterpolator, t::AbstractFloat, locs...) = interp!(itp, Dates.unix2datetime(t), locs...)
interp_unsafe(itp::DataSetInterpolator, t::AbstractFloat, locs...) = interp_unsafe(itp, Dates.unix2datetime(t), locs...)

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
The RHS of each equation will be multiplied by the optional `scale`.
"""
function create_interp_equation(itp::DataSetInterpolator, filename, t, sample_time, coords, scale=1)
    desc = description(itp, sample_time)
    uu = units(itp, sample_time) * ModelingToolkit.get_unit(scale)
    n = Symbol("$(filename)₊$(itp.varname)")
    lhs = only(@variables $n(t) [unit = uu, description = desc])

    # Create equation.
    if length(coords) == 3
        return lhs ~ interp!(itp, t, coords[1], coords[2], coords[3]) * scale
    elseif length(coords) == 2
        return lhs ~ interp!(itp, t, coords[1], coords[2]) * scale
    elseif length(coords) == 1
        return lhs ~ interp!(itp, t, coords[1]) * scale
    else
        error("Unexpected number of coordinates: $(length(coords))")
    end
end