using EarthSciData
using EarthSciMLBase
using Test
using Dates
using ModelingToolkit
using ModelingToolkit: t, D
using DynamicQuantities
import NCDatasets

domain = DomainInfo(
    DateTime(2022, 1, 1),
    DateTime(2022, 1, 3);
    latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
    lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
    levrange = 1:10
)

@testset "GEOS-FP" begin
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    @constants c_unit = 6.0 [unit = u"rad" description = "constant to make units cancel out"]
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
        @variables c(t) = 5.0 [unit = u"mol/m^3"]
        ODESystem(
            [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t],
            t,
            name = :ExampleSys,
            metadata = Dict(:coupletype => ExampleCoupler)
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
        "GEOSFP₊A3dyn₊U_itp(t + t_ref, lon, lat, lev)",
        "GEOSFP₊A3dyn₊OMEGA(t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊OMEGA_itp(t + t_ref, lon, lat, lev)",
        "GEOSFP₊A3dyn₊V(t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊V_itp(t + t_ref, lon, lat, lev)",
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

@testset "GEOS-FP pressure levels" begin
    tt = datetime2unix(DateTime(2022, 1, 2))
    @parameters lat, [unit = u"rad"], lon, [unit = u"rad"], lev
    @parameters t_ref=0 [unit=u"s"]
    geosfp = GEOSFP("4x5", domain)

    # Rearrange pressure equation so it can be evaluated for P.
    iips = findfirst(
        (x) -> x == :I3₊PS,
        [Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(geosfp)]
    )
    iip = findfirst(
        (x) -> x == :P,
        [Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(geosfp)]
    )
    pseq = equations(geosfp)[iips]
    peq = substitute(equations(geosfp)[iip], pseq.lhs => pseq.rhs)

    dflts = ModelingToolkit.get_defaults(geosfp)
    psitp = collect(keys(dflts))[findfirst(isequal(:I3₊PS_itp),
        EarthSciMLBase.var2symbol.(keys(dflts)))]
    ps_itp = dflts[psitp]
    EarthSciData.lazyload!(ps_itp.itp, tt)

    # Check Pressure levels
    P = ModelingToolkit.subs_constants(peq.rhs)
    P_expr = build_function(P, [t, t_ref, lon, lat, lev, psitp])
    mypf = eval(P_expr)
    lonv = deg2rad(-155.7)
    latv = deg2rad(39.1)
    p_levels = [mypf([tt, 0.0, lonv, latv, lev, ps_itp])
                for lev in [1, 1.5, 2, 72, 72.5, 73]]
    @test p_levels ≈
          [102340.37924047427, 101572.77264006894, 100805.16603966363, 2.0, 1.5, 1.0]
end

@testset "GEOS-FP new day" begin
    @parameters(lon=0.0, [unit=u"rad"], lat=0.0, [unit=u"rad"], lev=1.0,)
    @parameters t_ref=0 [unit=u"s"]
    starttime = datetime2unix(DateTime(2022, 1, 1, 23, 58))
    endtime = datetime2unix(DateTime(2022, 1, 2, 0, 3))

    geosfp = GEOSFP("4x5", domain)

    iips = findfirst(
        (x) -> x == :I3₊PS,
        [Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(geosfp)]
    )
    pseq = equations(geosfp)[iips]

    dflts = ModelingToolkit.get_defaults(geosfp)
    psitp = collect(keys(dflts))[findfirst(isequal(:I3₊PS_itp),
        EarthSciMLBase.var2symbol.(keys(dflts)))]
    ps_itp = dflts[psitp]
    EarthSciData.lazyload!(ps_itp.itp, DateTime(2022, 1, 1, 23, 58))

    PS_expr = build_function(pseq.rhs, t, t_ref, lon, lat, lev, psitp)
    psf = eval(PS_expr)
    psf(starttime, 0.0, 0.0, 0.0, 1.0, ps_itp)
end

@testset "GEOS-FP wrong year" begin
    @parameters(lon=0.0, [unit=u"rad"], lat=0.0, [unit=u"rad"], lev=1.0,)
    @parameters t_ref=0 [unit=u"s"]
    starttime = datetime2unix(DateTime(2022, 5, 1))

    geosfp = GEOSFP("4x5", domain)

    iips = findfirst(
        (x) -> x == :I3₊PS,
        [Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(geosfp)]
    )
    pseq = equations(geosfp)[iips]
    PS_expr = build_function(pseq.rhs, t, t_ref, lon, lat, lev)
    psf = eval(PS_expr)
    @test_throws Base.Exception psf(starttime, 0.0, 0.0, 0.0, 1.0)
end
