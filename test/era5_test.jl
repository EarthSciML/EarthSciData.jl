@testsnippet ERA5Setup begin
    using EarthSciData
    using EarthSciMLBase
    using Dates
    using ModelingToolkit

    # Use pre-downloaded local test data.
    era5_mirror = "file:///tmp/era5_local_test"

    domain = DomainInfo(
        DateTime(2022, 1, 1),
        DateTime(2022, 1, 3);
        latrange = deg2rad(20.0f0):deg2rad(0.25):deg2rad(50.0f0),
        lonrange = deg2rad(-130.0f0):deg2rad(0.25):deg2rad(-60.0f0),
        levrange = 1:4,  # Corresponding to ERA5 levels: 1000, 975, 950, 925 hPa
    )
end

@testitem "ERA5 structure" setup=[ERA5Setup] begin
    using ModelingToolkit: t, D
    using DynamicQuantities

    era5 = ERA5(domain; mirror=era5_mirror)

    # Check that the system has the expected parameters.
    param_syms = Symbol.(parameters(era5))
    @test :lon in param_syms
    @test :lat in param_syms
    @test :lev in param_syms

    # Check that key variables are present (prefixed with pl₊).
    var_syms = [Symbolics.tosymbol(v, escape=false) for v in unknowns(era5)]
    @test :pl₊t in var_syms  # Temperature
    @test :pl₊u in var_syms  # U wind
    @test :pl₊v in var_syms  # V wind
    @test :pl₊w in var_syms  # Vertical velocity
    @test :pl₊q in var_syms  # Specific humidity
    @test :P in var_syms  # Pressure (derived)
    @test :δxδlon in var_syms
    @test :δyδlat in var_syms
    @test :δPδlev in var_syms
end

@testitem "ERA5 pressure levels" setup=[ERA5Setup] begin
    # Test the pressure-level mapping directly.
    # ERA5_PRESSURE_LEVELS_HPA: [1000, 975, 950, 925, ...]
    plevs = EarthSciData.ERA5_PRESSURE_LEVELS_HPA
    @test plevs[1] == 1000
    @test plevs[2] == 975
    @test plevs[3] == 950
    @test plevs[4] == 925

    # Test the interpolator: level index → hPa.
    itp = EarthSciData.era5_P_itp
    @test itp(1.0) ≈ 1000.0
    @test itp(2.0) ≈ 975.0
    @test itp(3.0) ≈ 950.0
    @test itp(4.0) ≈ 925.0
    # Midpoint interpolation.
    @test itp(1.5) ≈ 987.5

    # Verify the pressure equation is present in the system.
    era5 = ERA5(domain; mirror=era5_mirror)
    eqs = equations(era5)
    idx = findfirst(x -> Symbolics.tosymbol(x.lhs, escape=false) == :P, eqs)
    @test idx !== nothing
end

@testitem "ERA5 interpolation" setup=[ERA5Setup] begin
    using Dates
    using DynamicQuantities

    era5_fs = EarthSciData.ERA5PressureLevelFileSet(domain; mirror=era5_mirror)

    # Test metadata loading.
    md = EarthSciData.loadmetadata(era5_fs, "t")
    @test md.xdim > 0
    @test md.ydim > 0
    @test md.zdim > 0
    @test md.unit_str == "K"
    @test md.description == "Temperature"

    # Check coordinate ordering.
    @test issorted(md.coords[md.xdim])  # Longitude should be ascending.
    @test issorted(md.coords[md.ydim])  # Latitude should be ascending.

    # Test that we can create a DataSetInterpolator and load data.
    dt = EarthSciMLBase.dtype(domain)
    starttime, endtime = EarthSciMLBase.get_tspan_datetime(domain)
    itp = EarthSciData.DataSetInterpolator{dt}(
        era5_fs, "t", starttime, endtime, domain; stream=true
    )
    @test EarthSciData.units(itp) == u"K"

    # Test interpolation at a specific point.
    tt = DateTime(2022, 1, 1, 12, 0, 0)
    lonv = deg2rad(-90.0)
    latv = deg2rad(35.0)
    levv = 1.0
    val = EarthSciData.interp!(itp, tt, lonv, latv, levv)
    # Temperature should be reasonable (200-320 K at 1000 hPa).
    @test 200.0 < val < 320.0
end

@testitem "ERA5 varnames" setup=[ERA5Setup] begin
    era5_fs = EarthSciData.ERA5PressureLevelFileSet(domain; mirror=era5_mirror)
    vnames = EarthSciData.varnames(era5_fs)

    # All 16 variables should be present.
    expected = ["t", "u", "v", "w", "q", "r", "z", "d", "vo", "o3",
                "cc", "ciwc", "clwc", "crwc", "cswc", "pv"]
    for v in expected
        @test v in vnames
    end
end
