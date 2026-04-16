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
        @test dimension(unit) == dimension(Quantity(1.0))

        # Test (0 - 1) → dimensionless
        scale, unit = EarthSciData.to_unit("(0 - 1)")
        @test scale == 1
        @test dimension(unit) == dimension(Quantity(1.0))
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
end
