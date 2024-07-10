using EarthSciData
using Dates
using ModelingToolkit
using Random
using Latexify, LaTeXStrings
using AllocCheck
using Unitful
using GridInterpolations

fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn")
t = DateTime(2022, 5, 1)
@test EarthSciData.url(fs, t) == "http://geoschemdata.wustl.edu/ExtData/GEOS_4x5/GEOS_FP/2022/05/GEOSFP.20220501.A3dyn.4x5.nc"

@test endswith(EarthSciData.localpath(fs, t), joinpath("GEOS_4x5", "GEOS_FP", "2022", "05", "GEOSFP.20220501.A3dyn.4x5.nc"))

ti = EarthSciData.DataFrequencyInfo(fs, t)
epp = EarthSciData.endpoints(ti)

@test epp[1] == (DateTime("2022-05-01T00:00:00"), DateTime("2022-05-01T03:00:00"))
@test epp[8] == (DateTime("2022-05-01T21:00:00"), DateTime("2022-05-02T00:00:00"))

dat, metadata = EarthSciData.loadslice(fs, t, "U")
@test size(dat) == (72, 46, 72)
@test metadata.dimnames == ["lon", "lat", "lev"]

itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t)

@test String(latexify(itp)) == L"$\mathrm{EarthSciData}\left( GEOSFPFileSet_{x}U_{interp} \right)$"

@test EarthSciData.dimnames(itp, t) == ["lon", "lat", "lev"]
@test issetequal(EarthSciData.varnames(fs, t), ["U", "OMEGA", "RH", "DTRAIN", "V"])

@testset "interpolation" begin
    uvals = []
    times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
    for t ∈ times
        push!(uvals, interp!(itp, t, 1.0f0, 0.0f0, 1.0f0))
    end
    for i ∈ 4:3:length(uvals)-1
        @test uvals[i] ≈ (uvals[i-1] + uvals[i+1]) / 2 atol = 1e-2
    end
    want_uvals = [-0.047426544f0, 0.06353962f0, 0.111806884f0, 0.09567301f0, 0.07896289f0, -0.01350067f0, -0.17766784f0,
        -0.3418351f0, -0.50139815f0, -0.65639806f0]
    @test uvals[1:10] ≈ want_uvals

    # Test that shuffling the times doesn't change the results.
    uvals2 = []
    idx = randperm(length(times))
    for t ∈ times[idx]
        push!(uvals2, interp!(itp, t, 1.0f0, 0.0f0, 1.0f0))
    end
    @test uvals2 ≈ uvals[idx]
end

@testset "DummyFileSet" begin
    struct DummyFileSet <: EarthSciData.FileSet
        start::DateTime
        finish::DateTime
    end

    function EarthSciData.DataFrequencyInfo(fs::DummyFileSet, t::DateTime)::EarthSciData.DataFrequencyInfo
        frequency = Second(3 * 3600)
        centerpoints = collect(fs.start+frequency/2:frequency:fs.finish)
        EarthSciData.DataFrequencyInfo(t, frequency, centerpoints)
    end

    tv(fs, t) = (t - fs.start) / (fs.finish - fs.start)

    function EarthSciData.loadslice!(cache::AbstractArray, fs::DummyFileSet, t::DateTime, varname)
        dfi = EarthSciData.DataFrequencyInfo(fs, t)
        tt = dfi.centerpoints[EarthSciData.centerpoint_index(dfi, t)]
        v = tv(fs, tt)
        cache .= [v, v * 0.5, v * 2.0]
    end
    function EarthSciData.loadslice(fs::DummyFileSet, t::DateTime, varname)
        cache = zeros(3)
        EarthSciData.loadslice!(cache, fs, t, varname)
        return cache, EarthSciData.MetaData([[0.0, 0.5, 1.0]], u"m", "description", ["x"], "EPSG:4326", 1, 1)
    end

    fs = DummyFileSet(DateTime(2022, 4, 30), DateTime(2022, 5, 4))

    itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U", fs.start; cache_size=5)
    dfi = EarthSciData.DataFrequencyInfo(fs, t)

    answerdata = [tv(fs, t) * v for t ∈ dfi.centerpoints, v ∈ [1.0, 0.5, 2.0]]
    answer_itp = RectangleGrid(datetime2unix.(dfi.centerpoints), [0.0, 0.5, 1.0])

    times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
    xs = [0.0f0, 0.25f0, 0.75f0]

    uvals = zeros(Float32, length(times), length(xs))
    answers = zeros(Float32, length(times), length(xs))
    for (i, tt) ∈ enumerate(times)
        for (j, x) ∈ enumerate(xs)
            uvals[i, j] = interp!(itp, tt, x)
            answers[i, j] = interpolate(answer_itp, answerdata, [datetime2unix(tt), x])
        end
    end

    @test uvals ≈ answers

    @test length(itp.times) == 5
    @test itp.times == [DateTime("2022-05-02T22:30:00"), DateTime("2022-05-03T01:30:00"),
        DateTime("2022-05-03T04:30:00"), DateTime("2022-05-03T07:30:00"),
        DateTime("2022-05-03T10:30:00")]

    uvals = zeros(Float32, length(times), length(xs))
    answers = zeros(Float32, length(times), length(xs))
    for i ∈ randperm(length(times))
        tt = times[i]
        for j ∈ randperm(length(xs))
            x = xs[j]
            uvals[i, j] = interp!(itp, tt, x)
            answers[i, j] = interpolate(answer_itp, answerdata, [datetime2unix(tt), x])
        end
    end
    @test uvals ≈ answers
end

@testset "allocations" begin
    itp = EarthSciData.DataSetInterpolator{Float64}(fs, "U", t)
    tt = DateTime(2022, 5, 1)
    interp!(itp, tt, 1.0, 0.0, 1.0)

    @test_broken begin
        @check_allocs checkf(itp, t, loc1, loc2, loc3) = EarthSciData.interp_unsafe(itp, t, loc1, loc2, loc3)

        try
            checkf(itp, tt, 1.0, 0.0, 1.0)
        catch err
            @warn err.errors
            rethrow(err)
        end

        itp2 = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t)
        interp!(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
        checkf(itp2, tt, 1.0f0, 0.0f0, 1.0f0)
    end
end

#== Profile data loading and interpolation.
fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn")
const itp4 = EarthSciData.DataSetInterpolator{Float32}(fs, "U", t)
ts = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
function interpfunc()
    for t ∈ ts 
        for lon ∈ -180f0:1f0:175f0
            for lat ∈ -90f0:1f0:85f0
                #interp!(itp4, t, lon, lat, 1.0f0)
                interp_unsafe(itp4, t, lon, lat, 1.0f0)
            end
        end
    end
end
interpfunc()
@profview interpfunc()
==#