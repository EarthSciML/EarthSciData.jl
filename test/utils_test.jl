using EarthSciData
using DynamicQuantities
using Test

@testset "utils" begin
    @testset "to_unit new entries" begin
        # Test s-1
        scale, unit = EarthSciData.to_unit("s-1")
        @test scale == 1
        @test unit == u"s^-1"

        # Test K m2 kg-1 s-1
        scale, unit = EarthSciData.to_unit("K m2 kg-1 s-1")
        @test scale == 1
        @test unit == u"K*m^2/kg/s"

        # Test % (percentage → dimensionless with scale 0.01)
        scale, unit = EarthSciData.to_unit("%")
        @test scale == 0.01
        @test DynamicQuantities.dimension(unit) == DynamicQuantities.dimension(Quantity(1.0))

        # Test (0 - 1) → dimensionless
        scale, unit = EarthSciData.to_unit("(0 - 1)")
        @test scale == 1
        @test DynamicQuantities.dimension(unit) == DynamicQuantities.dimension(Quantity(1.0))
    end

    @testset "to_unit CF convention ** normalization" begin
        # CF-convention uses ** for exponents (e.g., "m s**-1").
        # The ** should be stripped, mapping to the existing "m s-1" entry.
        scale, unit = EarthSciData.to_unit("m s**-1")
        @test scale == 1
        @test unit == u"m/s"

        # "Pa s**-1" → "Pa s-1"
        scale, unit = EarthSciData.to_unit("Pa s**-1")
        @test scale == 1
        @test unit == u"Pa/s"

        # "kg kg**-1" → "kg kg-1"
        scale, unit = EarthSciData.to_unit("kg kg**-1")
        @test scale == 1
        @test unit == u"kg/kg"

        # "m**2 s**-2" → "m2 s-2"
        scale, unit = EarthSciData.to_unit("m**2 s**-2")
        @test scale == 1
        @test unit == u"m^2/s^2"

        # "K m**2 kg**-1 s**-1" → "K m2 kg-1 s-1"
        scale, unit = EarthSciData.to_unit("K m**2 kg**-1 s**-1")
        @test scale == 1
        @test unit == u"K*m^2/kg/s"
    end

    @testset "to_unit existing entries" begin
        # Verify a selection of pre-existing entries still work.
        @test EarthSciData.to_unit("K") == (1, u"K")
        @test EarthSciData.to_unit("m") == (1, u"m")
        @test EarthSciData.to_unit("Pa") == (1, u"Pa")
        @test EarthSciData.to_unit("hPa") == (100, u"Pa")
        @test EarthSciData.to_unit("m s-1") == (1, u"m/s")

        # Whitespace stripping
        @test EarthSciData.to_unit("  K  ") == (1, u"K")

        # Unregistered unit should error.
        @test_throws Exception EarthSciData.to_unit("furlongs/fortnight")
    end

    @testset "_download_with_progress retries transient failures" begin
        mktempdir() do dir
            fileurl(p) = begin
                pp = replace(p, '\\' => '/')
                "file://" * (startswith(pp, '/') ? pp : "/" * pp)
            end
            # Happy path: a local file:// URL downloads on the first attempt.
            src = joinpath(dir, "src.bin")
            write(src, "payload")
            dst = joinpath(dir, "dst.bin")
            @test EarthSciData._download_with_progress(fileurl(src), dst) == dst
            @test read(dst, String) == "payload"

            # Failure path: an unresolvable URL fails fast per attempt; with
            # retries=1 exactly one retry warning fires before the rethrow,
            # and the partial file is cleaned up.
            bad = joinpath(dir, "bad.bin")
            badurl = fileurl(joinpath(dir, "nonexistent.bin"))
            @test_logs (:warn, "Download failed; retrying") match_mode=:any begin
                @test_throws Exception EarthSciData._download_with_progress(
                    badurl, bad; retries = 1)
            end
            @test !isfile(bad)

            # Environment overrides parse into the keyword defaults.
            withenv("EARTHSCIDATA_DOWNLOAD_TIMEOUT" => "42.5",
                "EARTHSCIDATA_DOWNLOAD_RETRIES" => "0") do
                # retries=0 → no retry warning, single attempt, still throws.
                @test_logs min_level=Base.CoreLogging.Warn begin
                    @test_throws Exception EarthSciData._download_with_progress(
                        badurl, bad)
                end
            end
        end
    end
end
