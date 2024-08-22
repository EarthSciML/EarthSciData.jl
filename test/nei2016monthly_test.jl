using Main.EarthSciData
using Test
using DynamicQuantities, EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t
using Dates
using DifferentialEquations
using AllocCheck

@parameters lat lon lev
emis, updater = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", lon, lat, lev; dtype=Float64)
fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc")

eqs = equations(emis)
@test length(eqs) == 69
@test contains(string(eqs[1].rhs), "/ Δz")

sample_time = DateTime(2016, 5, 1)
@testset "correct projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    @test interp!(itp, sample_time, -97.0f0, 40.0f0, 1.0f0) ≈ 9.211331f-10
    @test interp!(itp, sample_time, -97.0f0, 40.0f0, 2.0f0) == 0.0f0
end

@testset "incorrect projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", sample_time; spatial_ref="EPSG:3857")
    @test interp!(itp, sample_time, -97.0f0, 40.0f0, 1.0f0) == 0.0f0
end

@testset "monthly frequency" begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    EarthSciData.initialize!(itp, sample_time)
    ti = EarthSciData.DataFrequencyInfo(itp.fs, sample_time)
    @test month(itp.times[1]) == 4
    @test month(itp.times[2]) == 5

    sample_time = DateTime(2016, 5, 31)
    EarthSciData.initialize!(itp, sample_time)
    @test month(itp.times[1]) == 5
    @test month(itp.times[2]) == 6
end

@testset "run" begin
    @constants uc = 1.0 [unit = u"s" description="unit conversion"]
    eq = Differential(t)(emis.ACET) ~ equations(emis)[1].rhs * 1e10 / uc
    sys = extend(ODESystem([eq], t, [], []; name=:test_sys), emis)
    sys = structural_simplify(sys)
    tt = Dates.datetime2unix(sample_time)
    EarthSciData.lazyload!(updater, tt)
    prob = ODEProblem(sys, zeros(1), (tt, tt + 60.0), [lat => 40.0, lon => -97.0, lev => 1.0])
    sol = solve(prob)
    @test 2 > sol[end][end] > 1
end

@testset "allocations" begin
    @check_allocs checkf(itp, t, loc1, loc2, loc3) = EarthSciData.interp_unsafe(itp, t, loc1, loc2, loc3)

    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    interp!(itp, sample_time, -97.0f0, 40.0f0, 1.0f0)
    @test_broken checkf(itp, sample_time, -97.0f0, 40.0f0, 1.0f0) # https://github.com/JuliaGeo/Proj.jl/issues/104
    try # If there is an error, it should occur in the proj library.
        checkf(itp, sample_time, -97.0f0, 40.0f0, 1.0f0)
    catch err
        @warn err.errors
        @test_broken length(err.errors) == 1
        s = err.errors[1]
        contains(string(s), "libproj.proj_trans")
    end

    itp2 = EarthSciData.DataSetInterpolator{Float64}(fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    interp!(itp2, sample_time, -97.0, 40.0, 1.0)
    #@test_nowarn checkf(itp2, sample_time, -97.0, 40.0, 1.0)
    try # If there is an error, it should occur in the proj library.
        checkf(itp2, sample_time, -97.0, 40.0, 1.0)
    catch err
        @warn err.errors
        @test_broken length(err.errors) == 1
        s = err.errors[1]
        contains(string(s), "libproj.proj_trans")
    end
end

@testset "Coupling with GEOS-FP" begin
    gfp = GEOSFP("4x5"; dtype=Float64,
        coord_defaults=Dict(:lon => 0.0, :lat => 0.0, :lev => 1.0))

    eqs = equations(convert(ODESystem, couple(emis, gfp)))

    @test occursin("NEI2016MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
end

@testset "wrong year" begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", sample_time; spatial_ref="EPSG:4326")
    sample_time = DateTime(2017, 5, 1)
    try
        EarthSciData.initialize!(itp, sample_time)
    catch err
        @test occursin("Only 2016 emissions data is available with `NEI2016MonthlyEmis`.", string(err))
    end
end