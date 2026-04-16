using Dates
using DynamicQuantities
using EarthSciMLBase
using EarthSciData
using ModelingToolkit
using ModelingToolkit: equations, unknowns, t, D
using OrdinaryDiffEqTsit5
using Test

@testset "CEDS" begin
    function setup()
        domain = DomainInfo(
            DateTime(2016, 5, 1),
            DateTime(2016, 5, 2);
            latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
            lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
            levrange = 1:10
        )
        lon, lat, lev = EarthSciMLBase.pvars(domain)
        ts, te = get_tspan_datetime(domain)
        return (; domain, lon, lat, lev, ts, te)
    end

    @testset "Setup" begin
        (; domain) = setup()
        emis = CEDS(domain; species = ["SO2"])
        @test emis isa ModelingToolkit.AbstractSystem
    end

    @testset "Basics" begin
        (; domain) = setup()
        emis = CEDS(domain; species = ["SO2"])
        eqs = equations(emis)
        @test length(eqs) == 1
        @test any(v -> occursin("SO2_em_anthro", string(v)), unknowns(emis))

        emis_all = CEDS(domain)
        eqs_all = equations(emis_all)
        @test length(eqs_all) == 10
    end

    @testset "FileSet" begin
        (; ts, te) = setup()
        fs = EarthSciData.CEDSFileSet("SO2", ts, te)
        @test fs isa EarthSciData.FileSet

        vns = EarthSciData.varnames(fs)
        @test vns == ["SO2_em_anthro"]

        md = EarthSciData.loadmetadata(fs, "SO2_em_anthro")
        @test md.xdim == 1
        @test md.ydim == 2
        @test md.zdim == -1
        @test length(md.coords[1]) == 720
        @test length(md.coords[2]) == 360
        @test md.native_sr == "+proj=longlat +datum=WGS84 +no_defs"
    end

    @testset "interpolation" begin
        (; domain, ts, te) = setup()
        fs = EarthSciData.CEDSFileSet("SO2", ts, te)
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)

        result = interp!(itp, ts, deg2rad(116.0f0), deg2rad(39.0f0))
        @test result > 0.0f0

        result_ocean = interp!(itp, ts, deg2rad(-170.0f0), deg2rad(0.0f0))
        @test result_ocean >= 0.0f0
        @test result_ocean < result
    end

    @testset "sector filtering" begin
        (; domain, ts, te) = setup()
        fs_all = EarthSciData.CEDSFileSet("SO2", ts, te)
        itp_all = EarthSciData.DataSetInterpolator{Float32}(
            fs_all, "SO2_em_anthro", ts, te, domain)
        val_all = interp!(itp_all, ts, deg2rad(116.0f0), deg2rad(39.0f0))

        fs_energy = EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [1])
        itp_energy = EarthSciData.DataSetInterpolator{Float32}(
            fs_energy, "SO2_em_anthro", ts, te, domain)
        val_energy = interp!(itp_energy, ts, deg2rad(116.0f0), deg2rad(39.0f0))

        fs_multi = EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [1, 2])
        itp_multi = EarthSciData.DataSetInterpolator{Float32}(
            fs_multi, "SO2_em_anthro", ts, te, domain)
        val_multi = interp!(itp_multi, ts, deg2rad(116.0f0), deg2rad(39.0f0))

        @test val_energy <= val_multi || val_energy ≈ val_multi
        @test val_multi <= val_all || val_multi ≈ val_all
        @test val_all > 0.0f0
    end

    @testset "monthly frequency" begin
        (; domain, ts, te) = setup()
        fs = EarthSciData.CEDSFileSet("SO2", ts, te)
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)
        EarthSciData.lazyload!(itp, ts)

        @test month(itp.cache.times[1]) == 4 || month(itp.cache.times[1]) == 5
        @test month(itp.cache.times[2]) == 5 || month(itp.cache.times[2]) == 6
    end

    @testset "quantitative values" begin
        (; domain, ts, te) = setup()
        fs = EarthSciData.CEDSFileSet("SO2", ts, te)
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)

        val_china = interp!(itp, ts, deg2rad(116.0f0), deg2rad(39.0f0))
        @test val_china > 1.0f-12
        @test val_china < 1.0f-6

        val_sahara = interp!(itp, ts, deg2rad(10.0f0), deg2rad(25.0f0))
        @test val_sahara >= 0.0f0
        @test val_sahara < val_china * 0.01f0

        fs_co = EarthSciData.CEDSFileSet("CO", ts, te)
        itp_co = EarthSciData.DataSetInterpolator{Float32}(
            fs_co, "CO_em_anthro", ts, te, domain)
        val_co = interp!(itp_co, ts, deg2rad(116.0f0), deg2rad(39.0f0))
        @test val_co > 0.0f0
        @test val_co != val_china
    end

    @testset "longitude wrapping" begin
        (; domain, ts, te) = setup()
        fs = EarthSciData.CEDSFileSet("SO2", ts, te)

        @test issorted(fs.lons_rad)
        @test fs.lons_rad[1] >= -π
        @test fs.lons_rad[end] < π

        @test length(fs.lon_perm) == 720
        @test sort(fs.lon_perm) == 1:720

        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)

        val_us = interp!(itp, ts, deg2rad(-90.0f0), deg2rad(35.0f0))
        val_pacific = interp!(itp, ts, deg2rad(170.0f0), deg2rad(35.0f0))
        @test val_us > val_pacific
    end

    @testset "fill value replacement" begin
        (; ts, te) = setup()
        fs = EarthSciData.CEDSFileSet("SO2", ts, te)
        md = EarthSciData.loadmetadata(fs, "SO2_em_anthro")

        data = zeros(Float32, md.varsize...)
        EarthSciData.loadslice!(data, fs, ts, "SO2_em_anthro")

        @test all(d -> d < fs.fill_val, data)
        @test all(isfinite, data)
        @test all(d -> d >= 0.0f0, data)
    end

    @testset "error handling" begin
        (; domain, ts, te) = setup()
        @test_throws AssertionError EarthSciData.CEDSFileSet("INVALID_SPECIES", ts, te)
        @test_throws AssertionError EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [8])
        @test_throws AssertionError EarthSciData.CEDSFileSet("SO2", ts, te; sectors = [-1])
        @test_throws AssertionError CEDS(domain; species = ["FAKE"])
    end

    @testset "run" begin
        (; domain, ts, te) = setup()
        emis = CEDS(domain; species = ["SO2"])

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

        @test sol.u[end][1] > 0.0
        @test sol.u[end][1] > sol.u[1][1]

        fs = EarthSciData.CEDSFileSet("SO2", ts, te)
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "SO2_em_anthro", ts, te, domain)
        rate = interp!(itp, ts, deg2rad(116.0f0), deg2rad(40.0f0))
        expected_approx = Float64(rate) * 60.0
        @test sol.u[end][1] ≈ expected_approx rtol=0.1
    end

    @testset "Coupling with GEOS-FP" begin
        (; domain) = setup()
        emis = CEDS(domain; species = ["SO2"])
        gfp = GEOSFP("4x5", domain)

        csys = couple(emis, gfp)
        sys = convert(System, csys)
        eqs = observed(sys)

        eqs_str = string(eqs)
        @test occursin("CEDS₊lat(t) ~ GEOSFP₊lat", eqs_str)
        @test occursin("CEDS₊lon(t) ~ GEOSFP₊lon", eqs_str)

        @test !occursin("CEDS₊lev", eqs_str)

        @test length(unknowns(sys)) >= 0
        @test sys isa ModelingToolkit.AbstractSystem
    end
end
