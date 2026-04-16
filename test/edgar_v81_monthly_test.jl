using Dates: DateTime, month
using EarthSciMLBase
using EarthSciData
using ModelingToolkit
using ModelingToolkit: equations, t, D
using OrdinaryDiffEqTsit5
using Test

@testset "EDGAR" begin
    function setup()
        domain = DomainInfo(
            DateTime(2020, 6, 1),
            DateTime(2020, 7, 1);
            latrange = deg2rad(40.0f0):deg2rad(2):deg2rad(60.0f0),
            lonrange = deg2rad(-10.0f0):deg2rad(2.5):deg2rad(30.0f0),
            levrange = 1:10
        )
        lon, lat, lev = EarthSciMLBase.pvars(domain)

        ts, te = get_tspan_datetime(domain)

        emis = EDGARv81MonthlyEmis("NOx", "POWER_INDUSTRY", domain)
        fileset = EarthSciData.EDGARv81MonthlyEmisFileSet("NOx", "POWER_INDUSTRY", ts, te)
        return (; domain, lon, lat, lev, ts, te, emis, fileset)
    end

    @testset "Basics" begin
        (; emis) = setup()
        eqs=equations(emis)
        @test length(eqs) >= 1
        @test contains(string(eqs[1].rhs), "Δz")
    end

    @testset "Metadata" begin
        (; fileset) = setup()
        vnames=EarthSciData.varnames(fileset)
        @test length(vnames) >= 1

        varname=first(vnames)
        metadata=EarthSciData.loadmetadata(fileset, varname)

        # Should be a 2D (lon, lat) dataset
        @test length(metadata.varsize) == 2
        @test metadata.zdim == -1
        @test metadata.native_sr == "+proj=longlat +datum=WGS84 +no_defs"
        @test metadata.staggering == (false, false, false)

        # Coordinates should be in radians
        @test all(abs.(metadata.coords[metadata.xdim]) .<= π + 0.01)
        @test all(abs.(metadata.coords[metadata.ydim]) .<= π / 2 + 0.01)
    end

    @testset "Interpolation" begin
        (; domain, ts, te, fileset) = setup()
        vnames=EarthSciData.varnames(fileset)
        varname=first(vnames)
        sample_time=DateTime(2020, 6, 15)

        itp=EarthSciData.DataSetInterpolator{Float32}(fileset, varname, ts, te, domain)
        # Central Germany (high power plant density)
        result=EarthSciData.interp!(itp, sample_time, deg2rad(10.0f0), deg2rad(51.0f0))
        @test result >= 0.0f0
    end

    @testset "Monthly Frequency" begin
        (; domain, ts, te, fileset) = setup()
        vnames=EarthSciData.varnames(fileset)
        varname=first(vnames)
        sample_time=DateTime(2020, 6, 15)

        itp=EarthSciData.DataSetInterpolator{Float32}(fileset, varname, ts, te, domain)
        EarthSciData.lazyload!(itp, sample_time)
        ti=EarthSciData.DataFrequencyInfo(itp.fs.fs)
        @test length(ti.centerpoints) >= 2
        # The cached times should bracket the query month
        @test itp.cache.times[1] <= sample_time
        @test itp.cache.times[2] >= sample_time
    end

    @testset "ODE Run" begin
        (; emis) = setup()
        # `EDGARv81MonthlyEmis` has no state variables (only parameters and
        # observed equations), so `ODEProblem` on it directly produces a
        # DAE with `u0 = Nothing` which errors during solver initialization.
        # Wrap with a trivial `D(_dummy) ~ 0` state so `solve` has something
        # to integrate — same pattern used in the GEOSFP/WRF/NCEP tests.
        @variables _dummy(t)=0.0
        _sys=compose(System([D(_dummy)~0], t; name = :_w), emis)
        sys=mtkcompile(_sys)
        prob=ODEProblem(
            sys,
            [sys.EDGARv81MonthlyEmis.lat=>deg2rad(51.0),
                sys.EDGARv81MonthlyEmis.lon=>deg2rad(10.0),
                sys.EDGARv81MonthlyEmis.lev=>1.0],
            (0.0, 60.0)
        )
        sol=solve(prob, Tsit5())
        # Should complete without error
        @test length(sol.t) >= 2
    end

    @testset "Input Validation" begin
        (; ts, te) = setup()
        @test_throws AssertionError EarthSciData.EDGARv81MonthlyEmisFileSet(
            "INVALID_SUBSTANCE", "POWER_INDUSTRY", ts, te)
    end

    @testset "Coupling with GEOS-FP" begin
        (; domain, emis) = setup()
        gfp=GEOSFP("4x5", domain)

        csys=couple(emis, gfp)
        sys=convert(System, csys)
        eqs=observed(sys)

        @test occursin("EDGARv81MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
    end
end
