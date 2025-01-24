using EarthSciData
using Dates
using ModelingToolkit
using Random
using Latexify, LaTeXStrings
using AllocCheck
using DynamicQuantities
using Interpolations
using Test

t = DateTime(2022, 5, 1)
te = DateTime(2022, 5, 3)
fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn", t, te)
spatial_ref = "+proj=longlat +datum=WGS84 +no_defs"
@test EarthSciData.url(fs, t) == "https://geos-chem.s3-us-west-2.amazonaws.com/GEOS_4x5/GEOS_FP/2022/05/GEOSFP.20220501.A3dyn.4x5.nc"

@test endswith(EarthSciData.localpath(fs, t), joinpath("GEOS_4x5", "GEOS_FP", "2022", "05", "GEOSFP.20220501.A3dyn.4x5.nc"))

ti = EarthSciData.DataFrequencyInfo(fs)
epp = EarthSciData.endpoints(ti)

@test epp[begin] == (DateTime("2022-04-30T00:00:00"), DateTime("2022-04-30T03:00:00"))
@test epp[end] == (DateTime("2022-05-03T21:00:00"), DateTime("2022-05-04T00:00:00"))

metadata = EarthSciData.loadmetadata(fs, "U")
@test metadata.varsize == [72, 46, 72]
@test metadata.dimnames == ["lon", "lat", "lev"]

itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t, te, spatial_ref)

@test String(latexify(itp)) == "\$\\mathrm{GEOSFPFileSet}\\left( U \\right)\$"

@test EarthSciData.dimnames(itp) == ["lon", "lat", "lev"]
@test issetequal(EarthSciData.varnames(fs), ["U", "OMEGA", "RH", "DTRAIN", "V"])

@testset "interpolation" begin
    uvals = []
    times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
    for t ∈ times
        push!(uvals, interp!(itp, t, deg2rad(1.0f0), deg2rad(0.0f0), 1.0f0))
    end
    for i ∈ 4:3:length(uvals)-1
        @test uvals[i] ≈ (uvals[i-1] + uvals[i+1]) / 2 atol = 1e-2
    end
    want_uvals = [-0.047425747f0, 0.064035736f0, 0.11166346f0, 0.09545743f0, 0.07925139f0,
        -0.011301707f0, -0.17620188f0, -0.34110206f0, -0.501398f0, -0.65708977f0]
    @test uvals[1:10] ≈ want_uvals

    # Test that shuffling the times doesn't change the results.
    uvals2 = []
    idx = randperm(length(times))
    for t ∈ times[idx]
        push!(uvals2, interp!(itp, t, deg2rad(1.0f0), deg2rad(0.0f0), 1.0f0))
    end
    @test uvals2 ≈ uvals[idx]
end

@testset "DummyFileSet" begin
    struct DummyFileSet <: EarthSciData.FileSet
        start::DateTime
        finish::DateTime
    end

    function EarthSciData.DataFrequencyInfo(fs::DummyFileSet)::EarthSciData.DataFrequencyInfo
        frequency = Second(3 * 3600)
        centerpoints = collect(fs.start+frequency/2:frequency:fs.finish)
        EarthSciData.DataFrequencyInfo(fs.start, frequency, centerpoints)
    end

    tv(fs, t) = (t - fs.start) / (fs.finish - fs.start)

    function EarthSciData.loadslice!(cache::AbstractArray, fs::DummyFileSet, t::DateTime, varname)
        dfi = EarthSciData.DataFrequencyInfo(fs)
        tt = dfi.centerpoints[EarthSciData.centerpoint_index(dfi, t)]
        v = tv(fs, tt)
        cache .= [v, v * 0.5, v * 2.0]
    end
    function EarthSciData.loadmetadata(fs::DummyFileSet, varname)
        return EarthSciData.MetaData([[0.0, 0.5, 1.0]], u"m", "description", ["x"], [3], "+proj=longlat +datum=WGS84 +no_defs", 1, 1)
    end

    fs = DummyFileSet(DateTime(2022, 4, 30), DateTime(2022, 5, 4))

    @testset "big cache" begin
        @test_nowarn EarthSciData.DataSetInterpolator{Float32}(fs, "U", DateTime(2022, 5, 1), DateTime(2022, 5, 3),
            spatial_ref; stream=false)
    end

    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U", DateTime(2022, 5, 1), DateTime(2022, 5, 3),
        spatial_ref; stream=true)
    dfi = EarthSciData.DataFrequencyInfo(fs)

    answerdata = [tv(fs, t) * v for t ∈ dfi.centerpoints, v ∈ [1.0, 0.5, 2.0]]

    grid = Tuple(EarthSciData.knots2range.([datetime2unix.(dfi.centerpoints), [0.0, 0.5, 1.0]]))
    answer_itp = scale(interpolate(answerdata, BSpline(Linear())), grid)

    times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
    xs = [0.0f0, 0.25f0, 0.75f0]

    uvals = zeros(Float32, length(times), length(xs))
    answers = zeros(Float32, length(times), length(xs))
    for (i, tt) ∈ enumerate(times)
        for (j, x) ∈ enumerate(xs)
            uvals[i, j] = interp!(itp, tt, x)
            answers[i, j] = answer_itp(datetime2unix(tt), x)
        end
    end

    @test uvals ≈ answers

    interp!(itp, times[end], xs[end])
    @test length(itp.times) == 2
    @test itp.times == [DateTime("2022-05-02T22:30:00"), DateTime("2022-05-03T01:30:00")]

    uvals = zeros(Float32, length(times), length(xs))
    answers = zeros(Float32, length(times), length(xs))
    for i ∈ randperm(length(times))
        tt = times[i]
        for j ∈ randperm(length(xs))
            x = xs[j]
            uvals[i, j] = interp!(itp, tt, x)
            answers[i, j] = answer_itp(datetime2unix(tt), x)
        end
    end
    @test uvals ≈ answers

    @testset "no stream" begin
        itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U", DateTime(2022, 5, 1),
            DateTime(2022, 5, 2), spatial_ref; stream=false)

        uvals = zeros(Float32, length(times), length(xs))
        answers = zeros(Float32, length(times), length(xs))
        for (i, tt) ∈ enumerate(times)
            for (j, x) ∈ enumerate(xs)
                uvals[i, j] = interp!(itp, tt, x)
                answers[i, j] = answer_itp(datetime2unix(tt), x)
            end
        end

        @test uvals ≈ answers
    end
end

@testset "allocations" begin
    itp = EarthSciData.DataSetInterpolator{Float64}(fs, "U", t, te, spatial_ref)
    tt = DateTime(2022, 5, 1)
    interp!(itp, tt, 1.0, 0.0, 1.0)

    @test begin
        @check_allocs checkf(itp, t, loc1, loc2, loc3) = EarthSciData.interp_unsafe(itp, t, loc1, loc2, loc3)

        try
            checkf(itp, tt, 1.0, 0.0, 1.0)
        catch err
            @warn err.errors
            rethrow(err)
        end

        itp2 = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t, te, spatial_ref)
        interp!(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
        checkf(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
        true
    end
end
