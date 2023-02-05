export interp!

# Get the directory for storing data
function esmldatadir()
    ("ESMLDATADIR" ∈ keys(ENV)) ? ENV["ESMLDATADIR"] : "./ESMLData"
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
        # TODO(CT): Progress bar doesn't seem to be working correctly.
        Downloads.download(u, p, progress=(total::Integer, now::Integer) -> 
                @info("Downloading $u to $(realpath(esmldatadir()))...",
                    _id = :EarthSciDataDownload,
                    progress = total > 0 ? now/total : 0.0))
    catch e # Delete partially downloaded file if an error occurs.
        rm(p)
        e
    end
    @info("Downloading $u to $(realpath(esmldatadir()))...",
        _id = :EarthSciDataDownload,
        progress="done")
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
    units::AbstractString
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
    frequency::Union{Dates.Period, Dates.CompoundPeriod}
    "Time representing the temporal center of each record."
    centerpoints::AbstractVector
end

"""
Return the time endpoints correcponding to each centerpoint
"""
endpoints(t::DataFrequencyInfo) = [(cp - t.frequency/2, cp + t.frequency/2) for cp in t.centerpoints]

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
during the simulation and cached on the hard drive at the path specified by the `\\\$ESMLDATADIR`
environment variable. The interpolator will also cache data in memory representing the 
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
    currenttime

    DataSetInterpolator(fs::FileSet, varname) = new(fs, varname, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
end

function Base.show(io::IO, itp::DataSetInterpolator)
    print(io, "DataSetInterpolator{$(typeof(itp.fs)), $(itp.varname)}")
end

function initialize!(itp::DataSetInterpolator, t::DateTime)
    ti = DataFrequencyInfo(itp.fs, t)
    centerpoint = ti.centerpoints[centerpoint_index(ti, t)]
    if t < centerpoint # Load data for current and previous time step.
        itp.time2 = ti.centerpoints[centerpoint_index(ti, t)]
        if itp.time2 == itp.time1
            itp.itp2, itp.data2 = itp.itp1, itp.data1
        else
            itp.itp2, itp.data2 = load_interpolator(itp.fs, t, itp.varname)
        end
        ti_minus = DataFrequencyInfo(itp.fs, t - ti.frequency)
        itp.time1 = ti_minus.centerpoints[centerpoint_index(ti_minus, t - ti.frequency)]
        itp.itp1, itp.data1 = load_interpolator(itp.fs, t - ti.frequency, itp.varname)
    else # Load data for current and next time step.
        itp.time1 = ti.centerpoints[centerpoint_index(ti, t)]
        if itp.time1 == itp.time2
            itp.itp1, itp.data1 = itp.itp2, itp.data2
        else
            itp.itp1, itp.data1 = load_interpolator(itp.fs, t, itp.varname)
        end
        ti_plus = DataFrequencyInfo(itp.fs, t + ti.frequency)
        itp.itp2, itp.data2 = load_interpolator(itp.fs, t + ti.frequency, itp.varname)
        itp.time2 = ti_plus.centerpoints[centerpoint_index(ti_plus, t + ti.frequency)]
    end
    @assert itp.time1 < itp.time2 "Interpolator times are in wrong order"
end

function lazyload!(itp::DataSetInterpolator, t::DateTime)
    if itp.currenttime == t
        return
    end
    itp.currenttime = t
    if itp.itp1 == nothing # Initialize new interpolator.
        initialize!(itp, t)
        return
    end
    if  t <= itp.time1 || t > itp.time2
        @info "Updating data loader for $(itp.varname) for t = $t"
        initialize!(itp, t)
    end
end

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
    t_frac = (t - itp.time1) / (itp.time2 - itp.time1)
    itp.itp2(locs...) * t_frac + itp.itp1(locs...) * (1-t_frac)
end

# Register functions with specific numbers of arguments for ModelingToolkit.
interp!(itp, t::AbstractFloat, loc1, loc2, loc3) = interp!(itp, Dates.unix2datetime(t), loc1, loc2, loc3)
interp!(itp, t::AbstractFloat, loc1, loc2) = interp!(itp, Dates.unix2datetime(t), loc1, loc2)
interp!(itp, t::AbstractFloat, loc1) = interp!(itp, Dates.unix2datetime(t), loc1)
@register_symbolic interp!(itp::DataSetInterpolator, t::Num, loc1::Num, loc2::Num, loc3::Num)
@register_symbolic interp!(itp::DataSetInterpolator, t::Num, loc1::Num, loc2::Num)
@register_symbolic interp!(itp::DataSetInterpolator, t::Num, loc1::Num)