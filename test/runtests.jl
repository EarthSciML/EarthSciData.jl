using EarthSciMLData
using Test, SafeTestsets


@testset "EarthSciMLData.jl" begin
    @safetestset "load" begin include("load_test.jl") end
    @safetestset "geosfp" begin include("geosfp_test.jl") end
end
