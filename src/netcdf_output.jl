export NetCDFOutputter

"""
$(TYPEDSIGNATURES)

Create an `EarthSciMLBase.Operator` to write simulation output to a NetCDF file.

$(TYPEDFIELDS)
"""
mutable struct NetCDFOutputter <: EarthSciMLBase.Operator
    "The path of the NetCDF file to write to"
    filepath::String
    "The netcdf dataset"
    file
    "The netcdf variables corresponding to the state variables"
    vars
    "The netcdf variable for time"
    tvar
    "Times interval (in seconds) at which to write to disk"
    time_interval::AbstractFloat
    "Extra observed variables to write to disk"
    extra_vars::AbstractVector
    "Data type of the output"
    dtype

    function NetCDFOutputter(filepath::AbstractString, time_interval::AbstractFloat; extra_vars=[], dtype=Float32)
        new(filepath, nothing, nothing, nothing, time_interval, extra_vars, dtype)
    end
end

"Set up the output file."
function EarthSciMLBase.initialize!(nc::NetCDFOutputter, s::Simulator)
    rm(nc.filepath, force=true)
    ds = NCDataset(nc.filepath, "c")
    pv = EarthSciMLBase.pvars(s.sys.domaininfo)
    @assert length(pv) == 3 "Currently only 3D simulations are supported."
    @assert length(s.grid) == 3 "Currently only 3D simulations are supported."
    pvstr = [String(Symbol(p)) for p in pv]
    for (i, p) in enumerate(pvstr)
        ds.dim[p] = length(s.grid[i])
    end
    ds.dim["time"] = Inf
    function makencvar(v, dims)
        n = string(Symbolics.tosymbol(v, escape=false))
        ncvar = defVar(ds, n, Float32, dims)
        ncvar.attrib["description"] = ModelingToolkit.getdescription(v)
        ncvar.attrib["units"] = string(ModelingToolkit.get_unit(v))
        ncvar
    end
    ncvars = [makencvar(v, [pvstr..., "time"]) for v in vcat(states(s.sys_mtk), nc.extra_vars)]
    nctvar = defVar(ds, "time", Float64, ("time",))
    nctvar.attrib["description"] = "Time"
    nctvar.attrib["units"] = "seconds since 1970-1-1"
    for (i, p) in enumerate(pvstr)
        d = defVar(ds, p, nc.dtype, (p,))
        d.attrib["description"] = ModelingToolkit.getdescription(pv[i])
        d.attrib["units"] = string(ModelingToolkit.get_unit(pv[i]))
        d[:] = s.grid[i]
    end
    nc.file = ds
    nc.vars = ncvars
    nc.tvar = nctvar
    return false
end

"""
Write the current state of the `Simulator` to the NetCDF file.
"""
function EarthSciMLBase.run!(nc::NetCDFOutputter, s::EarthSciMLBase.Simulator, t, timestep)
    start, finish = EarthSciMLBase.time_range(s.domaininfo)
    output_times = start:nc.time_interval:finish
    h = findfirst(t .== output_times)
    @assert !isnothing(h) "Time $t is not in the output times ($(nc.output_times))."
    for j in eachindex(states(s.sys_mtk))
        v = nc.vars[j]
        v[:, :, :, h] = s.u[j, :, :, :]
    end
    if length(nc.extra_vars) > 0
        u = zeros(length.(s.grid)...) # Temporary array.
        for j in eachindex(nc.extra_vars)
            v = nc.vars[j + length(states(s.sys_mtk))]
            f = s.obs_fs[s.obs_fs_idx[nc.extra_vars[j]]]
            for (i, c1) ∈ enumerate(s.grid[1])
                for (j, c2) ∈ enumerate(s.grid[2])
                    for (k, c3) ∈ enumerate(s.grid[3])
                        u[i, j, k] = f(t, c1, c2, c3)
                    end
                end
            end
            v[:, :, :, h] = u
        end
    end
    nc.tvar[h] = t
    # @info "Wrote data to file for $(Dates.unix2datetime(t))"
    return false
end

"Close the NetCDF file"
EarthSciMLBase.finalize!(nc::NetCDFOutputter, s::Simulator) = close(nc.file)

"Return the interval at which to write the simulation state to disk."
EarthSciMLBase.timestep(nc::NetCDFOutputter) = nc.time_interval