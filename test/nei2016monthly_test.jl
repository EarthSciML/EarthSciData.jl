
@testsnippet NEISetup begin
    using Dates: DateTime
    using EarthSciMLBase
    using EarthSciData

    domain = DomainInfo(
        DateTime(2016, 5, 1),
        DateTime(2016, 5, 2);
        latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
        lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
        levrange = 1:10
    )
    lon, lat, lev = EarthSciMLBase.pvars(domain)

    ts, te = get_tspan_datetime(domain)
    sample_time = ts

    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
    fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
end

@testitem "NEI Basics" setup=[NEISetup] begin
    using ModelingToolkit: equations
    eqs = equations(emis)
    @test length(eqs) == 69
    @test contains(string(eqs[1].rhs), "/ Δz")
end

@testitem "projections" setup=[NEISetup] begin
    import Proj
    @testset "correct projection" begin
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        @test interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0)) ≈ 1.256768f-9
    end

    @testset "incorrect projection" begin
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
            lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
            levrange = 1:10,
            spatial_ref = "+proj=axisswap +order=2,1 +step +proj=longlat +datum=WGS84 +no_defs"
        )
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        @test_throws Proj.PROJError interp!(
            itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
    end

    @testset "Out of domain" begin
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        @test interp!(itp, sample_time, deg2rad(0.0f0), deg2rad(40.0f0)) ≈ 0.0
    end
end

@testitem "monthly frequency" setup=[NEISetup] begin
    using Dates: month
    ts, te = DateTime(2016, 5, 1), DateTime(2016, 6, 1)
    fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    EarthSciData.lazyload!(itp, sample_time)
    ti = EarthSciData.DataFrequencyInfo(itp.fs)
    @test month(itp.times[1]) == 4
    @test month(itp.times[2]) == 5

    sample_time = DateTime(2016, 5, 31)
    EarthSciData.lazyload!(itp, sample_time)
    @test month(itp.times[1]) == 5
    @test month(itp.times[2]) == 6
end

@testitem "run" setup=[NEISetup] begin
    using ModelingToolkit: t, D, @constants, extend, mtkcompile, equations, System,
                           @variables, get_unit
    using OrdinaryDiffEqTsit5
    using DynamicQuantities: @u_str
    @constants uc=1.0 [unit = u"s" description = "unit conversion"]
    @variables acet(t)=0.0 [unit = get_unit(emis.ACET)]
    eq = D(acet) ~ equations(emis)[1].rhs * 1e10 / uc
    sys = extend(System([eq], t, [acet], [uc]; name = :test_sys), emis)
    sys = mtkcompile(sys)
    prob = ODEProblem(
        sys,
        [lat => deg2rad(40.0), lon => deg2rad(-97.0), lev => 1.0],
        (0.0, 60.0)
    )
    sol = solve(prob, Tsit5())
    @test 2 > sol.u[end][end] > 1
end

@testitem "allocations" setup=[NEISetup] begin
    using AllocCheck
    if !Sys.iswindows() # Allocation tests don't seem to work on windows.
        @check_allocs checkf(itp, t, loc1, loc2) = EarthSciData.interp_unsafe(
            itp, t, loc1, loc2)

        sample_time = DateTime(2016, 5, 1)
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        checkf(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))

        itp2 = EarthSciData.DataSetInterpolator{Float64}(fileset, "NOX", ts, te, domain)
        interp!(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        checkf(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
    end
end

@testitem "Coupling with GEOS-FP" setup=[NEISetup] begin
    using ModelingToolkit: observed, System
    gfp = GEOSFP("4x5", domain)
    csys = couple(emis, gfp)
    sys = convert(System, csys)
    eqs = observed(sys)
    @test occursin("NEI2016MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
end

@testitem "wrong year" setup=[NEISetup] begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    sample_time = DateTime(2017, 5, 1)
    @test_throws ArgumentError EarthSciData.lazyload!(itp, sample_time)
end
