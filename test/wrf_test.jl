using Dates
using ModelingToolkit: D, t
using ModelingToolkit
using EarthSciData
using EarthSciMLBase
using DynamicQuantities
using Test


domain = DomainInfo(
    DateTime(2023, 8, 15, 0, 0, 0),
    DateTime(2023, 8, 15, 3, 0, 0);
    latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
    lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
    levrange=1:2,
    dtype=Float64
)

@testset "wrf" begin

    lon, lat, lev = EarthSciMLBase.pvars(domain)
    @constants c_unit = 6.0 [unit = u"rad" description = "constant to make units cancel out"]

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    coord_defaults = Dict(
        :lon => lonv,
        :lat => latv,
        :lev => levv,
        :time => tt
    )

    wrf_sys, params = WRF(
        "CONUS",
        DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange=1:2,
            dtype=Float64
        );
        name=:WRF,
        stream=true,
        coord_defaults=coord_defaults
    )

    domain2 = EarthSciMLBase.add_partial_derivative_func(domain,
        partialderivatives_δlevδz(wrf_sys))

    struct ExampleCoupler
        sys
    end

    function Example()
        @variables c(t) [unit = u"mol/m^3"]
        eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
        return ODESystem(eqs, t; name=:ExampleSys, metadata=Dict(:coupletype => ExampleCoupler))
    end

    function EarthSciMLBase.couple2(e::ExampleCoupler, w::WRFCoupler)
        e, w = e.sys, w.sys
        e = EarthSciMLBase.param_to_var(e, :lat, :lon)
        ConnectorSystem([
            e.lat ~ w.lat,
            e.lon ~ w.lon,
        ], e, w)
    end

    examplesys = Example()

    composed_sys = couple(examplesys, domain2, Advection(), wrf_sys)
    pde_sys = convert(PDESystem, composed_sys)

    eqs = equations(pde_sys)

    want_terms = [
        "MeanWind₊v_lon(t, lon, lat, lev)", "WRF₊hourly₊U(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)", "WRF₊hourly₊V(t, lon, lat, lev)",
        "MeanWind₊v_lev(t, lon, lat, lev)", "WRF₊hourly₊W(t, lon, lat, lev)",
        "WRF₊hourly₊U_itp(t, lon, lat, lev)", "WRF₊hourly₊V_itp(t, lon, lat, lev)",
        "WRF₊hourly₊W_itp(t, lon, lat, lev)",
        "WRF₊hourly₊T(t, lon, lat, lev)",
        "WRF₊hourly₊P(t, lon, lat, lev)", "WRF₊hourly₊PB(t, lon, lat, lev)",
        "WRF₊hourly₊PH(t, lon, lat, lev)", "WRF₊hourly₊PHB(t, lon, lat, lev)",
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

    using ModelingToolkit
    using Dates

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    coord_defaults = Dict(
        :lon => lonv,
        :lat => latv,
        :lev => levv,
        :time => tt
    )
    wrf_sys, params = WRF(
        "CONUS",
        DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange=1:2,
            dtype=Float64
        );
        name=:WRF,
        stream=true,
        coord_defaults=coord_defaults
    )

    @parameters lon [unit = u"rad"] lat [unit = u"rad"] lev [unit = u"1"]

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "P_total(t)", equations(wrf_sys))
    ptotal_eq = equations(wrf_sys)[iipt]

    ptotal_sub = ModelingToolkit.subs_constants(ptotal_eq.rhs)

    vars_in_expr = get_variables(ptotal_sub)
    P_itp = vars_in_expr[findfirst(isequal(:hourly₊P_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    PB_itp = vars_in_expr[findfirst(isequal(:hourly₊PB_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    P_expr = build_function(ptotal_sub, [t, lon, lat, lev, P_itp, PB_itp])
    myf = eval(P_expr)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    event_p  = only(events[[only(e.affects.pars_syms) == :hourly₊P_itp  for e in events]])
    event_pb = only(events[[only(e.affects.pars_syms) == :hourly₊PB_itp for e in events]])

    Main.EarthSciData.lazyload!(event_p.affects.ctx, tt)
    EarthSciData.lazyload!(event_pb.affects.ctx, tt)

    itp_p = ITPWrapper_w(event_p.affects.ctx)
    itp_pb = ITPWrapper_w(event_pb.affects.ctx)

    P_total = [
        myf([tt, lonv, latv, levv, itp_p(tt, lonv, latv, levv), itp_pb(tt, lonv, latv, levv)])
        for levv in [1, 1.5, 2, 21.5, 30, 31.5]
    ]
    println("P_total: ", P_total)
end

@testset "wrf total pressures at fractional-hour timestamps (minutes/seconds)" begin

    using ModelingToolkit
    using Dates

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 25, 36)

    coord_defaults = Dict(
        :lon => lonv,
        :lat => latv,
        :lev => levv,
        :time => tt
    )
    wrf_sys, params = WRF(
        "CONUS",
        DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange=1:2,
            dtype=Float64
        );
        name=:WRF,
        stream=true,
        coord_defaults=coord_defaults
    )

    @parameters lon [unit = u"rad"] lat [unit = u"rad"] lev [unit = u"1"]

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "P_total(t)", equations(wrf_sys))
    ptotal_eq = equations(wrf_sys)[iipt]

    ptotal_sub = ModelingToolkit.subs_constants(ptotal_eq.rhs)

    vars_in_expr = get_variables(ptotal_sub)
    P_itp = vars_in_expr[findfirst(isequal(:hourly₊P_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    PB_itp = vars_in_expr[findfirst(isequal(:hourly₊PB_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    P_expr = build_function(ptotal_sub, [t, lon, lat, lev, P_itp, PB_itp])
    myf = eval(P_expr)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    event_p  = only(events[[only(e.affects.pars_syms) == :hourly₊P_itp  for e in events]])
    event_pb = only(events[[only(e.affects.pars_syms) == :hourly₊PB_itp for e in events]])

    Main.EarthSciData.lazyload!(event_p.affects.ctx, tt)
    EarthSciData.lazyload!(event_pb.affects.ctx, tt)

    itp_p = ITPWrapper_w(event_p.affects.ctx)
    itp_pb = ITPWrapper_w(event_pb.affects.ctx)

    P_total = [
        myf([tt, lonv, latv, levv, itp_p(tt, lonv, latv, levv), itp_pb(tt, lonv, latv, levv)])
        for levv in [1, 1.5, 2, 21.5, 30, 31.5]
    ]
    println("P_total: ", P_total)
end


@testset "wrf δlevδz" begin

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2023, 8, 15, 0, 0, 0)

    coord_defaults = Dict(
        :lon => lonv,
        :lat => latv,
        :lev => levv,
        :time => tt
    )

    @parameters lat, [unit = u"rad"], lon, [unit = u"rad"], lev

    wrf_sys, params = WRF(
        "CONUS",
        DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange=1:2,
            dtype=Float64
        );
        name=:WRF,
        stream=true,
        coord_defaults=coord_defaults
    )

    wrf_sys.metadata[:coord_defaults][:time] = tt
    wrf_sys.metadata[:coord_defaults][:lon]  = lonv
    wrf_sys.metadata[:coord_defaults][:lat]  = latv
    wrf_sys.metadata[:coord_defaults][:lev]  = lev

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    e_ph  = only(events[[only(e.affects.pars_syms) == :hourly₊PH_itp  for e in events]])
    e_phb = only(events[[only(e.affects.pars_syms) == :hourly₊PHB_itp for e in events]])

    Main.EarthSciData.lazyload!(e_ph.affects.ctx, tt)
    Main.EarthSciData.lazyload!(e_phb.affects.ctx, tt)

    itp_ph = ITPWrapper_w(e_ph.affects.ctx)
    itp_phb = ITPWrapper_w(e_phb.affects.ctx)

    dp = partialderivatives_δlevδz(wrf_sys)

    ff = dp([lon, lat, lev])

    fff = ModelingToolkit.subs_constants(ff[3])

    vars_in_expr = get_variables(fff)
    ph_itp = vars_in_expr[findfirst(isequal(:hourly₊PH_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    phb_itp = vars_in_expr[findfirst(isequal(:hourly₊PHB_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    f_expr = build_function(fff, [t, lon, lat, lev, ph_itp, phb_itp])
    myf = eval(f_expr)
    δlevδz = [myf([tt, lonv, latv, levv, itp_ph, itp_phb]) for levv in [1, 1.5, 2, 21.5, 30, 31.5]]
    println("δlevδz: ", δlevδz)

end


@testset "wrf wrong year" begin

    using ModelingToolkit
    using Dates

    lonv = deg2rad(-118.2707)
    latv = deg2rad(34.0059)
    levv = 1.0
    tt = DateTime(2022, 8, 15, 0, 0, 0)

    coord_defaults = Dict(
        :lon => lonv,
        :lat => latv,
        :lev => levv,
        :time => tt
    )
    wrf_sys, params = WRF(
        "CONUS",
        DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange=deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange=deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange=1:2,
            dtype=Float64
        );
        name=:WRF,
        stream=true,
        coord_defaults=coord_defaults
    )

    @parameters lon [unit = u"rad"] lat [unit = u"rad"] lev [unit = u"1"]

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "P_total(t)", equations(wrf_sys))
    ptotal_eq = equations(wrf_sys)[iipt]

    ptotal_sub = ModelingToolkit.subs_constants(ptotal_eq.rhs)

    vars_in_expr = get_variables(ptotal_sub)
    P_itp = vars_in_expr[findfirst(isequal(:hourly₊P_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    PB_itp = vars_in_expr[findfirst(isequal(:hourly₊PB_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    P_expr = build_function(ptotal_sub, [t, lon, lat, lev, P_itp, PB_itp])
    myf = eval(P_expr)

    events = ModelingToolkit.get_discrete_events(wrf_sys)
    event_p  = only(events[[only(e.affects.pars_syms) == :hourly₊P_itp  for e in events]])
    event_pb = only(events[[only(e.affects.pars_syms) == :hourly₊PB_itp for e in events]])

    Main.EarthSciData.lazyload!(event_p.affects.ctx, tt)
    EarthSciData.lazyload!(event_pb.affects.ctx, tt)

    itp_p = ITPWrapper_w(event_p.affects.ctx)
    itp_pb = ITPWrapper_w(event_pb.affects.ctx)

    P_total = [
        myf([tt, lonv, latv, levv, itp_p(tt, lonv, latv, levv), itp_pb(tt, lonv, latv, levv)])
        for levv in [1, 1.5, 2, 21.5, 30, 31.5]
    ]
    println("P_total: ", P_total)
end
