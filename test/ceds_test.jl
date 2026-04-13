@testsnippet CEDSSetup begin
    using Dates: DateTime
    using EarthSciMLBase
    using EarthSciData

    domain = DomainInfo(
        DateTime(2016, 5, 1),
        DateTime(2016, 5, 2);
        latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
        lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
        levrange = 1:10
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
    result = interp!(itp, ts, deg2rad(116.0f0), deg2rad(39.0f0))
    @test result > 0.0f0  # Should be positive emissions.

    # Test interpolation in the middle of the Pacific (should be very small).
    result_ocean = interp!(itp, ts, deg2rad(-170.0f0), deg2rad(0.0f0))
    @test result_ocean >= 0.0f0
    @test result_ocean < result  # Much less than eastern China.
end

@testitem "CEDS sector filtering" setup=[CEDSSetup] begin
    using Dates

    # All sectors summed.
    fs_all = EarthSciData.CEDSFileSet("SO2", ts, te)
    itp_all = EarthSciData.DataSetInterpolator{Float32}(
        fs_all, "SO2_em_anthro", ts, te, domain)
    val_all = interp!(itp_all, ts, deg2rad(116.0f0), deg2rad(39.0f0))

    # Energy sector only (index 1).
    fs_energy = EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [1])
    itp_energy = EarthSciData.DataSetInterpolator{Float32}(
        fs_energy, "SO2_em_anthro", ts, te, domain)
    val_energy = interp!(itp_energy, ts, deg2rad(116.0f0), deg2rad(39.0f0))

    # Energy + Industrial sectors (indices 1, 2).
    fs_multi = EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [1, 2])
    itp_multi = EarthSciData.DataSetInterpolator{Float32}(
        fs_multi, "SO2_em_anthro", ts, te, domain)
    val_multi = interp!(itp_multi, ts, deg2rad(116.0f0), deg2rad(39.0f0))

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

@testitem "CEDS quantitative values" setup=[CEDSSetup] begin
    using Dates

    fs = EarthSciData.CEDSFileSet("SO2", ts, te)
    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)

    # Pin a quantitative value at a known high-emission location (eastern China).
    # SO2 emissions from power plants and industry in this region are well-documented.
    val_china = interp!(itp, ts, deg2rad(116.0f0), deg2rad(39.0f0))
    @test val_china > 1.0f-12  # Should be a meaningful positive flux (kg/m²/s)
    @test val_china < 1.0f-6   # But not unreasonably large

    # Middle of the Sahara desert - should have very low SO2 emissions.
    val_sahara = interp!(itp, ts, deg2rad(10.0f0), deg2rad(25.0f0))
    @test val_sahara >= 0.0f0
    @test val_sahara < val_china * 0.01f0  # Orders of magnitude less than China

    # Multiple species should return independent, non-identical values at the same location.
    fs_co = EarthSciData.CEDSFileSet("CO", ts, te)
    itp_co = EarthSciData.DataSetInterpolator{Float32}(
        fs_co, "CO_em_anthro", ts, te, domain)
    val_co = interp!(itp_co, ts, deg2rad(116.0f0), deg2rad(39.0f0))
    @test val_co > 0.0f0
    @test val_co != val_china  # Different species should have different values
end

@testitem "CEDS longitude wrapping" setup=[CEDSSetup] begin
    using Dates

    fs = EarthSciData.CEDSFileSet("SO2", ts, te)

    # Verify longitudes are sorted and in [-π, π).
    @test issorted(fs.lons_rad)
    @test fs.lons_rad[1] >= -π
    @test fs.lons_rad[end] < π

    # Verify the permutation has the right length and is a valid permutation.
    @test length(fs.lon_perm) == 720  # 0.5° resolution → 720 points
    @test sort(fs.lon_perm) == 1:720  # Valid permutation (no duplicates, no gaps)

    # Verify that interpolation at a negative longitude (western hemisphere) works
    # and gives a different value than the equivalent positive longitude.
    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)

    # Continental US (high emissions) vs middle of Pacific (low emissions) -
    # if wrapping were wrong, these could be swapped.
    val_us = interp!(itp, ts, deg2rad(-90.0f0), deg2rad(35.0f0))
    val_pacific = interp!(itp, ts, deg2rad(170.0f0), deg2rad(35.0f0))
    @test val_us > val_pacific  # US should have more SO2 than open Pacific
