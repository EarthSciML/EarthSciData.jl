@testsnippet SolveSetup begin
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

    @variables ACET(t)=0.0 [unit = u"kg/kg"]
    @constants c=1000 [unit = u"s"]

    struct SysCoupler
        sys::Any
    end
    @named sys = System([D(ACET) ~ 0], t, metadata = Dict(CoupleType => SysCoupler))
    function EarthSciMLBase.couple2(
            sys::SysCoupler,
            emis::EarthSciData.NEI2016MonthlyEmisCoupler
    )
        sys, emis = sys.sys, emis.sys
        operator_compose(sys, emis)
    end

    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
    csys = couple(sys, emis, domain)
    sys2 = convert(System, csys)
end

@testitem "single run" setup=[SolveSetup] begin
    @test length(equations(sys2)) == 1
    @test length(observed(sys2)) == 73
    de = ModelingToolkit.get_discrete_events(sys2)
    @test length(de) == 1
    @test unix2datetime.(de[1].conditions .+ get_tref(domain)) == [
        DateTime("2016-02-15T12:00:00"),
        DateTime("2016-03-01T00:00:00"),
        DateTime("2016-03-16T12:00:00"),
        DateTime("2016-04-16T00:00:00"),
        DateTime("2016-05-16T12:00:00")
    ]
    prob = ODEProblem(sys2, [], get_tspan(domain))
    sol = solve(prob, Tsit5())
    @test only(sol.u[end]) ≈ 2.2934818546266597e-6 rtol = 0.01
end

@testitem "Strang Serial" setup=[SolveSetup] begin
    dt = 100.0
    st = SolverStrangSerial(Tsit5(), dt)
    prob = ODEProblem(csys, st)
    sol = solve(prob, Euler(), dt = dt)
    @test sum(sol.u[end]) ≈ 1.2427611177095041e-5 rtol = 0.01
end

@testitem "Strang Threads" setup=[SolveSetup] begin
    dt = 100.0
    st = SolverStrangThreads(Tsit5(), dt)
    prob = ODEProblem(csys, st)
    sol = solve(prob, Euler(), dt = dt)
    @test sum(sol.u[end]) ≈ 1.2427611177083582e-5 rtol = 0.01
end

@testitem "IMEX" setup=[SolveSetup] begin
    dt = 100.0
    st = SolverIMEX()
    prob = ODEProblem(csys, st)
    sol = solve(prob, KenCarp3())
    @test sum(sol.u[end]) ≈ 1.0853047399831468e-5 rtol = 0.01
    @test_nowarn solve(prob, KenCarp3())
end

domain_2 = DomainInfo(
    DateTime(2016, 5, 1), DateTime(2016, 5, 2),
    lonrange = deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
    latrange = deg2rad(25):deg2rad(0.5):deg2rad(49),
    levrange = 1:1:2
)

emis_2 = NEI2016MonthlyEmis_regrid("mrggrid_withbeis_withrwc", domain_2)

csys_2 = couple(sys, emis_2, domain_2)

dt = 100.0
st = SolverStrangSerial(Tsit5(), dt)
prob = ODEProblem(csys_2, st)
