using EarthSciData
using EarthSciMLBase
using Test
using Dates
using ModelingToolkit
using ModelingToolkit: t, D
using DynamicQuantities
import NCDatasets

domain = DomainInfo(DateTime(2022, 1, 1), DateTime(2022, 1, 3);
    latrange=deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
    lonrange=deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
    levrange=1:10, dtype=Float64)

@testset "GEOS-FP" begin
    lon, lat, lev = EarthSciMLBase.pvars(domain)
    @constants c_unit = 6.0 [unit = u"rad" description = "constant to make units cancel out"]
    geosfp = GEOSFP("4x5", domain)

    @test Symbol.(parameters(geosfp)) == [:lon, :lat, :lev]

    domain2 = EarthSciMLBase.add_partial_derivative_func(domain,
        partialderivatives_δPδlev_geosfp(geosfp))

    function Example()
        @variables c(t) = 5.0 [unit = u"mol/m^3"]
        ODESystem([D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t], t, name=:ExampleSys)
    end
    examplesys = Example()

    composed_sys = couple(examplesys, domain2, Advection(), geosfp)
    pde_sys = convert(PDESystem, composed_sys)

    eqs = equations(pde_sys)

    want_terms = [
        "MeanWind₊v_lon(t, lon, lat, lev)", "GEOSFP₊A3dyn₊U(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)", "GEOSFP₊A3dyn₊V(t, lon, lat, lev)",
        "MeanWind₊v_lev(t, lon, lat, lev)", "GEOSFP₊A3dyn₊OMEGA(t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊U(t, lon, lat, lev)", "EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, U}, t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊OMEGA(t, lon, lat, lev)", "EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, OMEGA}, t, lon, lat, lev)",
        "GEOSFP₊A3dyn₊V(t, lon, lat, lev)", "EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, V}, t, lon, lat, lev)",
        "Differential(t)(ExampleSys₊c(t, lon, lat, lev))", "Differential(lon)(ExampleSys₊c(t, lon, lat, lev)",
        "MeanWind₊v_lon(t, lon, lat, lev)", "lon2m",
        "Differential(lat)(ExampleSys₊c(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)", "lat2meters",
        "sin(ExampleSys₊c_unit*lat)", "sin(ExampleSys₊c_unit*lon)",
        "ExampleSys₊c(t, lon, lat, lev)", "t",
        "Differential(lev)(ExampleSys₊c(t, lon, lat, lev))",
        "MeanWind₊v_lev(t, lon, lat, lev)", "P_unit",
    ]
    have_eqs = string.(eqs)
    have_eqs = replace.(have_eqs, ("Main." => "",))
    for term ∈ want_terms
        @test any(occursin.((term,), have_eqs))
    end
end

@testset "GEOS-FP pressure levels" begin
    @parameters lat, [unit = u"rad"], lon, [unit = u"rad"], lev
    geosfp = GEOSFP("4x5", domain)

    # Rearrange pressure equation so it can be evaluated for P.
    iips = findfirst((x) -> x == :I3₊PS, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    iip = findfirst((x) -> x == :P, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    pseq = equations(geosfp)[iips]
    peq = substitute(equations(geosfp)[iip], pseq.lhs => pseq.rhs)

    # Check Pressure levels
    P = ModelingToolkit.subs_constants(peq.rhs)
    P_expr = build_function(P, [t, lon, lat, lev])
    mypf = eval(P_expr)
    p_levels = [mypf([DateTime(2022, 5, 1), deg2rad(-155.7), deg2rad(39.1), lev]) for lev in [1, 1.5, 2, 72, 72.5, 73]]
    @test p_levels ≈ [1021.6242118225098, 1013.9615353827572, 1006.2988589430047, 0.02, 0.015, 0.01] .* 100


    dp = partialderivatives_δPδlev_geosfp(geosfp)

    # Check level coordinate index
    ff = dp([lon, lat, lev])
    @test all(keys(ff) .=== [3])

    fff = ModelingToolkit.subs_constants(ff[3])

    # Check δP at different levels
    f_expr = build_function(fff, [t, lon, lat, lev])
    myf = eval(f_expr)
    δP_levels = [myf([DateTime(2022, 5, 1), deg2rad(-155.7), deg2rad(39.1), lev]) for lev in [1, 1.5, 2, 71.5, 72, 72.5]]
    @test 1.0 ./ δP_levels ≈ [-15.32535287950509, -15.325352879504862, -15.466211527927955,
        -0.012699999999999994, -0.010000000000000002, -0.009999999999999998] .* 100.0
end

@testset "GEOS-FP new day" begin
    @parameters(
        lon = 0.0, [unit = u"rad"],
        lat = 0.0, [unit = u"rad"],
        lev = 1.0,
    )
    starttime = datetime2unix(DateTime(2022, 5, 1, 23, 58))
    endtime = datetime2unix(DateTime(2022, 5, 2, 0, 3))

    geosfp = GEOSFP("4x5", domain)

    iips = findfirst((x) -> x == :I3₊PS, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    pseq = equations(geosfp)[iips]
    PS_expr = build_function(pseq.rhs, t, lon, lat, lev)
    psf = eval(PS_expr)
    psf(starttime, 0.0, 0.0, 1.0)
end

@testset "GEOS-FP wrong year" begin
    @parameters(
        lon = 0.0, [unit = u"rad"],
        lat = 0.0, [unit = u"rad"],
        lev = 1.0,
    )
    starttime = datetime2unix(DateTime(5000, 1, 1))

    geosfp = GEOSFP("4x5", domain)

    iips = findfirst((x) -> x == :I3₊PS, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    pseq = equations(geosfp)[iips]
    PS_expr = build_function(pseq.rhs, t, lon, lat, lev)
    psf = eval(PS_expr)
    @test_throws Base.Exception psf(starttime, 0.0, 0.0, 1.0)
end
