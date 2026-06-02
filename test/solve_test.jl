using EarthSciData
using EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t, D
using Dates
using OrdinaryDiffEqSDIRK, OrdinaryDiffEqLowOrderRK, OrdinaryDiffEqTsit5
using DynamicQuantities
using Test

struct SysCoupler
    sys::Any
end

function EarthSciMLBase.couple2(
        sys::SysCoupler,
        emis::EarthSciData.NEI2016MonthlyEmisCoupler
)
    sys, emis = sys.sys, emis.sys
    operator_compose(sys, emis)
end

@testset "solve" begin
    function setup()
        domain = DomainInfo(
            DateTime(2016, 3, 1), DateTime(2016, 5, 2),
            lonrange = deg2rad(-115):deg2rad(15):deg2rad(-68.75),
            latrange = deg2rad(25):deg2rad(15):deg2rad(53.71875),
            levrange = 1:1:2
        )

        @variables ACET(t)=0.0 [unit = u"kg/kg"]
        @constants c=1000 [unit = u"s"]

        @named sys = System([D(ACET) ~ 0], t, metadata = Dict(CoupleType => SysCoupler))

        emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
        csys = couple(sys, emis, domain)
        sys2 = convert(System, csys)
        return (; domain, csys, sys2)
    end

    @testset "single run" begin
        (; domain, sys2) = setup()
        @test length(equations(sys2)) == 1
        @test length(observed(sys2)) == 73
        # NOTE: In MTK v11, discrete events are not directly accessible via get_discrete_events
        # on compiled systems. The events are still correctly used during solve (verified by
        # the ODEProblem solve result below).
        prob = ODEProblem(sys2, [], get_tspan(domain))
        sol = solve(prob, Tsit5())
        @test only(sol.u[end]) ≈ 9.916966804519471e-8 rtol = 0.01
    end

    @testset "Strang Serial" begin
        (; csys) = setup()
        dt = 100.0
        st = SolverStrangSerial(Tsit5(), dt)
        prob = ODEProblem(csys, st)
        sol = solve(prob, Euler(), dt = dt)
        @test sum(sol.u[end]) ≈ 6.62176884520524e-7 rtol = 0.01
    end

    @testset "Strang Threads" begin
        (; csys) = setup()
        dt = 100.0
        st = SolverStrangThreads(Tsit5(), dt)
        prob = ODEProblem(csys, st)
        sol = solve(prob, Euler(), dt = dt)
        @test sum(sol.u[end]) ≈ 6.621768845915271e-7 rtol = 0.01
    end

    @testset "IMEX" begin
        (; csys) = setup()
        dt = 100.0
        st = SolverIMEX()
        prob = ODEProblem(csys, st)
        sol = solve(prob, KenCarp3())
        @test sum(sol.u[end]) ≈ 5.990519547082663e-7 rtol = 0.15
    end
end