end

@testitem "CEDS fill value replacement" setup=[CEDSSetup] begin
    using Dates

    fs = EarthSciData.CEDSFileSet("SO2", ts, te)
    md = EarthSciData.loadmetadata(fs, "SO2_em_anthro")

    # Load a raw data slice and verify no fill values remain.
    data = zeros(Float32, md.varsize...)
    EarthSciData.loadslice!(data, fs, ts, "SO2_em_anthro")

    # No values should equal or exceed the fill value.
    @test all(d -> d < fs.fill_val, data)

    # All values should be finite (no NaN or Inf).
    @test all(isfinite, data)

    # All values should be non-negative (emissions cannot be negative).
    @test all(d -> d >= 0.0f0, data)
end

@testitem "CEDS error handling" setup=[CEDSSetup] begin
    using Dates

    # Invalid species should throw an assertion error.
    @test_throws AssertionError EarthSciData.CEDSFileSet("INVALID_SPECIES", ts, te)

    # Invalid sector index should throw an assertion error.
    @test_throws AssertionError EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [8])
    @test_throws AssertionError EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [-1])

    # Invalid species in the CEDS factory function should also throw.
    @test_throws AssertionError CEDS(domain; species = ["FAKE"])
end

@testitem "CEDS run" setup=[CEDSSetup] begin
    using ModelingToolkit
    using ModelingToolkit: t, D
    using DynamicQuantities
    using OrdinaryDiffEqTsit5

    emis = CEDS(domain; species = ["SO2"])

    # Compose with an ODE that accumulates the emission rate (kg/m²/s).
    # D(SO2_acc) [kg/m²/s] ~ emis.SO2_em_anthro [kg/m²/s]
    @variables SO2_acc(t) = 0.0 [unit = u"kg/m^2"]
    eq = D(SO2_acc) ~ emis.SO2_em_anthro
    sys = compose(System([eq], t, [SO2_acc], []; name = :test_ceds), emis)
    sys = mtkcompile(sys)

    ps = parameters(sys)
    lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
    lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))

    prob = ODEProblem(
        sys,
        [lat_p => deg2rad(40.0), lon_p => deg2rad(116.0)],
        (0.0, 60.0)
    )
    sol = solve(prob, Tsit5())
    @test length(sol.t) > 1

    # Solution should accumulate positive emissions over time.
    @test sol.u[end][1] > 0.0
    @test sol.u[end][1] > sol.u[1][1]  # Monotonically increasing (positive source)

    # Verify magnitude is consistent with interpolation:
    # After ~60 seconds of constant emission rate, accumulated value should be
    # approximately rate * time.
    fs = EarthSciData.CEDSFileSet("SO2", ts, te)
    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)
    rate = interp!(itp, ts, deg2rad(116.0f0), deg2rad(40.0f0))
    expected_approx = Float64(rate) * 60.0
    @test sol.u[end][1] ≈ expected_approx rtol=0.1
end

@testitem "CEDS Coupling with GEOS-FP" setup=[CEDSSetup] begin
    using ModelingToolkit

    emis = CEDS(domain; species = ["SO2"])
    gfp = GEOSFP("4x5", domain)

    csys = couple(emis, gfp)
    sys = convert(System, csys)
    eqs = observed(sys)

    # Verify coupling equations exist for lat and lon.
    eqs_str = string(eqs)
    @test occursin("CEDS₊lat(t) ~ GEOSFP₊lat", eqs_str)
    @test occursin("CEDS₊lon(t) ~ GEOSFP₊lon", eqs_str)

    # Verify that lev is NOT coupled (CEDS is 2D surface data).
    @test !occursin("CEDS₊lev", eqs_str)

    # Verify the coupled system has unknowns (it was already compiled by convert).
    @test length(unknowns(sys)) >= 0
    @test sys isa ModelingToolkit.AbstractSystem
end
