using EarthSciData
using EarthSciMLBase
using Dates
using ModelingToolkit, DomainSets
using Unitful

@testset "GEOS-FP" begin
    @parameters t [unit = u"s"]
    @parameters lev
    @parameters lon [unit = u"rad"]
    @parameters lat [unit = u"rad"]
    @constants c_unit = 180 / π / 6 [unit = u"rad" description = "constant to make units cancel out"]
    geosfp = GEOSFP("4x5", t; dtype=Float64)

    function Example(t)
        @variables c(t) = 5.0 [unit = u"mol/m^3"]
        D = Differential(t)
        ODESystem([D(c) ~ (sin(lat / c_unit) + sin(lon / c_unit)) * c / t], t, name=:Test₊ExampleSys)
    end
    examplesys = Example(t)

    deg2rad(x) = x * π / 180.0
    domain = DomainInfo(
        [
            partialderivatives_δxyδlonlat,
            partialderivatives_δPδlev_geosfp(geosfp),
        ],
        constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),
        zerogradBC(lat ∈ Interval(deg2rad(-85.0f0), deg2rad(85.0f0))),
        periodicBC(lon ∈ Interval(deg2rad(-180.0f0), deg2rad(175.0f0))),
        zerogradBC(lev ∈ Interval(1.0f0, 10.0f0)),
    )

    composed_sys = couple(examplesys, domain, Advection(), geosfp)
    pde_sys = get_mtk(composed_sys)

    eqs = equations(pde_sys)

    want_terms = [
        "EarthSciMLBase₊MeanWind₊v_lon(t, lat, lon, lev)", "GEOSFP₊A3dyn₊U(t, lat, lon, lev)",
        "EarthSciMLBase₊MeanWind₊v_lat(t, lat, lon, lev)", "GEOSFP₊A3dyn₊V(t, lat, lon, lev)",
        "EarthSciMLBase₊MeanWind₊v_lev(t, lat, lon, lev)", "GEOSFP₊A3dyn₊OMEGA(t, lat, lon, lev)",
        "EarthSciData₊GEOSFP₊A3dyn₊U(t, lat, lon, lev)", "EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, U}, t, lon, lat, lev)",
        "EarthSciData₊GEOSFP₊A3dyn₊OMEGA(t, lat, lon, lev)", "EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, OMEGA}, t, lon, lat, lev)",
        "EarthSciData₊GEOSFP₊A3dyn₊V(t, lat, lon, lev)", "EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, V}, t, lon, lat, lev)",
        "Differential(t)(Test₊ExampleSys₊c(t, lat, lon, lev))", "(-Differential(lon)(Test₊ExampleSys₊c(t, lat, lon, lev))",
        "EarthSciMLBase₊MeanWind₊v_lon(t, lat, lon, lev)) / (lon2m*cos(lat))",
        "(-Differential(lat)(Test₊ExampleSys₊c(t, lat, lon, lev))",
        "EarthSciMLBase₊MeanWind₊v_lat(t, lat, lon, lev)) / lat2meters",
        "sin(lat / Test₊ExampleSys₊c_unit)", "sin(lon / Test₊ExampleSys₊c_unit)",
        "Test₊ExampleSys₊c(t, lat, lon, lev)", "t",
        "Differential(lev)(Test₊ExampleSys₊c(t, lat, lon, lev))",
        "EarthSciMLBase₊MeanWind₊v_lev(t, lat, lon, lev)", "P_unit", "Pa_per_hPa",
    ]
    have_eqs = string.(eqs)
    for term ∈ want_terms
        @test any(occursin.((term,), have_eqs))
    end
end

@testset "GEOS-FP pressure levels" begin
    @parameters t [unit = u"s"]
    @parameters lat lon lev
    geosfp = GEOSFP("4x5", t; dtype=Float64,
        coord_defaults=Dict(:lev => 1.0, :lat => 39.1, :lon => -155.7))

    # Rearrange pressure equation so it can be evaluated for P.
    iips = findfirst((x) -> x == :I3₊PS, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    iip = findfirst((x) -> x == :P, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    pseq = equations(geosfp)[iips]
    peq = substitute(equations(geosfp)[iip], pseq.lhs => pseq.rhs)

    # Check Pressure levels
    P = ModelingToolkit.subs_constants(peq.rhs)
    P_expr = build_function(P, [t, lon, lat, lev])
    mypf = eval(P_expr)
    p_levels = [mypf([DateTime(2022, 5, 1), -155.7, 39.1, lev]) for lev in [1, 1.5, 2, 72, 72.5, 73]]
    @test p_levels ≈ [1021.6242118225098, 1013.9615353827572, 1006.2988589430047, 0.02, 0.015, 0.01]


    dp = partialderivatives_δPδlev_geosfp(geosfp)

    # Check level coordinate index
    ff = dp([lat, lon, lev])
    @test all(keys(ff) .=== [3])

    fff = ModelingToolkit.subs_constants(ff[3])

    # Check δP at different levels
    f_expr = build_function(fff, [t, lon, lat, lev])
    myf = eval(f_expr)
    δP_levels = [myf([DateTime(2022, 5, 1), -155.7, 39.1, lev]) for lev in [1, 1.5, 2, 71.5, 72, 72.5]]
    @test 1.0 ./ δP_levels ≈ [-15.32535287950509, -15.325352879504862, -15.466211527927955,
        -0.012699999999999994, -0.010000000000000002, -0.009999999999999998] .* 100.0
end

@testset "GEOS-FP new day" begin
    @parameters lon = 0.0 lat = 0.0 lev = 1.0 t
    starttime = datetime2unix(DateTime(2022, 5, 1, 23, 58))
    endtime = datetime2unix(DateTime(2022, 5, 2, 0, 3))

    geosfp = GEOSFP("4x5", t; dtype=Float64,
        coord_defaults=Dict(:lon => 0.0, :lat => 0.0, :lev => 1.0))

    iips = findfirst((x) -> x == :I3₊PS, [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(geosfp)])
    pseq = equations(geosfp)[iips]
    PS_expr = build_function(pseq.rhs, t, lon, lat, lev)
    psf = eval(PS_expr)
    psf(starttime, 0.0, 0.0, 1.0)
end