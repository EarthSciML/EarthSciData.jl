using EarthSciData
using Test
using Logging

@testset "regridding" begin
    @testset "data2vecormat" begin
        d = zeros(1, 2, 3)
        d2 = EarthSciData.data2vecormat(d, 2, 3)
        @test size(d2) == (6, 1)

        d = zeros(2, 3)
        d2 = EarthSciData.data2vecormat(d, 2, 1)
        @test size(d2) == (6,)
    end

    @testset "non-uniform axis (GEOS-FP half-polar latitude)" begin
        # True GEOS-FP 0.25x0.3125 latitude axis: half-size polar rows give
        # spacings {0.1875, 0.25} deg -- NOT uniform.
        lat = [-89.9375; collect(-89.75:0.25:89.75); 89.9375]
        lon = collect(0.0:0.3125:3.125)
        f(x, y) = 2y + 0.01y^2
        src = [f(x, y) for x in lon, y in lat]

        @test !EarthSciData.isuniform(lat)
        @test EarthSciData.isuniform(collect(-90.0:4.0:90.0))
        # forcing a range onto the non-uniform axis must now be an error,
        # not silent corruption
        @test_throws AssertionError EarthSciData.knots2range(lat)

        itp = EarthSciData._build_regrid_interp(
            copy(src), [lon, lat], EarthSciData.Flat())
        # Exact reproduction at the native knots. The previous uniformized-range
        # path was off by ~0.078 here (a ~3 km poleward displacement at 40N).
        @test itp(lon[2], 40.0) ≈ f(lon[2], 40.0) atol = 1.0e-12
        @test itp(lon[2], 25.0) ≈ f(lon[2], 25.0) atol = 1.0e-12
        @test itp(lon[2], -89.9375) ≈ f(lon[2], -89.9375) atol = 1.0e-12
        # uniform axes still take the fast path and reproduce knots exactly
        itp_u = EarthSciData._build_regrid_interp(
            copy(src[:, 2:42]), [lon, collect(-89.75:0.25:-79.75)], EarthSciData.Flat())
        @test itp_u(lon[2], -85.0) ≈ f(lon[2], -85.0) atol = 1.0e-12
    end

    @testset "planar_regridder" begin
        square(x, y, d) = [(x, y), (x + d, y), (x + d, y + d), (x, y + d), (x, y)]
        dst = [square(x, y, 1.0) for y in 0:2 for x in 0:2]
        src = [square(x, y, 0.7) for y in 0.0:0.7:2.1 for x in 0.0:0.7:2.1]
        # No `crstrait` deprecation warning (logged at Warn under `--depwarn=yes`).
        rg = @test_logs min_level=Logging.Warn EarthSciData.planar_regridder(dst, src)
        ref = with_logger(NullLogger()) do
            EarthSciData.ConservativeRegridding.Regridder(dst, src)
        end
        @test rg.intersections == ref.intersections
        @test rg.dst_areas == ref.dst_areas
        @test rg.src_areas == ref.src_areas
    end
end
