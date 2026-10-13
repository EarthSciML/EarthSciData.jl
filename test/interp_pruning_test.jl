using Dates
using DynamicQuantities
using EarthSciMLBase
using EarthSciData
using ModelingToolkit
using ModelingToolkit: t, D
using NCDatasets
using OrdinaryDiffEqTsit5
using Test

# When a multi-variable data loader is composed into a parent system that
# references only a subset of its variables, `EarthSciData.prune_unused_interps!`
# (opt-in) marks the unreferenced ones as dead so the discrete update event's
# affect skips their `lazyload!`, leaving the sentinel buffers in place.  This
# test verifies that gating works for the simple `ODEProblem(sys, ...)` path.
@testset "Interpolator pruning under partial use" begin
    era5_dir = mktempdir()

    lon_vals = Float64.(-130.0:2.0:-60.0)
    lat_vals = Float64.(20.0:2.0:50.0)
    plev_vals = Float64.([1000, 975, 950, 925])
    hours_per_day = 0:6:18

    era5_vars = Dict(
        "t" => ("K", "Temperature", 260.0, 300.0),
        "u" => ("m s**-1", "U component of wind", -15.0, 15.0),
        "v" => ("m s**-1", "V component of wind", -15.0, 15.0),
        "w" => ("Pa s**-1", "Vertical velocity", -1.0, 1.0),
        "q" => ("kg kg**-1", "Specific humidity", 0.0, 0.02),
        "r" => ("%", "Relative humidity", 0.0, 100.0),
        "z" => ("m**2 s**-2", "Geopotential", 0.0, 1e5),
        "d" => ("s**-1", "Divergence", -1e-5, 1e-5),
        "vo" => ("s**-1", "Vorticity (relative)", -1e-5, 1e-5),
        "o3" => ("kg kg**-1", "Ozone mass mixing ratio", 0.0, 1e-5),
        "cc" => ("(0 - 1)", "Fraction of cloud cover", 0.0, 1.0),
        "ciwc" => ("kg kg**-1", "Specific cloud ice water content", 0.0, 1e-5),
        "clwc" => ("kg kg**-1", "Specific cloud liquid water content", 0.0, 1e-5),
        "crwc" => ("kg kg**-1", "Specific rain water content", 0.0, 1e-5),
        "cswc" => ("kg kg**-1", "Specific snow water content", 0.0, 1e-5),
        "pv" => ("K m**2 kg**-1 s**-1", "Potential vorticity", -1e-5, 1e-5)
    )

    nlon, nlat, nplev = length(lon_vals), length(lat_vals), length(plev_vals)
    fpath = joinpath(era5_dir, "era5_pl_2022_01.nc")
    time_vals = DateTime[]
    for d in 1:Dates.daysinmonth(2022, 1), h in hours_per_day

        push!(time_vals, DateTime(2022, 1, d, h))
    end
    ntime = length(time_vals)

    NCDataset(fpath, "c") do ds
        defDim(ds, "longitude", nlon)
        defDim(ds, "latitude", nlat)
        defDim(ds, "pressure_level", nplev)
        defDim(ds, "valid_time", ntime)
        defVar(ds, "longitude", Float64, ("longitude",))[:] = lon_vals
        defVar(ds, "latitude", Float64, ("latitude",))[:] = lat_vals
        defVar(ds, "pressure_level", Float64, ("pressure_level",))[:] = plev_vals
        nctime = defVar(ds, "valid_time", Float64, ("valid_time",),
            attrib = Dict("units" => "hours since 1900-01-01 00:00:00",
                "calendar" => "proleptic_gregorian"))
        nctime[:] = time_vals
        for (varname, (unit_str, long_name, vmin, vmax)) in era5_vars
            ncvar = defVar(ds, varname, Float32,
                ("longitude", "latitude", "pressure_level", "valid_time"),
                attrib = Dict("units" => unit_str, "long_name" => long_name))
            data = Array{Float32}(undef, nlon, nlat, nplev, ntime)
            for ti in 1:ntime, k in 1:nplev, j in 1:nlat, i in 1:nlon
                frac = (i + j + k + ti) / (nlon + nlat + nplev + ntime)
                data[i, j, k, ti] = Float32(vmin + (vmax - vmin) * frac)
            end
            ncvar[:, :, :, :] = data
        end
    end

    domain = DomainInfo(
        DateTime(2022, 1, 1), DateTime(2022, 1, 2);
        latrange = deg2rad(20.0f0):deg2rad(2.0):deg2rad(50.0f0),
        lonrange = deg2rad(-130.0f0):deg2rad(2.0):deg2rad(-60.0f0),
        levrange = 1:4
    )
    era5 = ERA5(domain; mirror = "file://$(era5_dir)")

    infos = ModelingToolkit.getmetadata(era5, EarthSciData.InterpInfos, nothing)
    @test length(infos) == length(era5_vars)
    for info in infos
        @test info.itp.cache.initialized == false
    end

    # Auto-registration check: every loader's metadata should carry a
    # `SysDiscreteEvent` factory so EarthSciMLBase's
    # `convert(::Type{System}, ::CoupledSystem)` walks it automatically.
    auto_factory = ModelingToolkit.getmetadata(
        era5, EarthSciMLBase.SysDiscreteEvent, nothing)
    @test auto_factory !== nothing
    @test auto_factory isa Function
    @test hasmethod(auto_factory, (ModelingToolkit.AbstractSystem,))

    # Parent state references only the temperature interpolator (`pl₊t`).
    # All other ERA5 variables (u, v, w, q, ...) are unreferenced.
    @variables C(t) = 0.0 [unit = u"K*s"]
    eq = D(C) ~ era5.pl₊t
    sys_unsimp = compose(System([eq], t, [C], []; name = :state), era5)
    sys = mtkcompile(sys_unsimp)

    # `compose` + `mtkcompile` bypasses `convert(::Type{System}, ::CoupledSystem)`,
    # so the auto-registered `SysDiscreteEvent` walk doesn't fire.  We do NOT
    # call `auto_factory(sys)` here — the discrete update event's affect runs
    # the same `_apply_live_mask!` walk on its first fire (using
    # `integ.f.sys`), so this test verifies the auto-prune-at-init path.
    @test all(info.itp.cache.initialized == false for info in infos)
    @test all(info.live[] == true for info in infos)

    ps = parameters(sys)
    lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
    lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))
    lev_p = only(filter(p -> endswith(string(Symbol(p)), "₊lev"), ps))

    prob = ODEProblem(
        sys,
        [lat_p => deg2rad(35.0), lon_p => deg2rad(-90.0), lev_p => 1.0],
        (0.0, 60.0)
    )
    integ = init(prob, Tsit5())

    initialized = sort([String(info.itp.varname)
                        for info in infos if info.itp.cache.initialized])
    not_initialized = sort([String(info.itp.varname)
                            for info in infos if !info.itp.cache.initialized])

    @info "After init(prob): $(length(initialized)) of $(length(infos)) interpolators loaded" initialized not_initialized

    # Sanity: the variable referenced by the state RHS must be loaded.
    @test "t" in initialized

    # Per-variable gating: variables that no compiled equation references
    # must NOT have their parameter buffer grown from the sentinel by the
    # discrete event firing during `init`.  The init affect prunes them via
    # `needed_vars(integ.f.sys)` so subsequent fires (and the init fire
    # itself) skip `lazyload!` on dead interpolators.
    for v in ["u", "v", "w", "q", "r", "z", "d", "vo", "o3", "cc",
        "ciwc", "clwc", "crwc", "cswc", "pv"]
        @test v in not_initialized
    end
    @test length(initialized) == 1
