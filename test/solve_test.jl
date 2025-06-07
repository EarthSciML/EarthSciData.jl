using EarthSciData

using Test
using EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t, D
using Dates
using OrdinaryDiffEqSDIRK, OrdinaryDiffEqLowOrderRK, OrdinaryDiffEqTsit5
using DynamicQuantities

domain = DomainInfo(
    DateTime(2016, 3, 1), DateTime(2016, 5, 2),
    lonrange = deg2rad(-115):deg2rad(15):deg2rad(-68.75),
    latrange = deg2rad(25):deg2rad(15):deg2rad(53.71875),
    levrange = 1:1:2
)

@variables ACET(t)=0.0 [unit = u"kg*m^-3"]
@constants c=1000 [unit = u"s"]

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
    @test unix2datetime.(de[1].condition .+ get_tref(domain)) == [
        DateTime("2016-02-15T12:00:00"),
        DateTime("2016-03-01T00:00:00"),
        DateTime("2016-03-16T12:00:00"),
        DateTime("2016-04-16T00:00:00"),
        DateTime("2016-05-16T12:00:00")
    ]
    prob = ODEProblem(sys2, [], get_tspan(domain), [])
    sol = solve(prob, Tsit5())
    @test only(sol.u[end]) ≈ 5.844687946776202e-6
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

st = SolverIMEX()

prob = ODEProblem(csys, st)

sol = solve(prob, KenCarp3())

@test sum(sol.u[end]) ≈ 2.414101174478711e-5

@test_nowarn solve(prob, KenCarp3())
