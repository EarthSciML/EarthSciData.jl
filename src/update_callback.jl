
"""
This struct holds information that can be used to create a callback function that updates the
states of the interpolators.
"""
struct UpdateCallbackCreator
    sys::ODESystem
    variables
    interpolators
end

function lazyload!(uc::UpdateCallbackCreator, t::AbstractFloat)
    dt = unix2datetime(t)
    for itp in uc.interpolators
        lazyload!(itp, dt)
    end
end

"""
Create a callback for this simulator. We only want to update the interpolators
that are actually used in the system.
"""
function EarthSciMLBase.init_callback(uc::UpdateCallbackCreator, s::Simulator)
    simname = nameof(s.sys_mtk)
    sysname = nameof(uc.sys)
    needvars = Symbol.([unknowns(s.sys_mtk); [eq.lhs for eq in observed(s.sys_mtk)]])
    itps = []
    for (v, itp) in zip(uc.variables, uc.interpolators)
        nv = Symbol(simname, "₊", sysname, "₊", v)
        if nv ∈ needvars
            push!(itps, itp)
        end
    end
    function update_callback(integrator)
        dt = unix2datetime(integrator.t)
        for itp in itps
            lazyload!(itp, dt)
        end
    end
    DiscreteCallback(
        (u, t, integrator) -> true, # TODO(CT): Could change to only run when we know interpolators need to be updated.
        update_callback,
        save_positions = (false, false),
    )
end