end

using EarthSciData: make_prune_factory
using ModelingToolkit: t_nounits, D_nounits

using ModelingToolkit
using ModelingToolkit: t_nounits as t, D_nounits as D

# tiny real System: the 2-arg prune path inspects observed(parent_sys)
@variables x(t)
@named _mini = System([D(x) ~ 0], t)
const _msys = mtkcompile(_mini)

@testset "Data: prune factory 1-arg/2-arg contract" begin
    # Empty interp_infos keeps the test independent of any dataset: the point is
    # the DISPATCH branch, and _apply_live_mask! over [] is a well-defined no-op.
    f = make_prune_factory(Any[])
    @test f isa Function

    # 1-arg (legacy walker): must return nothing AND not attempt to prune.
    # A safe skip keeps callback-only met vars live — a callback-only met var
    # (A1₊PBLH) sits in no compiled equation, so equation-only pruning would drop
    # it. The legacy path therefore keeps every interp live.
    @test f(nothing) === nothing

    # 2-arg with an explicit keep-set: takes the prune path (no error on []).
    @test f(_msys, String[]) === nothing
    @test f(_msys, ["GEOSFP₊A1₊PBLH"]) === nothing

    # the two branches are selected exactly as the convert() call site does it
    @test applicable(f, _msys, String[])            # 2-arg method exists
    @test applicable(f, nothing)                       # 1-arg (default extra_needed) too
