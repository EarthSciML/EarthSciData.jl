# ModelingToolkit integration for DataSetInterpolator.
# This file contains symbolic registration, equation creation, and
# system event generation that depend on ModelingToolkit.

# Dummy function for unit validation. ModelingToolkit calls the function with
# a DynamicQuantities.Quantity or an integer to get information about the type
# and units of the output. The array-based interp_unsafe is unitless, so we
# return a dimensionless value (units are applied via a separate @constants multiplier).
interp_unsafe(data::Union{DynamicQuantities.AbstractQuantity, Real}, fit, args...) = one(Float64)

# Symbolic tracing for array-based interp_unsafe.
# Arguments are: data, fit (fractional time index), fi1..fiN (fractional spatial indices), extrap.
# Fractional indices are computed in the symbolic equation: fi = 1 + (coord - start) / step
# 3 spatial dims + time (4D array): data, fit, fi1, fi2, fi3, extrap = 6 args
@register_symbolic interp_unsafe(data::AbstractArray, fit, fi1, fi2, fi3, extrap) false
# 2 spatial dims + time (3D array): data, fit, fi1, fi2, extrap = 5 args
@register_symbolic interp_unsafe(data::AbstractArray, fit, fi1, fi2, extrap) false
# 1 spatial dim + time (2D array): data, fit, fi1, extrap = 4 args
@register_symbolic interp_unsafe(data::AbstractArray, fit, fi1, extrap) false

# Tell SymbolicUtils that interp_unsafe always returns a scalar.
# Without this, maketerm's default promote_shape returns Unknown(-1) when rebuilding
# during substitute, which breaks ifelse shape checks.
const _scalar_shape = Symbolics.SymbolicUtils.ShapeVecT()
for n_args in 4:6
    @eval Symbolics.SymbolicUtils.promote_shape(::typeof(interp_unsafe),
        $(fill(:(::Symbolics.SymbolicUtils.ShapeT), n_args)...)) = _scalar_shape
end

# Fix SymbolicUtils bug: promote_shape for ifelse returns `true` (Bool) instead of the
# shape when branches match, because `sht == shf || error(...)` returns `true`.
# This causes parse_shape(::Bool) errors when maketerm rebuilds ifelse during substitute.
# Must be done in __init__ because method overwriting is not allowed during precompilation.
function _fix_ifelse_promote_shape()
    @eval Symbolics.SymbolicUtils function promote_shape(::typeof(ifelse),
            shc::ShapeT, sht::ShapeT, shf::ShapeT)
        @nospecialize shc sht shf
        is_array_shape(shc) && error("Condition of `ifelse` cannot be an array.")
        sht == shf || error("Both branches of `ifelse` must have the same shape.")
        return sht
    end
end

# Helper to create an array-valued @discretes with a typed AbstractArray annotation.
# The type annotation gives scalar symbolic shape (unlike the [dims...] syntax which
# gives array shape and breaks ifelse during substitute).
function _make_array_discrete(name::Symbol, init_data, ndims::Int, desc::String)
    if ndims == 2
        return only(@discretes $name(t)::AbstractArray{Float64,2} = Float64.(init_data) [
            description = desc])
    elseif ndims == 3
        return only(@discretes $name(t)::AbstractArray{Float64,3} = Float64.(init_data) [
            description = desc])
    elseif ndims == 4
        return only(@discretes $name(t)::AbstractArray{Float64,4} = Float64.(init_data) [
            description = desc])
    else
        error("Unsupported array dimensions: $ndims")
    end
end

