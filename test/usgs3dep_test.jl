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
    @test any(data .> 0)
    @test minimum(data[data.>0]) > 50
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
