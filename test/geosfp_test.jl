@testsnippet GEOSFPDomainSetup begin
    using EarthSciMLBase
    using Dates
    using ModelingToolkit

    domain = DomainInfo(
        DateTime(2022, 1, 1),
        DateTime(2022, 1, 3);
        latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
        lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
        levrange = 1:73
    )
end

@testitem "GEOS-FP" setup=[GEOSFPDomainSetup] begin
    using ModelingToolkit: t, D
    using DynamicQuantities

    geosfp = GEOSFP("4x5", domain)

    @test all([x in Symbol.(parameters(geosfp)) for x in [:lon, :lat, :lev]])

    domain2 = EarthSciMLBase.add_partial_derivative_func(
        domain,
        partialderivatives_δPδlev_geosfp(geosfp)
    )

    struct ExampleCoupler
        sys::Any
    end

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
        "GEOSFP₊A3dyn₊U_itp(GEOSFP₊t_ref + t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊OMEGA(t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊OMEGA_itp(GEOSFP₊t_ref + t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊V(t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊V_itp(GEOSFP₊t_ref + t, lon, lat, lev)",
        "Differential(t)(ExampleSys₊c(t, lon, lat, lev))",
        "Differential(lon)(ExampleSys₊c(t, lon, lat, lev)",
        "MeanWind₊v_lon(t, lon, lat, lev)",
        "lon2m",
        "Differential(lat)(ExampleSys₊c(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)",
        "lat2meters",
        "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
        "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
        "ExampleSys₊c(t, lon, lat, lev)",
        "t",
        "Differential(lev)(ExampleSys₊c(t, lon, lat, lev))",
        "MeanWind₊v_lev(t, lon, lat, lev)",
        "P_unit"
    ]
    have_eqs = string.(eqs)
    have_eqs = replace.(have_eqs, ("Main." => "",))
    for term in want_terms
        @test any(occursin.((term,), have_eqs))
    end
end

@testitem "GEOS-FP pressure levels" setup=[GEOSFPDomainSetup] begin
    using SymbolicIndexingInterface: setp, getsym, parameter_values

    geosfp = mtkcompile(GEOSFP("4x5", domain))
    prob = ODEProblem(geosfp, [], (24.0 * 3600, 48.0 * 3600))
    f = getsym(prob, geosfp.P)
    setter = setp(geosfp, [geosfp.lon, geosfp.lat, geosfp.lev])
    ps = parameter_values(prob)

    p_levels = map([1, 1.5, 2, 72, 72.5, 73]) do lev
        setter(prob, [deg2rad(-155.7), deg2rad(39.1), lev])
        f(prob)
    end
    @test p_levels ≈
          [102340.37924047427, 101572.77264006894, 100805.16603966363, 2.0, 1.5, 1.0]
end

@testitem "GEOS-FP new day" setup=[GEOSFPDomainSetup] begin
    using DynamicQuantities
    @parameters(lon=0.0, [unit=u"rad"], lat=0.0, [unit=u"rad"], lev=1.0,)
    @parameters t_ref=0 [unit=u"s"]
    starttime = datetime2unix(DateTime(2022, 1, 1, 23, 58))
    endtime = datetime2unix(DateTime(2022, 1, 2, 0, 3))

    geosfp = GEOSFP("4x5", domain)

    eqs = equations(geosfp)
    idx(sym) = findfirst(x -> x == sym,
        [Symbolics.tosymbol(e.lhs, escape=false) for e in eqs])

    iT       = idx(:I3₊T)
    iQV      = idx(:I3₊QV)
    iT2M     = idx(:A1₊T2M)
    iQV2M    = idx(:A1₊QV2M)
    iPS      = idx(:I3₊PS)
    iTv      = idx(:Tv)
    iTv_sfc  = idx(:Tv_sfc)
    iTvbar   = idx(:Tv̄)
    iZ       = idx(:Z_agl)
    iP       = idx(:P)

    T_eq      = eqs[iT]
    QV_eq     = eqs[iQV]
    T2M_eq    = eqs[iT2M]
    QV2M_eq   = eqs[iQV2M]
    PS_eq     = eqs[iPS]
    Tv_eq     = eqs[iTv]
    Tv_sfc_eq = eqs[iTv_sfc]
    Tvbar_eq  = eqs[iTvbar]
    Z_eq      = eqs[iZ]

    P_eq = substitute(eqs[iP], PS_eq.lhs => PS_eq.rhs)

    dflts = ModelingToolkit.get_defaults(geosfp)
    psitp = collect(keys(dflts))[findfirst(isequal(:I3₊PS_itp),
        EarthSciMLBase.var2symbol.(keys(dflts)))]
    ps_itp = dflts[psitp]
    EarthSciData.lazyload!(ps_itp.itp, DateTime(2022, 1, 1, 23, 58))

    PS_expr = build_function(pseq.rhs, t, t_ref, lon, lat, lev, psitp)
    psf = eval(PS_expr)
    psf(starttime, 0.0, 0.0, 0.0, 1.0, ps_itp)
