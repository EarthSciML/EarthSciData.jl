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
        shared_rg = EarthSciData.regridder(fileset,
            EarthSciData.loadmetadata(fileset, first(EarthSciData.varnames(fileset))),
            domain)
        @testset "correct projection" begin
            itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain;
                regrid_f = shared_rg)
            buf = EarthSciData.make_data_buffer(itp)
            result = interp!(itp, buf, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
            @test result > 0.0f0
            @test result < 1.0f-7  # Should be a small positive value
        end

        @testset "Out of domain" begin
            itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain;
                regrid_f = shared_rg)
            buf = EarthSciData.make_data_buffer(itp)
            @test interp!(itp, buf, sample_time, deg2rad(0.0f0), deg2rad(40.0f0)) ≈ 0.0
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
        buf = EarthSciData.make_data_buffer(itp)
        EarthSciData.lazyload!(itp, sample_time, buf)
        ti = EarthSciData.DataFrequencyInfo(itp.fs)
        @test month(itp.cache.times[1]) == 4
        @test month(itp.cache.times[2]) == 5

        sample_time = DateTime(2016, 5, 31)
        EarthSciData.lazyload!(itp, sample_time, buf)
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

    @testset "daysinmonth normalization" begin
        # Regression test for https://github.com/EarthSciML/EarthSciData.jl/issues/209.
        # The EPA gridded-merge monthly files carry a `units = "tons/day"`
        # attribute but actually store monthly totals on a single 24-hour
        # TSTEP.  `loadslice!` must divide by `daysinmonth(t)` so the value is
        # a true daily rate before the tons/day→kg/s conversion; otherwise the
        # injected emissions are ~daysinmonth (~30×) too high.
        (; fileset) = setup()
        varname = "NO"
        meta = EarthSciData.loadmetadata(fileset, varname)
        sample_time = DateTime(2016, 5, 15)

        # Value the public loader actually feeds to the regridder.
        loaded = zeros(Float64, meta.varsize...)
        EarthSciData.loadslice!(loaded, fileset, sample_time, varname)

        # Independently reconstruct the expected kg/s/m² value: pull the raw
        # monthly slice for the same TSTEP (via the inner loader, which selects
        # the time index exactly as the public one does), then apply the unit
        # conversion, cell-area division, and the days-in-month normalization.
        expected = zeros(Float64, meta.varsize...)
        EarthSciData.lock(EarthSciData.nclock) do
            tmp = reshape(expected, size(expected)..., 1)
            var = EarthSciData.loadslice!(
                tmp, fileset, fileset.ds, sample_time, varname, "TSTEP")
            scale, _ = EarthSciData.to_unit(var.attrib["units"])
            Δx = fileset.ds.attrib["XCELL"]
            Δy = fileset.ds.attrib["YCELL"]
            expected .*= scale
            expected ./= (Δx * Δy)
            expected ./= Dates.daysinmonth(sample_time)
        end

        @test Dates.daysinmonth(sample_time) == 31
        @test loaded ≈ expected
        # Sanity check: the normalization made a real difference (not a no-op).
        @test !(loaded ≈ expected .* Dates.daysinmonth(sample_time))
    end

    @testset "diurnal_itp function" begin
        # Test domain starts at 2016-05-01 00:00:00 UTC
        t_ref_numeric = datetime2unix(DateTime(2016, 5, 1))  # Domain starts at 2016-05-01 00:00:00

        # Test 1: UTC (0° longitude)
        lon_utc = deg2rad(0.0)  # UTC timezone

        # 6 AM UTC
        six_am_utc = t_ref_numeric + 6 * 3600.0  # 7th factor
        @test EarthSciData.diurnal_itp(six_am_utc, lon_utc) ==
              EarthSciData.DIURNAL_FACTORS[7]

        # 6 PM UTC
        six_pm_utc = t_ref_numeric + 18 * 3600.0  # 19th factor
        @test EarthSciData.diurnal_itp(six_pm_utc, lon_utc) ==
              EarthSciData.DIURNAL_FACTORS[19]

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

            # Julia 1.12+ emits `jl_get_pgcstack_static` for the GC safepoint
            # retrieval; AllocCheck's safelist still matches `get_pgcstack`
            # (old name), so these safepoints get reported as allocations
            # even though they don't actually heap-allocate.  Filter them out.
            is_real_alloc(e) = !(e isa AllocCheck.AllocatingRuntimeCall &&
                                 occursin("pgcstack", e.name))

            for T in (Float32, Float64)
                sample_time = DateTime(2016, 5, 1)
                itp = EarthSciData.DataSetInterpolator{T}(fileset, "NOX", ts, te, domain)
                buf = EarthSciData.make_data_buffer(itp)
                EarthSciData.lazyload!(itp, sample_time, buf)
                db = EarthSciData.DataBufferType(buf)
                # `@check_allocs` is a static (LLVM IR) analysis; every
                # invocation raises the same `AllocCheckFailure` if any
                # allocation is detected, so a warm-up pass is redundant.
                # On Julia 1.12 the failure always fires because of
                # `jl_get_pgcstack_static` safepoint markers; filter those
                # out before asserting (see `is_real_alloc` above).
                real_errors = Any[]
                try
                    checkf(db, T(1.5), T(5.3), T(5.7), T(1.0))
                catch err
                    append!(real_errors, filter(is_real_alloc, err.errors))
                end
                isempty(real_errors) ||
                    @warn "Allocation errors ($T):\n$(real_errors)"
                @test isempty(real_errors)
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
        buf = EarthSciData.make_data_buffer(itp)
        @test_throws ArgumentError EarthSciData.lazyload!(itp, sample_time, buf)
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
            rg = EarthSciData.regridder(fileset,
                EarthSciData.loadmetadata(fileset, "NO"), domain)
            itp = EarthSciData.DataSetInterpolator{Float64}(fileset, "NO", ts, te, domain;
                regrid_f = rg)
            @test itp.varname == "NO"
            @test itp.metadata !== nothing

            # Test that interpolation works
            buf = EarthSciData.make_data_buffer(itp)
            result = interp!(itp, buf, ts, deg2rad(-88.125), deg2rad(42.0))
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
            rg = EarthSciData.regridder(fileset,
                EarthSciData.loadmetadata(fileset, "NO"), domain)
            itp = EarthSciData.DataSetInterpolator{Float64}(fileset, "NO", ts, te, domain;
                regrid_f = rg)

            # Test that interpolation works at a specific location
            buf = EarthSciData.make_data_buffer(itp)
            result = interp!(itp, buf, ts, deg2rad(-87.5), deg2rad(41.0))
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
                sys = compose(
                    System(
                        [eq], t, [NO], [uc]; name = Symbol("NO_sys_$(i)_$(j)")), emis)
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

