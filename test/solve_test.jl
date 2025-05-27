using EarthSciData

using Test
using EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t, D
using DomainSets, Dates
using DifferentialEquations
using DynamicQuantities

@parameters lat=deg2rad(40.0) lon=deg2rad(-97.0) lev=0.0
starttime = datetime2unix(DateTime(2016, 3, 1))
endtime = datetime2unix(DateTime(2016, 5, 2))
domain = DomainInfo(
    constIC(16.0, t ∈ Interval(starttime, endtime)),
    constBC(
        16.0,
        lon ∈ Interval(deg2rad(-115), deg2rad(-68.75)),
        lat ∈ Interval(deg2rad(25), deg2rad(53.71875)),
        lev ∈ Interval(1, 2)
    ),
    grid_spacing = [deg2rad(15.0), deg2rad(15.0), 1]
)

@variables ACET(t) = 0.0 [unit = u"kg*m^-3"]
@constants c = 1000 [unit = u"s"]

struct SysCoupler
    sys::Any
end
@named sys = ODESystem([D(ACET) ~ 0], t, metadata = Dict(:coupletype => SysCoupler))
function EarthSciMLBase.couple2(
        sys::SysCoupler,
        emis::EarthSciData.NEI2016MonthlyEmisCoupler
)
    sys, emis = sys.sys, emis.sys
    operator_compose(sys, emis)
end

@testset "single run" begin
    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
    csys = couple(sys, emis, domain)
    sys2 = convert(ODESystem, csys)

    @test length(equations(sys2)) == 1
    @test length(observed(sys2)) == 73
    de = ModelingToolkit.get_discrete_events(sys2)
    @test length(de) == 1
    @test unix2datetime.(de[1].condition) == [
        DateTime("2016-02-15T12:00:00"),
        DateTime("2016-03-01T00:00:00"),
        DateTime("2016-03-16T12:00:00"),
        DateTime("2016-04-16T00:00:00"),
        DateTime("2016-05-16T12:00:00")
    ]
    prob = ODEProblem(sys2, [], get_tspan(domain), [])
    sol = solve(prob)
    @test only(sol.u[end]) ≈ 5.322912896619149e-6
end

emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)

csys = couple(sys, emis, domain)

dt = 100.0
st = SolverStrangSerial(Tsit5(), dt)
prob = ODEProblem(csys, st)

sol = solve(prob, Euler(), dt = dt)

@test sum(sol.u[end]) ≈ 2.7791006168742467e-5

st = SolverStrangThreads(Tsit5(), dt)

prob = ODEProblem(csys, st)

sol = solve(prob, Euler(), dt = dt)

@test sum(sol.u[end]) ≈ 2.7791006168742467e-5