end

@testitem "GEOS-FP wrong month" setup=[GEOSFPDomainSetup] begin
    using SymbolicIndexingInterface: getsym
    geosfp = mtkcompile(GEOSFP("4x5", domain))
    tspan = datetime2unix.((DateTime(2022, 5, 1), DateTime(2022, 5, 2))) .-
            get_tref(domain)
    prob = ODEProblem(geosfp, [], tspan)
    f = getsym(prob, geosfp.I3₊PS)
    @test_throws Base.Exception f(prob)
end

@testitem "GEOS-FP height above ground" setup=[GEOSFPDomainSetup] begin
    using DynamicQuantities
    tt = datetime2unix(DateTime(2022, 1, 2))
    @parameters lat, [unit = u"rad"], lon, [unit = u"rad"], lev
    @parameters t_ref=0 [unit=u"s"]
    geosfp = GEOSFP("4x5", domain)

    eqs = equations(geosfp)
    idx(sym) = findfirst(x -> x == sym,
        [Symbolics.tosymbol(e.lhs, escape=false) for e in eqs])

    iT       = idx(:I3₊T)
    iQV      = idx(:I3₊QV)
    iT2M     = idx(:A1₊T2M)
    iQV2M    = idx(:A1₊QV2M)
    iPS      = idx(:I3₊PS)
    iTv      = idx(:Tv)
    iTv_sfc  = idx(:Tv_sfc)
    iTvbar   = idx(:Tv̄)
    iZ       = idx(:Z_agl)
    iP       = idx(:P)

    T_eq      = eqs[iT]
    QV_eq     = eqs[iQV]
    T2M_eq    = eqs[iT2M]
    QV2M_eq   = eqs[iQV2M]
    PS_eq     = eqs[iPS]
    Tv_eq     = eqs[iTv]
    Tv_sfc_eq = eqs[iTv_sfc]
    Tvbar_eq  = eqs[iTvbar]
    Z_eq      = eqs[iZ]

    P_eq = substitute(eqs[iP], PS_eq.lhs => PS_eq.rhs)

    dflts = ModelingToolkit.get_defaults(geosfp)

    function load_itp(symname)
        key = collect(keys(dflts))[findfirst(isequal(symname),
            EarthSciMLBase.var2symbol.(keys(dflts)))]
        itpvar = dflts[key]
        EarthSciData.lazyload!(itpvar.itp, tt)
        return key, itpvar
    end

    PSitp,   PS_itp   = load_itp(:I3₊PS_itp)
    Titp,    T_itp    = load_itp(:I3₊T_itp)
    T2Mitp,  T2M_itp  = load_itp(:A1₊T2M_itp)
    QVitp,   QV_itp   = load_itp(:I3₊QV_itp)
    QV2Mitp, QV2M_itp = load_itp(:A1₊QV2M_itp)

    Z_rhs = Z_eq.rhs
    Z_rhs = ModelingToolkit.substitute(Z_rhs, Tvbar_eq.lhs => Tvbar_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, Tv_eq.lhs => Tv_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, Tv_sfc_eq.lhs => Tv_sfc_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, T_eq.lhs    => T_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, QV_eq.lhs   => QV_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, T2M_eq.lhs  => T2M_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, QV2M_eq.lhs => QV2M_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, P_eq.lhs => P_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, PS_eq.lhs => PS_eq.rhs)

    Z_rhs = ModelingToolkit.subs_constants(Z_rhs)

    Z_expr = build_function(Z_rhs, [t, t_ref, lon, lat, lev, Titp, QVitp, T2Mitp, QV2Mitp, PSitp])

    Z_f = eval(Z_expr)

    lonv = deg2rad(-155.7)
    latv = deg2rad(39.1)
    Z_above_ground = [Z_f([tt, 0.0, lonv, latv, lev, T_itp, QV_itp, T2M_itp, QV2M_itp, PS_itp])
                for lev in [1, 1.5, 2, 72, 72.5]]
    @test Z_above_ground ≈
          [63.38451747881698, 127.11513708190306, 191.83774317607677, 77316.16731665366, 80132.63935650676]