@testset "day-of-week factors conserve the weekly total" begin
    # HEMCO's GEIA_DOW_CO line repeats the NOx weekday value on Tue-Fri and sums
    # to 6.852; with 1.1076 on all weekdays it sums to exactly 7, like GEIA_DOW_NOX.
    @test EarthSciData.DayofWeekFactors_NOx ==
          [1.0706, 1.0706, 1.0706, 1.0706, 1.0706, 0.863, 0.784]
    @test EarthSciData.DayofWeekFactors_CO ==
          [1.1076, 1.1076, 1.1076, 1.1076, 1.1076, 0.779, 0.683]
    @test sum(EarthSciData.DayofWeekFactors_NOx) ≈ 7 rtol = 1e-12
    @test sum(EarthSciData.DayofWeekFactors_CO) ≈ 7 rtol = 1e-12
    t_mon = Dates.datetime2unix(Dates.DateTime(2016, 3, 7, 12))  # a Monday
    @test EarthSciData.dayofweek_itp_CO(t_mon, 0.0) == EarthSciData.DayofWeekFactors_CO[1]
end

@testset "local-time clock conventions" begin
    # Dallas (96.8°W), 12:00 UTC: NOx clock round(lon/15) = -6 h, CO clock floor(lon/15) = -7 h.
    t = Dates.datetime2unix(DateTime(2016, 7, 15, 12))
    dallas = deg2rad(-96.8)
    @test EarthSciData.diurnal_itp_NOx(t, dallas) == EarthSciData.DIURNAL_FACTORS_NOx[6 + 1]
    @test EarthSciData.diurnal_itp_ISOP(t, dallas) ==
          EarthSciData.DIURNAL_FACTORS_ISOP[6 + 1]
    @test EarthSciData.diurnal_itp(t, dallas) == EarthSciData.DIURNAL_FACTORS[5 + 1]

    # Half-hour meridians on the 0.625° grid; EDGAR file offsets are -6, -6, -8 (round half to even).
    for (lon_deg, offset) in ((-97.5, -6), (-82.5, -6), (-112.5, -8))
        @test EarthSciData.diurnal_itp_NOx(t, deg2rad(lon_deg)) ==
              EarthSciData.DIURNAL_FACTORS_NOx[12 + offset + 1]
    end

    # 2016-07-17 06:30 UTC is Sunday; at 97.5°W it is Sunday on the NOx clock, Saturday on the CO clock.
    ts = Dates.datetime2unix(DateTime(2016, 7, 17, 6, 30))
    @test EarthSciData.dayofweek_itp_NOx(ts, deg2rad(-97.5)) ==
          EarthSciData.DayofWeekFactors_NOx[7]
    @test EarthSciData.dayofweek_itp_CO(ts, deg2rad(-97.5)) ==
          EarthSciData.DayofWeekFactors_CO[6]
