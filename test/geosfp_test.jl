using EarthSciMLData
using EarthSciMLBase
using Dates
using ModelingToolkit, DomainSets

@testset "GEOS-FP" begin
    @parameters t lev lon lat
    geosfp = GEOSFP("4x5", t)

    struct Example <: EarthSciMLODESystem
        sys
        function Example(t; name)
            @variables c(t) = 5.0
            D = Differential(t)
            new(ODESystem([D(c) ~ sin(lat * π / 180.0 * 6) + sin(lon * π / 180 * 6)], t, name=name))
        end
    end
    @named examplesys = Example(t)

    domain = DomainInfo(
        partialderivatives_lonlat2xymeters,
        zerogradBC(lat ∈ Interval(-85.0f0, 85.0f0)),
        periodicBC(lon ∈ Interval(-180.0f0, 175.0f0)),
        zerogradBC(lev ∈ Interval(1.0f0, 10.0f0)),
        constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),
    )

    composed_sys = examplesys + domain + Advection() + geosfp
    pde_sys = get_mtk(composed_sys)

    eqs = equations(pde_sys)

    want_eqs = [
        "meanwind₊u(lat, lon, lev, t) ~ GEOSFP₊A3dyn₊U(lat, lon, lev, t)"
        "meanwind₊v(lat, lon, lev, t) ~ GEOSFP₊A3dyn₊V(lat, lon, lev, t)"
        "meanwind₊w(lat, lon, lev, t) ~ GEOSFP₊A3dyn₊OMEGA(lat, lon, lev, t)"
        "GEOSFP₊A3dyn₊U(lat, lon, lev, t) ~ EarthSciMLData.interp!(DataSetInterpolator{EarthSciMLData.GEOSFPFileSet, U}, t, lon, lat, lev)"
        "GEOSFP₊A3dyn₊OMEGA(lat, lon, lev, t) ~ EarthSciMLData.interp!(DataSetInterpolator{EarthSciMLData.GEOSFPFileSet, OMEGA}, t, lon, lat, lev)"
        "GEOSFP₊A3dyn₊V(lat, lon, lev, t) ~ EarthSciMLData.interp!(DataSetInterpolator{EarthSciMLData.GEOSFPFileSet, V}, t, lon, lat, lev)"
        "Differential(t)(examplesys₊c(lat, lon, lev, t)) ~ (-Differential(lon)(examplesys₊c(lat, lon, lev, t))*meanwind₊v(lat, lon, lev, t)) / (111319.44444444445cos(0.017453292519943295lat)) + sin(0.10471975511965978lat) + sin(0.10471975511965978lon) - 8.98311174991017e-6Differential(lat)(examplesys₊c(lat, lon, lev, t))*meanwind₊u(lat, lon, lev, t) - Differential(lev)(examplesys₊c(lat, lon, lev, t))*meanwind₊w(lat, lon, lev, t)"
    ]

    @test string.(eqs) == want_eqs
end