end

# Regression test for the callback-aware prune (PR #217): `_apply_live_mask!`
# must keep an interpolator alive when it appears in `extra_needed` — the
# operator/init-callback keep-set that `_operator_and_callback_vars` forwards
# through the 2-arg prune path — even though no compiled equation references
# it.  Unlike the dispatch-contract testset above, this one runs the
# live-masking logic on REAL `interp_info` entries (built by
# `create_interp_equation` via the same offline synthetic-ERA5 fixture as the
# first testset), so the mask actually executes on non-empty input.
@testset "Regression: _apply_live_mask! keeps callback-needed interps live" begin
    # Explicit bindings: the `t_nounits as t` import above is ignored by Julia
    # (conflicting import warning), so grab the unitful iv/derivative directly.
    tu = ModelingToolkit.t
    Du = ModelingToolkit.D

    era5_dir = mktempdir()

    lon_vals = Float64.(-130.0:2.0:-60.0)
    lat_vals = Float64.(20.0:2.0:50.0)
    plev_vals = Float64.([1000, 975, 950, 925])
    hours_per_day = 0:6:18

    # Three variables, one per pruning role:
    #   t — referenced by the parent system's only state equation (equation-needed);
    #   q — referenced by NO equation: stands in for a callback-only met var
    #       (the GEOSFP `A1₊PBLH` role — consumed out-of-band by
    #       `PBLMixingCallback`'s observed function, so invisible to the
    #       equation-reference scan);
    #   u — needed by nothing (must actually be pruned, proving the mask ran).
    era5_vars = Dict(
        "t" => ("K", "Temperature", 260.0, 300.0),
        "q" => ("kg kg**-1", "Specific humidity", 0.0, 0.02),
        "u" => ("m s**-1", "U component of wind", -15.0, 15.0)
    )

    nlon, nlat, nplev = length(lon_vals), length(lat_vals), length(plev_vals)
    fpath = joinpath(era5_dir, "era5_pl_2022_01.nc")
    time_vals = DateTime[]
    for d in 1:Dates.daysinmonth(2022, 1), h in hours_per_day

        push!(time_vals, DateTime(2022, 1, d, h))
    end
    ntime = length(time_vals)

    NCDataset(fpath, "c") do ds
        defDim(ds, "longitude", nlon)
        defDim(ds, "latitude", nlat)
        defDim(ds, "pressure_level", nplev)
        defDim(ds, "valid_time", ntime)
        defVar(ds, "longitude", Float64, ("longitude",))[:] = lon_vals
        defVar(ds, "latitude", Float64, ("latitude",))[:] = lat_vals
        defVar(ds, "pressure_level", Float64, ("pressure_level",))[:] = plev_vals
        nctime = defVar(ds, "valid_time", Float64, ("valid_time",),
            attrib = Dict("units" => "hours since 1900-01-01 00:00:00",
                "calendar" => "proleptic_gregorian"))
        nctime[:] = time_vals
        for (varname, (unit_str, long_name, vmin, vmax)) in era5_vars
            ncvar = defVar(ds, varname, Float32,
                ("longitude", "latitude", "pressure_level", "valid_time"),
                attrib = Dict("units" => unit_str, "long_name" => long_name))
            data = Array{Float32}(undef, nlon, nlat, nplev, ntime)
            for ti in 1:ntime, k in 1:nplev, j in 1:nlat, i in 1:nlon
                frac = (i + j + k + ti) / (nlon + nlat + nplev + ntime)
                data[i, j, k, ti] = Float32(vmin + (vmax - vmin) * frac)
            end
            ncvar[:, :, :, :] = data
        end
    end

    domain_reg = DomainInfo(
        DateTime(2022, 1, 1), DateTime(2022, 1, 2);
        latrange = deg2rad(20.0f0):deg2rad(2.0):deg2rad(50.0f0),
        lonrange = deg2rad(-130.0f0):deg2rad(2.0):deg2rad(-60.0f0),
        levrange = 1:4
    )
    era5 = ERA5(domain_reg; mirror = "file://$(era5_dir)",
        variables = ["t", "q", "u"])

    infos = ModelingToolkit.getmetadata(era5, EarthSciData.InterpInfos, nothing)
    @test length(infos) == 3
    info_for(n) = infos[findfirst(i -> i.var_sym == Symbol("pl₊", n), infos)]
    t_info, q_info, u_info = info_for("t"), info_for("q"), info_for("u")
    reset_live!() = foreach(i -> i.live[] = true, infos)
    @test all(i.live[] for i in infos)

    # Parent state equation references only the temperature interpolator.
    @variables Creg(tu) = 0.0 [unit = u"K*s"]
    eq = Du(Creg) ~ era5.pl₊t
    parent = mtkcompile(compose(
        System([eq], tu, [Creg], []; name = :reg_state), era5))

    # The callback-needed variable exactly as the real caller supplies it:
    # `_operator_and_callback_vars` forwards symbolic variables of the compiled
    # parent system (e.g. from `get_needed_vars(::PBLMixingCallback, ...)`), so
    # pull `ERA5₊pl₊q` back out of the compiled system's observed equations.
    qvar = only(filter(
        v -> endswith(string(EarthSciMLBase.var2symbol(v)), "₊pl₊q"),
        [obs_eq.lhs for obs_eq in ModelingToolkit.observed(parent)]))

    # (a) Equation-only prune (no keep-set): the hazard PR #217 guards against.
    # The callback-only variable is indistinguishable from an unused one and is
    # dropped alongside it.
    mask = EarthSciData._apply_live_mask!(infos, parent)
    @test t_info.live[]
    @test !q_info.live[]   # callback-only var wrongly dropped without keep-set
    @test !u_info.live[]
    @test mask == [i.live[] for i in infos]

    # (b) THE regression: the same prune through the factory's 2-arg path with
    # the keep-set the real caller forwards.  The callback-needed interpolator
    # must survive, and the genuinely unused one must still be pruned (i.e. the
    # mask actually executed rather than no-op'ing).
    reset_live!()
    f = make_prune_factory(infos)
    @test f(parent, [qvar]) === nothing
    @test t_info.live[]    # equation-needed: kept
    @test q_info.live[]    # callback-needed: kept via extra_needed — the fix
    @test !u_info.live[]   # unused: pruned

    # (c) 2-arg with an EMPTY keep-set reproduces (a) through the factory:
    # pruning still runs, so the callback-only variable is dropped again.
    reset_live!()
    @test f(parent, Any[]) === nothing
    @test t_info.live[]
    @test !q_info.live[]
    @test !u_info.live[]

    # (d) Legacy 1-arg factory call: no keep-set can exist, so no pruning at
    # all — every interpolator stays live (the backward-compatible safe skip).
    reset_live!()
    @test f(parent) === nothing
    @test all(i.live[] for i in infos)

    # (e) Shipped safety fallback: pruning against a parent that references NO
    # interpolator (with an empty keep-set) keeps everything live rather than
    # dropping everything.
    reset_live!()
    @variables xreg(tu)
    mini = mtkcompile(System([Du(xreg) ~ 0], tu; name = :reg_mini))
    EarthSciData._apply_live_mask!(infos, mini)
    @test all(i.live[] for i in infos)
