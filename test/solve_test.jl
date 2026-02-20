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
    # NOTE: In MTK v11, discrete events are not directly accessible via get_discrete_events
    # on compiled systems. The events are still correctly used during solve (verified by
    # the ODEProblem solve result below).
    prob = ODEProblem(sys2, [], get_tspan(domain))
    sol = solve(prob, Tsit5())
    @test only(sol.u[end]) ≈ 3.017283738615849e-6 rtol = 0.01
end

@testitem "Strang Serial" setup=[SolveSetup] begin
    dt = 100.0
    st = SolverStrangSerial(Tsit5(), dt)
    prob = ODEProblem(csys, st)
    sol = solve(prob, Euler(), dt = dt)
    @test sum(sol.u[end]) ≈ 2.014381322963178e-5 rtol = 0.01
end

@testitem "Strang Threads" setup=[SolveSetup] begin
    dt = 100.0
    st = SolverStrangThreads(Tsit5(), dt)
    prob = ODEProblem(csys, st)
    sol = solve(prob, Euler(), dt = dt)
    @test sum(sol.u[end]) ≈ 2.014381322963178e-5 rtol = 0.01
end

@testitem "IMEX" setup=[SolveSetup] begin
    dt = 100.0
    st = SolverIMEX()
    prob = ODEProblem(csys, st)
    sol = solve(prob, KenCarp3())
    @test sum(sol.u[end]) ≈ 1.824462850685205e-5 rtol = 0.15
end

