using Dates
using ModelingToolkit: D, t
using ModelingToolkit
using EarthSciMLBase
using EarthSciData
using DynamicQuantities
using Proj
using OrdinaryDiffEqTsit5
using SymbolicIndexingInterface: setp, getsym, parameter_values
using Test

struct WRFExampleCoupler
    sys::Any
end

@testset "WRF" begin
    function setup()
        domain = DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange = deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange = deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange = 1:32
        )
        return (; domain)
    end

    # Helper: wrap the WRF system with a dummy state variable so that
    # ODEProblem + init work (DiffEq requires at least one DV).
    # The `init` call fires the SymbolicDiscreteCallback's `initialize`
    # affect, which loads data at tspan[1].
    function setup_solved()
        (; domain) = setup()
        wrf_raw = WRF(domain)
        @variables _dummy(t) = 0.0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), wrf_raw)
        wrf_compiled = mtkcompile(_sys)
        return (; wrf_raw, wrf_compiled)
    end

    # Test that the coordinates that we calculate match the coordinates in the file.
    @testset "coordinates" begin
        (; domain) = setup()
        fs = EarthSciData.WRFFileSet("https://data.rda.ucar.edu/d340000/", domain)
        mdU = EarthSciData.loadmetadata(fs, "U")
        @test mdU.staggering == (true, false, false)
        trans = Proj.Transformation(
            "+proj=pipeline +step " * domain.spatial_ref * " +step " * mdU.native_sr,
        )
        @testset "U" begin
            fc = trans.(deg2rad.(fs.ds["XLONG_U"][1:390]), deg2rad.(fs.ds["XLAT_U"][1:390]))

            @test mdU.coords[mdU.xdim][1]≈fc[1][1] rtol=1e-5
            @test mdU.coords[mdU.xdim][end]≈fc[end][1] rtol=1e-5
            @test mdU.coords[mdU.ydim][1]≈fc[1][2] rtol=1e-5
        end

        @testset "V" begin
            mdV = EarthSciData.loadmetadata(fs, "V")
            fc = trans.(deg2rad.(fs.ds["XLONG_V"][1:389]), deg2rad.(fs.ds["XLAT_V"][1:389]))

            @test mdV.coords[mdV.xdim][1]≈fc[1][1] rtol=1e-5
            @test mdV.coords[mdV.xdim][end]≈fc[end][1] rtol=1e-5
            @test mdV.coords[mdV.ydim][1]≈fc[1][2] rtol=1e-5
        end
    end

    @testset "wrf" begin
        (; domain) = setup()
        lon, lat, lev = EarthSciMLBase.pvars(domain)
        @constants c_unit=6.0 [unit = u"rad" description = "constant to make units cancel out"]

        lonv = deg2rad(-118.2707)
        latv = deg2rad(34.0059)
        levv = 1.0
        tt = DateTime(2023, 8, 15, 0, 0, 0)

        wrf_sys = WRF(domain)

        function Example()
            @variables c(t) [unit = u"mol/m^3"]
            eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
            return System(
                eqs,
                t;
                name = :ExampleSys,
                metadata = Dict(CoupleType => WRFExampleCoupler)
            )
        end

        function EarthSciMLBase.couple2(e::WRFExampleCoupler, w::EarthSciData.WRFCoupler)
            e, w = e.sys, w.sys
            e = EarthSciMLBase.param_to_var(e, :lat, :lon)
            ConnectorSystem([e.lat ~ w.lat, e.lon ~ w.lon], e, w)
        end

        examplesys = Example()

        composed_sys = couple(examplesys, domain, Advection(), wrf_sys)
        pde_sys = convert(PDESystem, composed_sys)

        eqs = equations(pde_sys)

        want_terms = [
            "MeanWind₊v_lon(t, lon, lat, lev)",
            "WRF₊U(t, lon, lat, lev)",
            "MeanWind₊v_lat(t, lon, lat, lev)",
            "WRF₊V(t, lon, lat, lev)",
            "MeanWind₊v_lev(t, lon, lat, lev)",
            "WRF₊W(t, lon, lat, lev)",
            "interp_unsafe(WRF₊U_data",
            "interp_unsafe(WRF₊V_data",
            "interp_unsafe(WRF₊W_data",
            "WRF₊T(t, lon, lat, lev)",
            "WRF₊P(t, lon, lat, lev)",
            "WRF₊PB(t, lon, lat, lev)",
            "WRF₊PH(t, lon, lat, lev)",
            "WRF₊PHB(t, lon, lat, lev)",
            "lon2m",
            "lat2meters",
            "Differential(lat, 1)(ExampleSys₊c(t, lon, lat, lev)",
            "Differential(t, 1)(ExampleSys₊c(t, lon, lat, lev))",
            "Differential(lon, 1)(ExampleSys₊c(t, lon, lat, lev)",
            "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
            "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
            "ExampleSys₊c(t, lon, lat, lev)",
            "t",
            "Differential(lev, 1)(ExampleSys₊c(t, lon, lat, lev))"
        ]

        have_eqs = string.(eqs)
        have_eqs = replace.(have_eqs, ("Main." => "",))

        for term in want_terms
            @test any(occursin.((term,), have_eqs))
        end
    end

    @testset "wrf total pressures" begin
        (; domain) = setup()
        (; wrf_compiled) = setup_solved()
        prob = ODEProblem(wrf_compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.P_total)
        setter = setp(integ, [wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        p_want = [100331.86015842063, 100235.71904432855, 100139.57793023644,
            67846.0833619396, 30679.47156109965, 28729.87012240142]
        @test p_levels ≈ p_want
    end

    @testset "wrf lambert projection" begin
        domain = DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            xrange = -2.334e6:12000:2.334e6,
            yrange = -1.374e6:12000:1.374e6,
            levrange = 1:32,
            spatial_ref = "+proj=lcc +lat_1=30.0 +lat_2=60.0 +lat_0=38.999996 +lon_0=-97.0 +x_0=0 +y_0=0 +a=6370000 +b=6370000 +to_meter=1"
        )

        lonv = deg2rad(-118.2707)
        latv = deg2rad(34.0059)
        trans = Proj.Transformation(
            "+proj=pipeline +step " *
            "+proj=longlat +datum=WGS84 +no_defs" *
            " +step " *
            domain.spatial_ref,
        )
        xv, yv = trans(lonv, latv)

        wrf_raw = WRF(domain)
        @variables _dummy(t) = 0.0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), wrf_raw)
        compiled = mtkcompile(_sys)
        prob = ODEProblem(compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, compiled.WRF.P_total)
        setter = setp(integ, [compiled.WRF.x, compiled.WRF.y, compiled.WRF.lev])

        p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [xv, yv, lev])
            f(integ)
        end
        p_want = [100099.2143558437, 100003.30283880791, 99907.39132177213, 67693.99609309093,
            30617.55578737014, 28672.612298322314]
        @test p_levels ≈ p_want
    end

    @testset "wrf total pressures at fractional-hour timestamps (minutes/seconds)" begin
        (; wrf_compiled) = setup_solved()
        tstart = 25.0 * 60 + 36
        tend = tstart + 1

        prob = ODEProblem(wrf_compiled, [], (tstart, tend))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.P_total)
        setter = setp(integ, [wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        p_want = [100295.9284090799, 100199.12630285477, 100102.32419662959, 67826.4962347177,
            30668.59654150301, 28719.783883029562]
        @test p_levels ≈ p_want
    end

    @testset "wrf δzδlev" begin
        (; domain) = setup()
        (; wrf_compiled) = setup_solved()
        prob = ODEProblem(wrf_compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.δzδlev)
        setter = setp(integ, [wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        δzδlevs = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        δzδlev_want = [10.605308519529093, 16.96470420154144, 23.33493331829344,
            655.5566269461963, 352.24392973192874, 279.69888985290606]
        @test δzδlevs ≈ δzδlev_want
    end

    @testset "wrf ground level vertical velocity" begin
        (; domain) = setup()
        (; wrf_compiled) = setup_solved()
        prob = ODEProblem(wrf_compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.W)
        setter = setp(integ, [wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        ws = map([0.5, 1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        w_want = [0.0, 0.00520469831395109, 0.01040939662790218, 0.011643543143849931,
            -0.016975643831838198, 0.026965458394074104, 0.022436248330301084]
        @test ws ≈ w_want
    end
end
