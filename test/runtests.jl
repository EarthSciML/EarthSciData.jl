using EarthSciData
using Test, SafeTestsets


@testset "EarthSciData.jl" begin
    @safetestset "load" begin include("load_test.jl") end
    @safetestset "geosfp" begin include("geosfp_test.jl") end
end
