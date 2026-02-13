@testitem "NEI Setup" begin
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
end

@testitem "projections" setup=[NEISetup] begin
    import Proj
    fs = EarthSciData.FileSetWithRegridder(fileset, EarthSciData.regridder(fileset,
        EarthSciData.loadmetadata(fileset, first(EarthSciData.varnames(fileset))), domain))
    @testset "correct projection" begin
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "NOX", ts, te, domain)
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
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "NOX", ts, te, domain)
        @test_throws Proj.PROJError interp!(
            itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
    end

    @testset "Out of domain" begin
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "NOX", ts, te, domain)
        @test interp!(itp, sample_time, deg2rad(0.0f0), deg2rad(40.0f0)) ≈ 0.0
    end
end

@testitem "polygons" setup=[NEISetup] begin
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    polys = EarthSciData.get_geometry(fileset, itp.metadata)
    xmin, xmax, ymin, ymax = Inf, -Inf, Inf, -Inf
    for poly in polys
        for (x, y) in poly
            global xmin = min(xmin, x)
            global xmax = max(xmax, x)
            global ymin = min(ymin, y)
            global ymax = max(ymax, y)
        end
    end
    @test xmin ≈ -2.556e6
    @test ymin ≈ -1.728e6
    # With nx+1 edges, xmax and ymax include the full last cell
    @test xmax ≈ 2.952e6
    @test ymax ≈ 1.86e6
end

@testitem "monthly frequency" setup=[NEISetup] begin
    using Dates: month
    ts, te = DateTime(2016, 5, 1), DateTime(2016, 6, 1)
    fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    EarthSciData.lazyload!(itp, sample_time)
    ti = EarthSciData.DataFrequencyInfo(itp.fs.fs)
    @test month(itp.times[1]) == 4
    @test month(itp.times[2]) == 5

    sample_time = DateTime(2016, 5, 31)
    EarthSciData.lazyload!(itp, sample_time)
    @test month(itp.times[1]) == 5
    @test month(itp.times[2]) == 6
end

@testitem "run" setup=[NEISetup] begin
    using ModelingToolkit
    using OrdinaryDiffEqTsit5
    sys = structural_simplify(emis)
    prob = ODEProblem(
        sys,
        zeros(1),
        (0.0, 60.0),
        [lat => deg2rad(40.0), lon => deg2rad(-97.5), lev => 1.0]
    )
    solve(prob, Tsit5())
end

@testitem "run_nei" setup=[NEISetup] begin
    using ModelingToolkit, OrdinaryDiffEqTsit5
    using ModelingToolkit: t, D
    using DynamicQuantities
    domain = DomainInfo(
    DateTime(2016, 5, 16),
    DateTime(2016, 5, 17);
    lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
    latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
    levrange=1:2,
    u_proto=zeros(Float64, 1, 1, 1, 1))

    lon, lat, lev = EarthSciMLBase.pvars(domain)
    emis_nei = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
    @constants uc = 1.0 [unit = u"s" description = "unit conversion"]
    @variables ACET(t) [unit = u"1/s"]
    eq = D(ACET) ~ emis_nei.ACET / uc
    sys = compose(ODESystem([eq], t, [ACET], [uc]; name = :test_sys), emis_nei)
    sys = structural_simplify(sys)
    prob = ODEProblem(
        sys,
        zeros(1),
        (0.0, 60.0),
        [lat => deg2rad(40.0), lon => deg2rad(-97.5), lev => 1.0]
    )
    sol = solve(prob, Tsit5())
    @test sol.u[end][end] != 0.0  # Ensure we get a nonzero result
end

