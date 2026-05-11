# ModelingToolkit integration for DataSetInterpolator.
# This file contains symbolic registration, equation creation, and
# system event generation that depend on ModelingToolkit.

# Custom symtype for data buffer discretes. Using a non-Real, non-AbstractArray
# type gives scalar symbolic shape (so canonicalize_eq! works) while routing
# values to MTK's nonnumeric parameter buffer (is_variable_floatingpoint returns false).
# Parameterized on the underlying array type so that dispatch resolves the
# concrete element type and backend (CPU `Array` vs. device arrays like
# `CuArray`). This is load-bearing for GPU execution: `interp_unsafe(data.data,
# ...)` is only type-stable (and therefore kernel-compilable) when the array
# type is known at compile time — not when `data.data::Any`.
struct DataBufferType{A <: AbstractArray}
    data::A
end
# Pass-through constructors for MTK's `narrow_buffer_type`, which broadcasts
# the target type over each entry of the nonnumeric buffer. When an entry is
# already wrapped we short-circuit; when given a raw array we wrap it.
DataBufferType{A}(x::DataBufferType{A}) where {A <: AbstractArray} = x
function DataBufferType{A}(x::DataBufferType) where {A <: AbstractArray}
    DataBufferType{A}(convert(A, x.data))
end
Base.convert(::Type{DataBufferType}, x::DataBufferType) = x
Base.convert(::Type{DataBufferType}, x::AbstractArray) = DataBufferType(x)
Base.convert(::Type{DataBufferType{A}}, x::DataBufferType{A}) where {A} = x
function Base.convert(::Type{DataBufferType{A}}, x::AbstractArray) where {A}
    DataBufferType{A}(convert(A, x))
