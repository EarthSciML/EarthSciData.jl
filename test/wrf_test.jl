@testsnippet WRFSetup begin
    using Dates
    using ModelingToolkit: D, t
    using ModelingToolkit
    using EarthSciMLBase
    using DynamicQuantities
    using Proj

    domain = DomainInfo(
        DateTime(2023, 8, 15, 0, 0, 0),
        DateTime(2023, 8, 15, 3, 0, 0);
        latrange = deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
        lonrange = deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
        levrange = 1:32
    )
end

# Test that the coordinates that we calculate match the coordinates in the file.
@testitem "coordinates" setup=[WRFSetup] begin
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

@testitem "wrf" setup=[WRFSetup] begin
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    @constants c_unit=6.0 [unit = u"rad" description = "constant to make units cancel out"]

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    wrf_sys = WRF(domain)

    struct ExampleCoupler
        sys::Any
    end

    function Example()
        @variables c(t) [unit = u"mol/m^3"]
        eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
        return ODESystem(
            eqs,
            t;
            name = :ExampleSys,
            metadata = Dict(CoupleType => ExampleCoupler)
        )
    end

    function EarthSciMLBase.couple2(e::ExampleCoupler, w::EarthSciData.WRFCoupler)
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
        "WRF₊U_itp(WRF₊t_ref + t, lon, lat, lev)",
        "WRF₊V_itp(WRF₊t_ref + t, lon, lat, lev)",
        "WRF₊W_itp(WRF₊t_ref + t, lon, lat, lev)",
        "WRF₊T(t, lon, lat, lev)",
        "WRF₊P(t, lon, lat, lev)",
        "WRF₊PB(t, lon, lat, lev)",
        "WRF₊PH(t, lon, lat, lev)",
        "WRF₊PHB(t, lon, lat, lev)",
        "lon2m",
        "lat2meters",
        "Differential(lat)(ExampleSys₊c(t, lon, lat, lev)",
        "Differential(t)(ExampleSys₊c(t, lon, lat, lev))",
        "Differential(lon)(ExampleSys₊c(t, lon, lat, lev)",
        "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
        "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
        "ExampleSys₊c(t, lon, lat, lev)",
        "t",
        "Differential(lev)(ExampleSys₊c(t, lon, lat, lev))"
    ]

    have_eqs = string.(eqs)
    have_eqs = replace.(have_eqs, ("Main." => "",))

    for term in want_terms
        @test any(occursin.((term,), have_eqs))
    end
end

@testitem "wrf total pressures" setup=[WRFSetup] begin
    using SymbolicIndexingInterface: setp, getsym, parameter_values

    wrf_sys = mtkcompile(WRF(domain))
    prob = ODEProblem(wrf_sys, [], get_tref(domain))
    f = getsym(prob, wrf_sys.P_total)
    setter = setp(wrf_sys, [wrf_sys.lon, wrf_sys.lat, wrf_sys.lev])
    ps = parameter_values(prob)

    p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
        setter(prob, [deg2rad(-118.2707), deg2rad(34.0059), lev])
        f(prob)
    end

    p_want = [100331.86015842063, 100235.71904432855, 100139.57793023644,
        67846.0833619396, 30679.47156109965, 28729.87012240142]
    @test p_levels ≈ p_want
end

@testitem "wrf lambert projection" setup=[WRFSetup] begin
    using SymbolicIndexingInterface: setp, getsym, parameter_values

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

    wrf_sys = mtkcompile(WRF(domain))
    prob = ODEProblem(wrf_sys, [], get_tref(domain))
    f = getsym(prob, wrf_sys.P_total)
    setter = setp(wrf_sys, [wrf_sys.x, wrf_sys.y, wrf_sys.lev])
    ps = parameter_values(prob)

    p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
        setter(prob, [xv, yv, lev])
        f(prob)
    end
    p_want = [100099.2143558437, 100003.30283880791, 99907.39132177213, 67693.99609309093,
        30617.55578737014, 28672.612298322314]
    @test p_levels ≈ p_want
end

@testitem "wrf total pressures at fractional-hour timestamps (minutes/seconds)" setup=[WRFSetup] begin
    using SymbolicIndexingInterface: setp, getsym, parameter_values

    tstart = 25.0 * 60 + 36
    tend = tstart + 1

    wrf_sys = mtkcompile(WRF(domain))
    prob = ODEProblem(wrf_sys, [], (tstart, tend))
    f = getsym(prob, wrf_sys.P_total)
    setter = setp(wrf_sys, [wrf_sys.lon, wrf_sys.lat, wrf_sys.lev])
    ps = parameter_values(prob)

    p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
        setter(prob, [deg2rad(-118.2707), deg2rad(34.0059), lev])
        f(prob)
    end

    p_want = [100295.9284090799, 100199.12630285477, 100102.32419662959, 67826.4962347177,
        30668.59654150301, 28719.783883029562]
    @test p_levels ≈ p_want
end

@testitem "wrf δzδlev" setup=[WRFSetup] begin
    using SymbolicIndexingInterface: setp, getsym, parameter_values

    wrf_sys = mtkcompile(WRF(domain))
    prob = ODEProblem(wrf_sys, [], get_tref(domain))
    f = getsym(prob, wrf_sys.δzδlev)
    setter = setp(wrf_sys, [wrf_sys.lon, wrf_sys.lat, wrf_sys.lev])
    ps = parameter_values(prob)

    δzδlevs = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
        setter(prob, [deg2rad(-118.2707), deg2rad(34.0059), lev])
        f(prob)
    end

    δzδlev_want = [10.605308519529093, 16.96470420154144, 23.33493331829344,
        655.5566269461963, 352.24392973192874, 279.69888985290606]
    @test δzδlevs ≈ δzδlev_want
end

@testitem "wrf ground level vertical velocity" setup=[WRFSetup] begin
    using SymbolicIndexingInterface: setp, getsym, parameter_values

    wrf_sys = mtkcompile(WRF(domain))
    prob = ODEProblem(wrf_sys, [], get_tref(domain))
    f = getsym(prob, wrf_sys.W)
    setter = setp(wrf_sys, [wrf_sys.lon, wrf_sys.lat, wrf_sys.lev])
    ps = parameter_values(prob)

    ws = map([0.5, 1, 1.5, 2, 21.5, 30, 31.5]) do lev
        setter(prob, [deg2rad(-118.2707), deg2rad(34.0059), lev])
        f(prob)
    end

    w_want = [0.0, 0.00520469831395109, 0.01040939662790218, 0.011643543143849931,
        -0.016975643831838198, 0.026965458394074104, 0.022436248330301084]
    @test ws ≈ w_want
end
