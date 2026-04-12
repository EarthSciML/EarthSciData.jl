# ModelingToolkit integration for DataSetInterpolator.
# This file contains symbolic registration, equation creation, and
# system event generation that depend on ModelingToolkit.

# Custom symtype for data buffer discretes. Using a non-Real, non-AbstractArray
# type gives scalar symbolic shape (so canonicalize_eq! works) while routing
# values to MTK's nonnumeric parameter buffer (is_variable_floatingpoint returns false).
# Concrete wrapper so that MTK's Vector{DataBufferType} buffer can hold array values
# via convert(DataBufferType, array).
struct DataBufferType
    data::Any
end
Base.convert(::Type{DataBufferType}, x::DataBufferType) = x
Base.convert(::Type{DataBufferType}, x) = DataBufferType(x)
Base.copy(x::DataBufferType) = DataBufferType(copy(x.data))

# Dummy functions for unit validation. ModelingToolkit calls the function with
# a DynamicQuantities.Quantity or an integer to get information about the type
# and units of the output. The array-based interp_unsafe is unitless, so we
# return a dimensionless value (units are applied via a separate @constants multiplier).
function interp_unsafe(data::Union{DynamicQuantities.AbstractQuantity, Real}, fit, args...)
    one(Float64)
end
function interp_time_only(
        data::Union{DynamicQuantities.AbstractQuantity, Real}, fit, args...)
    one(Float64)
end

# Runtime unwrap: when MTK calls interp_unsafe/interp_time_only with a
# DataBufferType wrapper, forward to the actual array-based implementation.
interp_unsafe(data::DataBufferType, fit, args...) = interp_unsafe(data.data, fit, args...)
function interp_time_only(data::DataBufferType, fit, args...)
    interp_time_only(data.data, fit, args...)
end

# Symbolic tracing for array-based interp_unsafe.
# Arguments are: data, fit (fractional time index), fi1..fiN (fractional spatial indices), extrap.
# Fractional indices are computed in the symbolic equation: fi = 1 + (coord - start) / step
# DataBufferType is used as the symtype for the data buffer discrete parameter.
# 3 spatial dims + time (4D array): data, fit, fi1, fi2, fi3, extrap = 6 args
@register_symbolic interp_unsafe(data::DataBufferType, fit, fi1, fi2, fi3, extrap) false
# 2 spatial dims + time (3D array): data, fit, fi1, fi2, extrap = 5 args
@register_symbolic interp_unsafe(data::DataBufferType, fit, fi1, fi2, extrap) false
# 1 spatial dim + time (2D array): data, fit, fi1, extrap = 4 args
@register_symbolic interp_unsafe(data::DataBufferType, fit, fi1, extrap) false

# Same registrations for interp_time_only (spatial nearest, time linear).
@register_symbolic interp_time_only(data::DataBufferType, fit, fi1, fi2, fi3, extrap) false
@register_symbolic interp_time_only(data::DataBufferType, fit, fi1, fi2, extrap) false
@register_symbolic interp_time_only(data::DataBufferType, fit, fi1, extrap) false

# Tell SymbolicUtils that interp_unsafe/interp_time_only always return a Real scalar.
# promote_symtype: @register_symbolic generates promote_symtype dispatches for the
# declared argument types, but DataBufferType needs explicit overrides since
# the fallback may not handle it correctly.
for n_args in 4:6
    @eval Symbolics.SymbolicUtils.promote_symtype(::typeof(interp_unsafe),
        ::Type{DataBufferType}, $(fill(:(::Type), n_args - 2)...), ::Type) = Real
    @eval Symbolics.SymbolicUtils.promote_symtype(::typeof(interp_time_only),
        ::Type{DataBufferType}, $(fill(:(::Type), n_args - 2)...), ::Type) = Real
end