end

using Symbolics

# Synthetic ERA5 pressure-level file for January 2022 with the given variables
# (`name => (units, long_name, min, max)`), on the same grid as the fixtures above.
function write_era5_fixture(dir, era5_vars)
    lon_vals = Float64.(-130.0:2.0:-60.0)
    lat_vals = Float64.(20.0:2.0:50.0)
    plev_vals = Float64.([1000, 975, 950, 925])
    time_vals = [DateTime(2022, 1, d, h) for d in 1:31 for h in 0:6:18]
    nlon, nlat, nplev, ntime = length(lon_vals), length(lat_vals), length(plev_vals),
    length(time_vals)
    NCDataset(joinpath(dir, "era5_pl_2022_01.nc"), "c") do ds
        defDim(ds, "longitude", nlon)
        defDim(ds, "latitude", nlat)
        defDim(ds, "pressure_level", nplev)
        defDim(ds, "valid_time", ntime)
        defVar(ds, "longitude", Float64, ("longitude",))[:] = lon_vals
        defVar(ds, "latitude", Float64, ("latitude",))[:] = lat_vals
        defVar(ds, "pressure_level", Float64, ("pressure_level",))[:] = plev_vals
        nctime = defVar(ds, "valid_time", Float64, ("valid_time",),
            attrib = Dict("units" => "hours since 1900-01-01 00:00:00",
                "calendar" => "proleptic_gregorian"))
        nctime[:] = time_vals
        for (varname, (unit_str, long_name, vmin, vmax)) in era5_vars
            ncvar = defVar(ds, varname, Float32,
                ("longitude", "latitude", "pressure_level", "valid_time"),
                attrib = Dict("units" => unit_str, "long_name" => long_name))
            data = Array{Float32}(undef, nlon, nlat, nplev, ntime)
            for ti in 1:ntime, k in 1:nplev, j in 1:nlat, i in 1:nlon
                frac = (i + j + k + ti) / (nlon + nlat + nplev + ntime)
                data[i, j, k, ti] = Float32(vmin + (vmax - vmin) * frac)
            end
            ncvar[:, :, :, :] = data
        end
    end
    return dir
