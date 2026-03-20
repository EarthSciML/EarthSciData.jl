@testsnippet LANDFIRESetup begin
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

@testitem "LANDFIRE FileSet construction" setup = [LANDFIRESetup] tags = [:landfire] begin
    fs = EarthSciData.LANDFIREFileSet(domain)
    @test EarthSciData.varnames(fs) == ["fuel_model"]
    @test fs.product == "FBFM13"
    @test fs.version == "LF2022"
    @test fs.width > 0
    @test fs.height > 0
    @test fs.bbox[1] <= -121.65
    @test fs.bbox[3] >= -121.55
end

@testitem "LANDFIRE metadata" setup = [LANDFIRESetup] tags = [:landfire] begin
    fs = EarthSciData.LANDFIREFileSet(domain; resolution=10.0)
    md = EarthSciData.loadmetadata(fs, "fuel_model")
    @test md.unit_str == "1"
    @test length(md.coords) == 2
    @test md.xdim == 1
    @test md.ydim == 2
    @test md.zdim == -1
    @test issorted(md.coords[1])
    @test issorted(md.coords[2])
end

@testitem "LANDFIRE data loading" setup = [LANDFIRESetup] tags = [:landfire] begin
    fs = EarthSciData.LANDFIREFileSet(domain; resolution=10.0)
    md = EarthSciData.loadmetadata(fs, "fuel_model")
    data = zeros(Float32, md.varsize...)
    ts, _ = EarthSciMLBase.get_tspan_datetime(domain)
    EarthSciData.loadslice!(data, fs, ts, "fuel_model")
    # Should have valid Anderson 13 fuel model codes plus special values
    valid_codes = Set([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
        91, 92, 93, 98, 99, 101, 102, 103, 104, 105, 106, 107, 108, 109,
        121, 122, 123, 124, 141, 142, 143, 144, 145, 146, 147, 148, 149,
        161, 162, 163, 164, 165, 181, 182, 183, 184, 185, 186, 187, 188, 189,
        201, 202, 203, 204])
    unique_vals = Set(round.(Int, unique(data)))
    @test length(unique_vals) > 1  # Should have multiple fuel types
    @test all(v -> v in valid_codes || (v >= -9999 && v <= 9999), unique_vals)
end

@testitem "LANDFIRE nearest-neighbour interpolation" setup = [LANDFIRESetup] tags = [:landfire] begin
    fs = EarthSciData.LANDFIREFileSet(domain; resolution=10.0)
    ts, te = EarthSciMLBase.get_tspan_datetime(domain)

    metadata = EarthSciData.loadmetadata(fs, "fuel_model")
    model_grid = EarthSciData._compute_grid(domain, metadata.staggering)
    regrid_f = (dst, src; extrapolate_type=EarthSciData.Interpolations.Flat()) -> begin
        EarthSciData._nearest_interpolate_from!(dst, src, metadata, model_grid, domain;
            extrapolate_type=extrapolate_type)
    end
    fswr = EarthSciData.FileSetWithRegridder(fs, regrid_f)

    itp = EarthSciData.DataSetInterpolator{Float32}(
        fswr, "fuel_model", ts, te, domain; stream=true)
    lon_c = deg2rad(-121.60)
    lat_c = deg2rad(39.78)
    val = EarthSciData.interp(itp, ts, Float32(lon_c), Float32(lat_c))
    # Nearest-neighbour should produce integer-valued results
    @test val ≈ round(val)
    @test val >= 0
end

@testitem "LANDFIRE System" setup = [LANDFIRESetup] tags = [:landfire] begin
    sys = LANDFIRE(domain; resolution=10.0)
    @test sys isa ModelingToolkit.AbstractSystem
    @test length(equations(sys)) >= 1
    eq_names = [Symbolics.tosymbol(eq.lhs, escape=false) for eq in equations(sys)]
    @test :fuel_model ∈ eq_names
end