@testitem "diurnal_itp function" setup=[NEISetup] begin
    using Dates

    # Test domain starts at 2016-05-01 00:00:00 UTC
    t_ref_numeric = datetime2unix(DateTime(2016, 5, 1))  # Domain starts at 2016-05-01 00:00:00

    # Test 1: UTC (0° longitude)
    lon_utc = deg2rad(0.0)  # UTC timezone

    # 6 AM UTC
    six_am_utc = t_ref_numeric + 6 * 3600.0  # 7th factor
    @test EarthSciData.diurnal_itp(six_am_utc, lon_utc) == EarthSciData.DIURNAL_FACTORS[7]

    # 6 PM UTC
    six_pm_utc = t_ref_numeric + 18 * 3600.0  # 19th factor
    @test EarthSciData.diurnal_itp(six_pm_utc, lon_utc) == EarthSciData.DIURNAL_FACTORS[19]

    # Test 2: Chicago (UTC-6, longitude ~ -87.6°)
    lon_chicago = deg2rad(-87.6)  # Chicago longitude

    # 6 AM Chicago = 12 PM UTC (6 hours later)
    six_am_chicago = t_ref_numeric + 12 * 3600.0  # 6 AM Chicago = 12 PM UTC, 7th factor
    @test EarthSciData.diurnal_itp(six_am_chicago, lon_chicago) == EarthSciData.DIURNAL_FACTORS[7]

    # 6 PM Chicago = 12 AM UTC next day (6 hours later)
    six_pm_chicago = t_ref_numeric + 24 * 3600.0  # 6 PM Chicago = 12 AM UTC next day, 19th factor
    @test EarthSciData.diurnal_itp(six_pm_chicago, lon_chicago) == EarthSciData.DIURNAL_FACTORS[19]

    # Test that the function wraps around 24 hours correctly
    # 24 hours = 86400 seconds
    next_midnight_utc = t_ref_numeric + 24 * 3600.0  # 24 hours since start
    @test EarthSciData.diurnal_itp(next_midnight_utc, lon_utc) == EarthSciData.DIURNAL_FACTORS[1]

    # Test fractional hours
    half_past_one_utc = t_ref_numeric + 1.5 * 3600.0  # 1.5 hours since start
    @test EarthSciData.diurnal_itp(half_past_one_utc, lon_utc) == EarthSciData.DIURNAL_FACTORS[2]  # Should floor to hour 1
end