# Register zero derivatives. The data is updated discretely via callbacks
# (not continuously), so the symbolic derivative is zero for all arguments.
# Without this, calculate_tgrad creates unevaluated Differential terms with symtype Any,
# which causes *(::Type{Any}, ::Type{Real}) errors in the IMEX solver path.
@register_derivative interp_unsafe(args...) I Symbolics.SConst(zero(Float64))
@register_derivative interp_time_only(args...) I Symbolics.SConst(zero(Float64))

# Tell SymbolicUtils that interp_unsafe/interp_time_only always return a scalar shape.
# Without this, maketerm's default promote_shape returns Unknown(-1) when rebuilding
# during substitute, which breaks ifelse shape checks.
const _scalar_shape = Symbolics.SymbolicUtils.ShapeVecT()
for n_args in 4:6
    @eval Symbolics.SymbolicUtils.promote_shape(::typeof(interp_unsafe),
        $(fill(:(::Symbolics.SymbolicUtils.ShapeT), n_args)...)) = _scalar_shape
    @eval Symbolics.SymbolicUtils.promote_shape(::typeof(interp_time_only),
        $(fill(:(::Symbolics.SymbolicUtils.ShapeT), n_args)...)) = _scalar_shape
end

function _make_array_discrete(name::Symbol, init_data, ndims::Int, desc::String)
    return only(@discretes $name(t)::DataBufferType = Float64.(init_data) [
        description = desc])
end