end

@testset "NEI2016 elevated sectors" begin
    using SymbolicIndexingInterface: setp

    # Emission tendencies (1/s) of `terms` (system index => species) at the given
    # (lon, lat, lev) points (degrees), read from the compiled right-hand side at
    # `tq` seconds after the start of the domain. Returns one row per point.
    function rates(systems, terms, points; tq = 0.0)
        @constants uc = 1.0 [unit = u"s"]
        vars = [only(@variables $(Symbol(:X, i))(t) = 0.0 [unit = u"1/s"])
                for i in eachindex(terms)]
        eqs = [D(v) ~ getproperty(systems[g], s) / uc for (v, (g, s)) in zip(vars, terms)]
        sys = mtkcompile(compose(System(eqs, t, vars, [uc]; name = :rates), systems...))
        ps = parameters(sys)
        coord(suffix) = filter(p -> endswith(string(Symbol(p)), suffix), ps)
        cs = [coord(c) for c in ("₊lon", "₊lat", "₊lev")]
        setters = [[setp(sys, p) for p in c] for c in cs]
        lo, la, k = first(points)
        init_vals = [p => v for (c, v) in zip(cs, (deg2rad(lo), deg2rad(la), Float64(k)))
                     for p in c]
        prob = ODEProblem(sys, init_vals, (0.0, 3600.0))
        integ = init(prob, Tsit5())
        order = [findfirst(isequal(v), unknowns(sys)) for v in vars]
        du = similar(integ.u)
        out = zeros(length(points), length(terms))
        for (r, (lo, la, k)) in enumerate(points)
            for (set, val) in zip(setters, (deg2rad(lo), deg2rad(la), Float64(k)))
                foreach(s -> s(integ, val), set)
            end
            integ.f(du, integ.u, integ.p, tq)
            out[r, :] = du[order]
        end
        return out, sys
    end
    profile(p) = findfirst(==(p), EarthSciData.NEI2016_PROFILE_NAMES)

    @testset "layer fractions" begin
        names = EarthSciData.NEI2016_PROFILE_NAMES
        @test names[1] == "surface"
        for i in eachindex(names)
            @test sum(EarthSciData.NEI2016_LAYER_FRACTIONS[i]) ≈ 1
            @test sum(EarthSciData.nei_layer_fraction(i, k) for k in 1:15) ≈ 1
            for ktop in (1, 3, 11, 30)
                # Folded at the domain top: the column total is kept, nothing above.
                @test sum(EarthSciData.nei_layer_fraction(i, ktop, k)
                for k in 1:(ktop + 2)) ≈ 1
                @test EarthSciData.nei_layer_fraction(i, ktop, ktop + 1) == 0
                @test sum(EarthSciData.nei_domain_fractions(i, ktop)) ≈ 1
            end
        end
        f(p, k) = EarthSciData.nei_layer_fraction(profile(p), k)
        @test f("surface", 1) == 1
        @test f("surface", 2) == 0
        # Layer fractions of GEOS-Chem's NEI2016 3-D files (2016fh_16j_<sector>_0pt1degree_3D_month_05).
        @test f("ptegu", 1) ≈ 0.0279 atol = 1e-4
        @test sum(f("ptegu", k) for k in 4:11) ≈ 0.651 atol = 1e-3
        @test f("ptnonipm", 1) ≈ 0.7537 atol = 1e-4
        @test f("pt_oilgas", 1) ≈ 0.9188 atol = 1e-4
        @test f("cmv", 1) ≈ 0.5375 atol = 1e-4
        @test f("cmv", 3) > 0
        @test f("cmv", 4) == 0
        @test f("ptegu", 12) == 0
        fr = EarthSciData.NEI2016_LAYER_FRACTIONS[profile("ptegu")]
        @test EarthSciData.nei_domain_fractions(profile("ptegu"), 3) ≈
              [fr[1], fr[2], sum(fr[3:end])]
        @test EarthSciData.nei_domain_fractions(profile("ptegu"), 30) == fr
        @test EarthSciData.nei_layer_fraction(profile("ptegu"), 30, NaN) == 0
        # Layer k covers k <= lev < k + 1 and values below 1 count as layer 1, as the
        # surface-only loader's former `lev < 2` test did (e.g. a domain-default lev of 1.5).
        @test EarthSciData.nei_layer_fraction(1, 30, 1.5) == 1
        @test EarthSciData.nei_layer_fraction(1, 30, 0.5) == 1
        @test EarthSciData.nei_layer_fraction(1, 30, 2.0) == 0
        @test EarthSciData.nei_layer_fraction(profile("ptegu"), 30, 3.7) == fr[3]
        @test EarthSciData.nei_layer_gate(1.5, 1) == 1
        @test EarthSciData.nei_layer_gate(2.0, 1) == 0
        @test EarthSciData.nei_layer_gate(NaN, 11) == 0
        @test EarthSciData.NEI2016_SECTOR_PROFILES["emln_ptegu"] == "ptegu"
        @test EarthSciData.NEI2016_SECTOR_PROFILES["emln_cmv_c3_12"] == "cmv"
        @test !haskey(EarthSciData.NEI2016_SECTOR_PROFILES, "emln_othpt")
        @test NEI2016_ELEVATED_SECTORS == ["emln_ptegu", "emln_ptnonipm", "emln_pt_oilgas",
            "emln_othpt", "emln_cmv_c3_12", "emln_cmv_c1c2_12"]
    end

    @testset "delp_dry_itp" begin
        lon, lat = deg2rad(-94.375), deg2rad(44.5)
        d1 = EarthSciData.delp_dry_surface_itp(lon, lat)
        @test EarthSciData.delp_dry_itp(lon, lat, 1) == d1
        # The lowest GEOS-FP layers are all about 15 hPa thick.
        for k in 2:11
            @test 0.9 < EarthSciData.delp_dry_itp(lon, lat, k) / d1 < 1.1
        end
        # Consistent with the hybrid grid: thickness = ΔAp + ΔBp * ps (Ap is in Pa, delp in hPa).
        ΔAp(k) = (EarthSciData.Ap(k) - EarthSciData.Ap(k + 1)) / 100
        ΔBp(k) = EarthSciData.Bp(k) - EarthSciData.Bp(k + 1)
        ps = (d1 - ΔAp(1)) / ΔBp(1)
        @test EarthSciData.delp_dry_itp(lon, lat, 5) ≈ ΔAp(5) + ΔBp(5) * ps
    end

    @testset "multi-sector file set" begin
        sector = "mrggrid_withbeis_withrwc"
        ts, te = DateTime(2016, 5, 1), DateTime(2016, 5, 2)
        fs1 = EarthSciData.NEI2016MonthlyEmisFileSet(sector, ts, te)
        # Listing the same sector twice must give exactly twice the emissions.
        fs2 = EarthSciData.NEI2016MonthlyEmisMultiFileSet([sector, sector], ts, te)
        @test EarthSciData.verify_fileset_interface(typeof(fs2))
        @test EarthSciData.varnames(fs2) == EarthSciData.varnames(fs1)
        m = EarthSciData.loadmetadata(fs2, "NOX")
        a = zeros(m.varsize...)
        b = zeros(m.varsize...)
        EarthSciData.loadslice!(a, fs1, ts, "NOX")
        EarthSciData.loadslice!(b, fs2, ts, "NOX")
        @test maximum(a) > 0
        @test b == 2a
        @test_throws ErrorException EarthSciData.NEI2016MonthlyEmisMultiFileSet(
            String[], ts, te)
        domain = DomainInfo(ts, te; lonrange = deg2rad(-90):deg2rad(1):deg2rad(-89),
            latrange = deg2rad(40):deg2rad(1):deg2rad(41), levrange = 1:2)
        @test_throws ErrorException NEI2016MonthlyEmis([sector], domain;
            vertical_profiles = Dict(sector => "stack"))
        @test_throws ArgumentError NEI2016MonthlyEmis(sector, domain; spatial_interp = :cubic)
    end

    @testset "surface regression and vertical allocation" begin
        domain = DomainInfo(DateTime(2016, 5, 15), DateTime(2016, 5, 16);
            lonrange = deg2rad(-88.125):deg2rad(0.625):deg2rad(-86.875),
            latrange = deg2rad(42):deg2rad(0.5):deg2rad(43), levrange = 1:3)
        sector = "mrggrid_withbeis_withrwc"
        surface = NEI2016MonthlyEmis(sector, domain; name = :surface)
        # The same file treated as a power-plant sector: the column total is spread over
        # the layers, folded into the top layer of this 3-layer domain.
        elevated = NEI2016MonthlyEmis([sector], domain;
            vertical_profiles = Dict(sector => "ptegu"), name = :elevated)

        # The single-sector call keeps its parameter names: one interpolator per
        # species, named after it.
        @test any(p -> string(Symbol(p)) == "NO_data", parameters(surface))
        @test length(ModelingToolkit.getmetadata(surface, EarthSciData.InterpInfos, nothing)) ==
              69
        @test length(equations(elevated)) == 69
        @test any(p -> string(Symbol(p)) == "NO_ptegu_data", parameters(elevated))

        species = [:NO, :NO2, :CO, :FORM, :ISOP, :ACET]
        points = [(-88.125, 42.0), (-87.5, 42.5), (-86.875, 43.0)]
        r, _ = rates([surface, elevated], [[1 => s for s in species]; 2 => :NO],
            [(lo, la, k) for k in 1:4 for (lo, la) in points])
        row(i, k) = (k - 1) * length(points) + i

        # The single-sector call must reproduce the layer-1 emissions (1/s) of the
        # surface-only loader at 2016-05-15 00:00 UTC (values from commit af45420, before
        # multi-sector support and vertical allocation were added), and nothing above.
        expected = Dict(
            ("NO", -88.125, 42.0) => 3.696630216752866e-12,
            ("NO2", -88.125, 42.0) => 4.3730420959836544e-13,
            ("CO", -88.125, 42.0) => 9.478783058412906e-12,
            ("FORM", -88.125, 42.0) => 4.037229705850393e-14,
            ("ISOP", -88.125, 42.0) => 5.184836779214539e-13,
            ("ACET", -88.125, 42.0) => 1.3005873181398365e-13,
            ("NO", -87.5, 42.5) => 1.3329110156415248e-13,
            ("NO2", -87.5, 42.5) => 1.42753478357713e-14,
            ("CO", -87.5, 42.5) => 3.628395844549008e-13,
            ("FORM", -87.5, 42.5) => 1.7564883575452577e-15,
            ("ISOP", -87.5, 42.5) => 9.160316615712789e-15,
            ("ACET", -87.5, 42.5) => 7.801309939082226e-15,
            ("NO", -86.875, 43.0) => 2.714099586734287e-15,
            ("NO2", -86.875, 43.0) => 2.774412889837166e-16,
            ("CO", -86.875, 43.0) => 1.2543254094733087e-14,
            ("FORM", -86.875, 43.0) => 2.803387435072575e-17,
            ("ISOP", -86.875, 43.0) => 1.1051762504955001e-17,
            ("ACET", -86.875, 43.0) => 3.841633770766277e-18
        )
        for (i, (lo, la)) in enumerate(points)
            for (j, s) in enumerate(species)
                @test r[row(i, 1), j] ≈ expected[(string(s), lo, la)] rtol = 1e-12
                @test all(r[row(i, k), j] == 0 for k in 2:4)
            end
        end

        # Elevated: layer k gets the profile fraction (the top layer also everything
        # above it), divided by the layer's thickness; nothing above the domain top.
        lo, la = points[1]
        d(k) = EarthSciData.delp_dry_itp(deg2rad(lo), deg2rad(la), k)
        fr = EarthSciData.NEI2016_LAYER_FRACTIONS[profile("ptegu")]
        r1 = r[row(1, 1), 1]
        @test r1 > 0
        for (k, fk) in enumerate([fr[1], fr[2], sum(fr[3:end])])
            @test r[row(1, k), 7] ≈ r1 * fk * d(1) / d(k) rtol = 1e-10
        end
        @test r[row(1, 4), 7] == 0
        # Column total over the domain's layers equals the surface-only column.
        @test sum(r[row(1, k), 7] * d(k) for k in 1:3) ≈ r1 * d(1) rtol = 1e-10
    end

    @testset "surface plus ships" begin
        # Surface file plus ocean-going ships (Gulf of Mexico off Louisiana), in a domain
        # one layer deeper than the ship profile.
        domain = DomainInfo(DateTime(2016, 5, 15), DateTime(2016, 5, 16);
            lonrange = deg2rad(-90.625):deg2rad(0.625):deg2rad(-89.375),
            latrange = deg2rad(28):deg2rad(0.5):deg2rad(29), levrange = 1:4)
        sectors = ["mrggrid_withbeis_withrwc", "emln_cmv_c3_12"]
        combined = NEI2016MonthlyEmis(sectors, domain; name = :combined)
        surface = NEI2016MonthlyEmis(sectors[1], domain; name = :surface_only)

        @test length(equations(combined)) == 69 # union of the variables of both files
        infos = ModelingToolkit.getmetadata(combined, EarthSciData.InterpInfos, nothing)
        names = [string(i.var_sym) for i in infos]
        @test "NO" in names && "NO_cmv" in names
        @test !("NO_ptegu" in names)

        lo, la = -90.0, 28.5
        points = [(lo, la, k) for k in 1:5]
        r, _ = rates([combined, surface], [1 => :NO, 2 => :NO, 1 => :SO2], points;
            tq = 43323.0)
        cmv = profile("cmv")
        f(k) = EarthSciData.nei_layer_fraction(cmv, k)
        d(k) = EarthSciData.delp_dry_itp(deg2rad(lo), deg2rad(la), k)
        # Only ships emit above layer 1, and their column flux is the same from every layer.
        col(k) = r[k, 1] * d(k) / f(k)
        @test r[2, 1] > 0
        @test col(3) ≈ col(2) rtol = 1e-10
        @test r[1, 1] ≈ r[1, 2] + col(2) * f(1) / d(1) rtol = 1e-10
        @test all(r[2:5, 2] .== 0)
        @test r[4, 1] == 0 # above the ship profile
        @test r[5, 1] == 0 # above the domain
        @test r[2, 3] > 0

        # At grid cells nearest-neighbour lookup gives the same values. In a system that
        # uses only NO, the update event keeps both NO interpolators and drops the others.
        nearest = NEI2016MonthlyEmis(sectors, domain; name = :nearest,
            spatial_interp = :nearest)
        rn, _ = rates([nearest], [1 => :NO], points; tq = 43323.0)
        @test rn[:, 1] ≈ r[:, 1] rtol = 1e-10
        ninfos = ModelingToolkit.getmetadata(nearest, EarthSciData.InterpInfos, nothing)
        live(n) = only(i.live[] for i in ninfos if string(i.var_sym) == n)
        @test live("NO") && live("NO_cmv")
        @test !live("CO") && !live("CO_cmv") && !live("SO2_cmv")
    end
end
