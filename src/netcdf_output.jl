export NetCDFOutputter

"""
$(TYPEDSIGNATURES)

Create an `EarthSciMLBase.Operator` to write simulation output to a NetCDF file.

At each output time the output variables are evaluated and copied into a buffer
on the calling thread. With `async_write` (default: on unless the environment
variable `EARTHSCIDATA_ASYNC_OUTPUT` is `0`), the buffer is then written to the
file by a background task, so the simulation does not wait for `nclock` while
background data loads hold it. At most one write is in flight: the next output
time waits for the previous write before reusing the buffer. A failed write is
rethrown at the next output time or when the simulation finishes.

$(TYPEDFIELDS)
"""
mutable struct NetCDFOutputter
    "The path of the NetCDF file to write to"
    filepath::String
    "The netcdf dataset"
    file::Any
    "The netcdf variables corresponding to the state variables"
    vars::Any
    "The netcdf variable for time"
    tvar::Any
    "Current time index for writing"
    h::Int
    "Simulation time interval (in seconds) at which to write to disk"
    time_interval::AbstractFloat
    "Extra observed variables to write to disk"
    extra_vars::AbstractVector
    "Functions to get the extra vars"
    extra_var_fs::AbstractVector
    "Spatial grid specification"
    grid::Any
    "Data type of the output"
    dtype::Any
    "Reference time for the simulation, used to convert to Unix time"
    tref::Any
    "Whether to write to the file in a background task"
    async_write::Bool
    "The values to write at the current output time, one array per output variable"
    buffers::Vector{Array{Float32, 3}}
    "The background write in flight, or `nothing`"
    pending::Union{Nothing, Task}

    function NetCDFOutputter(
            filepath::AbstractString,
            time_interval::AbstractFloat;
            extra_vars = [],
            dtype = Float32,
            async_write::Bool = _async_output_default()
    )
        new(
            filepath,
            nothing,
            nothing,
            nothing,
            1,
            time_interval,
            extra_vars,
            [],
            nothing,
            dtype,
            0.0,
            async_write,
            Array{Float32, 3}[],
            nothing
        )
    end
end

# Background writes are on unless `EARTHSCIDATA_ASYNC_OUTPUT=0`; read when an outputter is built.
_async_output_default() = get(ENV, "EARTHSCIDATA_ASYNC_OUTPUT", "1") != "0"

"""
Set up the output file and the callback function.
"""
function EarthSciMLBase.init_callback(
        nc::NetCDFOutputter,
        sys::EarthSciMLBase.CoupledSystem,
        sys_mtk,
        coord_args,
        dom::EarthSciMLBase.DomainInfo,
        alg::EarthSciMLBase.MapAlgorithm
)
    rm(nc.filepath, force = true)
    lock(nclock) do
        ds = NCDataset(nc.filepath, "c")
        grid = EarthSciMLBase.grid(dom)
        pv = EarthSciMLBase.pvars(dom)
        @assert length(pv) == 3 "Currently only 3D simulations are supported."
        @assert length(grid) == 3 "Currently only 3D simulations are supported."
        pvstr = [String(Symbol(p)) for p in pv]
        for (i, p) in enumerate(pvstr)
            ds.dim[p] = length(grid[i])
        end
        ds.dim["time"] = Inf
        function makencvar(v, dims)
            n = string(Symbolics.tosymbol(v, escape = false))
            ncvar = defVar(ds, n, Float32, dims)
            ncvar.attrib["description"] = ModelingToolkit.getdescription(v)
            ncvar.attrib["units"] = string(DynamicQuantities.dimension(ModelingToolkit.get_unit(v)))
            ncvar
        end
        ncvars = [makencvar(v, [pvstr..., "time"])
                  for v in vcat(unknowns(sys_mtk), nc.extra_vars)]
        nctvar = defVar(ds, "time", Float64, ("time",))
        nctvar.attrib["description"] = "Time"
        nctvar.attrib["units"] = "seconds since 1970-1-1"
        for (i, p) in enumerate(pvstr)
            d = defVar(ds, p, nc.dtype, (p,))
            d.attrib["description"] = ModelingToolkit.getdescription(pv[i])
            d.attrib["units"] = string(DynamicQuantities.dimension(ModelingToolkit.get_unit(pv[i])))
            d[:] = grid[i]
        end
        if length(nc.extra_vars) > 0
            for v in nc.extra_vars
                obs_f = EarthSciMLBase.build_coord_observed_function(
                    sys_mtk, coord_args, [v])
                push!(nc.extra_var_fs, obs_f)
            end
        end
        nc.file = ds
        nc.vars = ncvars
        nc.tvar = nctvar
        nc.grid = grid
        nc.tref = get_tref(dom)
    end
    nc.h = 1
    nc.buffers = [Array{Float32}(undef, length.(nc.grid)...) for _ in nc.vars]
    nc.pending = nothing
    start, finish = get_tspan(dom)
    return PresetTimeCallback(
        start:nc.time_interval:finish,
        (integrator) -> affect!(nc, integrator),
        finalize = (c, u, t, integrator) -> _finalize_output!(nc),
        save_positions = (false, false),
        filter_tstops = false
    )
end

"""
Write the current state of the system to the NetCDF file: copy the output
variables into `nc.buffers`, then write them, in a background task when
`nc.async_write`.
"""
function affect!(nc::NetCDFOutputter, integrator)
    _wait_write!(nc)  # the previous write reads the buffers
    _fill_buffers!(nc, integrator)
    h, tval = nc.h, integrator.t + nc.tref
    if nc.async_write
        nc.pending = Threads.@spawn _write_record(nc, h, tval)
    else
        _write_record(nc, h, tval)
    end
    nc.h += 1
    return false
end

# Evaluate the output variables at the integrator's current state into
# `nc.buffers`. Storing into the `Float32` buffers converts each value as
# NCDatasets would when writing it to the file's `Float32` variables, and extra
# variables pass through `Float64` as they did when written from a `Float64`
# array, so the file holds the same values as when they were written directly.
function _fill_buffers!(nc::NetCDFOutputter, integrator)
    nstate = length(nc.vars) - length(nc.extra_vars)
    u = reshape(integrator.u, nstate, [length(g) for g in nc.grid]...)
    for j in 1:nstate
        nc.buffers[j] .= view(u, j, :, :, :)
    end
    for (n, f) in enumerate(nc.extra_var_fs)
        buf = nc.buffers[nstate + n]
        for (i, c1) in enumerate(nc.grid[1])
            for (j, c2) in enumerate(nc.grid[2])
                for (k, c3) in enumerate(nc.grid[3])
                    buf[i, j, k] = Float64(only(
                        f(view(u, :, i, j, k), integrator.p, integrator.t, c1, c2, c3)))
                end
            end
        end
    end
    return nothing
end

# Write the buffers to time index `h` of the file.
function _write_record(nc::NetCDFOutputter, h::Int, tval)
    lock(nclock) do
        for (v, buf) in zip(nc.vars, nc.buffers)
            v[:, :, :, h] = buf
        end
        nc.tvar[h] = tval
    end
    return nothing
end

# Wait for the write in flight, if any; rethrows its error if it failed.
function _wait_write!(nc::NetCDFOutputter)
    task = nc.pending
    task === nothing && return nothing
    nc.pending = nothing
    wait(task)
    return nothing
end

# Wait for the write in flight, then close the file, also when the write failed.
function _finalize_output!(nc::NetCDFOutputter)
    try
        _wait_write!(nc)
    finally
        lock(nclock) do
            close(nc.file)
        end
    end
    return nothing
end