"""
$(SIGNATURES)

Create an equation that interpolates the given dataset at the given time and location.
`filename` is an identifier for the dataset, and `t` is the time variable.
`wrapper_f` can specify a function to wrap the interpolated value, for example `eq -> eq / 2`
to divide the interpolated value by 2.

`spatial_interp` selects the spatial interpolation mode:

  - `:linear` (default) — full multilinear interpolation (2^(1+dim) corners).
    Safe for arbitrary query points; the classic behavior.
  - `:nearest` — nearest-neighbour spatial indexing combined with linear time
    interpolation (2 corners). Used when the caller knows every query is at a
    grid point that matches the data grid exactly — e.g., a PDE simulation on
    the same grid the data is regridded to. `interp_unsafe` is replaced with
    `interp_time_only` at the symbolic level, eliminating the wasted corner
    loads/multiplies.

Returns `(equation, discretes, constants, interp_info)` where:

  - `discretes`: vector of discrete symbolic variables [data, t_start, t_step]
  - `constants`: vector of constant symbolic variables [spatial grid params..., extrap, unit_scale]
  - `interp_info`: named tuple with all symbolic pieces needed to build interpolation expressions
"""
function create_interp_equation(itp::DataSetInterpolator{To}, filename, t, t_ref, coords;
        wrapper_f = v -> v, spatial_interp::Symbol = :linear) where {To}
    spatial_interp in (:linear, :nearest) ||
        throw(ArgumentError("spatial_interp must be :linear or :nearest, got $spatial_interp"))
    interp_f = spatial_interp === :nearest ? interp_time_only : interp_unsafe

    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") :
        Symbol("$(itp.varname)")

    # Compute the correct data array dimensions from the model grid.
    grid_ranges = _model_grid(itp)
    grid_dims = length.(grid_ranges)
    cache_nt = size(itp.cache.data_buffer, ndims(itp.cache.data_buffer))
    data_dims = (grid_dims..., cache_nt)

    # Data discrete — typed as AbstractArray so MTK stores it in the nonnumeric buffer
    # while keeping scalar shape (avoids ifelse shape mismatch during substitute).
    # Initial value is zeros; the discrete update event populates the buffer
    # with real data at solve time.
    n_data = Symbol(n, :_data)
    init_data = zeros(To, data_dims...)
    p_data = _make_array_discrete(n_data, init_data, length(data_dims),
        "Interpolation data for $(n)")

    # Time grid discretes — scalar defaults work fine in MTK.
    n_tstart = Symbol(n, :_tstart)
    n_tstep = Symbol(n, :_tstep)
    ts_default, tstep_default = get_time_grid_params(itp)
    p_tstart = only(@discretes $n_tstart(t) = ts_default [
        unit = u"s", description = "Time grid start for $(n)"])
    p_tstep = only(@discretes $n_tstep(t) = tstep_default [
        unit = u"s", description = "Time grid step for $(n)"])

    # Spatial grid constants (fixed for the lifetime of the simulation).
    # Each constant gets the same unit as the corresponding coordinate variable
    # (e.g., meters for Lambert, radians for longlat) so that fi = 1 + (coord - start) / step
    # is dimensionally consistent.
    spatial_consts = []
    for (i, r) in enumerate(grid_ranges)
        coord_unit = ModelingToolkit.get_unit(coords[i])
        sn_start = Symbol(n, :_s, i, :start)
        sn_step = Symbol(n, :_s, i, :step)
        push!(spatial_consts,
            only(@constants $sn_start = first(r) [
                unit = coord_unit,
                description = "Spatial grid start dim $(i) for $(n)"]))
        push!(spatial_consts,
            only(@constants $sn_step = step(r) [
                unit = coord_unit,
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
    fis = [1 + (coords[i] - spatial_consts[2i - 1]) / spatial_consts[2i]
           for i in 1:length(coords)]

    # Build RHS: interp_f(data, fit, fi1, ..., extrap) * unit_scale
    # where interp_f is either interp_unsafe (linear) or interp_time_only (nearest).
    rhs_interp = interp_f(p_data, fit, fis..., p_extrap) * unit_scale

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
        const_defaults[spatial_consts[2i - 1]] = first(r)
        const_defaults[spatial_consts[2i]] = step(r)
    end
    const_defaults[p_extrap] = extrap_val
    const_defaults[unit_scale] = 1.0

    interp_info = (data_sym = p_data, tstart_sym = p_tstart, tstep_sym = p_tstep,
        spatial_consts = spatial_consts, extrap_const = p_extrap,
        unit_const = unit_scale, itp = itp, var_sym = n,
        data_dims = data_dims, data_eltype = To,
        const_defaults = const_defaults, spatial_interp = spatial_interp)

    return eq, discretes, constants, interp_info
end

"""
$(SIGNATURES)

Build a symbolic interpolation expression for the given `interp_info` at the given
time expression and coordinate expressions. This is useful when you need to evaluate
the interpolation at modified coordinates (e.g., `lev + 1` for finite differences).
Uses the same `spatial_interp` mode that was configured on `interp_info`.
"""
function build_interp_expr(info, t_expr, coord_exprs)
    fit = 1 + (t_expr - info.tstart_sym) / info.tstep_sym
    n_spatial = length(coord_exprs)
    fis = [1 + (coord_exprs[i] - info.spatial_consts[2i - 1]) / info.spatial_consts[2i]
           for i in 1:n_spatial]
    interp_f = get(info, :spatial_interp, :linear) === :nearest ? interp_time_only :
               interp_unsafe
    interp_f(info.data_sym, fit, fis..., info.extrap_const) * info.unit_const
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
            if val isa AbstractArray
                # Array-valued discretes (from @discretes) need to be wrapped
                # in `DataBufferType` so they route to MTK's nonnumeric buffer.
                # This provides the initial value for direct-`mtkcompile` users
                # (e.g. `mtkcompile(GEOSFP(...))`) who bypass the CoupledSystem
                # `sys_event` pathway that would otherwise seed these.
                push!(dflts, p => DataBufferType(val))
            else
                push!(dflts, p => val)
            end
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
    all_vars = Set{Any}()
    for eq in needed_eqs
        union!(all_vars, get_variables(eq))
    end
    EarthSciMLBase.var2symbol.(collect(all_vars))
end

# Build a preset-time `SymbolicDiscreteCallback` that reloads the
# interpolation data buffers at each dataset time stop. The event uses the
# bare (un-namespaced) parameter symbols from `interp_infos`; MTK's
# `namespace_affect` rewrites them when this event is attached to a subsystem
# that later gets composed into a parent system. Attaching this directly to
# the data loader's `System` means both `mtkcompile(loader)` and
# `convert(System, couple(loader, ...))` pick it up automatically through
# the standard discrete-events machinery.
#
# The same affect is registered as the callback's `initialize` so it runs at
# problem init — populating the parameter buffer at `tspan[1]` before any
# parameter query or the first RHS evaluation. This makes direct
# `getsym(prob, ...)` return real data without having to run `solve`.
function build_interp_event(interp_infos, starttime::DateTime)
    t_ref = datetime2unix(starttime)

    # Compute all time stops across all interpolators.
    all_tstops = Float64[]
    for info in interp_infos
        append!(all_tstops, get_tstops(info.itp, starttime))
    end
    all_tstops = unique(all_tstops) .- t_ref

    # Build modified NamedTuple using bare subsystem syms.
    mod_keys = Symbol[]
    mod_vals = []
    for info in interp_infos
        push!(mod_keys, EarthSciMLBase.var2symbol(info.data_sym))
        push!(mod_vals, info.data_sym)
        push!(mod_keys, EarthSciMLBase.var2symbol(info.tstart_sym))
        push!(mod_vals, info.tstart_sym)
        push!(mod_keys, EarthSciMLBase.var2symbol(info.tstep_sym))
        push!(mod_vals, info.tstep_sym)
    end
    modified_nt = NamedTuple{Tuple(mod_keys)}(Tuple(mod_vals))

    # Build context NamedTuple: `DataSetInterpolator` objects.
    ctx_keys = Symbol[]
    ctx_vals = []
    for info in interp_infos
        push!(ctx_keys, Symbol(:itp_, info.var_sym))
        push!(ctx_vals, info.itp)
    end
    ctx_nt = NamedTuple{Tuple(ctx_keys)}(Tuple(ctx_vals))

    # Map ctx key → (data_key, tstart_key, tstep_key) for the update callback.
    key_map = Dict{Symbol, NamedTuple}()
    for (i, info) in enumerate(interp_infos)
        ck = Symbol(:itp_, info.var_sym)
        key_map[ck] = (
            data_key = mod_keys[3 * (i - 1) + 1],
            tstart_key = mod_keys[3 * (i - 1) + 2],
            tstep_key = mod_keys[3 * (i - 1) + 3]
        )
    end

    function update_data!(modified, observed, ctx, integ)
        # Build result in the same order as mod_keys to guarantee the
        # returned NamedTuple matches the `modified` declaration order.
        # (Dict iteration order is not guaranteed in Julia.)
        result_vals = Vector{Any}(undef, length(mod_keys))
        for (ck, dsi) in pairs(ctx)
            lazyload!(dsi, integ.t + t_ref)
            km = key_map[ck]
            result_vals[findfirst(==(km.data_key), mod_keys)] = DataBufferType(
                copy(dsi.cache.data_buffer))
            ts, tstep = get_time_grid_params(dsi)
            result_vals[findfirst(==(km.tstart_key), mod_keys)] = ts
            result_vals[findfirst(==(km.tstep_key), mod_keys)] = tstep
        end
        NamedTuple{Tuple(mod_keys)}(Tuple(result_vals))
    end

    affect = ModelingToolkit.ImperativeAffect(
        update_data!; modified = modified_nt, observed = NamedTuple(), ctx = ctx_nt)

    return ModelingToolkit.SymbolicDiscreteCallback(
        all_tstops, affect; initialize = affect)
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(split(string(typeof(itp.fs.fs)), ".")[end]).$(itp.varname)"
end

function _get_staggering(var)
    misc = getmisc(var)
    @assert :staggering in keys(misc) "Staggering is not specified for variable $(var)."
    return misc[:staggering]
end