"""
$(SIGNATURES)

Create an equation that interpolates the given dataset at the given time and location.
`filename` is an identifier for the dataset, and `t` is the time variable.
`wrapper_f` can specify a function to wrap the interpolated value, for example `eq -> eq / 2`
to divide the interpolated value by 2.

Returns `(equation, discretes, constants, interp_info)` where:
- `discretes`: vector of discrete symbolic variables [data, t_start, t_step]
- `constants`: vector of constant symbolic variables [spatial grid params..., extrap, unit_scale]
- `interp_info`: named tuple with all symbolic pieces needed to build interpolation expressions
"""
function create_interp_equation(itp::DataSetInterpolator{To}, filename, t, t_ref, coords;
        wrapper_f = v -> v) where {To}
    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") :
        Symbol("$(itp.varname)")

    # Compute the correct data array dimensions from the model grid.
    grid_ranges = _model_grid(itp)
    grid_dims = length.(grid_ranges)
    cache_nt = size(itp.cache.data_buffer, ndims(itp.cache.data_buffer))
    data_dims = (grid_dims..., cache_nt)

    # Data discrete — typed as AbstractArray so MTK stores it in the nonnumeric buffer
    # while keeping scalar shape (avoids ifelse shape mismatch during substitute).
    n_data = Symbol(n, :_data)
    init_data = zeros(To, data_dims...)
    p_data = _make_array_discrete(n_data, init_data, length(data_dims),
        "Interpolation data for $(n)")

    # Time grid discretes — scalar defaults work fine in MTK.
    n_tstart = Symbol(n, :_tstart)
    n_tstep = Symbol(n, :_tstep)
    ts_default, tstep_default = get_time_grid_params(itp)
    p_tstart = only(@discretes $n_tstart(t) = ts_default [unit = u"s", description = "Time grid start for $(n)"])
    p_tstep = only(@discretes $n_tstep(t) = tstep_default [unit = u"s", description = "Time grid step for $(n)"])

    # Spatial grid constants (fixed for the lifetime of the simulation).
    spatial_consts = []
    for (i, r) in enumerate(grid_ranges)
        sn_start = Symbol(n, :_s, i, :start)
        sn_step = Symbol(n, :_s, i, :step)
        push!(spatial_consts, only(@constants $sn_start = first(r) [
            description = "Spatial grid start dim $(i) for $(n)"]))
        push!(spatial_consts, only(@constants $sn_step = step(r) [
            description = "Spatial grid step dim $(i) for $(n)"]))
    end

    # Extrapolation type constant: 1.0 = Flat (clamp), 0.0 = zero outside bounds.
    n_extrap = Symbol(n, :_extrap)
    extrap_val = itp.extrapolate_type isa Real ? 0.0 : 1.0
    p_extrap = only(@constants $n_extrap = extrap_val [
        description = "Extrapolation type for $(n)"])

    # Unit scale constant: the raw array data is unitless, so multiply by data units.
    uu = units(itp)
    n_unit = Symbol(n, :_unit)
    unit_scale = only(@constants $n_unit = 1.0 [unit = uu,
        description = "Unit scale for $(n)"])

    # Compute fractional 1-based indices symbolically: fi = 1 + (coord - start) / step
    fit = 1 + (t_ref + t - p_tstart) / p_tstep
    fis = [1 + (coords[i] - spatial_consts[2i-1]) / spatial_consts[2i]
           for i in 1:length(coords)]

    # Build RHS: interp_unsafe(data, fit, fi1, ..., extrap) * unit_scale
    rhs_interp = interp_unsafe(p_data, fit, fis..., p_extrap) * unit_scale

    # Apply wrapper (e.g., NEI scaling).
    rhs = wrapper_f(rhs_interp)

    # Create left hand side of equation.
    desc = description(itp)
    uu_rhs = ModelingToolkit.get_unit(rhs)
    lhs = only(
        @variables $n(t) [
        unit = uu_rhs,
        description = desc,
        misc = Dict(:staggering => itp.metadata.staggering)
    ]
    )

    eq = lhs ~ rhs

    discretes = [p_data, p_tstart, p_tstep]
    constants = [spatial_consts..., p_extrap, unit_scale]

    # Collect default values for constants (needed for initial_conditions in System).
    const_defaults = Dict{Any, Any}()
    for (i, r) in enumerate(grid_ranges)
        const_defaults[spatial_consts[2i-1]] = first(r)
        const_defaults[spatial_consts[2i]] = step(r)
    end
    const_defaults[p_extrap] = extrap_val
    const_defaults[unit_scale] = 1.0

    interp_info = (data_sym = p_data, tstart_sym = p_tstart, tstep_sym = p_tstep,
        spatial_consts = spatial_consts, extrap_const = p_extrap,
        unit_const = unit_scale, itp = itp, var_sym = n,
        data_dims = data_dims, data_eltype = To,
        const_defaults = const_defaults)

    return eq, discretes, constants, interp_info
end

