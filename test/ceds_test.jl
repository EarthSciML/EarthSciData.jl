@testsnippet CEDSSetup begin
    using Dates: DateTime
    using EarthSciMLBase
    using EarthSciData

    domain = DomainInfo(
        DateTime(2016, 5, 1),
        DateTime(2016, 5, 2);
        latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
        lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
        levrange = 1:10,
    )
    lon, lat, lev = EarthSciMLBase.pvars(domain)

    ts, te = get_tspan_datetime(domain)
end

@testitem "CEDS Setup" setup=[CEDSSetup] begin
    using ModelingToolkit

    # Test loading a single species.
    emis = CEDS(domain; species = ["SO2"])
    @test emis isa ModelingToolkit.AbstractSystem
end

@testitem "CEDS Basics" setup=[CEDSSetup] begin
    using ModelingToolkit: equations, unknowns

    # Load just SO2.
    emis = CEDS(domain; species = ["SO2"])
    eqs = equations(emis)
    @test length(eqs) == 1
    @test any(v -> occursin("SO2_em_anthro", string(v)), unknowns(emis))

    # Load all species.
    emis_all = CEDS(domain)
    eqs_all = equations(emis_all)
    @test length(eqs_all) == 10
end

@testitem "CEDS FileSet" setup=[CEDSSetup] begin
    using Dates

    fs = EarthSciData.CEDSFileSet("SO2", ts, te)
    @test fs isa EarthSciData.FileSet

    # Check that the dataset was opened.
    vns = EarthSciData.varnames(fs)
    @test vns == ["SO2_em_anthro"]

    # Check metadata.
    md = EarthSciData.loadmetadata(fs, "SO2_em_anthro")
    @test md.xdim == 1
    @test md.ydim == 2
    @test md.zdim == -1
    @test length(md.coords[1]) == 720  # lon
    @test length(md.coords[2]) == 360  # lat
    @test md.native_sr == "+proj=longlat +datum=WGS84 +no_defs"
end

@testitem "CEDS interpolation" setup=[CEDSSetup] begin
    using Dates

    fs = EarthSciData.CEDSFileSet("SO2", ts, te)
    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)

    # Test interpolation at a point in eastern China (known high SO2 area).
    result = interp(itp, ts, deg2rad(116.0f0), deg2rad(39.0f0))
    @test result > 0.0f0  # Should be positive emissions.

    # Test interpolation in the middle of the Pacific (should be very small).
    result_ocean = interp(itp, ts, deg2rad(-170.0f0), deg2rad(0.0f0))
    @test result_ocean >= 0.0f0
    @test result_ocean < result  # Much less than eastern China.
end

@testitem "CEDS sector filtering" setup=[CEDSSetup] begin
    using Dates

    # All sectors summed.
    fs_all = EarthSciData.CEDSFileSet("SO2", ts, te)
    itp_all = EarthSciData.DataSetInterpolator{Float32}(fs_all, "SO2_em_anthro", ts, te, domain)
    val_all = interp(itp_all, ts, deg2rad(116.0f0), deg2rad(39.0f0))

    # Energy sector only (index 1).
    fs_energy = EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [1])
    itp_energy = EarthSciData.DataSetInterpolator{Float32}(fs_energy, "SO2_em_anthro", ts, te, domain)
    val_energy = interp(itp_energy, ts, deg2rad(116.0f0), deg2rad(39.0f0))

    # Energy + Industrial sectors (indices 1, 2).
    fs_multi = EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [1, 2])
    itp_multi = EarthSciData.DataSetInterpolator{Float32}(fs_multi, "SO2_em_anthro", ts, te, domain)
    val_multi = interp(itp_multi, ts, deg2rad(116.0f0), deg2rad(39.0f0))

    # Single sector should be <= multi-sector <= total.
    @test val_energy <= val_multi || val_energy ≈ val_multi
    @test val_multi <= val_all || val_multi ≈ val_all
    @test val_all > 0.0f0  # Eastern China should have SO2 emissions.
end

@testitem "CEDS monthly frequency" setup=[CEDSSetup] begin
    using Dates: month

    fs = EarthSciData.CEDSFileSet("SO2", ts, te)
    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)
    EarthSciData.lazyload!(itp, ts)

    # After lazy loading, the cached times should bracket the start time.
    @test month(itp.cache.times[1]) == 4 || month(itp.cache.times[1]) == 5
    @test month(itp.cache.times[2]) == 5 || month(itp.cache.times[2]) == 6
end

@testitem "CEDS run" setup=[CEDSSetup] begin
    using ModelingToolkit
    using OrdinaryDiffEqTsit5

    emis = CEDS(domain; species = ["SO2"])
    sys = mtkcompile(emis)
    prob = ODEProblem(
        sys,
        [lat => deg2rad(40.0), lon => deg2rad(116.0)],
        (0.0, 60.0),
    )
    sol = solve(prob, Tsit5())
    @test length(sol.t) > 1
end

@testitem "CEDS Coupling with GEOS-FP" setup=[CEDSSetup] begin
    using ModelingToolkit

    emis = CEDS(domain; species = ["SO2"])
    gfp = GEOSFP("4x5", domain)

    csys = couple(emis, gfp)
    sys = convert(System, csys)
    eqs = observed(sys)

    @test occursin("CEDS₊lat(t) ~ GEOSFP₊lat", string(eqs))
end
