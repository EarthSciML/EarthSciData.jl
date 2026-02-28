# ModelingToolkit integration for DataSetInterpolator.
# This file contains symbolic registration, equation creation, and
# system event generation that depend on ModelingToolkit.

"""
Return the units of the data.
"""
ModelingToolkit.get_unit(itp::DataSetInterpolator) = units(itp)

mutable struct ITPWrapper{ITP}
    itp::ITP
    ITPWrapper(itp::ITP) where {ITP} = new{ITP}(itp)
end

(itp::ITPWrapper)(t, locs::Vararg{T, N}) where {T, N} = interp_unsafe(itp.itp, t, locs...)

# Dummy functions for unit validation. Basically ModelingToolkit
# will call the function with a DynamicQuantities.Quantity or an integer to
# get information about the type and units of the output.
interp(itp::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = itp
interp_unsafe(itp::Union{DynamicQuantities.AbstractQuantity, Real}, t, locs...) = itp

# Symbolic tracing, for different numbers of dimensions (up to three dimensions).
@register_symbolic interp(itp::DataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic interp(itp::DataSetInterpolator, t, loc1, loc2) false
@register_symbolic interp(itp::DataSetInterpolator, t, loc1) false
@register_symbolic interp_unsafe(itp::DataSetInterpolator, t, loc1, loc2, loc3)
@register_symbolic interp_unsafe(itp::DataSetInterpolator, t, loc1, loc2) false
@register_symbolic interp_unsafe(itp::DataSetInterpolator, t, loc1) false

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
function create_interp_equation(itp::DataSetInterpolator, filename, t, t_ref, coords;
        wrapper_f = v -> v)
    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") :
        Symbol("$(itp.varname)")
    n_p = Symbol(n, "_itp")

    itp = ITPWrapper(itp)
    t_itp = typeof(itp)
    p_itp = only(
        @parameters ($n_p::t_itp)(..)=itp [
        unit = units(itp.itp),
        description = "Interpolated $(n)"
    ]
    )

    # Create right hand side of equation.
    rhs = wrapper_f(p_itp(t_ref + t, coords...))

    # Create left hand side of equation.
    desc = description(itp.itp)
    uu = ModelingToolkit.get_unit(rhs)
    lhs = only(
        @variables $n(t) [
        unit = uu,
        description = desc,
        misc = Dict(:staggering => itp.itp.metadata.staggering)
    ]
    )

    eq = lhs ~ rhs

    return eq, p_itp
end

# In MTK v11, parameter defaults set via `@parameters x = val` are stored as
# metadata on the symbolic variable but are NOT included in `initial_conditions(sys)`.
# This function extracts all parameter defaults so they can be passed to the
# System constructor via the `initial_conditions` kwarg.
# This is critical for parameters like `t_ref` (the reference time) which must
# have their default values correctly propagated through system composition and
# compilation, particularly for the SolverIMEX path which constructs
# MTKParameters directly from `initial_conditions(sys)`.
function _itp_defaults(params)
    dflts = Pair[]
    for p in params
        if ModelingToolkit.hasdefault(p)
            push!(dflts, p => ModelingToolkit.getdefault(p))
        end
    end
    return dflts
end

# Utility function to get the variables that are needed to solve a
# system.
function needed_vars(sys)
    exprs = [eq.rhs for eq in equations(sys)]
    needed_eqs = vcat(equations(sys),
        observed(sys)[ModelingToolkit.observed_equations_used_by(sys, exprs)])
    needed_vars = unique(vcat(get_variables.(needed_eqs)...))
    EarthSciMLBase.var2symbol.(needed_vars)
end

# Create a "system event" (https://base.earthsci.dev/dev/system_events/)
# to update the interpolators associated with the given parameters.
function create_updater_sys_event(name, params, starttime::DateTime)
    pnames = Symbol.((name,), (:₊,), EarthSciMLBase.var2symbol.(params))
    t_ref = datetime2unix(starttime)
    function sys_event(sys::ModelingToolkit.AbstractSystem)
        needed = needed_vars(sys)
        psyms = []
        params_to_update = []
        for p in parameters(sys) # Figure out which parameters need to be updated.
            psym = EarthSciMLBase.var2symbol(p)
            if (psym in pnames) && (psym in needed) && ModelingToolkit.hasdefault(p) && ModelingToolkit.getdefault(p) isa ITPWrapper
                push!(psyms, psym)
                push!(params_to_update, p)
            end
        end
        params_to_update = NamedTuple{Tuple(psyms)}(params_to_update)
        all_tstops = []
        for p_itp in params_to_update
            itp = ModelingToolkit.getdefault(p_itp).itp
            push!(all_tstops, get_tstops(itp, starttime)...)
        end
        all_tstops = unique(all_tstops) .- t_ref
        function update_itps!(modified, observed, ctx, integ)
            function loadf(p_itp)
                p_itp.itp = lazyload!(p_itp.itp, integ.t + t_ref)
                return p_itp
            end
            NamedTuple((k => loadf(v) for (k, v) in pairs(modified)))
        end
        if length(params_to_update) == 0
            return nothing
        end
        all_tstops => (update_itps!, params_to_update, NamedTuple())
    end
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(split(string(typeof(itp.fs.fs)), ".")[end]).$(itp.varname)"
end

function _get_staggering(var)
    misc = getmisc(var)
    @assert :staggering in keys(misc) "Staggering is not specified for variable $(var)."
    return misc[:staggering]
end
