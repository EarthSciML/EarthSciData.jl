using EarthSciData
using EarthSciMLBase
using Dates
using ModelingToolkit
using ModelingToolkit: t, D
using DynamicQuantities
using OrdinaryDiffEqTsit5
using SymbolicIndexingInterface: setp, getsym, parameter_values
using Test

struct ExampleCoupler
    sys::Any
end

@testset "GEOSFP" begin
    function setup_domain()
        domain = DomainInfo(
            DateTime(2022, 1, 1),
            DateTime(2022, 1, 3);
            latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
            lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
            levrange = 1:73
        )
        return (; domain)
    end

    # Helper: wrap a parameter-only data system with a trivial state variable
    # so that ODEProblem + init/solve work (DiffEq requires at least one DV).
    function setup_solved()
        (; domain) = setup_domain()
        geosfp_raw = GEOSFP("4x5", domain)
        @variables _dummy(t) = 0.0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), geosfp_raw)
        compiled = mtkcompile(_sys)
        return (; geosfp_raw, compiled)
    end

    @testset "GEOS-FP" begin
        (; domain) = setup_domain()
        geosfp = GEOSFP("4x5", domain)

        @test all([x in Symbol.(parameters(geosfp)) for x in [:lon, :lat, :lev]])

        domain2 = EarthSciMLBase.add_partial_derivative_func(
            domain,
            partialderivatives_δPδlev_geosfp(geosfp)
        )

        function Example()
            lon, lat, _ = EarthSciMLBase.pvars(domain)
            @variables c(t)=5.0 [unit = u"mol/m^3"]
            @constants c_unit=6.0 [unit = u"rad" description = "constant to make units cancel out"]
            System(
                [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t],
                t,
                name = :ExampleSys,
                metadata = Dict(CoupleType => ExampleCoupler)
            )
        end
        function EarthSciMLBase.couple2(e::ExampleCoupler, g::EarthSciData.GEOSFPCoupler)
            e, g, = e.sys, g.sys
            e = EarthSciMLBase.param_to_var(e, :lat, :lon)
            ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon], e, g)
        end

        examplesys = Example()

        composed_sys = couple(examplesys, domain2, Advection(), geosfp)
        pde_sys = convert(PDESystem, composed_sys)

        eqs = equations(pde_sys)

        want_terms = [
            "MeanWind₊v_lon(t, lon, lat, lev)",
            "GEOSFP₊A3dyn₊U(t, lon, lat, lev)",
            "MeanWind₊v_lat(t, lon, lat, lev)",
            "GEOSFP₊A3dyn₊V(t, lon, lat, lev)",
            "MeanWind₊v_lev(t, lon, lat, lev)",
            "GEOSFP₊A3dyn₊OMEGA(t, lon, lat, lev)",
            "GEOSFP₊A3dyn₊U(t, lon, lat, lev)",
            "interp_unsafe(GEOSFP₊A3dyn₊U_data",
            "GEOSFP₊A3dyn₊OMEGA(t, lon, lat, lev)",
            "interp_unsafe(GEOSFP₊A3dyn₊OMEGA_data",
            "GEOSFP₊A3dyn₊V(t, lon, lat, lev)",
            "interp_unsafe(GEOSFP₊A3dyn₊V_data",
            "Differential(t, 1)(ExampleSys₊c(t, lon, lat, lev))",
            "Differential(lon, 1)(ExampleSys₊c(t, lon, lat, lev)",
            "MeanWind₊v_lon(t, lon, lat, lev)",
            "lon2m",
            "Differential(lat, 1)(ExampleSys₊c(t, lon, lat, lev)",
            "MeanWind₊v_lat(t, lon, lat, lev)",
            "lat2meters",
            "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
            "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
            "ExampleSys₊c(t, lon, lat, lev)",
            "t",
            "Differential(lev, 1)(ExampleSys₊c(t, lon, lat, lev))",
            "MeanWind₊v_lev(t, lon, lat, lev)",
            "P_unit"
        ]
        have_eqs = string.(eqs)
        have_eqs = replace.(have_eqs, ("Main." => "",))
        for term in want_terms
            @test any(occursin.((term,), have_eqs))
        end
    end

    @testset "GEOS-FP pressure levels" begin
        # `P` is the hybrid-grid pressure
        # `P_unit * Ap(lev) + Bp(lev) * I3.PS`. The `lev` dependence is
        # purely analytical (piecewise linear in `Ap` and `Bp`); only
        # the surface pressure `I3.PS` reads from the NetCDF, and that
        # read is at fixed `(lon, lat)`, independent of `lev`. So the
        # six `lev` values below exercise the analytical pressure
        # formula at one fixed grid point — the data interpolation is
        # what provides `PS`, not what differentiates the six results.
        # For high `lev` (≥72), `Bp(lev) = 0`, so `P` collapses to
        # `Ap(lev)` (≈ 2, 1.5, 1 Pa).
        (; compiled) = setup_solved()
        prob = ODEProblem(compiled, [], (24.0 * 3600, 48.0 * 3600))
        integ = init(prob, Tsit5())
        f = getsym(integ, compiled.GEOSFP.P)
        setter = setp(integ, [compiled.GEOSFP.lon, compiled.GEOSFP.lat, compiled.GEOSFP.lev])

        p_levels = map([1, 1.5, 2, 72, 72.5, 73]) do lev
            setter(integ, [deg2rad(-155.7), deg2rad(39.1), lev])
            f(integ)
        end
        @test p_levels ≈
              [102340.37924047427, 101572.77264006894, 100805.16603966363, 2.0, 1.5, 1.0]
    end

    @testset "GEOS-FP ground-level vertical velocity" begin
        (; compiled) = setup_solved()
        prob = ODEProblem(compiled, [], (24.0 * 3600, 48.0 * 3600))
        integ = init(prob, Tsit5())
        f = getsym(integ, compiled.GEOSFP.A3dyn₊OMEGA)
        setter = setp(integ, [compiled.GEOSFP.lon, compiled.GEOSFP.lat, compiled.GEOSFP.lev])

        omega_levels = map([0.5, 1, 1.5, 2, 72, 72.5, 73]) do lev
            setter(integ, [deg2rad(-155.7), deg2rad(39.1), lev])
            f(integ)
        end
        @test omega_levels ≈ [0.0, -0.0038511699971381114, -0.007702339994276223,
            -0.006515003709544222, 1.1196587112172361e-5, 0.0, 0.0]
    end

    @testset "GEOS-FP new day" begin
        (; domain) = setup_domain()
        (; compiled) = setup_solved()
        tspan = datetime2unix.((DateTime(2022, 1, 1, 23, 58), DateTime(2022, 1, 2, 0, 3))) .-
                get_tref(domain)
        prob = ODEProblem(compiled, [], tspan)
        integ = init(prob, Tsit5())
        f = getsym(integ, compiled.GEOSFP.I3₊PS)
        @test f(integ) ≈ 101193.67232405252
    end

    @testset "GEOS-FP wrong month" begin
        (; domain) = setup_domain()
        (; compiled) = setup_solved()
        tspan = datetime2unix.((DateTime(2022, 5, 1), DateTime(2022, 5, 2))) .-
                get_tref(domain)
        prob = ODEProblem(compiled, [], tspan)
        # The initialize callback fires at tspan[1] which is outside the dataset
        # range — expect an error during init.
        @test_throws Base.Exception init(prob, Tsit5())
    end

    @testset "GEOS-FP height above ground" begin
        (; compiled) = setup_solved()
        prob = ODEProblem(compiled, [], (24.0 * 3600, 48.0 * 3600))
        integ = init(prob, Tsit5())
        f = getsym(integ, compiled.GEOSFP.Z_agl)
        setter = setp(integ, [compiled.GEOSFP.lon, compiled.GEOSFP.lat, compiled.GEOSFP.lev])

        z_levels = map([1.0, 1.5, 2.0, 72.0, 72.5, 73.0]) do lev
            setter(integ, [deg2rad(-155.7), deg2rad(39.1), lev])
            f(integ)
        end
        # lev=1 sits at the surface (P=Ps), so Z_agl(1) is identically zero.
        @test z_levels[1] == 0.0
        # Monotonic increase with lev.
        @test issorted(z_levels)
        # Cumulative-thickness regression: half a layer ≈ 63 m, full layer 1 ≈ 127 m,
        # top of grid (lev=73) ≈ 77 km above surface.
        @test z_levels ≈ [0.0, 63.286268234824156, 127.05262260647852,
            73259.38608525122, 74830.28974058769, 77044.35408950633]
    end
end