end

# `_apply_live_mask!` before the reachability walk: every observed equation is
# substituted into every root with `fixpoint_sub`.  Kept here, without the
# mutation, as the oracle the walk must reproduce.
function fixpoint_is_needed(interp_infos, parent_sys; extra_needed = ())
    name(v) = string(EarthSciMLBase.var2symbol(v))
    bare_data_syms = [name(info.data_sym) for info in interp_infos]
    bare_var_syms = [name(info.var_sym) for info in interp_infos]
    matches(bare, n) = n == bare || endswith(n, "₊" * bare)
    obs = ModelingToolkit.observed(parent_sys)
    obs_subst = Dict{Any, Any}(eq.lhs => eq.rhs for eq in obs)
    loader_ns = ""
    for eq in obs
        lhs_name = name(eq.lhs)
        k = findfirst(b -> endswith(lhs_name, "₊" * b), bare_var_syms)
        if k !== nothing
            loader_ns = chop(lhs_name; tail = length(bare_var_syms[k]))
            break
        elseif lhs_name in bare_var_syms
            break
        end
    end
    referenced = Set{String}()
    function record!(expr)
        substed = isempty(obs_subst) ? expr : Symbolics.fixpoint_sub(expr, obs_subst)
        foreach(v -> push!(referenced, name(v)), Symbolics.get_variables(substed))
    end
    foreach(eq -> record!(eq.rhs), ModelingToolkit.equations(parent_sys))
    for eq in ModelingToolkit.get_initialization_eqs(parent_sys)
        record!(eq.lhs)
        record!(eq.rhs)
    end
    if !isempty(loader_ns)
        for eq in obs
            startswith(name(eq.lhs), loader_ns) || record!(eq.rhs)
        end
    end
    foreach(v -> push!(referenced, name(v)), extra_needed)
    return [any(s -> matches(bare_data_syms[k], s) || matches(bare_var_syms[k], s),
                referenced)
            for k in eachindex(interp_infos)]
end

# A model coupled to ERA5 through connector equations, and an init-callback that
# reads one ERA5 field out-of-band (the `PBLMixingCallback` / `A1₊PBLH` role).
struct PruneWalkCoupler
    sys::Any
end
function EarthSciMLBase.couple2(m::PruneWalkCoupler, e::EarthSciData.ERA5Coupler)
    m, e = m.sys, e.sys
    ConnectorSystem([m.Qc ~ e.dq, m.Oc ~ e.pl₊o3, m.Ic ~ e.pl₊ciwc], m, e)
end
struct PruneWalkCallback end
function EarthSciMLBase.init_callback(::PruneWalkCallback, ::EarthSciMLBase.CoupledSystem,
        sys_mtk, coord_args, ::DomainInfo, ::EarthSciMLBase.MapAlgorithm)
    error("not used: the test builds an ODEProblem from the converted System")
end
function EarthSciMLBase.get_needed_vars(::PruneWalkCallback, csys, mtk_sys, domain)
    [only(filter(v -> endswith(string(EarthSciMLBase.var2symbol(v)), "₊pl₊crwc"),
        [eq.lhs for eq in ModelingToolkit.observed(mtk_sys)]))]
end

