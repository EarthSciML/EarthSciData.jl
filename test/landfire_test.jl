using EarthSciData
using EarthSciMLBase
using ModelingToolkit
using Dates
using Proj
using Symbolics
using Test

@testset "LANDFIRE" begin
    function setup()
        # Small domain near Paradise, CA (Camp Fire area)
        domain = DomainInfo(
            DateTime(2018, 11, 8),
            DateTime(2018, 11, 9);
            lonrange = deg2rad(-121.65):deg2rad(0.01):deg2rad(-121.55),
            latrange = deg2rad(39.73):deg2rad(0.01):deg2rad(39.83),
            levrange = 1:1
        )
        return (; domain)
    end

    function setup_lcc()
        lcc_sr = "+proj=lcc +lat_1=30.0 +lat_2=60.0 +lat_0=38.999996 +lon_0=-97.0 +x_0=0 +y_0=0 +a=6370000 +b=6370000 +to_meter=1"

        # Transform Paradise, CA centre to LCC coordinates
        trans = Proj.Transformation(
            "+proj=pipeline +step +proj=longlat +datum=WGS84 +no_defs +step " * lcc_sr)
        x_center, y_center = trans(deg2rad(-121.6), deg2rad(39.78))

        domain_lcc = DomainInfo(
            DateTime(2018, 11, 8),
            DateTime(2018, 11, 9);
            xrange = (x_center - 5000):1000:(x_center + 5000),
            yrange = (y_center - 5000):1000:(y_center + 5000),
            levrange = 1:1,
            spatial_ref = lcc_sr
        )
        return (; lcc_sr, domain_lcc)
    end

    @testset "FileSet construction" begin
        (; domain) = setup()
        fs=EarthSciData.LANDFIREFileSet(domain)
        @test EarthSciData.varnames(fs) == ["fuel_model"]
        @test fs.product == "FBFM13"
        @test fs.version == "LF2022"
        @test fs.width > 0
        @test fs.height > 0
        @test fs.bbox[1] <= -121.65
        @test fs.bbox[3] >= -121.55
    end

    @testset "relpath and url" begin
        (; domain) = setup()
        fs=EarthSciData.LANDFIREFileSet(domain; resolution = 10.0)
        ts, _=EarthSciMLBase.get_tspan_datetime(domain)

        rp=EarthSciData.relpath(fs, ts)
        @test startswith(rp, "landfire/FBFM13_")
        @test endswith(rp, ".tif")

        u=EarthSciData.url(fs, ts)
        @test contains(u, "lfps.usgs.gov")
        @test contains(u, "LF2022_FBFM13_CONUS")
        @test contains(u, "exportImage")
        @test contains(u, "bbox=")
        @test contains(u, "pixelType=S16")
        @test contains(u, "format=tiff")
    end

    @testset "metadata" begin
        (; domain) = setup()
        fs=EarthSciData.LANDFIREFileSet(domain; resolution = 10.0)
        md=EarthSciData.loadmetadata(fs, "fuel_model")
        @test md.unit_str == "1"
        @test length(md.coords) == 2
        @test md.xdim == 1
        @test md.ydim == 2
        @test md.zdim == -1
        @test issorted(md.coords[1])
        @test issorted(md.coords[2])
    end

    @testset "data loading" begin
        (; domain) = setup()
        fs=EarthSciData.LANDFIREFileSet(domain; resolution = 10.0)
        md=EarthSciData.loadmetadata(fs, "fuel_model")
        data=zeros(Float32, md.varsize...)
        ts, _=EarthSciMLBase.get_tspan_datetime(domain)
        EarthSciData.loadslice!(data, fs, ts, "fuel_model")
        # Valid FBFM13 fuel model codes: 0 (no fuel), 1-13 (Anderson 13),
        # and special codes 91-99 (non-burnable: urban, snow, agriculture, water, barren).
        # FBFM40 adds codes 101-204 (Scott & Burgan), but FBFM13 should not have those.
        valid_codes=Set([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
            91, 92, 93, 98, 99])
        unique_vals=Set(round.(Int, unique(data)))
        @test length(unique_vals) > 1  # Should have multiple fuel types
        @test all(v -> v in valid_codes, unique_vals)
    end

    @testset "nearest-neighbour interpolation" begin
        (; domain) = setup()
        fs=EarthSciData.LANDFIREFileSet(domain; resolution = 10.0)
        ts, te=EarthSciMLBase.get_tspan_datetime(domain)

        metadata=EarthSciData.loadmetadata(fs, "fuel_model")
        model_grid=EarthSciData._compute_grid(domain, metadata.staggering)
        regrid_f=(dst,
            src;
            extrapolate_type = EarthSciData.Interpolations.Flat())->begin
            EarthSciData._nearest_interpolate_from!(dst, src, metadata, model_grid, domain;
                extrapolate_type = extrapolate_type)
        end
        fswr=EarthSciData.FileSetWithRegridder(fs, regrid_f)

        itp=EarthSciData.DataSetInterpolator{Float32}(
            fswr, "fuel_model", ts, te, domain; stream = true)
        lon_c=deg2rad(-121.60)
        lat_c=deg2rad(39.78)
        val=EarthSciData.interp!(itp, ts, Float32(lon_c), Float32(lat_c))
        # Nearest-neighbour should produce integer-valued results
        @test val ≈ round(val)
        @test val >= 0
    end

    @testset "System" begin
        (; domain) = setup()
        sys=LANDFIRE(domain; resolution = 10.0)
        @test sys isa ModelingToolkit.AbstractSystem
        @test length(equations(sys)) >= 1
        eq_names=[Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(sys)]
        @test :fuel_model ∈ eq_names
    end

    # ---- LCC (Lambert Conformal Conic) projection tests -------------------------

    @testset "LCC bbox helper" begin
        (; domain_lcc) = setup_lcc()
        lon_min, lat_min, lon_max, lat_max=EarthSciData._domain_bbox_wgs84(domain_lcc)
        @test lon_min < -121.6 < lon_max
        @test lat_min < 39.78 < lat_max
        # Bbox should be reasonable (not huge)
        @test lon_max - lon_min < 1.0
        @test lat_max - lat_min < 1.0
    end

    @testset "LCC FileSet construction" begin
        (; domain_lcc) = setup_lcc()
        fs=EarthSciData.LANDFIREFileSet(domain_lcc)
        @test fs.product == "FBFM13"
        @test fs.bbox[1] < -121.6 < fs.bbox[3]
        @test fs.bbox[2] < 39.78 < fs.bbox[4]
        @test fs.width > 0
        @test fs.height > 0
    end

    @testset "LCC data loading" begin
        (; domain_lcc) = setup_lcc()
        fs=EarthSciData.LANDFIREFileSet(domain_lcc; resolution = 10.0)
        md=EarthSciData.loadmetadata(fs, "fuel_model")
        data=zeros(Float32, md.varsize...)
        ts, _=EarthSciMLBase.get_tspan_datetime(domain_lcc)
        EarthSciData.loadslice!(data, fs, ts, "fuel_model")
        valid_codes=Set([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
            91, 92, 93, 98, 99])
        unique_vals=Set(round.(Int, unique(data)))
        @test length(unique_vals) > 1
        @test all(v -> v in valid_codes, unique_vals)
    end

    @testset "LCC System" begin
        (; domain_lcc) = setup_lcc()
        sys=LANDFIRE(domain_lcc; resolution = 10.0)
        @test sys isa ModelingToolkit.AbstractSystem
        @test length(equations(sys)) >= 1
        eq_names=[Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(sys)]
        @test :fuel_model ∈ eq_names
    end
end
