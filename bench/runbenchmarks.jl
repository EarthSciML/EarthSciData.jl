using BenchmarkTools
using EarthSciData
using Dates

const fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn")
const itp4 = EarthSciData.DataSetInterpolator{Float64}(fs, "U", DateTime(2022, 5, 1))
const ts = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
function interpfunc_serial()
    for t ∈ datetime2unix.(ts)
        for lon ∈ deg2rad.(-180.0:1:175), lat ∈ deg2rad.(-90:1:85)
            EarthSciData.interp!(itp4, t, lon, lat, 1.0)
        end
    end
end
function interpfunc_threads()
    for t ∈ datetime2unix.(ts)
        Threads.@threads for lon ∈ deg2rad.(-180.0:1:175)
            for lat ∈ deg2rad.(-90:1:85)
                EarthSciData.interp!(itp4, t, lon, lat, 1.0)
            end
        end
    end
end

suite = BenchmarkGroup()
suite["GEOSFP"] = BenchmarkGroup()
suite["GEOSFP"]["Interpolation serial"] = @benchmarkable interpfunc_serial()
suite["GEOSFP"]["Interpolation threaded"] = @benchmarkable interpfunc_threads()

tune!(suite, verbose = true)
results = run(suite, verbose = true)

BenchmarkTools.save("output.json", median(results))