using Dates
using ModelingToolkit: D, t
using ModelingToolkit
using EarthSciData
using EarthSciMLBase
using DynamicQuantities
using Proj
using Test

domain = DomainInfo(
    DateTime(2023, 8, 15, 0, 0, 0),
    DateTime(2023, 8, 15, 3, 0, 0);
    latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
    lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
    levrange=1:32,
    dtype=Float64
)

# Test that the coordinates that we calculate match the coordinates in the file.
@testset "coordinates" begin
    fs = EarthSciData.WRFFileSet("https://data.rda.ucar.edu/d340000/", domain)
    mdU = EarthSciData.loadmetadata(fs, "U")
    @test mdU.staggering == (true, false, false)
    trans = Proj.Transformation("+proj=pipeline +step " * domain.spatial_ref *
                                " +step " * mdU.native_sr)
    @testset "U" begin
        fc = trans.(deg2rad.(fs.ds["XLONG_U"][1:390]), deg2rad.(fs.ds["XLAT_U"][1:390]))

        @test mdU.coords[mdU.xdim][1] ≈ fc[1][1] rtol = 1e-5
        @test mdU.coords[mdU.xdim][end] ≈ fc[end][1] rtol = 1e-5
        @test mdU.coords[mdU.ydim][1] ≈ fc[1][2] rtol = 1e-5
    end

    @testset "V" begin
        mdV = EarthSciData.loadmetadata(fs, "V")
        fc = trans.(deg2rad.(fs.ds["XLONG_V"][1:389]), deg2rad.(fs.ds["XLAT_V"][1:389]))

        @test mdV.coords[mdV.xdim][1] ≈ fc[1][1] rtol = 1e-5
        @test mdV.coords[mdV.xdim][end] ≈ fc[end][1] rtol = 1e-5
        @test mdV.coords[mdV.ydim][1] ≈ fc[1][2] rtol = 1e-5
    end
end

@testset "wrf" begin
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    @constants c_unit = 6.0 [unit = u"rad" description = "constant to make units cancel out"]

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    wrf_sys = WRF(domain)

    struct ExampleCoupler
        sys
    end

    function Example()
        @variables c(t) [unit = u"mol/m^3"]
        eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
        return ODESystem(eqs, t; name=:ExampleSys, metadata=Dict(:coupletype => ExampleCoupler))
    end

    function EarthSciMLBase.couple2(e::ExampleCoupler, w::EarthSciData.WRFCoupler)
        e, w = e.sys, w.sys
        e = EarthSciMLBase.param_to_var(e, :lat, :lon)
        ConnectorSystem([
                e.lat ~ w.lat,
                e.lon ~ w.lon,
            ], e, w)
    end

    examplesys = Example()

    composed_sys = couple(examplesys, domain, Advection(), wrf_sys)
    pde_sys = convert(PDESystem, composed_sys)

    eqs = equations(pde_sys)

    want_terms = [
        "MeanWind₊v_lon(t, lon, lat, lev)", "WRF₊U(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)", "WRF₊V(t, lon, lat, lev)",
        "MeanWind₊v_lev(t, lon, lat, lev)", "WRF₊W(t, lon, lat, lev)",
        "WRF₊U_itp(t, lon, lat, lev)", "WRF₊V_itp(t, lon, lat, lev)",
        "WRF₊W_itp(t, lon, lat, lev)",
        "WRF₊T(t, lon, lat, lev)",
        "WRF₊P(t, lon, lat, lev)", "WRF₊PB(t, lon, lat, lev)",
        "WRF₊PH(t, lon, lat, lev)", "WRF₊PHB(t, lon, lat, lev)",
        "lon2m", "lat2meters",
        "Differential(lat)(ExampleSys₊c(t, lon, lat, lev)",
        "Differential(t)(ExampleSys₊c(t, lon, lat, lev))", "Differential(lon)(ExampleSys₊c(t, lon, lat, lev)",
        "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
        "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
        "ExampleSys₊c(t, lon, lat, lev)", "t",
        "Differential(lev)(ExampleSys₊c(t, lon, lat, lev))",
    ]

    have_eqs = string.(eqs)
    have_eqs = replace.(have_eqs, ("Main." => "",))

    for term ∈ want_terms
        @test any(occursin.((term,), have_eqs))
    end
