using EarthSciData
using Dates
using ModelingToolkit
using Random
using Latexify, LaTeXStrings

fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn")
t = DateTime(2022, 5, 1)
@test EarthSciData.url(fs, t) == "http://geoschemdata.wustl.edu/ExtData/GEOS_4x5/GEOS_FP/2022/05/GEOSFP.20220501.A3dyn.4x5.nc"

@test endswith(EarthSciData.localpath(fs, t), joinpath("GEOS_4x5", "GEOS_FP", "2022", "05", "GEOSFP.20220501.A3dyn.4x5.nc"))

ti = EarthSciData.DataFrequencyInfo(fs, t)
epp = EarthSciData.endpoints(ti)

@test epp[1] == (DateTime("2022-05-01T00:00:00"), DateTime("2022-05-01T03:00:00"))
@test epp[8] == (DateTime("2022-05-01T21:00:00"), DateTime("2022-05-02T00:00:00"))

dat = EarthSciData.loadslice!(zeros(10), fs, t, "U")
@test size(dat.data) == (72, 46, 72)
@test dat.dimnames == ["lon", "lat", "lev"]

itp = EarthSciData.DataSetInterpolator{Float32}(fs, "U")

@test String(latexify(itp)) == L"$\mathrm{EarthSciData}\left( GEOSFPFileSet_{x}U_{interp} \right)$"

@test EarthSciData.dimnames(itp, t) == ["lon", "lat", "lev"]
@test issetequal(EarthSciData.varnames(fs, t), ["U", "OMEGA", "RH", "DTRAIN", "V"])

@testset "interpolation" begin
    uvals = []
    times = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
    for t ∈ times
        push!(uvals, interp!(itp, t, 1.0, 0.0, 1.0))
    end
    for i ∈ 4:3:length(uvals)-1
        @test uvals[i] ≈ (uvals[i-1] + uvals[i+1]) / 2
    end
    want_uvals = [-0.0474265694618225, 0.06403500636418662, 0.1116628348827362, 0.0954569160938263, 0.07925099730491639, 
                -0.011302002271016437, -0.1762020826339722, -0.34110216299692797, -0.5013981193304062, -0.6570899516344071]
    @test uvals[1:10] ≈ want_uvals

    # Test that shuffling the times doesn't change the results.
    uvals2 = []
    idx = randperm(length(times))
    for t ∈ times[idx]
        push!(uvals2, interp!(itp, t, 1.0, 0.0, 1.0))
    end
    @test uvals2 ≈ uvals[idx]
end

#== Profile data loading and interpolation.
fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn")
itp = EarthSciData.DataSetInterpolator(fs, "U")
ts = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
function interpfunc()
    for t ∈ ts 
        Threads.@threads for lon ∈ -180:1:175
            for lat ∈ -90:1:85
                interp!(itp, t, lon, lat, 1.0)
            end
        end
    end
end
interpfunc()
@profview interpfunc()
==#