using EarthSciData
using EarthSciMLBase
using ModelingToolkit
using Dates
using Proj
using Symbolics
using Test

@testset "USGS3DEP" begin
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
        # LCC projection centered on Paradise, CA area.
        lcc_sr = "+proj=lcc +lat_1=33 +lat_2=45 +lat_0=39.78 +lon_0=-121.6 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

        # Transform the lon-lat domain corners to LCC coordinates.
        lonlat_sr = "+proj=longlat +datum=WGS84 +no_defs"
        to_lcc = Proj.Transformation(
            "+proj=pipeline +step +inv " * lonlat_sr * " +step " * lcc_sr)
        x_sw, y_sw = to_lcc(deg2rad(-121.65), deg2rad(39.73))
        x_ne, y_ne = to_lcc(deg2rad(-121.55), deg2rad(39.83))

        # Build a domain in LCC coordinates (~100m grid spacing).
        dx = 100.0
        lcc_domain = DomainInfo(
            DateTime(2018, 11, 8),
            DateTime(2018, 11, 9);
            xrange = x_sw:dx:x_ne,
            yrange = y_sw:dx:y_ne,
            levrange = 1:1,
            spatial_ref = lcc_sr
        )
        return (; lcc_sr, lcc_domain)
    end

    @testset "FileSet construction" begin
        (; domain) = setup()
        fs=EarthSciData.USGS3DEPFileSet(domain)
        @test EarthSciData.varnames(fs) == ["elevation"]
        @test fs.width > 0
        @test fs.height > 0
        # Bounding box should enclose the domain
        @test fs.bbox[1] <= -121.65
        @test fs.bbox[3] >= -121.55
        @test fs.bbox[2] <= 39.73
        @test fs.bbox[4] >= 39.83
    end

    @testset "offline structural tests" begin
        (; domain) = setup()
        # These tests verify FileSet construction, metadata, and URL generation
        # without any network access.
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)

        # URL format
        u=EarthSciData.url(fs, DateTime(2018, 11, 8))
        @test startswith(u,
            "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage?")
        @test occursin("bbox=", u)
        @test occursin("bboxSR=4326", u)
        @test occursin("format=tiff", u)
        @test occursin("pixelType=F32", u)

        # relpath encodes bbox and dimensions
        rp=EarthSciData.relpath(fs, DateTime(2018, 11, 8))
        @test startswith(rp, "usgs3dep/elevation_")
        @test endswith(rp, ".tif")
        @test occursin("$(fs.width)x$(fs.height)", rp)

        # Metadata (computed from bbox, no download needed)
        md=EarthSciData.loadmetadata(fs, "elevation")
        @test md.unit_str == "m"
        @test md.description == "Terrain elevation above sea level"
        @test md.xdim == 1
        @test md.ydim == 2
        @test md.zdim == -1
        @test md.varsize == [fs.width, fs.height]
        # Coords in radians, correct hemisphere, sorted ascending
        @test all(md.coords[1] .< 0)  # western hemisphere
        @test all(md.coords[2] .> 0)  # northern hemisphere
        @test issorted(md.coords[1])
        @test issorted(md.coords[2])
        # Pixel-centre coordinates should lie within the bounding box
        @test rad2deg(first(md.coords[1])) > fs.bbox[1]
        @test rad2deg(last(md.coords[1])) < fs.bbox[3]
        @test rad2deg(first(md.coords[2])) > fs.bbox[2]
        @test rad2deg(last(md.coords[2])) < fs.bbox[4]

        # Pixel clamping: very fine resolution should hit the 1000-pixel cap
        fs_fine=EarthSciData.USGS3DEPFileSet(domain; resolution = 0.001)
        @test fs_fine.width == 1000
        @test fs_fine.height == 1000

        # Invalid varname should error
        @test_throws AssertionError EarthSciData.loadmetadata(fs, "temperature")

        # Out-of-coverage domain should warn
        eu_domain=DomainInfo(
            DateTime(2018, 11, 8), DateTime(2018, 11, 9);
            lonrange = deg2rad(10.0):deg2rad(0.1):deg2rad(11.0),
            latrange = deg2rad(48.0):deg2rad(0.1):deg2rad(49.0),
            levrange = 1:1
        )
        @test_warn "outside USGS 3DEP coverage" EarthSciData.USGS3DEPFileSet(eu_domain)
    end

    @testset "metadata" begin
        (; domain) = setup()
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)  # coarse for speed
        md=EarthSciData.loadmetadata(fs, "elevation")
        @test md.unit_str == "m"
        @test md.description == "Terrain elevation above sea level"
        @test length(md.coords) == 2
        @test md.xdim == 1
        @test md.ydim == 2
        @test md.zdim == -1
        # Coords should be in radians
        @test all(md.coords[1] .< 0)  # western hemisphere
        @test all(md.coords[2] .> 0)  # northern hemisphere
        # Coords should be sorted ascending
        @test issorted(md.coords[1])
        @test issorted(md.coords[2])
    end

    @testset "data loading" begin
        (; domain) = setup()
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)
        md=EarthSciData.loadmetadata(fs, "elevation")
        data=zeros(Float32, md.varsize...)
        ts, _=EarthSciMLBase.get_tspan_datetime(domain)
        EarthSciData.loadslice!(data, fs, ts, "elevation")
        # Paradise area elevation should be roughly 100-1000m
        valid=data[data .> 0]
        # At least 90% of pixels should have valid elevation data
        @test length(valid) / length(data) > 0.9
        @test minimum(valid) > 50
        @test maximum(data) < 3000
    end

    @testset "interpolator" begin
        (; domain) = setup()
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)
        ts, te=EarthSciMLBase.get_tspan_datetime(domain)
        itp=EarthSciData.DataSetInterpolator{Float32}(
            fs, "elevation", ts, te, domain; stream = true)
        # Interpolate at the centre of the domain
        lon_c=deg2rad(-121.60)
        lat_c=deg2rad(39.78)
        val=EarthSciData.interp!(itp, ts, Float32(lon_c), Float32(lat_c))
        @test 50 < val < 3000
    end

    @testset "slope FileSet structural" begin
        (; domain) = setup()
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)

        # dzdx
        slope_x=EarthSciData.USGS3DEPSlopeFileSet(fs, :dzdx)
        @test EarthSciData.varnames(slope_x) == ["dzdx"]
        md_x=EarthSciData.loadmetadata(slope_x, "dzdx")
        @test md_x.unit_str == "1"
        @test md_x.varsize == [fs.width, fs.height]
        @test occursin("east", md_x.description)
        # Same download path as parent
        @test EarthSciData.relpath(slope_x, DateTime(2018, 11, 8)) ==
              EarthSciData.relpath(fs, DateTime(2018, 11, 8))

        # dzdy
        slope_y=EarthSciData.USGS3DEPSlopeFileSet(fs, :dzdy)
        @test EarthSciData.varnames(slope_y) == ["dzdy"]
        md_y=EarthSciData.loadmetadata(slope_y, "dzdy")
        @test md_y.unit_str == "1"
        @test occursin("north", md_y.description)
    end

    @testset "slope data loading" begin
        (; domain) = setup()
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)
        md=EarthSciData.loadmetadata(fs, "elevation")
        ts, _=EarthSciMLBase.get_tspan_datetime(domain)

        dzdx=zeros(Float64, md.varsize...)
        slope_x=EarthSciData.USGS3DEPSlopeFileSet(fs, :dzdx)
        EarthSciData.loadslice!(dzdx, slope_x, ts, "dzdx")

        dzdy=zeros(Float64, md.varsize...)
        slope_y=EarthSciData.USGS3DEPSlopeFileSet(fs, :dzdy)
        EarthSciData.loadslice!(dzdy, slope_y, ts, "dzdy")

        # Slopes should be finite and physically reasonable
        # (Paradise, CA area has mountains; slopes up to ~1.0 = 45°)
        @test all(isfinite, dzdx)
        @test all(isfinite, dzdy)
        @test maximum(abs, dzdx) > 0.001  # not completely flat
        @test maximum(abs, dzdy) > 0.001
        @test maximum(abs, dzdx) < 10.0   # not unreasonably steep
        @test maximum(abs, dzdy) < 10.0

        # Combined slope magnitude
        tanphi=sqrt.(dzdx .^ 2 .+ dzdy .^ 2)
        @test maximum(tanphi) > 0.01  # mountainous terrain has noticeable slope
        @test maximum(tanphi) < 10.0
    end

    @testset "slope analytical test" begin
        (; domain) = setup()
        # Verify slope computation against synthetic elevation ramps.
        # Test each direction independently to avoid cross-terms from
        # the latitude-dependent metric in the x direction.
        fs=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)
        md=EarthSciData.loadmetadata(fs, "elevation")
        nlon, nlat=md.varsize
        lons_rad=md.coords[1]
        lats_rad=md.coords[2]

        # --- Test dzdx: elevation ramp that only varies in longitude ---
        target_slope_x=0.15
        elev_x=zeros(Float64, nlon, nlat)
        for j in 1:nlat
            for i in 1:nlon
                x_m=EarthSciData._LON2M*cos(lats_rad[j])*(lons_rad[i]-lons_rad[1])
                elev_x[i, j]=target_slope_x*x_m
            end
        end
        dzdx=zeros(Float64, nlon, nlat)
        for j in 1:nlat
            dx_per_rad=EarthSciData._LON2M*cos(lats_rad[j])
            for i in 1:nlon
                if i==1
                    dz=elev_x[2, j]-elev_x[1, j]
                    dlon=lons_rad[2]-lons_rad[1]
                elseif i==nlon
                    dz=elev_x[nlon, j]-elev_x[nlon - 1, j]
                    dlon=lons_rad[nlon]-lons_rad[nlon - 1]
                else
                    dz=elev_x[i + 1, j]-elev_x[i - 1, j]
                    dlon=lons_rad[i + 1]-lons_rad[i - 1]
                end
                dzdx[i, j]=dz/(dlon*dx_per_rad)
            end
        end
        # Interior points should recover the target slope.
        @test all(abs.(dzdx[2:(end - 1), :] .- target_slope_x) .< 1e-6)

        # --- Test dzdy: elevation ramp that only varies in latitude ---
        target_slope_y=-0.08
        elev_y=zeros(Float64, nlon, nlat)
        for j in 1:nlat
            for i in 1:nlon
                y_m=EarthSciData._LAT2M*(lats_rad[j]-lats_rad[1])
                elev_y[i, j]=target_slope_y*y_m
            end
        end
        dzdy=zeros(Float64, nlon, nlat)
        for j in 1:nlat
            for i in 1:nlon
                if j==1
                    dz=elev_y[i, 2]-elev_y[i, 1]
                    dlat=lats_rad[2]-lats_rad[1]
                elseif j==nlat
                    dz=elev_y[i, nlat]-elev_y[i, nlat - 1]
                    dlat=lats_rad[nlat]-lats_rad[nlat - 1]
                else
                    dz=elev_y[i, j + 1]-elev_y[i, j - 1]
                    dlat=lats_rad[j + 1]-lats_rad[j - 1]
                end
                dzdy[i, j]=dz/(dlat*EarthSciData._LAT2M)
            end
        end
        @test all(abs.(dzdy[:, 2:(end - 1)] .- target_slope_y) .< 1e-6)
    end

    @testset "System" begin
        (; domain) = setup()
        sys=USGS3DEP(domain; resolution = 10.0)
        @test sys isa ModelingToolkit.AbstractSystem
        @test length(equations(sys)) == 3  # elevation + dzdx + dzdy
        # Check that all three variables exist
        eq_names=[Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(sys)]
        @test :elevation ∈ eq_names
        @test :dzdx ∈ eq_names
        @test :dzdy ∈ eq_names
    end

    # ---- Tests with Lambert Conformal Conic (LCC) projected domain ----

    @testset "LCC FileSet construction" begin
        (; lcc_domain) = setup_lcc()
        fs=EarthSciData.USGS3DEPFileSet(lcc_domain; resolution = 10.0)
        @test EarthSciData.varnames(fs) == ["elevation"]
        @test fs.width > 0
        @test fs.height > 0
        # Bounding box should be in lon-lat degrees and enclose the original region.
        @test fs.bbox[1] <= -121.65
        @test fs.bbox[3] >= -121.55
        @test fs.bbox[2] <= 39.73
        @test fs.bbox[4] >= 39.83
    end

    @testset "LCC data loading and interpolation" begin
        (; lcc_domain) = setup_lcc()
        fs=EarthSciData.USGS3DEPFileSet(lcc_domain; resolution = 10.0)
        ts, te=EarthSciMLBase.get_tspan_datetime(lcc_domain)

        # The DataSetInterpolator should handle the coord_trans from LCC→lonlat.
        itp=EarthSciData.DataSetInterpolator{Float32}(
            fs, "elevation", ts, te, lcc_domain; stream = true)

        # Interpolate at the LCC origin (0, 0) which corresponds to the projection centre.
        val=EarthSciData.interp!(itp, ts, Float32(0.0), Float32(0.0))
        # Paradise, CA area elevation should be physically reasonable.
        @test 50 < val < 3000
    end

    @testset "LCC System construction" begin
        (; lcc_domain) = setup_lcc()
        # This should not error — previously it would fail because the data has
        # dimnames ["lon", "lat"] but an LCC domain has pvars [:x, :y].
        sys=USGS3DEP(lcc_domain; resolution = 10.0)
        @test sys isa ModelingToolkit.AbstractSystem
        @test length(equations(sys)) == 3  # elevation + dzdx + dzdy
        eq_names=[Symbolics.tosymbol(eq.lhs, escape = false) for eq in equations(sys)]
        @test :elevation ∈ eq_names
        @test :dzdx ∈ eq_names
        @test :dzdy ∈ eq_names
    end

    @testset "LCC vs lonlat consistency" begin
        (; domain) = setup()
        (; lcc_domain) = setup_lcc()
        # Both domains cover approximately the same region.
        # The elevation at the same physical location should match.
        ts_ll, _=EarthSciMLBase.get_tspan_datetime(domain)
        ts_lcc, te_lcc=EarthSciMLBase.get_tspan_datetime(lcc_domain)

        # Lon-lat interpolator
        fs_ll=EarthSciData.USGS3DEPFileSet(domain; resolution = 10.0)
        itp_ll=EarthSciData.DataSetInterpolator{Float32}(
            fs_ll, "elevation", ts_ll, ts_ll+Dates.Day(2), domain; stream = true)

        # LCC interpolator
        fs_lcc=EarthSciData.USGS3DEPFileSet(lcc_domain; resolution = 10.0)
        itp_lcc=EarthSciData.DataSetInterpolator{Float32}(
            fs_lcc, "elevation", ts_lcc, te_lcc, lcc_domain; stream = true)

        # Query both at the projection centre (Paradise, CA).
        lon_c=deg2rad(-121.60)
        lat_c=deg2rad(39.78)
        val_ll=EarthSciData.interp!(itp_ll, ts_ll, Float32(lon_c), Float32(lat_c))

        val_lcc=EarthSciData.interp!(itp_lcc, ts_lcc, Float32(0.0), Float32(0.0))

        # Values should be close (not exact due to different grid resolutions).
        @test abs(val_ll - val_lcc) / max(abs(val_ll), abs(val_lcc)) < 0.1
    end
end
