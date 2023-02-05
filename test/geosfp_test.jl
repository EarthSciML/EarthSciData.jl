using EarthSciData
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
        constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),
        zerogradBC(lat ∈ Interval(-85.0f0, 85.0f0)),
        periodicBC(lon ∈ Interval(-180.0f0, 175.0f0)),
        zerogradBC(lev ∈ Interval(1.0f0, 10.0f0)),
    )

    composed_sys = examplesys + domain + Advection() + geosfp
    pde_sys = get_mtk(composed_sys)

    eqs = equations(pde_sys)

    want_eqs = [
        "meanwind₊u(t, lat, lon, lev) ~ GEOSFP₊A3dyn₊U(t, lat, lon, lev)"
        "meanwind₊v(t, lat, lon, lev) ~ GEOSFP₊A3dyn₊V(t, lat, lon, lev)"
        "meanwind₊w(t, lat, lon, lev) ~ GEOSFP₊A3dyn₊OMEGA(t, lat, lon, lev)"
        "GEOSFP₊A3dyn₊U(t, lat, lon, lev) ~ EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, U}, t, lon, lat, lev)"
        "GEOSFP₊A3dyn₊OMEGA(t, lat, lon, lev) ~ EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, OMEGA}, t, lon, lat, lev)"
        "GEOSFP₊A3dyn₊V(t, lat, lon, lev) ~ EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, V}, t, lon, lat, lev)"
        "Differential(t)(examplesys₊c(t, lat, lon, lev)) ~ (-Differential(lon)(examplesys₊c(t, lat, lon, lev))*meanwind₊v(t, lat, lon, lev)) / (111319.44444444445cos(0.017453292519943295lat)) + sin(0.10471975511965978lat) + sin(0.10471975511965978lon) - 8.98311174991017e-6Differential(lat)(examplesys₊c(t, lat, lon, lev))*meanwind₊u(t, lat, lon, lev) - Differential(lev)(examplesys₊c(t, lat, lon, lev))*meanwind₊w(t, lat, lon, lev)"
    ]

    @test string.(eqs) == want_eqs
end
