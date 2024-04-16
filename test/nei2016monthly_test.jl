using EarthSciData
using Test
using Unitful, EarthSciMLBase, ModelingToolkit
using Dates
using AllocCheck

@parameters t lat lon lev
@parameters Δz = 60 [unit = u"m"]
emis = NEI2016MonthlyEmis{Float64}("mrggrid_withbeis_withrwc", t, lon, lat, lev, Δz)

eqs = equations(emis.sys)
@test length(eqs) == 69
@test contains(string(eqs[1].rhs), "/ Δz")

sample_time = DateTime(2016, 5, 1)
@testset "correct projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    @test interp!(itp, sample_time, -97.0f0, 40.0f0, 1.0f0) ≈ 8.198218f-10
    @test interp!(itp, sample_time, -97.0f0, 40.0f0, 2.0f0) == 0.0f0
end

@testset "incorrect projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX", sample_time; spatial_ref="EPSG:3857")
    @test interp!(itp, sample_time, -97.0f0, 40.0f0, 1.0f0) == 0.0f0
end

@testset "monthly frequency" begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    EarthSciData.initialize!(itp, sample_time)
    @test_broken month(itp.time1) == 4 #TODO(CT): Fix by adding next() and previous() methods instead of adding and subtracting frequency.
    @test month(itp.time2) == 5

    sample_time = DateTime(2016, 5, 31)
    EarthSciData.initialize!(itp, sample_time)
    @test month(itp.time1) == 5
    @test_broken month(itp.time2) == 6
end

@testset "allocations" begin
    @check_allocs checkf(itp, t, loc1, loc2, loc3) = EarthSciData.interp_unsafe(itp, t, loc1, loc2, loc3)
    
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    interp!(itp, sample_time, -97.0f0, 40.0f0, 1.0f0)
    #@test_nowarn checkf(itp, sample_time, -97.0f0, 40.0f0, 1.0f0)
    try # If there is an error, it should occur in the proj library.
        checkf(itp, sample_time, -97.0f0, 40.0f0, 1.0f0)
    catch err
        @test length(err.errors) == 1
        s = err.errors[1]
        @test contains(string(s), "libproj.proj_trans")
    end

    itp2 = EarthSciData.DataSetInterpolator{Float64}(emis.fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    interp!(itp2, sample_time, -97.0, 40.0, 1.0)
    #@test_nowarn checkf(itp2, sample_time, -97.0, 40.0, 1.0)
    try # If there is an error, it should occur in the proj library.
        checkf(itp2, sample_time, -97.0, 40.0, 1.0)
    catch err
        @test length(err.errors) == 1
        s = err.errors[1]
        @test contains(string(s), "libproj.proj_trans")
    end
end