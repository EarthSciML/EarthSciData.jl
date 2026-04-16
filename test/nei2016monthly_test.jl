using AllocCheck
using Dates
using Dates: DateTime, month
using DynamicQuantities
using EarthSciMLBase
using EarthSciData
using ModelingToolkit
using ModelingToolkit: equations, t, D
using OrdinaryDiffEqTsit5
using Test
import Proj

@testset "NEI2016Monthly" begin
    function setup()
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
        return (; domain, lon, lat, lev, ts, te, sample_time, emis, fileset)
    end

    @testset "NEI Setup" begin
        setup()
    end

    @testset "Basics" begin
        (; emis) = setup()
        eqs = equations(emis)
        @test length(eqs) == 69
    end

    @testset "projections" begin
        (; domain, ts, te, sample_time, fileset) = setup()
        fs = EarthSciData.FileSetWithRegridder(fileset,
            EarthSciData.regridder(fileset,
                EarthSciData.loadmetadata(fileset, first(EarthSciData.varnames(fileset))), domain))
        @testset "correct projection" begin
            itp = EarthSciData.DataSetInterpolator{Float32}(fs, "NOX", ts, te, domain)
            result = interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
            @test result > 0.0f0
            @test result < 1.0f-7  # Should be a small positive value
        end

        @testset "Out of domain" begin
            itp = EarthSciData.DataSetInterpolator{Float32}(fs, "NOX", ts, te, domain)
            @test interp!(itp, sample_time, deg2rad(0.0f0), deg2rad(40.0f0)) ≈ 0.0
        end
    end

    @testset "polygons" begin
        (; domain, ts, te, fileset) = setup()
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        polys = EarthSciData.get_geometry(fileset, itp.metadata)
        xmin, xmax, ymin, ymax = Inf, -Inf, Inf, -Inf
        for poly in polys
            for (x, y) in poly
                xmin = min(xmin, x)
                xmax = max(xmax, x)
                ymin = min(ymin, y)
                ymax = max(ymax, y)
            end
        end
        @test xmin ≈ -2.556e6
        @test ymin ≈ -1.728e6
        # With nx+1 edges, xmax and ymax include the full last cell
        @test xmax ≈ 2.952e6
        @test ymax ≈ 1.86e6
    end

    @testset "monthly frequency" begin
        (; domain) = setup()
        ts, te = DateTime(2016, 5, 1), DateTime(2016, 6, 1)
        fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
        sample_time = DateTime(2016, 5, 1)
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        EarthSciData.lazyload!(itp, sample_time)
        ti = EarthSciData.DataFrequencyInfo(itp.fs.fs)
        @test month(itp.cache.times[1]) == 4
        @test month(itp.cache.times[2]) == 5

        sample_time = DateTime(2016, 5, 31)
        EarthSciData.lazyload!(itp, sample_time)
        @test month(itp.cache.times[1]) == 5
        @test month(itp.cache.times[2]) == 6
    end

    @testset "run" begin
        (; emis) = setup()
        # NEI has no state variables; wrap with a trivial dummy to satisfy
        # the ODE solver (same pattern as the GEOSFP/WRF/NCEP/EDGAR tests).
        @variables _dummy(t) = 0.0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), emis)
        sys = mtkcompile(_sys)
        prob = ODEProblem(
            sys,
            [sys.NEI2016MonthlyEmis.lat => deg2rad(40.0),
                sys.NEI2016MonthlyEmis.lon => deg2rad(-97.5),
                sys.NEI2016MonthlyEmis.lev => 1.0],
            (0.0, 60.0)
        )
        solve(prob, Tsit5())
    end

    @testset "run_nei" begin
        domain = DomainInfo(
            DateTime(2016, 5, 16),
            DateTime(2016, 5, 17);
            lonrange = deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange = deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:2,
            u_proto = zeros(Float64, 1, 1, 1, 1))

        emis_nei = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
        @constants uc = 1.0 [unit = u"s" description = "unit conversion"]
        @variables ACET(t) = 0.0 [unit = u"1/s"]
        eq = D(ACET) ~ emis_nei.ACET / uc
        sys = compose(System([eq], t, [ACET], [uc]; name = :test_sys), emis_nei)
        sys = mtkcompile(sys)
        # After composition, parameters are namespaced; extract them from the compiled system
        ps = parameters(sys)
        lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
        lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))
        lev_p = only(filter(p -> endswith(string(Symbol(p)), "₊lev"), ps))
        prob = ODEProblem(
            sys,
            [lat_p => deg2rad(40.0), lon_p => deg2rad(-97.5), lev_p => 1.0],
            (0.0, 60.0)
        )
        sol = solve(prob, Tsit5())
        @test sol.u[end][end] != 0.0  # Ensure we get a nonzero result
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
        @test EarthSciData.diurnal_itp(six_am_chicago, lon_chicago) ==
              EarthSciData.DIURNAL_FACTORS[7]

        # 6 PM Chicago = 12 AM UTC next day (6 hours later)
        six_pm_chicago = t_ref_numeric + 24 * 3600.0  # 6 PM Chicago = 12 AM UTC next day, 19th factor
        @test EarthSciData.diurnal_itp(six_pm_chicago, lon_chicago) ==
              EarthSciData.DIURNAL_FACTORS[19]

        # Test that the function wraps around 24 hours correctly
        # 24 hours = 86400 seconds
        next_midnight_utc = t_ref_numeric + 24 * 3600.0  # 24 hours since start
        @test EarthSciData.diurnal_itp(next_midnight_utc, lon_utc) ==
              EarthSciData.DIURNAL_FACTORS[1]

        # Test fractional hours
        half_past_one_utc = t_ref_numeric + 1.5 * 3600.0  # 1.5 hours since start
        @test EarthSciData.diurnal_itp(half_past_one_utc, lon_utc) ==
              EarthSciData.DIURNAL_FACTORS[2]  # Should floor to hour 1
    end

    @testset "allocations" begin
        (; domain, ts, te, fileset) = setup()
        if !Sys.iswindows() # Allocation tests don't seem to work on windows.
            # Verify that the MTK-hot-path `interp_unsafe(data::DataBufferType,
            # fit, fi1, fi2, extrap)` is statically allocation-free. This is
            # the exact entry point used by the RHS function that MTK generates;
            # everything else (coordinate-to-index conversion, DateTime to unix,
            # etc.) is folded into the symbolic equation at codegen time, so the
            # runtime call receives pre-computed fractional indices.
            AllocCheck.@check_allocs checkf(
                db, fit, fi1, fi2, extrap) = EarthSciData.interp_unsafe(
                db, fit, fi1, fi2, extrap)

            for T in (Float32, Float64)
                sample_time = DateTime(2016, 5, 1)
                itp = EarthSciData.DataSetInterpolator{T}(fileset, "NOX", ts, te, domain)
                EarthSciData.lazyload!(itp, sample_time)
                db = EarthSciData.DataBufferType(itp.cache.data_buffer)
                # Warm up then check: no catch needed — this MUST be alloc-free.
                checkf(db, T(1.5), T(5.3), T(5.7), T(1.0))
                try
                    checkf(db, T(1.5), T(5.3), T(5.7), T(1.0))
                catch err
                    @warn "Allocation errors ($T):\n$(err.errors)"
                    @test length(err.errors) == 0
                end
            end
        end
    end

    @testset "Coupling with GEOS-FP" begin
        (; domain, emis) = setup()
        gfp = GEOSFP("4x5", domain)

        csys = couple(emis, gfp)
        sys = convert(System, csys)
        eqs = observed(sys)

        @test occursin("NEI2016MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
    end

    @testset "wrong year" begin
        (; domain, ts, te, fileset) = setup()
        sample_time = DateTime(2016, 5, 1)
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        sample_time = DateTime(2017, 5, 1)
        @test_throws ArgumentError EarthSciData.lazyload!(itp, sample_time)
    end

    @testset "delp_dry_surface_itp" begin
        @test EarthSciData.delp_dry_surface_itp(deg2rad(-94.375), deg2rad(44.5)) ≈
              14.721285536474896
        @test EarthSciData.delp_dry_surface_itp(deg2rad(-88.125), deg2rad(42.0)) ≈
              14.8498301901334
    end

    @testset "conservative regridding" begin
        # Test that conservative regridding works through the unified NEI2016MonthlyEmis function
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            lonrange = deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
            latrange = deg2rad(25):deg2rad(0.5):deg2rad(49),
            levrange = 1:10
        )
        emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
        eqs = equations(emis)
        @test length(eqs) == 69

        @testset "DataSetInterpolator with conservative regridding" begin
            domain = DomainInfo(
                DateTime(2016, 5, 16, 12, 0, 0),
                DateTime(2016, 5, 17, 12, 0, 0);
                lonrange = deg2rad(-125):deg2rad(0.625):deg2rad(-66.875),
                latrange = deg2rad(25):deg2rad(0.5):deg2rad(49),
                levrange = 1:10
            )
            ts, te = get_tspan_datetime(domain)
            fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
            # Use the unified DataSetInterpolator with conservative regridding via regridder()
            fs = EarthSciData.FileSetWithRegridder(fileset,
                EarthSciData.regridder(fileset,
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
                lonrange = deg2rad(-125):deg2rad(2.5):deg2rad(-66.875),
                latrange = deg2rad(25):deg2rad(2.0):deg2rad(49),
                levrange = 1:10
            )
            ts, te = get_tspan_datetime(domain)
            fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
            fs = EarthSciData.FileSetWithRegridder(fileset,
                EarthSciData.regridder(fileset,
                    EarthSciData.loadmetadata(fileset, "NO"), domain))
            itp = EarthSciData.DataSetInterpolator{Float64}(fs, "NO", ts, te, domain)

            # Test that interpolation works at a specific location
            result = interp!(itp, ts, deg2rad(-87.5), deg2rad(41.0))
            @test result > 0.0
        end
    end

    @testset "emission values" begin
        domain = DomainInfo(
            DateTime(2016, 5, 15),
            DateTime(2016, 5, 16);
            lonrange = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
            latrange = deg2rad(42):deg2rad(0.5):deg2rad(43),
            levrange = 1:2
        )
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
        @variables NO(t) = 0.0 [unit = u"1/s"]

        saveat = range(tspan[1], tspan[2], length = nt)

        for (i, lon_val) in enumerate(lon_grid)
            for (j, lat_val) in enumerate(lat_grid)
                eq = D(NO) ~ emis.NO / uc
                sys = compose(System([eq], t, [NO], [uc]; name = Symbol("NO_sys_$(i)_$(j)")), emis)
                sys = mtkcompile(sys)
                # After composition, parameters are namespaced; extract them from the compiled system
                ps = parameters(sys)
                lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
                lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))
                lev_p = only(filter(p -> endswith(string(Symbol(p)), "₊lev"), ps))

                prob = ODEProblem(sys,
                    [lat_p => lat_val, lon_p => lon_val, lev_p => 1.0],
                    tspan)

                sol = solve(prob, Tsit5(), saveat = saveat)
                # Use the interpolant: the data-update discrete callback fires at
                # tspan[1] and `save_positions=(true,true)` adds an extra entry
                # at t=0, so `length(sol.u)` may exceed `length(saveat)`.
                NO_map[i, j, :] = [u[1] for u in sol(saveat).u]
            end
        end

        @test NO_map[1, 1, end] != 0.0  # Ensure we get nonzero emissions
    end

    @testset "emission values -- ACET" begin
        domain = DomainInfo(
            DateTime(2016, 5, 15),
            DateTime(2016, 5, 16);
            lonrange = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
            latrange = deg2rad(42):deg2rad(0.5):deg2rad(43),
            levrange = 1:2
        )
        emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)

        ts, te = get_tspan_datetime(domain)

        t_end = 3600  # in seconds
        nt = 5
        lon_grid = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875)
        lat_grid = deg2rad(42):deg2rad(0.5):deg2rad(43)
        ACET_map = Array{Float64}(undef, length(lon_grid), length(lat_grid), nt)
        tspan = (0.0, t_end)

        @constants uc = 1.0 [unit = u"s", description = "unit conversion"]
        @variables ACET(t) = 0.0 [unit = u"1/s"]

        saveat = range(tspan[1], tspan[2], length = nt)

        for (i, lon_val) in enumerate(lon_grid)
            for (j, lat_val) in enumerate(lat_grid)
                eq = D(ACET) ~ emis.ACET / uc
                sys = compose(
                    System(
                        [eq], t, [ACET], [uc]; name = Symbol("ACET_sys_$(i)_$(j)")), emis)
                sys = mtkcompile(sys)
                # After composition, parameters are namespaced; extract them from the compiled system
                ps = parameters(sys)
                lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
                lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))
                lev_p = only(filter(p -> endswith(string(Symbol(p)), "₊lev"), ps))

                prob = ODEProblem(sys,
                    [lat_p => lat_val, lon_p => lon_val, lev_p => 1.0],
                    tspan)

                sol = solve(prob, Tsit5(), saveat = saveat)
                # Use the interpolant: the data-update discrete callback fires at
                # tspan[1] and `save_positions=(true,true)` adds an extra entry
                # at t=0, so `length(sol.u)` may exceed `length(saveat)`.
                ACET_map[i, j, :] = [u[1] for u in sol(saveat).u]
            end
        end

        @test ACET_map[1, 1, end] != 0.0  # Ensure we get nonzero emissions
    end
end