end

@testset "wrf total pressures at exact-hour timestamps" begin
    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    wrf_sys = WRF(domain)

    @parameters lon [unit = u"rad"] lat [unit = u"rad"] lev [unit = u"1"]

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "P_total(t)", equations(wrf_sys))
    ptotal_eq = equations(wrf_sys)[iipt]

    ptotal_sub = ModelingToolkit.subs_constants(ptotal_eq.rhs)

    vars_in_expr = get_variables(ptotal_sub)
    getv(v) = vars_in_expr[findfirst(isequal(v), EarthSciMLBase.var2symbol.(vars_in_expr))]
    P_itp = getv(:P_itp)
    PB_itp = getv(:PB_itp)

    P_expr = build_function(ptotal_sub, [t, lon, lat, lev, P_itp, PB_itp])
    myf = eval(P_expr)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    event_p = only(events[[only(e.affects.pars_syms) == :P_itp for e in events]])
    event_pb = only(events[[only(e.affects.pars_syms) == :PB_itp for e in events]])

    EarthSciData.lazyload!(event_p.affects.ctx, tt)
    EarthSciData.lazyload!(event_pb.affects.ctx, tt)

    itp_p = EarthSciData.ITPWrapper(event_p.affects.ctx)
    itp_pb = EarthSciData.ITPWrapper(event_pb.affects.ctx)

    p_want = [100331.86015842063, 100235.71904432855, 100139.57793023644, 67846.0833619396,
        30679.47156109965, 28729.87012240142]
    P_total = [
        myf([tt, lonv, latv, levv, itp_p, itp_pb])
        for levv in [1, 1.5, 2, 21.5, 30, 31.5]
    ]
    @test P_total ≈ p_want
end

@testset "wrf lambert projection" begin
    domain = DomainInfo(
        DateTime(2023, 8, 15, 0, 0, 0),
        DateTime(2023, 8, 15, 3, 0, 0);
        xrange=-2.334e6:12000:2.334e6,
        yrange=-1.374e6:12000:1.374e6,
        levrange=1:32,
        spatial_ref="+proj=lcc +lat_1=30.0 +lat_2=60.0 +lat_0=38.999996 +lon_0=-97.0 +x_0=0 +y_0=0 +a=6370000 +b=6370000 +to_meter=1",
        dtype=Float64
    )

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    trans = Proj.Transformation("+proj=pipeline +step " * "+proj=longlat +datum=WGS84 +no_defs" *
                                " +step " * domain.spatial_ref)
    xv, yv = trans(lonv, latv)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    wrf_sys = WRF(domain)

    x, y, lev = EarthSciMLBase.pvars(domain)

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "P_total(t)", equations(wrf_sys))
    ptotal_eq = equations(wrf_sys)[iipt]

    ptotal_sub = ModelingToolkit.subs_constants(ptotal_eq.rhs)

    vars_in_expr = get_variables(ptotal_sub)
    getv(v) = vars_in_expr[findfirst(isequal(v), EarthSciMLBase.var2symbol.(vars_in_expr))]
    P_itp = getv(:P_itp)
    PB_itp = getv(:PB_itp)

    P_expr = build_function(ptotal_sub, [t, x, y, lev, P_itp, PB_itp])
    myf = eval(P_expr)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    event_p = only(events[[only(e.affects.pars_syms) == :P_itp for e in events]])
    event_pb = only(events[[only(e.affects.pars_syms) == :PB_itp for e in events]])

    EarthSciData.lazyload!(event_p.affects.ctx, tt)
    EarthSciData.lazyload!(event_pb.affects.ctx, tt)

    itp_p = EarthSciData.ITPWrapper(event_p.affects.ctx)
    itp_pb = EarthSciData.ITPWrapper(event_pb.affects.ctx)

    #p_want = [100331.86015842063, 100235.71904432855, 100139.57793023644, 67846.0833619396,
    #    30679.47156109965, 28729.87012240142]
    p_want = [100099.2143558437, 100003.30283880791, 99907.39132177213, 67693.99609309093,
        30617.55578737014, 28672.612298322314] # TODO(CT): Why is this different from the one above?
    P_total = [
        myf([tt, xv, yv, levv, itp_p, itp_pb])
        for levv in [1, 1.5, 2, 21.5, 30, 31.5]
    ]
    @test P_total ≈ p_want
