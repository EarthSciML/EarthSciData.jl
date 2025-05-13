using EarthSciData
using Test
using DynamicQuantities, EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t
using Dates
using DifferentialEquations
import Proj
using AllocCheck

domain = DomainInfo(
    DateTime(2016, 5, 1),
    DateTime(2016, 5, 2);
    latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
    lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
    levrange = 1:10,
    dtype = Float64
)
lon, lat, lev = EarthSciMLBase.pvars(domain)

ts, te = get_tspan_datetime(domain)
sample_time = ts

emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)

eqs = equations(emis)
@test length(eqs) == 69
@test contains(string(eqs[1].rhs), "/ Δz")

sample_time = DateTime(2016, 5, 1)

@testset "correct projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    @test interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0)) ≈ 1.256768f-9
end

@testset "incorrect projection" begin
    domain = DomainInfo(
        DateTime(2016, 5, 1),
        DateTime(2016, 5, 2);
        latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
        lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
        levrange = 1:10,
        dtype = Float64,
        spatial_ref = "+proj=axisswap +order=2,1 +step +proj=longlat +datum=WGS84 +no_defs"
    )
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    @test_throws Proj.PROJError interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
end

@testset "Out of domain" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    @test interp!(itp, sample_time, deg2rad(0.0f0), deg2rad(40.0f0)) ≈ 0.0
end

@testset "monthly frequency" begin
    ts, te = DateTime(2016, 5, 1), DateTime(2016, 6, 1)
    fileset = EarthSciData.NEI2016MonthlyEmisFileSet("mrggrid_withbeis_withrwc", ts, te)
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    EarthSciData.lazyload!(itp, sample_time)
    ti = EarthSciData.DataFrequencyInfo(itp.fs)
    @test month(itp.times[1]) == 4
    @test month(itp.times[2]) == 5

    sample_time = DateTime(2016, 5, 31)
    EarthSciData.lazyload!(itp, sample_time)
    @test month(itp.times[1]) == 5
    @test month(itp.times[2]) == 6
end

@testset "run" begin
    @constants uc = 1.0 [unit = u"s" description = "unit conversion"]
    eq = Differential(t)(emis.ACET) ~ equations(emis)[1].rhs * 1e10 / uc
    sys = extend(ODESystem([eq], t, [], []; name = :test_sys), emis)
    sys = structural_simplify(sys)
    tt = Dates.datetime2unix(sample_time)
    prob = ODEProblem(
        sys,
        zeros(1),
        (tt, tt + 60.0),
        [lat => deg2rad(40.0), lon => deg2rad(-97.0), lev => 1.0]
    )
    sol = solve(prob)
    @test 2 > sol.u[end][end] > 1
end

if !Sys.iswindows() # Allocation tests don't seem to work on windows.
    @testset "allocations" begin
        @check_allocs checkf(
            itp, t, loc1, loc2) = EarthSciData.interp_unsafe(itp, t, loc1, loc2)

        sample_time = DateTime(2016, 5, 1)
        itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
        interp!(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        # If there is an error, it should occur in the proj library.
        # https://github.com/JuliaGeo/Proj.jl/issues/104
        try
            checkf(itp, sample_time, deg2rad(-97.0f0), deg2rad(40.0f0))
        catch err
            @test length(err.errors) == 1
            s = err.errors[1]
            contains(string(s), "libproj.proj_trans")
        end

        itp2 = EarthSciData.DataSetInterpolator{Float64}(fileset, "NOX", ts, te, domain)
        interp!(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        try # If there is an error, it should occur in the proj library.
            checkf(itp2, sample_time, deg2rad(-97.0), deg2rad(40.0))
        catch err
            @test length(err.errors) == 1
            s = err.errors[1]
            contains(string(s), "libproj.proj_trans")
        end
    end
end

@testset "Coupling with GEOS-FP" begin
    gfp = GEOSFP("4x5", domain)

    csys = couple(emis, gfp)
    sys = convert(ODESystem, csys, prune = false)
    eqs = observed(sys)

    @test occursin("NEI2016MonthlyEmis₊lat(t) ~ GEOSFP₊lat", string(eqs))
end

@testset "wrong year" begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(fileset, "NOX", ts, te, domain)
    sample_time = DateTime(2017, 5, 1)
    @test_throws ArgumentError EarthSciData.lazyload!(itp, sample_time)
end