@testset "Live mask: reachability walk matches fixpoint_sub; settled mask survives init" begin
    tu = ModelingToolkit.t
    Du = ModelingToolkit.D
    dimless = "kg kg**-1"
    # One ERA5 field per way of being reached (or not):
    #   q    — state equation → model observed chain → connector → ERA5's own
    #          derived observed chain (dq ~ 2dq2, dq2 ~ q + 1): five hops;
    #   o3   — connector only, used by no state (an observed-only output);
    #   ciwc — state equation through a connector;
    #   crwc — only the init-callback's keep-set;
    #   clwc — only an unused derived observed inside ERA5's namespace (not a root);
    #   cswc — nothing.
    era5_vars = Dict(v => (dimless, v, 0.0, 1e-5)
    for v in ("q", "o3", "ciwc", "crwc", "clwc", "cswc"))
    era5_dir = write_era5_fixture(mktempdir(), era5_vars)
    domain = DomainInfo(
        DateTime(2022, 1, 1), DateTime(2022, 1, 2);
        latrange = deg2rad(20.0f0):deg2rad(2.0):deg2rad(50.0f0),
        lonrange = deg2rad(-130.0f0):deg2rad(2.0):deg2rad(-60.0f0),
        levrange = 1:4
    )

    function build()
        era5 = ERA5(domain; mirror = "file://$(era5_dir)",
            variables = collect(keys(era5_vars)))
        raw(n) = only(filter(v -> string(EarthSciMLBase.var2symbol(v)) == n,
            ModelingToolkit.unknowns(era5)))
        @variables dq(tu) dq2(tu) dl(tu)
        derived = System([dq ~ 2 * dq2, dq2 ~ raw("pl₊q") + 1, dl ~ 2 * raw("pl₊clwc")],
            tu; name = :ERA5)
        era5x = extend(derived, era5)
        @constants uc_w = 1.0 [unit = u"s"]
        @variables X1(tu) = 0.0 X2(tu) = 0.0 Ac(tu) Bc(tu) Qc(tu) Oc(tu) Ic(tu)
        model = System(
            [Du(X1) ~ Ac / uc_w, Ac ~ 2 * Bc, Bc ~ Qc + 1, Du(X2) ~ Ic / uc_w],
            tu, [X1, X2, Ac, Bc, Qc, Oc, Ic], [uc_w]; name = :PruneWalk,
            metadata = Dict(EarthSciMLBase.CoupleType => PruneWalkCoupler))
        infos = ModelingToolkit.getmetadata(era5x, EarthSciData.InterpInfos, nothing)
        return era5x, model, infos
    end

    # (1) Real `couple` → `convert` path: the factory prunes with the callback's
    # keep-set and settles the mask.  The update event's first fire then sees
    # `integ.f.sys` but must not re-prune without the keep-set (which would drop
    # crwc and leave it as a zero sentinel).
    era5x, model, infos = build()
    info_for(n) = infos[findfirst(i -> i.var_sym == Symbol("pl₊", n), infos)]
    csys = couple(model, era5x, domain, PruneWalkCallback())
    parent = convert(System, csys)
    kept = ["q", "o3", "ciwc", "crwc"]
    dropped = ["clwc", "cswc"]
    @test all(info_for(n).live[] for n in kept)
    @test !any(info_for(n).live[] for n in dropped)
    @test all(i.mask_settled[] for i in infos)
    # With EarthSciMLBase's `ReplaceDiscreteEvents` hook the factory's rebuilt
    # event takes the place of ERA5's own, so the converted system's event
    # modifies only the kept interpolators' parameters.
    nmod = length([v for ev in ModelingToolkit.discrete_events(parent)
                   for v in ev.affect.modified])
    nlisted = isdefined(EarthSciMLBase, :ReplaceDiscreteEvents) ? length(kept) :
              length(infos)
    @test nmod == 3 * nlisted

    ps = parameters(parent)
    coords = (("₊lat", deg2rad(35.0)), ("₊lon", deg2rad(-90.0)), ("₊lev", 1.0))
    coord_vals = [p => v for (suffix, v) in coords
                  for p in filter(p -> endswith(string(Symbol(p)), suffix), ps)]
    init(ODEProblem(parent, coord_vals, (0.0, 60.0)), Tsit5())
    @test all(info_for(n).live[] for n in kept)
    @test all(info_for(n).itp.cache.initialized for n in kept)
    @test !any(info_for(n).itp.cache.initialized for n in dropped)

    # (2) The walk and the fixpoint_sub oracle agree on the coupled system, with
    # and without the keep-set, and on the expected keep/drop split.
    crwc = only(EarthSciMLBase.get_needed_vars(PruneWalkCallback(), csys, parent, domain))
    field(info) = chopprefix(string(info.var_sym), "pl₊")
    for (extra, needed) in ((Any[], ["q", "o3", "ciwc"]), (Any[crwc], kept))
        walk = EarthSciData._apply_live_mask!(infos, parent; extra_needed = extra)
        @test walk == fixpoint_is_needed(infos, parent; extra_needed = extra)
        @test walk == [field(i) in needed for i in infos]
    end

    # (3) Same on a `compose` + `mtkcompile` parent whose only use of ERA5 is the
    # chain through ERA5's own derived observed equations, and on one that uses
    # nothing (safety fallback: nothing needed, nothing pruned).
    era5x, _, infos = build()
    @constants uc3 = 1.0 [unit = u"s"]
    @variables X3(tu) = 0.0
    chain_only = mtkcompile(compose(
        System([Du(X3) ~ era5x.dq / uc3], tu, [X3], [uc3]; name = :chain), era5x))
    walk = EarthSciData._apply_live_mask!(infos, chain_only)
    @test walk == fixpoint_is_needed(infos, chain_only)
    @test walk == [field(i) == "q" for i in infos]
    @variables X4(tu)
    unused = mtkcompile(System([Du(X4) ~ 0], tu; name = :unused))
    @test EarthSciData._apply_live_mask!(infos, unused) ==
          fixpoint_is_needed(infos, unused) == falses(length(infos))
