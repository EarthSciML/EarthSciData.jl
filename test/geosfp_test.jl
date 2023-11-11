using EarthSciData
using EarthSciMLBase
using Dates
using ModelingToolkit, DomainSets
using Unitful

@testset "GEOS-FP" begin
    @parameters t [unit = u"s"]
    @parameters lev [unit = u"Pa"]
    @parameters lon [unit = u"m"]
    @parameters lat [unit = u"m"]
    @constants c_unit = 180 / π / 6 [unit = u"m" description = "constant to make units cancel out"]
    geosfp = GEOSFP("4x5", t)

    struct Example <: EarthSciMLODESystem
        sys
        function Example(t; name)
            @variables c(t) = 5.0 [unit = u"mol/m^3"]
            D = Differential(t)
            new(ODESystem([D(c) ~ (sin(lat / c_unit) + sin(lon / c_unit)) * c / t], t, name=name))
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
        "meanwind₊v_lon(t, lat, lon, lev) ~ GEOSFP₊A3dyn₊U(t, lat, lon, lev)", 
        "meanwind₊v_lat(t, lat, lon, lev) ~ GEOSFP₊A3dyn₊V(t, lat, lon, lev)", 
        "meanwind₊v_lev(t, lat, lon, lev) ~ GEOSFP₊A3dyn₊OMEGA(t, lat, lon, lev)", 
        "GEOSFP₊A3dyn₊U(t, lat, lon, lev) ~ EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, U}, t, lon, lat, lev)", 
        "GEOSFP₊A3dyn₊OMEGA(t, lat, lon, lev) ~ EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, OMEGA}, t, lon, lat, lev)", 
        "GEOSFP₊A3dyn₊V(t, lat, lon, lev) ~ EarthSciData.interp!(DataSetInterpolator{EarthSciData.GEOSFPFileSet, V}, t, lon, lat, lev)", 
        "Differential(t)(examplesys₊c(t, lat, lon, lev)) ~ (-Differential(lon)(examplesys₊c(t, lat, lon, lev))*meanwind₊v_lon(t, lat, lon, lev)) / (lon2m*cos(lat)) + (-Differential(lat)(examplesys₊c(t, lat, lon, lev))*meanwind₊v_lat(t, lat, lon, lev)) / lat2meters + ((sin(lat / examplesys₊c_unit) + sin(lon / examplesys₊c_unit))*examplesys₊c(t, lat, lon, lev)) / t - Differential(lev)(examplesys₊c(t, lat, lon, lev))*meanwind₊v_lev(t, lat, lon, lev)",
    ]
    @test string.(eqs) == want_eqs
end