@testitem "allocations" setup=[NEISetup] begin
     using AllocCheck
    if !Sys.iswindows() # Allocation tests don't seem to work on windows.
        AllocCheck.@check_allocs checkf(
            itp, t, loc1, loc2) = EarthSciData.interp_unsafe(itp, t, loc1, loc2)

        sample_time = DateTime(2016, 5, 1)
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        # If there is an error, it should occur in the proj library.
        # https://github.com/JuliaGeo/Proj.jl/issues/104
        try
            checkf(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        catch err
            @warn "Allocation errors:\n$(err.errors)"
            @test length(err.errors) == 1
            s = err.errors[1]
            contains(string(s), "libproj.proj_trans")
        end

        itp2 = EarthSciData.DataSetInterpolator{Float64}(fileset, "NOX", ts, te, domain)
        interp!(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        try # If there is an error, it should occur in the proj library.
            checkf(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        catch err
            @warn "Allocation errors:\n$(err.errors)"
            @test length(err.errors) == 1
            s = err.errors[1]
            contains(string(s), "libproj.proj_trans")
        end
    end
end

@testitem "Coupling with GEOS-FP" setup=[NEISetup] begin
    using ModelingToolkit
    gfp = GEOSFP("4x5", domain)

    csys = couple(emis, gfp)
    sys = convert(System, csys)
    eqs = observed(sys)

    @test occursin("NEI2016MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
end

@testitem "wrong year" setup=[NEISetup] begin
    using Dates
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    sample_time = DateTime(2017, 5, 1)
    @test_throws ArgumentError EarthSciData.lazyload!(itp, sample_time)
end

@testitem "delp_dry_surface_itp" setup=[NEISetup] begin
    @test EarthSciData.delp_dry_surface_itp(deg2rad(-94.375), deg2rad(44.5)) ≈ 14.721285536474896
    @test EarthSciData.delp_dry_surface_itp(deg2rad(-88.125), deg2rad(42.0)) ≈ 14.8498301901334
end

@testitem "conservative regridding" setup=[NEISetup] begin
    using ModelingToolkit
    # Test that conservative regridding works through the unified NEI2016MonthlyEmis function
    domain = DomainInfo(
        DateTime(2016, 5, 1),
        DateTime(2016, 5, 2);
        lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
        latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
        levrange = 1:10
    )
    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
    eqs = equations(emis)
    @test length(eqs) == 69

    @testset "DataSetInterpolator with conservative regridding" begin
        domain = DomainInfo(
            DateTime(2016, 5, 16, 12, 0, 0),
            DateTime(2016, 5, 17, 12, 0, 0);
            lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
        # Use the unified DataSetInterpolator with conservative regridding via regridder()
        fs = EarthSciData.FileSetWithRegridder(fileset, EarthSciData.regridder(fileset,
            EarthSciData.loadmetadata(fileset, "NO"), domain))
        itp = EarthSciData.DataSetInterpolator{Float64}(fs, "NO", ts, te, domain)
        @test itp.varname == "NO"
        @test itp.metadata !== nothing

        # Test that interpolation works
        result = interp!(itp, ts, deg2rad(-88.125), deg2rad(42.0))
        @test result > 0.0  # Should be nonzero for this location
    end

    @testset "Conservative regridding - coarse domain" begin
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            lonrange=deg2rad(-125):deg2rad(2.5):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(2.0):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
        fs = EarthSciData.FileSetWithRegridder(fileset, EarthSciData.regridder(fileset,
            EarthSciData.loadmetadata(fileset, "NO"), domain))
        itp = EarthSciData.DataSetInterpolator{Float64}(fs, "NO", ts, te, domain)

        # Test that interpolation works at a specific location
        result = interp!(itp, ts, deg2rad(-87.5), deg2rad(41.0))
        @test result > 0.0
    end
end

@testitem "emission values" setup=[NEISetup] begin
    using ModelingToolkit, DynamicQuantities
    using ModelingToolkit: t, D
    using OrdinaryDiffEqTsit5
    using Dates
    domain = DomainInfo(
        DateTime(2016, 5, 15),
        DateTime(2016, 5, 16);
        lonrange=deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
        latrange=deg2rad(42):deg2rad(0.5):deg2rad(43),
        levrange = 1:2
    )
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
    eqs = equations(emis)
    @test length(eqs) == 69

    ts, te = get_tspan_datetime(domain)

    # Setup output array
    t_end = 1800  # in seconds
    nt = 5
    lon_grid = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875)
    lat_grid = deg2rad(42):deg2rad(0.5):deg2rad(43)
    NO_map = Array{Float64}(undef, length(lon_grid), length(lat_grid), nt)
    tspan = (0.0, t_end)

    @constants uc = 1.0 [unit = u"s", description = "unit conversion"]
    @variables NO(t) [unit = u"1/s"]

    saveat = range(tspan[1], tspan[2], length=nt)

    for (i, lon_val) in enumerate(lon_grid)
        for (j, lat_val) in enumerate(lat_grid)
            eq = D(NO) ~ emis.NO / uc
            sys = compose(ODESystem([eq], t, [NO], [uc]; name = Symbol("NO_sys_$(i)_$(j)")), emis)
            sys = structural_simplify(sys)

            prob = ODEProblem(sys, zeros(1), tspan, [
                lat => lat_val,
                lon => lon_val,
                lev => 1.0
            ])

            sol = solve(prob, Tsit5(), saveat=saveat)
            NO_map[i, j, :] = getindex.(sol.u, 1)
        end
    end

    @test NO_map[1, 1, end] != 0.0  # Ensure we get nonzero emissions
end

@testitem "emission values -- ACET" setup=[NEISetup] begin
    using ModelingToolkit, DynamicQuantities
    using ModelingToolkit: t, D
    using OrdinaryDiffEqTsit5
    using Dates
    domain = DomainInfo(
        DateTime(2016, 5, 15),
        DateTime(2016, 5, 16);
        lonrange=deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
        latrange=deg2rad(42):deg2rad(0.5):deg2rad(43),
        levrange = 1:2
    )
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)

    ts, te = get_tspan_datetime(domain)

    t_end = 3600  # in seconds
    nt = 5
    lon_grid = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875)
    lat_grid = deg2rad(42):deg2rad(0.5):deg2rad(43)
    ACET_map = Array{Float64}(undef, length(lon_grid), length(lat_grid), nt)
    tspan = (0.0, t_end)

    @constants uc = 1.0 [unit = u"s", description = "unit conversion"]
    @variables ACET(t) [unit = u"1/s"]

    saveat = range(tspan[1], tspan[2], length=nt)

    for (i, lon_val) in enumerate(lon_grid)
        for (j, lat_val) in enumerate(lat_grid)
            eq = D(ACET) ~ emis.ACET / uc
            sys = compose(ODESystem([eq], t, [ACET], [uc]; name = Symbol("ACET_sys_$(i)_$(j)")), emis)
            sys = structural_simplify(sys)

            prob = ODEProblem(sys, zeros(1), tspan, [
                lat => lat_val,
                lon => lon_val,
                lev => 1.0
            ])

            sol = solve(prob, Tsit5(), saveat=saveat)
            ACET_map[i, j, :] = getindex.(sol.u, 1)
        end
    end

    @test ACET_map[1, 1, end] != 0.0  # Ensure we get nonzero emissions
end
