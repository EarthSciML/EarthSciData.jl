@testsnippet EDGARSetup begin
    using Dates: DateTime
    using EarthSciMLBase
    using EarthSciData

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
end

@testitem "EDGAR Setup" tags=[:edgar] begin
    using Dates: DateTime
    using EarthSciMLBase
    using EarthSciData

    domain = DomainInfo(
        DateTime(2020, 6, 1),
        DateTime(2020, 7, 1);
        latrange = deg2rad(40.0f0):deg2rad(2):deg2rad(60.0f0),
        lonrange = deg2rad(-10.0f0):deg2rad(2.5):deg2rad(30.0f0),
        levrange = 1:10
    )

    ts, te = get_tspan_datetime(domain)

    emis = EDGARv81MonthlyEmis("NOx", "POWER_INDUSTRY", domain)
    fileset = EarthSciData.EDGARv81MonthlyEmisFileSet("NOx", "POWER_INDUSTRY", ts, te)
end

@testitem "EDGAR Basics" setup=[EDGARSetup] tags=[:edgar] begin
    using ModelingToolkit: equations
    eqs = equations(emis)
    @test length(eqs) >= 1
    @test contains(string(eqs[1].rhs), "Δz")
end

@testitem "EDGAR Metadata" setup=[EDGARSetup] tags=[:edgar] begin
    vnames = EarthSciData.varnames(fileset)
    @test length(vnames) >= 1

    varname = first(vnames)
    metadata = EarthSciData.loadmetadata(fileset, varname)

    # Should be a 2D (lon, lat) dataset
    @test length(metadata.varsize) == 2
    @test metadata.zdim == -1
    @test metadata.native_sr == "+proj=longlat +datum=WGS84 +no_defs"
    @test metadata.staggering == (false, false, false)

    # Coordinates should be in radians
    @test all(abs.(metadata.coords[metadata.xdim]) .<= π + 0.01)
    @test all(abs.(metadata.coords[metadata.ydim]) .<= π / 2 + 0.01)
end

@testitem "EDGAR Interpolation" setup=[EDGARSetup] tags=[:edgar] begin
    vnames = EarthSciData.varnames(fileset)
    varname = first(vnames)
    sample_time = DateTime(2020, 6, 15)

    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, varname, ts, te, domain)
    # Central Germany (high power plant density)
    result = EarthSciData.interp(itp, sample_time, deg2rad(10.0f0), deg2rad(51.0f0))
    @test result >= 0.0f0
end

@testitem "EDGAR Monthly Frequency" setup=[EDGARSetup] tags=[:edgar] begin
    using Dates: month
    vnames = EarthSciData.varnames(fileset)
    varname = first(vnames)
    sample_time = DateTime(2020, 6, 15)

    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, varname, ts, te, domain)
    EarthSciData.lazyload!(itp, sample_time)
    ti = EarthSciData.DataFrequencyInfo(itp.fs.fs)
    @test length(ti.centerpoints) >= 2
    # The cached times should bracket the query month
    @test itp.cache.times[1] <= sample_time
    @test itp.cache.times[2] >= sample_time
end

@testitem "EDGAR ODE Run" setup=[EDGARSetup] tags=[:edgar] begin
    using ModelingToolkit
    using OrdinaryDiffEqTsit5

    sys = mtkcompile(emis)
    prob = ODEProblem(
        sys,
        [lat => deg2rad(51.0), lon => deg2rad(10.0), lev => 1.0],
        (0.0, 60.0),
    )
    sol = solve(prob, Tsit5())
    # Should complete without error
    @test length(sol.t) >= 2
end

@testitem "EDGAR Input Validation" setup=[EDGARSetup] tags=[:edgar] begin
    @test_throws AssertionError EarthSciData.EDGARv81MonthlyEmisFileSet(
        "INVALID_SUBSTANCE", "POWER_INDUSTRY", ts, te)
end

@testitem "EDGAR Coupling with GEOS-FP" setup=[EDGARSetup] tags=[:edgar] begin
    using ModelingToolkit
    gfp = GEOSFP("4x5", domain)

    csys = couple(emis, gfp)
    sys = convert(System, csys)
    eqs = observed(sys)

    @test occursin("EDGARv81MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
end
