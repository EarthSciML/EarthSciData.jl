export NetCDFOutputter

"""
$(TYPEDSIGNATURES)

Create an `EarthSciMLBase.Operator` to write simulation output to a NetCDF file.

$(TYPEDFIELDS)
"""
mutable struct NetCDFOutputter
    "The path of the NetCDF file to write to"
    filepath::String
    "The netcdf dataset"
    file
    "The netcdf variables corresponding to the state variables"
    vars
    "The netcdf variable for time"
    tvar
    "Current time index for writing"
    h::Int
    "Simulation time interval (in seconds) at which to write to disk"
    time_interval::AbstractFloat
    "Extra observed variables to write to disk"
    extra_vars::AbstractVector
    "Functions to get the extra vars"
    extra_var_fs::AbstractVector
    "Spatial grid specification"
    grid
    "Data type of the output"
    dtype

    function NetCDFOutputter(filepath::AbstractString, time_interval::AbstractFloat; extra_vars=[], dtype=Float32)
        new(filepath, nothing, nothing, nothing, 1, time_interval, extra_vars, [], nothing, dtype)
    end
end

"Set up the output file and the callback function."
function EarthSciMLBase.init_callback(nc::NetCDFOutputter, sys::EarthSciMLBase.CoupledSystem,
    sys_mtk, obs_eqs, dom::EarthSciMLBase.DomainInfo)

    rm(nc.filepath, force=true)
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
        n = string(Symbolics.tosymbol(v, escape=false))
        ncvar = defVar(ds, n, Float32, dims)
        ncvar.attrib["description"] = ModelingToolkit.getdescription(v)
        ncvar.attrib["units"] = string(DynamicQuantities.dimension(ModelingToolkit.get_unit(v)))
        ncvar
    end
    ncvars = [makencvar(v, [pvstr..., "time"]) for v in vcat(unknowns(sys_mtk), nc.extra_vars)]
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
        obs_fs = EarthSciMLBase.obs_functions(obs_eqs, dom)
        for j in eachindex(nc.extra_vars)
            push!(nc.extra_var_fs, obs_fs(nc.extra_vars[j]))
        end
    end
    nc.file = ds
    nc.vars = ncvars
    nc.tvar = nctvar
    nc.grid = grid
    nc.h = 1
    start, finish = EarthSciMLBase.tspan(dom)
    return PresetTimeCallback(start:nc.time_interval:finish,
        (integrator) -> affect!(nc, integrator),
        finalize=(c, u, t, integrator) -> close(nc.file),
        save_positions=(false, false),
        filter_tstops=false,
    )
end

"""
Write the current state of the system to the NetCDF file.
"""
function affect!(nc::NetCDFOutputter, integrator)
    u = reshape(integrator.u, length(nc.vars) - length(nc.extra_vars), [length(g) for g in nc.grid]...)
    for j in 1:(length(nc.vars)-length(nc.extra_vars))
        v = nc.vars[j]
        v[:, :, :, nc.h] = u[j, :, :, :]
    end
    if length(nc.extra_vars) > 0
        u = zeros(length.(nc.grid)...) # Temporary array.
        for j in eachindex(nc.extra_vars)
            v = nc.vars[j+length(nc.vars)-length(nc.extra_vars)]
            f = nc.extra_var_fs[j]
            for (i, c1) ∈ enumerate(nc.grid[1])
                for (j, c2) ∈ enumerate(nc.grid[2])
                    for (k, c3) ∈ enumerate(nc.grid[3])
                        u[i, j, k] = f(integrator.t, c1, c2, c3)
                    end
                end
            end
            v[:, :, :, nc.h] = u
        end
    end
    nc.tvar[nc.h] = integrator.t
    nc.h += 1
    return false
end