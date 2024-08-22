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

using EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t, D
using DomainSets, Dates
using DifferentialEquations
using DynamicQuantities

struct SysCoupler
    sys
end
function EarthSciMLBase.couple2(sys::SysCoupler, emis::EarthSciData.NEI2016MonthlyEmisCoupler)
    sys, emis = sys.sys, emis.sys
    operator_compose(sys, emis)
end
function nei_simulator()
    @parameters lat = 0.0 lon = 0.0 lev = 0.0
    @variables ACET(t) = 0.0 [unit = u"kg*m^-3"]
    @constants c = 1000 [unit = u"s"]
    
    @named sys = ODESystem(
        [D(ACET) ~ 0], t,
        metadata=Dict(:coupletype => SysCoupler)
    )
    
    emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", lon, lat, lev; dtype=Float64)
    
    starttime = datetime2unix(DateTime(2016, 5, 1))
    endtime = datetime2unix(DateTime(2016, 5, 2))
    domain = DomainInfo(
        constIC(16.0, t ∈ Interval(starttime, endtime)),
        constBC(16.0,
            lon ∈ Interval(-130.0, -60.0),
            lat ∈ Interval(9.75, 60.0),
            lev ∈ Interval(1, 2)
        ))
    
    csys = couple(sys, emis, domain)
    
    Simulator(csys, [2.0, 2.0, 1])    
end

suite["NEI Simulator"] = BenchmarkGroup()
sim = nei_simulator()
st = SimulatorStrangSerial(Tsit5(), Euler(), 100.0)
suite["NEI Simulator"]["Serial"] = @benchmarkable run!($sim, $st)

st = SimulatorStrangThreads(Tsit5(), Euler(), 100.0)
suite["NEI Simulator"]["Threads"] = @benchmarkable run!($sim, $st)


tune!(suite, verbose = true)
results = run(suite, verbose = true)

BenchmarkTools.save("output.json", median(results))