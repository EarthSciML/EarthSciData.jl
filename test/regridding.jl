
@testitem "data2vecormat" begin
    d = zeros(1,2,3)
    d2 = EarthSciData.data2vecormat(d, 2, 3)
    @test size(d2) == (6,1)

    d = zeros(2,3)
    d2 = EarthSciData.data2vecormat(d, 2, 1)
    @test size(d2) == (6,)
end