end
@testitem "GEOS-FP height above ground" setup=[GEOSFPDomainSetup] begin
    tt = datetime2unix(DateTime(2022, 1, 2))
    @parameters lat, [unit = u"rad"], lon, [unit = u"rad"], lev
    @parameters t_ref=0 [unit=u"s"]
    geosfp = GEOSFP("4x5", domain)

    eqs = equations(geosfp)
    idx(sym) = findfirst(x -> x == sym,
        [Symbolics.tosymbol(e.lhs, escape=false) for e in eqs])

    iT       = idx(:I3₊T)
    iQV      = idx(:I3₊QV)
    iT2M     = idx(:A1₊T2M)
    iQV2M    = idx(:A1₊QV2M)
    iPS      = idx(:I3₊PS)
    iTv      = idx(:Tv)
    iTv_sfc  = idx(:Tv_sfc)
    iTvbar   = idx(:Tv̄)
    iZ       = idx(:Z_agl)
    iP       = idx(:P)

    T_eq      = eqs[iT]
    QV_eq     = eqs[iQV]
    T2M_eq    = eqs[iT2M]
    QV2M_eq   = eqs[iQV2M]
    PS_eq     = eqs[iPS]
    Tv_eq     = eqs[iTv]
    Tv_sfc_eq = eqs[iTv_sfc]
    Tvbar_eq  = eqs[iTvbar]
    Z_eq      = eqs[iZ]

    P_eq = substitute(eqs[iP], PS_eq.lhs => PS_eq.rhs)

    dflts = ModelingToolkit.get_defaults(geosfp)

    function load_itp(symname)
        key = collect(keys(dflts))[findfirst(isequal(symname),
            EarthSciMLBase.var2symbol.(keys(dflts)))]
        itpvar = dflts[key]
        EarthSciData.lazyload!(itpvar.itp, tt)
        return key, itpvar
    end

    PSitp,   PS_itp   = load_itp(:I3₊PS_itp)
    Titp,    T_itp    = load_itp(:I3₊T_itp)
    T2Mitp,  T2M_itp  = load_itp(:A1₊T2M_itp)
    QVitp,   QV_itp   = load_itp(:I3₊QV_itp)
    QV2Mitp, QV2M_itp = load_itp(:A1₊QV2M_itp)

    Z_rhs = Z_eq.rhs
    Z_rhs = ModelingToolkit.substitute(Z_rhs, Tvbar_eq.lhs => Tvbar_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, Tv_eq.lhs => Tv_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, Tv_sfc_eq.lhs => Tv_sfc_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, T_eq.lhs    => T_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, QV_eq.lhs   => QV_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, T2M_eq.lhs  => T2M_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, QV2M_eq.lhs => QV2M_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, P_eq.lhs => P_eq.rhs)
    Z_rhs = ModelingToolkit.substitute(Z_rhs, PS_eq.lhs => PS_eq.rhs)

    Z_rhs = ModelingToolkit.subs_constants(Z_rhs)

    Z_expr = build_function(Z_rhs, [t, t_ref, lon, lat, lev, Titp, QVitp, T2Mitp, QV2Mitp, PSitp])

    Z_f = eval(Z_expr)

    lonv = deg2rad(-155.7)
    latv = deg2rad(39.1)
    Z_above_ground = [Z_f([tt, 0.0, lonv, latv, lev, T_itp, QV_itp, T2M_itp, QV2M_itp, PS_itp])
                for lev in [1, 1.5, 2, 72, 72.5]]
    @test Z_above_ground ≈
    [63.38451747881698, 127.11513708190306, 191.83774317607677, 77316.16731665366, 80132.63935650676]
end
