
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
    #@test contains(string(eqs[1].rhs), "/ Δz")
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

@testset "run" begin
    @constants uc = 1.0 [unit = u"s" description = "unit conversion"]
    eq = Differential(t)(emis.ACET) ~ equations(emis)[1].rhs / uc
    sys = extend(ODESystem([eq], t, [], []; name = :test_sys), emis)
    sys = structural_simplify(sys)
    prob = ODEProblem(
        sys,
        zeros(1),
        (0.0, 60.0),
        [lat => deg2rad(40.0), lon => deg2rad(-97.5), lev => 1.0]
    )
    sol = solve(prob, Tsit5())
    @test sol.u[end][end] ≈ 5.08133281184207e-11
end

@testset "run_regrid" begin
    domain = DomainInfo(
    DateTime(2016, 5, 16),
    DateTime(2016, 5, 17);
    lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
    latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
    levrange=1:2,
    u_proto=zeros(Float64, 1, 1, 1, 1))

    lon, lat, lev = EarthSciMLBase.pvars(domain)
    emis_regrid = NEI2016MonthlyEmis_regrid("mrggrid_withbeis_withrwc", domain)
    @constants uc = 1.0 [unit = u"s" description = "unit conversion"]
    eq = Differential(t)(emis_regrid.ACET) ~ equations(emis_regrid)[1].rhs / uc
    sys = extend(ODESystem([eq], t, [], []; name = :test_sys), emis_regrid)
    sys = structural_simplify(sys)
    prob = ODEProblem(
        sys,
        zeros(1),
        (0.0, 60.0),
        [lat => deg2rad(40.0), lon => deg2rad(-97.5), lev => 1.0]
    )
    sol = solve(prob, Tsit5())
    println(sol.u)
    @test sol.u[end][end] ≈ 5.750157952328239e-11
end

@testset "diurnal_itp function" begin
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