end

@testset "wrf total pressures at fractional-hour timestamps (minutes/seconds)" begin
    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 25, 36)

    wrf_sys = WRF(domain)

    @parameters lon [unit = u"rad"] lat [unit = u"rad"] lev [unit = u"1"]

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "P_total(t)", equations(wrf_sys))
    ptotal_eq = equations(wrf_sys)[iipt]

    ptotal_sub = ModelingToolkit.subs_constants(ptotal_eq.rhs)

    vars_in_expr = get_variables(ptotal_sub)
    P_itp = vars_in_expr[findfirst(isequal(:P_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    PB_itp = vars_in_expr[findfirst(isequal(:PB_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    P_expr = build_function(ptotal_sub, [t, lon, lat, lev, P_itp, PB_itp])
    myf = eval(P_expr)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    event_p = only(events[[only(e.affects.pars_syms) == :P_itp for e in events]])
    event_pb = only(events[[only(e.affects.pars_syms) == :PB_itp for e in events]])

    Main.EarthSciData.lazyload!(event_p.affects.ctx, tt)
    EarthSciData.lazyload!(event_pb.affects.ctx, tt)

    itp_p = EarthSciData.ITPWrapper(event_p.affects.ctx)
    itp_pb = EarthSciData.ITPWrapper(event_pb.affects.ctx)

    p_want = [100295.9284090799, 100199.12630285477, 100102.32419662959, 67826.4962347177,
        30668.59654150301, 28719.783883029562]
    P_total = [
        myf([tt, lonv, latv, levv, itp_p, itp_pb])
        for levv in [1, 1.5, 2, 21.5, 30, 31.5]
    ]
    @test P_total ≈ p_want
end


@testset "wrf δzδlev" begin
    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    @parameters lat, [unit = u"rad"], lon, [unit = u"rad"], lev

    wrf_sys = WRF(domain)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    e_ph = only(events[[only(e.affects.pars_syms) == :PH_itp for e in events]])
    e_phb = only(events[[only(e.affects.pars_syms) == :PHB_itp for e in events]])

    Main.EarthSciData.lazyload!(e_ph.affects.ctx, tt)
    Main.EarthSciData.lazyload!(e_phb.affects.ctx, tt)

    itp_ph = EarthSciData.ITPWrapper(e_ph.affects.ctx)
    itp_phb = EarthSciData.ITPWrapper(e_phb.affects.ctx)

    eqs = equations(wrf_sys)
    δzδlev_var = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :δzδlev, eqs)].rhs
    δzδlev_sub = ModelingToolkit.subs_constants(δzδlev_var)

    vars_in_expr = get_variables(δzδlev_sub)
    PH_itp = vars_in_expr[findfirst(isequal(:PH_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    PHB_itp = vars_in_expr[findfirst(isequal(:PHB_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    δzδlev_expr = build_function(δzδlev_sub, [t, lon, lat, lev, PH_itp, PHB_itp])
    δzδlev_f = eval(δzδlev_expr)

    δzδlev_want = [10.605308519529093, 16.96470420154144, 23.33493331829344, 655.5566269461963, 352.24392973192874, 279.69888985290606]
    δzδlev = [δzδlev_f([tt, lonv, latv, levv, itp_ph, itp_phb]) for levv in [1, 1.5, 2, 21.5, 30, 31.5]]
    @test δzδlev ≈ δzδlev_want
end
