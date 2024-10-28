using BenchmarkTools
using EarthSciData
using Dates

const fs = EarthSciData.GEOSFPFileSet("4x5", "A3dyn")
const itp4 = EarthSciData.DataSetInterpolator{Float64}(fs, "U", DateTime(2022, 5, 1))
const ts = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
const lons = deg2rad.(-180.0:1:174)
const lats = deg2rad.(-90:1:85)
function interpfunc_serial()
    for t ∈ datetime2unix.(ts)
        EarthSciData.lazyload!(itp4, t)
        for lon ∈ lons, lat ∈ lats
            EarthSciData.interp_unsafe(itp4, t, lon, lat, 1.0)
        end
    end
end
function interpfunc_threads()
    for t ∈ datetime2unix.(ts)
        EarthSciData.lazyload!(itp4, t)
        Threads.@threads for lon ∈ deg2rad.(-180.0:1:174)
            for lat ∈ deg2rad.(-90:1:85)
                EarthSciData.interp_unsafe(itp4, t, lon, lat, 1.0)
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
function nei_simulator(st)
    @parameters lat = deg2rad(40.0) lon = deg2rad(-97.0) lev = 0.0
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
            lon ∈ Interval(deg2rad(-115), deg2rad(-68.75)),
            lat ∈ Interval(deg2rad(25), deg2rad(53.7)),
            lev ∈ Interval(1, 2)
        );
        grid_spacing=[deg2rad(1.25), deg2rad(1.2), 1])

    csys = couple(sys, emis, domain)

    ODEProblem(csys, st)
end

suite["NEI Simulator"] = BenchmarkGroup()
st = SimulatorStrangSerial(Tsit5(), Euler(), 100.0)
sim = nei_simulator(st)
suite["NEI Simulator"]["Serial"] = @benchmarkable solve($sim, dt=100.0,
    save_on=false, save_start=false, save_end=false, initialize_save=false)

st = SimulatorStrangThreads(Tsit5(), Euler(), 100.0)
sim = nei_simulator(st)
suite["NEI Simulator"]["Threads"] = @benchmarkable solve($sim, dt=100.0,
    save_on=false, save_start=false, save_end=false, initialize_save=false)

tune!(suite, verbose=true)
results = run(suite, verbose=true)

BenchmarkTools.save("output.json", median(results))