if !Sys.iswindows() # Allocation tests don't seem to work on windows.
    @testset "allocations" begin
        @check_allocs checkf(
            itp, t, loc1, loc2) = EarthSciData.interp_unsafe(itp, t, loc1, loc2)

        sample_time = DateTime(2016, 5, 1)
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        # If there is an error, it should occur in the proj library.
        # https://github.com/JuliaGeo/Proj.jl/issues/104
        try
            checkf(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        catch err
            @test length(err.errors) == 1
            s = err.errors[1]
            contains(string(s), "libproj.proj_trans")
        end

        itp2 = EarthSciData.DataSetInterpolator{Float64}(fileset, "NOX", ts, te, domain)
        interp!(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        try # If there is an error, it should occur in the proj library.
            checkf(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        catch err
            @test length(err.errors) == 1
            s = err.errors[1]
            contains(string(s), "libproj.proj_trans")
        end
    end
end

@testset "Coupling with GEOS-FP" begin
    gfp = GEOSFP("4x5", domain)

    csys = couple(emis, gfp)
    sys = convert(ODESystem, csys, prune = false)
    eqs = observed(sys)

    @test occursin("NEI2016MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
end

@testset "wrong year" begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    sample_time = DateTime(2017, 5, 1)
    @test_throws ArgumentError EarthSciData.lazyload!(itp, sample_time)
end

@testset "delp_dry_surface_itp" begin
    @test EarthSciData.delp_dry_surface_itp(deg2rad(-94.375), deg2rad(44.5)) ≈ 14.721285536474896
    @test EarthSciData.delp_dry_surface_itp(deg2rad(-88.125), deg2rad(42.0)) ≈ 14.8498301901334
end

@testset "regridding" begin
    domain = DomainInfo(
        DateTime(2016, 5, 1),
        DateTime(2016, 5, 2);
        lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
        latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
        levrange = 1:10
    )
    emis = NEI2016MonthlyEmis_regrid("mrggrid_withbeis_withrwc", domain)
    eqs = equations(emis)
    @test length(eqs) == 69
    #@test contains(string(eqs[1].rhs), "/ Δz")

    sample_time = DateTime(2016, 5, 1)

    @testset "regridding weights loading" begin
        # Test that weights can be computed dynamically
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
        metadata = EarthSciData.loadmetadata(fileset, "NO")
        weights = EarthSciData.compute_weights_for_domain(fileset, metadata, domain)
        @test haskey(weights, :xc_b) || haskey(weights, "xc_b")
        @test haskey(weights, :yc_b) || haskey(weights, "yc_b")
        @test haskey(weights, :row) || haskey(weights, "row")
        @test haskey(weights, :col) || haskey(weights, "col")
        @test haskey(weights, :S) || haskey(weights, "S")
        @test haskey(weights, :frac_b) || haskey(weights, "frac_b")
    end

    @testset "RegridDataSetInterpolator creation" begin
        domain = DomainInfo(
            DateTime(2016, 5, 16, 12, 0, 0),
            DateTime(2016, 5, 17, 12, 0, 0);
            lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
        # Test creating RegridDataSetInterpolator (weights computed dynamically)
        itp = EarthSciData.RegridDataSetInterpolator{Float64}(fileset, "NO", ts, te, domain)
        @test itp.varname == "NO"
        @test itp.weights !== nothing
        @test itp.metadata !== nothing

        # Test regridding function
        result = EarthSciData.regrid!(itp, ts, deg2rad(-88.125), deg2rad(42.0))

        @test result ≈ 1.4874584451793892e-8   rtol = 0.01
    end

    @testset "Direct regrid_from! test" begin
        # Use the same domain as above
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)

        # Create RegridDataSetInterpolator (weights computed dynamically)
        itp = EarthSciData.RegridDataSetInterpolator{Float64}(fileset, "NO", ts, te, domain)

            # Initialize and load data
            EarthSciData.initialize!(itp, ts)
            EarthSciData.update!(itp, ts)

            # Get grid coordinates from domain (data array is [lon, lat, time])
            grid = EarthSciMLBase.grid(domain, itp.metadata.staggering)
            lon_grid = grid[1]
            lat_grid = grid[2]

            # Test direct array lookup, time dimension 2 (time dimension 1 is April data)
            # Convert coordinates to radians
            lon_coord = deg2rad(-88.125)
            lat_coord = deg2rad(42.0)

            # Find indices
            lon_idx = findfirst(x -> abs(x - lon_coord) < 1e-10, lon_grid)
            lat_idx = findfirst(x -> abs(x - lat_coord) < 1e-10, lat_grid)
            @test lon_idx == 60
            @test lat_idx == 35

            # Get the regridded data directly from the cache
            # Data array is [lon, lat, time] since domain_dims = length.(grid[1:2])
            regridded_value = itp.data[lon_idx, lat_idx, 2]  # [lon_idx, lat_idx, time_idx]
            # time dimension 2 is May data

        # Test if the direct regridded value matches expected
        @test regridded_value ≈ 1.4874584451793892e-8 rtol = 0.01
    end

    @testset "Direct regrid_from! test - 2*2.5 degree domain" begin
        # Use the same domain as above
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            lonrange=deg2rad(-125):deg2rad(2.5):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(2.0):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)

        # Create RegridDataSetInterpolator (weights computed dynamically)
        itp = EarthSciData.RegridDataSetInterpolator{Float64}(fileset, "NO", ts, te, domain)

            # Initialize and load data
            EarthSciData.initialize!(itp, ts)
            EarthSciData.update!(itp, ts)

            # Get grid coordinates from domain (data array is [lon, lat, time])
            grid = EarthSciMLBase.grid(domain, itp.metadata.staggering)
            lon_grid = grid[1]
            lat_grid = grid[2]

            # Test direct array lookup, time dimension 2 (time dimension 1 is April data)
            # Convert coordinates to radians
            lon_coord = deg2rad(-87.5)
            lat_coord = deg2rad(41.0)

            # Find indices
            lon_idx = findfirst(x -> abs(x - lon_coord) < 1e-10, lon_grid)
            lat_idx = findfirst(x -> abs(x - lat_coord) < 1e-10, lat_grid)
            @test lon_idx == 16
            @test lat_idx == 9

            # Get the regridded data directly from the cache
            # Data array is [lon, lat, time] since domain_dims = length.(grid[1:2])
            regridded_value = itp.data[lon_idx, lat_idx, 2]  # [lon_idx, lat_idx, time_idx]
            # time dimension 2 is May data

        # Test if the direct regridded value matches expected
        @test regridded_value ≈ 3.2903463487573787e-9 rtol = 0.01
    end

    @testset "contributors_for_lonlat function" begin
        # Test that weights are computed correctly
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            lonrange=deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange=deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:10
        )
        ts, te = get_tspan_datetime(domain)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
        metadata = EarthSciData.loadmetadata(fileset, "NO")
        weights = EarthSciData.compute_weights_for_domain(fileset, metadata, domain)

        # Test that weights have the expected structure
        @test haskey(weights, :W)
        @test haskey(weights, :row)
        @test haskey(weights, :col)
        @test haskey(weights, :S)
        @test haskey(weights, :frac_b)
        @test haskey(weights, :xc_b)
        @test haskey(weights, :yc_b)
        @test length(weights.xc_b) > 0
        @test length(weights.yc_b) > 0
    end

@testset "regrid emission values" begin
    domain = DomainInfo(
        DateTime(2016, 5, 15),
        DateTime(2016, 5, 16);
        lonrange=deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
        latrange=deg2rad(42):deg2rad(0.5):deg2rad(43),
        levrange = 1:2
    )
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    emis = NEI2016MonthlyEmis_regrid("mrggrid_withbeis_withrwc", domain)
    eqs = equations(emis)
    @test length(eqs) == 69
    # @test contains(string(eqs[1].rhs), "/ Δz")

    ts, te = get_tspan_datetime(domain)
    sample_time = ts


    # 3. Setup output array
    t_end = 1800  # in seconds (you can use longer for realistic change)
    nt = 5  # number of time steps saved
    lon_grid = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875)
    lat_grid = deg2rad(42):deg2rad(0.5):deg2rad(43)
    NO_map = Array{Float64}(undef, length(lon_grid), length(lat_grid), nt)
    tspan = (0.0, t_end)

    # 4. Constants
    @constants uc = 1.0 [unit = u"s", description = "unit conversion"]


    saveat = range(tspan[1], tspan[2], length=nt)

    # 5. Loop over grid points
    total_points = length(lon_grid) * length(lat_grid)
    for (i, lon_val) in enumerate(lon_grid)
        for (j, lat_val) in enumerate(lat_grid)
            # Create ODE system
            eq = Differential(t)(emis.NO) ~ equations(emis)[31].rhs / uc
            sys = extend(ODESystem([eq], t, [], []; name = Symbol("NO_sys_$(i)_$(j)")), emis)
            sys = structural_simplify(sys)

            # Setup problem
            prob = ODEProblem(sys, zeros(1), tspan, [
                lat => lat_val,
                lon => lon_val,
                lev => 1.0
            ])

            # Solve
            sol = solve(prob, Tsit5(), saveat=saveat)

            # Store time series
            NO_map[i, j, :] = getindex.(sol.u, 1)  # extract scalar values
        end
    end

    factor = EarthSciData.dayofweek_itp_NOx(datetime2unix(ts)+1800, deg2rad(-88.125))*EarthSciData.diurnal_itp_NOx(datetime2unix(ts)+1800, deg2rad(-88.125))
    @test NO_map[1, 1, end] ≈ 1.4874584451793892e-8*1800*factor /(100.0 / 9.80665 * 14.8498301901334) rtol = 0.01
    # The value is not exactly the same as the expected value because the model value is interpolated between the April and May regriddeddata.
    end


@testset "regrid emission values -- ACET " begin
    domain = DomainInfo(
        DateTime(2016, 5, 15),
        DateTime(2016, 5, 16);
        lonrange=deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
        latrange=deg2rad(42):deg2rad(0.5):deg2rad(43),
        levrange = 1:2
    )
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    emis = NEI2016MonthlyEmis_regrid("mrggrid_withbeis_withrwc", domain)

    ts, te = get_tspan_datetime(domain)
    sample_time = ts


    # 3. Setup output array
    t_end = 3600  # in seconds (you can use longer for realistic change)
    nt = 5  # number of time steps saved
    lon_grid = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875)
    lat_grid = deg2rad(42):deg2rad(0.5):deg2rad(43)
    ACET_map = Array{Float64}(undef, length(lon_grid), length(lat_grid), nt)
    tspan = (0.0, t_end)

    # 4. Constants
    @constants uc = 1.0 [unit = u"s", description = "unit conversion"]


    saveat = range(tspan[1], tspan[2], length=nt)

    # 5. Loop over grid points
    total_points = length(lon_grid) * length(lat_grid)
    for (i, lon_val) in enumerate(lon_grid)
        for (j, lat_val) in enumerate(lat_grid)
            # Create ODE system
            eq = Differential(t)(emis.ACET) ~ equations(emis)[1].rhs / uc
            sys = extend(ODESystem([eq], t, [], []; name = Symbol("ACET_sys_$(i)_$(j)")), emis)
            sys = structural_simplify(sys)

            # Setup problem
            prob = ODEProblem(sys, zeros(1), tspan, [
                lat => lat_val,
                lon => lon_val,
                lev => 1.0
            ])

            # Solve
            sol = solve(prob, Tsit5(), saveat=saveat)

            # Store time series
            ACET_map[i, j, :] = getindex.(sol.u, 1)  # extract scalar values
        end
    end

    @test ACET_map[1, 1, end] ≈ 6.119836158271685e-10*3600 /(100.0 / 9.80665 * 14.8498301901334) rtol = 0.01
    # The value is not exactly the same as the expected value because the model value is interpolated between the April and May regriddeddata.
    end
end