"""
$(SIGNATURES)

Build a symbolic interpolation expression for the given `interp_info` at the given
time expression and coordinate expressions. This is useful when you need to evaluate
the interpolation at modified coordinates (e.g., `lev + 1` for finite differences).
"""
function build_interp_expr(info, t_expr, coord_exprs)
    fit = 1 + (t_expr - info.tstart_sym) / info.tstep_sym
    n_spatial = length(coord_exprs)
    fis = [1 + (coord_exprs[i] - info.spatial_consts[2i-1]) / info.spatial_consts[2i]
           for i in 1:n_spatial]
    interp_unsafe(info.data_sym, fit, fis..., info.extrap_const) * info.unit_const
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
            val = ModelingToolkit.getdefault(p)
            # Skip array-valued defaults (from @discretes) — they are handled
            # separately by the sys_event initial conditions mechanism.
            val isa AbstractArray && continue
            push!(dflts, p => val)
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
# to update the interpolation data at each time stop.
# `interp_infos` is a vector of named tuples from `create_interp_equation`.
function create_updater_sys_event(name, interp_infos, starttime::DateTime)
    t_ref = datetime2unix(starttime)
    function sys_event(sys::ModelingToolkit.AbstractSystem)
        needed = needed_vars(sys)

        # Filter to only the interpolators whose variables are needed.
        active = filter(interp_infos) do info
            Symbol(name, :₊, info.var_sym) in needed
        end
        if isempty(active)
            return nothing
        end

        # Compute all time stops.
        all_tstops = Float64[]
        for info in active
            append!(all_tstops, get_tstops(info.itp, starttime))
        end
        all_tstops = unique(all_tstops) .- t_ref

        # Build modified NamedTuple: all data + tstart + tstep discretes.
        mod_keys = Symbol[]
        mod_vals = []
        for info in active
            push!(mod_keys, EarthSciMLBase.var2symbol(info.data_sym))
            push!(mod_vals, info.data_sym)
            push!(mod_keys, EarthSciMLBase.var2symbol(info.tstart_sym))
            push!(mod_vals, info.tstart_sym)
            push!(mod_keys, EarthSciMLBase.var2symbol(info.tstep_sym))
            push!(mod_vals, info.tstep_sym)
        end
        modified_nt = NamedTuple{Tuple(mod_keys)}(Tuple(mod_vals))

        # Build context NamedTuple: DataSetInterpolator objects.
        ctx_keys = Symbol[]
        ctx_vals = []
        for info in active
            push!(ctx_keys, Symbol(:itp_, info.var_sym))
            push!(ctx_vals, info.itp)
        end
        ctx_nt = NamedTuple{Tuple(ctx_keys)}(Tuple(ctx_vals))

        # Map from context keys to modified keys for each interpolator.
        key_map = Dict{Symbol, NamedTuple}()
        for (i, info) in enumerate(active)
            ck = Symbol(:itp_, info.var_sym)
            key_map[ck] = (
                data_key = mod_keys[3*(i-1)+1],
                tstart_key = mod_keys[3*(i-1)+2],
                tstep_key = mod_keys[3*(i-1)+3],
            )
        end

        function update_data!(modified, observed, ctx, integ)
            result = Dict{Symbol, Any}()
            for (ck, dsi) in pairs(ctx)
                lazyload!(dsi, integ.t + t_ref)
                km = key_map[ck]
                result[km.data_key] = copy(dsi.cache.data_buffer)
                ts, tstep = get_time_grid_params(dsi)
                result[km.tstart_key] = ts
                result[km.tstep_key] = tstep
            end
            NamedTuple{Tuple(keys(result))}(Tuple(values(result)))
        end

        event = all_tstops => (update_data!, modified_nt, NamedTuple(), ctx_nt)

        # Initial conditions for active variables only (avoids allocating
        # large arrays for variables that are not used by this system).
        # Unused variables have their defaults from the @discretes declaration.
        ics = Dict{Any, Any}()
        for info in active
            ics[info.data_sym] = zeros(info.data_eltype, info.data_dims...)
            ts, tstep = get_time_grid_params(info.itp)
            ics[info.tstart_sym] = ts
            ics[info.tstep_sym] = tstep
            merge!(ics, info.const_defaults)
        end

        return (event, ics)
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
