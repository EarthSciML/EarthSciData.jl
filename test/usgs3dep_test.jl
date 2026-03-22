@testsnippet USGS3DEPSetup begin
    using EarthSciData
    using EarthSciMLBase
    using ModelingToolkit
    using Dates

    # Small domain near Paradise, CA (Camp Fire area)
    domain = DomainInfo(
        DateTime(2018, 11, 8),
        DateTime(2018, 11, 9);
        lonrange=deg2rad(-121.65):deg2rad(0.01):deg2rad(-121.55),
        latrange=deg2rad(39.73):deg2rad(0.01):deg2rad(39.83),
        levrange=1:1,
    )
end

@testitem "USGS3DEP FileSet construction" setup = [USGS3DEPSetup] tags = [:usgs3dep] begin
    fs = EarthSciData.USGS3DEPFileSet(domain)
    @test EarthSciData.varnames(fs) == ["elevation"]
    @test fs.width > 0
    @test fs.height > 0
    # Bounding box should enclose the domain
    @test fs.bbox[1] <= -121.65
    @test fs.bbox[3] >= -121.55
    @test fs.bbox[2] <= 39.73
    @test fs.bbox[4] >= 39.83
end

@testitem "USGS3DEP offline structural tests" setup = [USGS3DEPSetup] tags = [:usgs3dep] begin
    # These tests verify FileSet construction, metadata, and URL generation
    # without any network access.
    fs = EarthSciData.USGS3DEPFileSet(domain; resolution=10.0)

    # URL format
    u = EarthSciData.url(fs, DateTime(2018, 11, 8))
    @test startswith(u, "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage?")
    @test occursin("bbox=", u)
    @test occursin("bboxSR=4326", u)
    @test occursin("format=tiff", u)
    @test occursin("pixelType=F32", u)

    # relpath encodes bbox and dimensions
    rp = EarthSciData.relpath(fs, DateTime(2018, 11, 8))
    @test startswith(rp, "usgs3dep/elevation_")
    @test endswith(rp, ".tif")
    @test occursin("$(fs.width)x$(fs.height)", rp)

    # Metadata (computed from bbox, no download needed)
    md = EarthSciData.loadmetadata(fs, "elevation")
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

    # Pixel clamping: very fine resolution should hit the 4000-pixel cap
    fs_fine = EarthSciData.USGS3DEPFileSet(domain; resolution=0.001)
    @test fs_fine.width == 4000
    @test fs_fine.height == 4000

    # Invalid varname should error
    @test_throws AssertionError EarthSciData.loadmetadata(fs, "temperature")

    # Out-of-coverage domain should warn
    eu_domain = DomainInfo(
        DateTime(2018, 11, 8), DateTime(2018, 11, 9);
        lonrange=deg2rad(10.0):deg2rad(0.1):deg2rad(11.0),
        latrange=deg2rad(48.0):deg2rad(0.1):deg2rad(49.0),
        levrange=1:1,
    )
    @test_warn "outside USGS 3DEP coverage" EarthSciData.USGS3DEPFileSet(eu_domain)
end

@testitem "USGS3DEP metadata" setup = [USGS3DEPSetup] tags = [:usgs3dep] begin
    fs = EarthSciData.USGS3DEPFileSet(domain; resolution=10.0)  # coarse for speed
    md = EarthSciData.loadmetadata(fs, "elevation")
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

@testitem "USGS3DEP data loading" setup = [USGS3DEPSetup] tags = [:usgs3dep] begin
    fs = EarthSciData.USGS3DEPFileSet(domain; resolution=10.0)
    md = EarthSciData.loadmetadata(fs, "elevation")
    data = zeros(Float32, md.varsize...)
    ts, _ = EarthSciMLBase.get_tspan_datetime(domain)
    EarthSciData.loadslice!(data, fs, ts, "elevation")
    # Paradise area elevation should be roughly 100-1000m
    valid = data[data.>0]
    # At least 90% of pixels should have valid elevation data
    @test length(valid) / length(data) > 0.9
    @test minimum(valid) > 50
    @test maximum(data) < 3000
end

@testitem "USGS3DEP interpolator" setup = [USGS3DEPSetup] tags = [:usgs3dep] begin
    fs = EarthSciData.USGS3DEPFileSet(domain; resolution=10.0)
    ts, te = EarthSciMLBase.get_tspan_datetime(domain)
    itp = EarthSciData.DataSetInterpolator{Float32}(
        fs, "elevation", ts, te, domain; stream=true)
    # Interpolate at the centre of the domain
    lon_c = deg2rad(-121.60)
    lat_c = deg2rad(39.78)
    val = EarthSciData.interp(itp, ts, Float32(lon_c), Float32(lat_c))
    @test 50 < val < 3000
end

@testitem "USGS3DEP System" setup = [USGS3DEPSetup] tags = [:usgs3dep] begin
    sys = USGS3DEP(domain; resolution=10.0)
    @test sys isa ModelingToolkit.AbstractSystem
    @test length(equations(sys)) >= 1
    # Check that the elevation variable exists
    eq_names = [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(sys)]
    @test :elevation ∈ eq_names
end