end
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
# the fallback may not handle it correctly. `Type{<:DataBufferType}` matches
# any concrete parameterization (e.g. `DataBufferType{Array{Float64,4}}`,
# `DataBufferType{Array{Float32,4}}`, `DataBufferType{CuArray{Float64,4}}`).
for n_args in 4:6
    @eval Symbolics.SymbolicUtils.promote_symtype(::typeof(interp_unsafe),
        ::Type{<:DataBufferType}, $(fill(:(::Type), n_args - 2)...), ::Type) = Real
    @eval Symbolics.SymbolicUtils.promote_symtype(::typeof(interp_time_only),
        ::Type{<:DataBufferType}, $(fill(:(::Type), n_args - 2)...), ::Type) = Real
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
    # `init_data` is allocated by the caller via `similar(domain.u_proto, ...)`,
    # so it already has the correct element type and array backend (CPU vs.
    # device). Do NOT promote to Float64 here — that would break Float32
    # simulations and force all data buffers onto the host.
    #
    # We use `@parameters` (not `@discretes $name(t)`) because the data buffer's
    # *value* does not depend on `t` in a way that the symbolic differentiator
    # can reason about — the value jumps discretely at callback fire times.
    # Declaring it as `name(t)` made `executediff` produce a non-trivial
    # `Differential(t)(name(t))` term during `calculate_tgrad`, whose symtype is
    # `DataBufferType`; `mul_worker` then threw `MethodError(*, (Real,
    # DataBufferType))` because the zero chain-rule factor from
    # `@register_derivative interp_unsafe` can't be multiplied by it. Making
    # the parameter time-independent short-circuits the derivative walk
    # (`occursin_info(t, name) == false` => `COMMON_ZERO`).
    # The discrete update event's `ImperativeAffect` writes to the parameter
    # just the same whether it's `@parameters` or `@discretes`.
    #
    # `@parameters` needs a concrete `DataType` for the `::T` annotation, and
    # `DataBufferType` as a parameterized struct is a `UnionAll`.  Build the
    # concrete parameterization `DataBufferType{typeof(init_data)}` at runtime
    # and feed it into `@parameters` via `@eval` so the macro sees a concrete
    # type.  This is called a handful of times at model construction — the
    # `@eval` cost is in the noise compared to `mtkcompile`.
    BT = DataBufferType{typeof(init_data)}
    expr = quote
        @parameters $name::$BT = $init_data [description = $desc]
    end
    return only(Core.eval(@__MODULE__, expr))
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

    n = length(filename) > 0 ? Symbol("$(filename)₊$(itp.varname)") :
        Symbol("$(itp.varname)")

    # Compute the correct data array dimensions from the cached spatial
    # grid size (populated once at DSI construction) plus the time-cache
    # depth (`itp.cache_size`, also fixed at construction).
    cache_nt = itp.cache_size
    data_dims = (itp.grid_size..., cache_nt)

    # Data discrete — wrapped in `DataBufferType` so MTK stores it in the
    # nonnumeric parameter buffer with scalar symbolic shape. Allocate via
    # `similar(domain.u_proto, ...)` so the buffer inherits the array backend
    # of the state vector (plain `Array` on CPU, `CuArray`/`ROCArray`/etc. on
    # device). Element type comes from the interpolator's `To` parameter,
    # which is derived from `eltype(domaininfo)`.
    #
    # *Size*: use a minimal sentinel array at construction time rather than
    # the full model grid.  At production domain sizes the full grid can be
    # hundreds of MB per variable; pre-allocating one for every symbolic
    # `create_interp_equation` would blow up the build-time memory budget
    # (GitHub Actions runners have 7 GB RAM, a multi-loader simulation has
    # 200+ variables).  The discrete update event (`build_interp_event`)
    # replaces the sentinel with a full-sized array only for the variables
    # whose data is actually referenced in the compiled RHS, matching the
    # pre-refactor behaviour of growing on first event fire.  The number of
    # dimensions still has to match the runtime `interp_unsafe` dispatch, so
    # we keep `ndims` intact and only collapse each spatial/time axis to 2.
    n_data = Symbol(n, :_data)
    sentinel_dims = ntuple(_ -> 2, length(data_dims))
    init_data = similar(itp.domain.u_proto, To, sentinel_dims...)
    fill!(init_data, zero(To))
    p_data = _make_array_discrete(n_data, init_data, length(sentinel_dims),
        "Interpolation data for $(n)")

    # Time grid discretes — scalar defaults work fine in MTK.
    #
    # The sentinel buffer above is `(2, ..., 2)`, so the computed fractional
    # time index `fit = 1 + (t_ref + t - p_tstart) / p_tstep` must land in
    # `[1, 2]` for `@boundscheck` not to fire during the RHS pre-evaluation
    # that ODE solvers perform inside `init(prob, alg)` BEFORE the discrete
    # callback's `initialize` affect runs (e.g. Tsit5's FSAL stage in
    # `Tsit5Cache.initialize!`).  Picking `p_tstart = t_ref + tspan[1]` and
    # `p_tstep = tspan[2] - tspan[1]` makes the sentinel cover exactly the
    # integration window: `fit = 1` at `t = tspan[1]` and `fit = 2` at
    # `t = tspan[2]`, with linear interpolation in between — so any in-tspan
    # probe is in bounds with a real meaning (all zeros, matching the
    # sentinel contents).  No `Inf` arithmetic, no special-casing in the
    # interpolation kernel.  The callback's initialize affect subsequently
    # overwrites both defaults with the cache-derived values once data is
    # loaded.
    n_tstart = Symbol(n, :_tstart)
    n_tstep = Symbol(n, :_tstep)
    t_ref_val = EarthSciMLBase.get_tref(itp.domain)
    tspan = EarthSciMLBase.get_tspan(itp.domain)
    ts_default = Float64(t_ref_val) + Float64(tspan[1])
    tstep_default = max(Float64(tspan[2]) - Float64(tspan[1]), 1.0)
    # `@parameters` (not `@discretes`) — see rationale on `_make_array_discrete`.
    # These parameters *are* updated by the discrete event at the same time
    # `_data` is, but leaving them as `(t)`-dependent `@discretes` makes
    # MTK attach a parameter timeseries slot which feeds a `SymbolCache` into
    # the IMEX solver's solution-saving path and crashes in
    # `get_saveable_values(::SymbolCache, ...)`.  Making them time-independent
    # parameters bypasses that entire machinery; `ImperativeAffect` can still
    # write to plain parameters.
    p_tstart = only(@parameters $n_tstart = ts_default [
        unit = u"s", description = "Time grid start for $(n)"])
    p_tstep = only(@parameters $n_tstep = tstep_default [
        unit = u"s", description = "Time grid step for $(n)"])

    # Spatial grid constants (fixed for the lifetime of the simulation).
    # Each constant gets the same unit as the corresponding coordinate variable
    # (e.g., meters for Lambert, radians for longlat) so that fi = 1 + (coord - start) / step
    # is dimensionally consistent.
    spatial_consts = []
    for i in eachindex(coords)
        coord_unit = ModelingToolkit.get_unit(coords[i])
        sn_start = Symbol(n, :_s, i, :start)
        sn_step = Symbol(n, :_s, i, :step)
        push!(spatial_consts,
            only(@constants $sn_start = itp.grid_starts[i] [
                unit = coord_unit,
                description = "Spatial grid start dim $(i) for $(n)"]))
        push!(spatial_consts,
            only(@constants $sn_step = itp.grid_steps[i] [
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

    # Bundle the interp info up front so both the equation's RHS and any
    # downstream at-different-coords evaluations go through a single code path
    # (`build_interp_expr`). `wrapper_f` (e.g., NEI scaling) is layered on
    # after; it's specific to the equation definition and not applicable to
    # callers that just want the raw interpolator value at other coordinates.
    const_defaults = Dict{Any, Any}()
    for i in eachindex(coords)
        const_defaults[spatial_consts[2i - 1]] = itp.grid_starts[i]
        const_defaults[spatial_consts[2i]] = itp.grid_steps[i]
    end
    const_defaults[p_extrap] = extrap_val
    const_defaults[unit_scale] = 1.0

    # `live`: per-variable run-time gate.  Flipped to `false` by
    # `build_interp_event`'s init affect for variables that no compiled equation
    # references, suppressing both `lazyload!` (no NetCDF read) and the
    # first-fire grow-from-sentinel allocation in the affect.  Defaults to
    # `true` so standalone `mtkcompile(loader)` (no parent system to prune
    # against) loads everything.
    interp_info = (data_sym = p_data, tstart_sym = p_tstart, tstep_sym = p_tstep,
        spatial_consts = spatial_consts, extrap_const = p_extrap,
        unit_const = unit_scale, itp = itp, var_sym = n,
        data_dims = data_dims, data_eltype = To,
        const_defaults = const_defaults, spatial_interp = spatial_interp,
        live = Ref(true))

    # Single source of truth for the interp formula.
    rhs = wrapper_f(build_interp_expr(interp_info, t_ref + t, coords))

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

"""
    InterpInfos

Marker type used as a metadata key on systems built by
[`create_interp_equation`](@ref) to store their per-variable `interp_info`
vector. Used by [`interp_callable`](@ref). Must be a type (not a `Symbol`)
because MTK's `System` metadata is typed `Dict{DataType, Any}`.
"""
struct InterpInfos end

"""
    InterpCallable(info)

A thin callable wrapper around an `interp_info` (as produced by
[`create_interp_equation`](@ref)). Calling it with an absolute-time expression
and one expression per spatial coordinate returns the symbolic interpolation
value at those coordinates — i.e. `itp(t_abs, locs...)` behaves like a classic
interpolator callable, regardless of what the system's current coordinate
variables are.

This exists so downstream packages can evaluate an interpolator at
**arbitrary** coordinates (e.g. plume-rise Newton steps at different vertical
levels) without having to recompute fractional indices by hand.

Use [`interp_callable`](@ref) to fetch one by variable name from a
`create_interp_equation`-built system, and [`parent_scope_interp_info`](@ref)
to re-scope the captured parameters when building a coupling equation in a
parent system.
"""
struct InterpCallable{I}
    info::I
end

function (c::InterpCallable)(t_expr, coord_exprs...)
    return build_interp_expr(c.info, t_expr, collect(coord_exprs))
end

"""
    interp_callable(sys, varname::Symbol; parent_scope = false) -> InterpCallable

Look up the `interp_info` for a variable named `varname` on a system built
with [`create_interp_equation`](@ref) (e.g. GEOSFP) and return an
[`InterpCallable`](@ref) that evaluates that interpolator at arbitrary
coordinates. If `parent_scope = true`, the captured parameters are resolved
*through* the system (so they carry the system's namespace) and then
wrapped with `ParentScope` — this is what you want when the returned
callable will be used inside a `couple2` method so the resulting equation
can live in the parent system's namespace.

The system must carry its `InterpInfos` metadata, which `GEOSFP` populates
automatically.
"""
function interp_callable(sys, varname::Symbol; parent_scope::Bool = false)
    infos = ModelingToolkit.getmetadata(sys, InterpInfos, nothing)
    infos === nothing && error(
        "System $(ModelingToolkit.nameof(sys)) has no `InterpInfos` metadata; " *
        "`interp_callable` only works on systems built via `create_interp_equation`."
    )
    idx = findfirst(i -> i.var_sym === varname, infos)
    idx === nothing && error(
        "No interpolator found for `$varname` on system " *
        "$(ModelingToolkit.nameof(sys)). Known vars: " *
        join([i.var_sym for i in infos], ", ")
    )
    info = infos[idx]

    if parent_scope
        # Access each captured parameter *through* `sys` so it picks up the
        # system's namespace, then apply `ParentScope` to lift it to the
        # parent coupler's scope. Using the bare symbols from `info` without
        # going through `sys` would leave references like `A1₊PBLH_data`
        # unnamespaced in the parent, and `mtkcompile` rejects them with
        # "…is present in the system but …is not an unknown".
        PS = ModelingToolkit.ParentScope
        get_name(sym) = ModelingToolkit.getname(
            sym isa Symbolics.Num ? Symbolics.unwrap(sym) : sym)
        via(sym) = PS(getproperty(sys, get_name(sym)))
        info = merge(info, (
            data_sym = via(info.data_sym),
            tstart_sym = via(info.tstart_sym),
            tstep_sym = via(info.tstep_sym),
            spatial_consts = Any[via(c) for c in info.spatial_consts],
            extrap_const = via(info.extrap_const),
            unit_const = via(info.unit_const),
        ))
    end
    return InterpCallable(info)
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

    # Build context NamedTuple: `DataSetInterpolator` objects.  Field order
    # matches `interp_infos`, and each info contributes a 3-stride block of
    # entries to `mod_keys` in the same order (data, tstart, tstep), so the
    # callback can index `mod_keys[3i-2 : 3i]` from the i-th ctx pair without
    # a key lookup.
    ctx_keys = Symbol[]
    ctx_vals = []
    for info in interp_infos
        push!(ctx_keys, Symbol(:itp_, info.var_sym))
        push!(ctx_vals, info.itp)
    end
    ctx_nt = NamedTuple{Tuple(ctx_keys)}(Tuple(ctx_vals))

    # The full-grid data buffer lives on the parameter object itself.  Each
    # data parameter starts out wrapping a 2^N sentinel array (see
    # `_make_array_discrete`); the `initialize` affect below grows it to the
    # full grid via `similar(domain.u_proto, ...)` and loads the first window
    # of data.  The steady-state `update` affect then reuses the parameter's
    # array in place via `lazyload!`, so steady-state memory is exactly one
    # full-grid buffer per live variable (plus, for cross-device runs, a host
    # staging array inside `cache.host_scratch`).  Variables whose `live[]`
    # has been cleared by `_apply_live_mask!` keep their sentinel buffer —
    # no NetCDF read, no full-grid allocation.
    #
    # `SolverStrangThreads` fires the update affect from multiple threads
    # concurrently, so it is guarded by a lock.  The lock only covers callback
    # invocation (rare, at tstops), not the RHS hot path, so the cost is
    # negligible.  The init affect runs exactly once at problem build and
    # doesn't need the lock for correctness, but shares it for symmetry.
    n_interps = length(interp_infos)
    # Hoisted: `result_vals` and the NamedTuple key-tuple are reused across
    # every callback fire instead of being rebuilt each time. The callback is
    # serialized by `update_lock`, so in-place mutation is safe.
    result_vals = Vector{Any}(undef, 3 * n_interps)
    mod_keys_tuple = Tuple(mod_keys)
    update_lock = ReentrantLock()

    # Per-interp_info `live` Refs captured so the affect can skip variables
    # that no compiled equation in the parent system references.  Refs
    # default to `true`; [`prune_unused_interps!`] (opt-in) flips them to
    # `false` after compilation.  Dead variables keep whatever the parameter
    # buffer was set to at problem construction (the 2^N sentinel) — no
    # NetCDF read, no full-grid allocation.
    lives = [info.live for info in interp_infos]

    # Pre-fill `result_vals` with the current parameter values, then overwrite
    # only the live entries.  Used by both init and update affects.
    @inline function _seed_result_vals!(mod_input)
        @inbounds for k in 1:length(mod_keys_tuple)
            result_vals[k] = mod_input[k]
        end
    end

    # `initialize` affect: fires exactly once at problem build (via MTK's
    # `init(prob, alg)`), *before* any solve-time tstop fire.  Handles:
    #   (1) auto-prune fallback for paths that bypass the convert-time
    #       `SysDiscreteEvent` factory walk (plain `compose + mtkcompile`);
    #       skipped for operator-split solvers whose inner integrator has
    #       `integ.f.sys === nothing`, since pruning has already run.
    #   (2) growing each live buffer from the 2^N sentinel to the full grid
    #       via `similar(domain.u_proto, ...)` so the array backend matches
    #       the state vector.
    #   (3) seeding the first window of data via `lazyload!` and updating
    #       the `tstart`/`tstep` parameters.
    # After this returns, MTK stores the full-size buffers in the parameter
    # object; the update affect below reuses them in place.
    function init_affect!(modified, observed, ctx, integ)
        lock(update_lock) do
            sys = isdefined(integ.f, :sys) ? integ.f.sys : nothing
            if sys !== nothing
                _apply_live_mask!(interp_infos, sys)
            end
            mod_input = values(modified)
            _seed_result_vals!(mod_input)
            i = 0
            for (_, dsi) in pairs(ctx)
                i += 1
                lives[i][] || continue
                current = mod_input[3i - 2]::DataBufferType
                buf = similar(dsi.domain.u_proto, eltype(current.data),
                    dsi.grid_size..., dsi.cache_size)
                fill!(buf, zero(eltype(buf)))
                lazyload!(dsi, integ.t + t_ref, buf)
                result_vals[3i - 2] = DataBufferType(buf)
                ts, tstep = get_time_grid_params(dsi)
                result_vals[3i - 1] = ts
                result_vals[3i] = tstep
            end
            NamedTuple{mod_keys_tuple}(Tuple(result_vals))
        end
    end

    # Steady-state `affect`: fires at each tstop in `all_tstops`.  Buffers are
    # already full-size and seeded by `init_affect!`, so this path just slides
    # the time window via `lazyload!` (in-place on the parameter's buffer) and
    # refreshes `tstart`/`tstep`.
    function update_affect!(modified, observed, ctx, integ)
        lock(update_lock) do
            mod_input = values(modified)
            _seed_result_vals!(mod_input)
            i = 0
            for (_, dsi) in pairs(ctx)
                i += 1
                lives[i][] || continue
                current = mod_input[3i - 2]::DataBufferType
                lazyload!(dsi, integ.t + t_ref, current.data)
                ts, tstep = get_time_grid_params(dsi)
                result_vals[3i - 1] = ts
                result_vals[3i] = tstep
            end
            NamedTuple{mod_keys_tuple}(Tuple(result_vals))
        end
    end

    init_affect = ModelingToolkit.ImperativeAffect(
        init_affect!; modified = modified_nt, observed = NamedTuple(),
        ctx = ctx_nt)
    update_affect = ModelingToolkit.ImperativeAffect(
        update_affect!; modified = modified_nt, observed = NamedTuple(),
        ctx = ctx_nt)

    # `initialize_save_discretes = false`: the data buffer parameters are
    # internal bookkeeping, not user-visible state, so we don't need MTK to
    # save them on the initialize affect.  This avoids a spurious
    # `sol.t == [tspan[1], tspan[1], ...]` duplicate at the start of the
    # solution.  Note: `save_positions` on the underlying `PresetTimeCallback`
    # may still produce extra entries; downstream code should use
    # `sol(saveat)` rather than `sol.u` indexing for fixed-size sampling.
    return ModelingToolkit.SymbolicDiscreteCallback(
        all_tstops, update_affect; initialize = init_affect,
        initialize_save_discretes = false)
end

"""
$(SIGNATURES)

Mark each interpolator in `loader_sys`'s [`InterpInfos`] metadata that no
compiled equation in `parent_sys` references as `live[] = false`, so
[`build_interp_event`]'s affect skips its `lazyload!` call (no NetCDF read,
no first-fire grow-from-sentinel allocation).  `parent_sys` should be the
post-`mtkcompile` system that `loader_sys` is part of.

`extra_needed` is an extra set of symbolic variables to treat as needed
(beyond what `equations(parent_sys)` and `observed(parent_sys)` reach).
Pass `EarthSciMLBase.operator_vars(csys, parent_sys, domain)` here when the
system uses [`EarthSciMLBase.Operator`]s (e.g. advection); operators
specify their needs via `get_needed_vars` outside the symbolic equation
graph and would otherwise be missed by the equation/observed walk.

Loaders auto-register a `SysDiscreteEvent`-shaped factory in their
metadata that calls this function with the temp coupled+`mtkcompile`d
system at `convert(::Type{System}, ::CoupledSystem)` time, so the standard
`couple(...)` → `convert(System, csys)` path applies pruning without any
extra user action.  Call this function manually only when you bypass that
path (e.g. plain `compose` + `mtkcompile`) or when you need to inject
`extra_needed`.

The pruning is irreversible for the lifetime of the loader's `interp_info`
vector — build a fresh loader to reset `live[]` to `true`.

The "needed" check substitutes observed equations into state-equation RHSs
via `Symbolics.fixpoint_sub` and walks the resulting variables.  A variable
that downstream compilation inlines through observed eqs that this walk
doesn't reach (e.g. through coordinate-aware codegen paths in some
operator-split solvers) could be marked dead in error.  If this happens
the symptom is `interp_unsafe: time index outside loaded cache range` at
solve time; in that case skip the call or expand `extra_needed`.

# Example

```julia
emis = NEI2016MonthlyEmis(\"sector\", domain)
@variables ACET(t) = 0.0
sys = compose(System([D(ACET) ~ emis.ACET], t, [ACET], []; name = :state), emis)
sys = mtkcompile(sys)
EarthSciData.prune_unused_interps!(emis, sys)  # opt in to gating
prob = ODEProblem(sys, ..., tspan)
```

When the workflow uses operators:

```julia
csys = couple(sys, emis, Advection(), domain)
parent_sys = convert(System, csys)
extra = EarthSciMLBase.operator_vars(csys, parent_sys, domain)
EarthSciData.prune_unused_interps!(emis, parent_sys; extra_needed = extra)
```
"""
# Single source of truth for the live-mask walk: substitute observed equations
# into each state equation's RHS and collect the names of every referenced
# variable.  Then mark each `interp_info` whose data symbol does not appear in
# the resulting set as `live[] = false`.  Used by `prune_unused_interps!`,
# `make_prune_factory`, and the affect's first-fire auto-prune path.
function _apply_live_mask!(interp_infos, parent_sys; extra_needed = ())
    bare_data_syms = [string(EarthSciMLBase.var2symbol(info.data_sym))
                      for info in interp_infos]
    obs_subst = Dict{Any, Any}()
    for eq in ModelingToolkit.observed(parent_sys)
        obs_subst[eq.lhs] = eq.rhs
    end
    referenced = Set{String}()
    for eq in ModelingToolkit.equations(parent_sys)
        substed = isempty(obs_subst) ? eq.rhs :
                  Symbolics.fixpoint_sub(eq.rhs, obs_subst)
        for v in Symbolics.get_variables(substed)
            push!(referenced, string(EarthSciMLBase.var2symbol(v)))
        end
    end
    for v in extra_needed
        push!(referenced, string(EarthSciMLBase.var2symbol(v)))
    end
    is_needed = [bare in referenced ||
                 any(s -> endswith(s, "₊" * bare), referenced)
                 for bare in bare_data_syms]
    if any(is_needed)
        kept = String[]
        dropped = String[]
        for (k, ok) in enumerate(is_needed)
            name = string(interp_infos[k].var_sym)
            if ok
                push!(kept, name)
            else
                interp_infos[k].live[] = false
                push!(dropped, name)
            end
        end
        # Surface the pruning result so users debugging "why is my chemistry
        # mechanism not seeing emissions for X?" can see whether X was pruned.
        # `@debug` keeps this silent in production; set
        # `JULIA_DEBUG=EarthSciData` to enable.
        @debug "Live-mask pruning: kept $(length(kept)) of $(length(interp_infos)) " *
               "interpolators, dropped $(length(dropped))" kept dropped
    end
    return is_needed
end

function prune_unused_interps!(loader_sys, parent_sys; extra_needed = ())
    interp_infos = ModelingToolkit.getmetadata(
        loader_sys, InterpInfos, nothing)
    isnothing(interp_infos) && return loader_sys
    _apply_live_mask!(interp_infos, parent_sys; extra_needed = extra_needed)
    return loader_sys
end

"""
$(SIGNATURES)

Convenience wrapper: convert `csys` to a `System`, gather operator-needed
variables via `EarthSciMLBase.operator_vars`, and call
[`prune_unused_interps!`] on `loader_sys` with both.  Returns the
post-`mtkcompile` parent system so callers can use it for
`ODEProblem(parent_sys, ...)`.
"""
function prune_unused_interps!(
        loader_sys, csys::EarthSciMLBase.CoupledSystem; kwargs...)
    parent_sys = convert(ModelingToolkit.System, csys; kwargs...)
    extra = isnothing(csys.domaininfo) || isempty(csys.ops) ? () :
            EarthSciMLBase.operator_vars(csys, parent_sys, csys.domaininfo)
    prune_unused_interps!(loader_sys, parent_sys; extra_needed = extra)
    return parent_sys
end

"""
$(SIGNATURES)

Build a `SysDiscreteEvent`-shaped factory closing over `interp_infos`.
EarthSciMLBase's `convert(::Type{System}, ::CoupledSystem)` walks every
subsystem's `SysDiscreteEvent` metadata and calls each factory with the
temp coupled+`mtkcompile`d parent system; this factory side-effects the
captured `interp_info.live` Refs and returns `nothing`, so the discrete
event list passed to the parent is empty.  EarthSciMLBase's walker
filters `nothing` returns, so registering this factory adds no new
discrete events to the parent system — the existing loader-attached
`build_interp_event` callback fires as before, just with a settled live
mask by the time it runs.

`operator_vars` is *not* consulted here because the factory only sees the
post-compile `System` (no `CoupledSystem` access).  Workflows using
`EarthSciMLBase.Operator`s should bypass auto-pruning by calling
[`prune_unused_interps!`](@ref) on the `CoupledSystem` directly (which
does include `operator_vars`).
"""
function make_prune_factory(interp_infos)
    return function (parent_sys)
        _apply_live_mask!(interp_infos, parent_sys)
        return nothing
    end
end

Latexify.@latexrecipe function f(itp::EarthSciData.DataSetInterpolator)
    return "$(split(string(typeof(itp.fs)), ".")[end]).$(itp.varname)"
end

function _get_staggering(var)
    misc = getmisc(var)
    @assert :staggering in keys(misc) "Staggering is not specified for variable $(var)."
    return misc[:staggering]
end
