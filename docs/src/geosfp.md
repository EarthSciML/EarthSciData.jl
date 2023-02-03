using DomainSets, MethodOfLines, DifferentialEquations

@parameters t lev lon lat
geosfp = GEOSFP("4x5", t)

struct Example <: EarthSciMLODESystem
    sys
    function Example(t; name)
        @variables c(t) = 5.0
        D = Differential(t)
        new(ODESystem([D(c) ~ sin(lat * π / 180.0 * 6) + sin(lon * π / 180 * 6)], t, name=name))
    end
end
@named examplesys = Example(t)

domain = DomainInfo(
    partialderivatives_lonlat2xymeters,
    zerogradBC(lat ∈ Interval(-85.0f0, 85.0f0)),
    periodicBC(lon ∈ Interval(-180.0f0, 175.0f0)),
    zerogradBC(lev ∈ Interval(1.0f0, 10.0f0)),
    constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),
)

composed_sys = examplesys + domain + Advection() + geosfp;
pde_sys = get_mtk(composed_sys)

pde_sys.dvs
equations(pde_sys)
parameters(pde_sys)

6^3
8 * 8 * 6
discretization = MOLFiniteDifference([lat => 6, lon => 6, lev => 6], t, approx_order=2)
@time pdeprob = discretize(pde_sys3, discretization)

cb = DiscreteCallback(
    (u, t, integrator) -> true,
    (integrator) -> begin
        t = integrator.t
        @info "t = $(Dates.unix2datetime(t))"
    end
)

@time pdesol = solve(pdeprob, Tsit5(), saveat=3600.0, callback=cb)