end

struct LiveEventCoupler
    sys::Any
end
function EarthSciMLBase.couple2(m::LiveEventCoupler, e::EarthSciData.ERA5Coupler)
    m, e = m.sys, e.sys
    ConnectorSystem([m.Tc ~ e.pl₊t, m.Qc ~ e.pl₊q], m, e)
end

# The convert-time factory's 2-arg path returns the update event rebuilt over the
# live interpolators, to replace the loader's own event.  Put in place of it, the
# rebuilt event must compile in a composed system (its parameters are namespaced
# with the loader) and give the same solution as the loader's own event.
@testset "Live event: replaces the loader's event with the same solution" begin
    tu = ModelingToolkit.t
    Du = ModelingToolkit.D
    era5_vars = Dict(
        "t" => ("K", "Temperature", 260.0, 300.0),
        "q" => ("kg kg**-1", "Specific humidity", 0.0, 0.02),
        "u" => ("m s**-1", "U component of wind", -15.0, 15.0)
    )
    era5_dir = write_era5_fixture(mktempdir(), era5_vars)
    starttime = DateTime(2022, 1, 1)
    domain = DomainInfo(
        starttime, DateTime(2022, 1, 2);
        latrange = deg2rad(20.0f0):deg2rad(2.0):deg2rad(50.0f0),
        lonrange = deg2rad(-130.0f0):deg2rad(2.0):deg2rad(-60.0f0),
        levrange = 1:4
    )
    hook = isdefined(EarthSciMLBase, :ReplaceDiscreteEvents)
    with_events(sys, evs) = ModelingToolkit.Setfield.@set sys.discrete_events = evs
    modified_syms(sys) = [string(EarthSciMLBase.var2symbol(v))
                          for ev in ModelingToolkit.discrete_events(sys)
                          for v in ev.affect.modified]
    # t and q are used, u is not.
    used(infos) = [i.var_sym != Symbol("pl₊u") for i in infos]
    coords = (("₊lat", deg2rad(35.0)), ("₊lon", deg2rad(-90.0)), ("₊lev", 1.0))
    coord_vals(sys) = [p => v for (suffix, v) in coords
                       for p in parameters(sys) if endswith(string(Symbol(p)), suffix)]

    # `mode`: `:own` keeps the loader's event after the 2-arg prune, `:live`
    # replaces it with the factory's rebuilt event, `:legacy` runs the 1-arg
    # (no-prune) factory call.
    function build_and_solve(mode)
        era5 = ERA5(domain; mirror = "file://$(era5_dir)", variables = ["t", "q", "u"])
        infos = ModelingToolkit.getmetadata(era5, EarthSciData.InterpInfos, nothing)
        @variables C1(tu) = 0.0 [unit = u"K*s"] C2(tu) = 0.0 [unit = u"s"]
        state = System([Du(C1) ~ era5.pl₊t, Du(C2) ~ era5.pl₊q], tu, [C1, C2], [];
            name = :live_state)
        parent = mtkcompile(compose(state, era5))
        f = ModelingToolkit.getmetadata(era5, EarthSciMLBase.SysDiscreteEvent, nothing)
        if mode === :legacy
            @test f(parent) === nothing
            @test all(i.live[] for i in infos)
        else
            r = f(parent, Any[])
            @test [i.live[] for i in infos] == used(infos)
            ev = EarthSciData.live_interp_event(infos, starttime)
            @test ev isa ModelingToolkit.SymbolicDiscreteCallback
            if hook
                @test r isa EarthSciMLBase.ReplaceDiscreteEvents
                ev = only(r.events)
            else
                @test r === nothing
            end
            mode === :live && (era5 = with_events(era5, [ev]))
        end
        sys = mtkcompile(compose(state, era5))
        sol = solve(ODEProblem(sys, coord_vals(sys), (0.0, 86400.0)), Tsit5();
            saveat = 3600.0)
        return sol, sys, infos
    end

    sol_own, sys_own, infos_own = build_and_solve(:own)
    sol_live, sys_live, infos_live = build_and_solve(:live)
    sol_leg, sys_leg, infos_leg = build_and_solve(:legacy)
    @test ModelingToolkit.SciMLBase.successful_retcode(sol_own)
    @test ModelingToolkit.SciMLBase.successful_retcode(sol_live)
    @test ModelingToolkit.SciMLBase.successful_retcode(sol_leg)

    # The compiled event lists only the live interpolators' parameters, with the
    # loader's namespace.
    live_syms = ["ERA5₊pl₊$(v)_$(s)" for v in ("t", "q")
                 for s in ("data", "tstart", "tstep")]
    @test sort(modified_syms(sys_live)) == sort(live_syms)
    @test length(modified_syms(sys_own)) == 9
    @test length(modified_syms(sys_leg)) == 9

    # Same solution, and the interpolators that were loaded: t and q, never u.
    @test sol_live.t == sol_own.t
    @test sol_live.u == sol_own.u
    @test sol_leg.u == sol_own.u
    loaded(infos) = [i.itp.cache.initialized for i in infos]
    @test loaded(infos_live) == loaded(infos_own) == used(infos_live)
    @test all(loaded(infos_leg))
    @test maximum(abs, sol_live.u[end]) > 0

    # Through `couple` → `convert`: with EarthSciMLBase's replace hook the
    # converted system carries the rebuilt event, unless
    # `EARTHSCIDATA_LIVE_EVENT=0`; the solution is the same either way.
    function convert_and_solve(live_event)
        era5 = ERA5(domain; mirror = "file://$(era5_dir)", variables = ["t", "q", "u"])
        infos = ModelingToolkit.getmetadata(era5, EarthSciData.InterpInfos, nothing)
        @variables C1(tu) = 0.0 [unit = u"K*s"] C2(tu) = 0.0 [unit = u"s"] Tc(tu) [
            unit = u"K"] Qc(tu)
        model = System([Du(C1) ~ Tc, Du(C2) ~ Qc], tu, [C1, C2, Tc, Qc], [];
            name = :LiveEvent,
            metadata = Dict(EarthSciMLBase.CoupleType => LiveEventCoupler))
        parent = withenv("EARTHSCIDATA_LIVE_EVENT" => live_event ? nothing : "0") do
            convert(System, couple(model, era5, domain))
        end
        @test [i.live[] for i in infos] == used(infos)
        sol = solve(ODEProblem(parent, coord_vals(parent), (0.0, 86400.0)), Tsit5();
            saveat = 3600.0)
        return sol, parent
    end
    sol_conv, parent_conv = convert_and_solve(true)
    sol_off, parent_off = convert_and_solve(false)
    @test ModelingToolkit.SciMLBase.successful_retcode(sol_conv)
    @test length(modified_syms(parent_conv)) == (hook ? 6 : 9)
    @test length(modified_syms(parent_off)) == 9
    @test sol_conv.t == sol_off.t
    @test sol_conv.u == sol_off.u
    @test maximum(abs, sol_conv.u[end]) > 0
end
