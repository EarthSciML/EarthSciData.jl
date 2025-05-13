using BenchmarkTools
using EarthSciData
using Dates

domain1 = DomainInfo(
    constIC(16.0, t ∈ Interval(DateTime(2022, 5, 1), DateTime(2022, 5, 3))),
    constBC(
        16.0,
        lon ∈ Interval(deg2rad(-180), deg2rad(174)),
        lat ∈ Interval(deg2rad(-90), deg2rad(85)),
        lev ∈ Interval(1, 1)
    );
    grid_spacing = [deg2rad(1), deg2rad(1), 1]
)

const fs = EarthSciData.GEOSFPFileSet(
    "4x5", "A3dyn", DateTime(2022, 5, 1), DateTime(2022, 5, 3))
const itp_stream = EarthSciData.DataSetInterpolator{Float64}(
    fs,
    "U",
    DateTime(2022, 5, 1),
    DateTime(2022, 5, 3),
    domain1;
    stream = true
)
const itp_nostream = EarthSciData.DataSetInterpolator{Float64}(
    fs,
    "U",
    DateTime(2022, 5, 1),
    DateTime(2022, 5, 3),
    domain1;
    stream = false
)
const ts = DateTime(2022, 5, 1):Hour(1):DateTime(2022, 5, 3)
const lons = deg2rad.(-180.0:1:174)
const lats = deg2rad.(-90:1:85)
function interpfunc_serial(itp, itpf)
    for t in datetime2unix.(ts)
        for lon in lons, lat in lats

            itpf(itp, t, lon, lat, 1.0)
        end
    end
end
function interpfunc_threads(itp, itpf)
    for t in datetime2unix.(ts)
        Threads.@threads for lon in deg2rad.(-180.0:1:174)
            for lat in deg2rad.(-90:1:85)
                itpf(itp, t, lon, lat, 1.0)
            end
        end
    end
end

# @profview interpfunc_serial(itp_stream, EarthSciData.interp!)

suite = BenchmarkGroup()
suite["GEOSFP"] = BenchmarkGroup()
suite["GEOSFP"]["stream"] = BenchmarkGroup()
suite["GEOSFP"]["nostream"] = BenchmarkGroup()
suite["GEOSFP"]["stream"]["Interpolation serial"] = @benchmarkable interpfunc_serial(
    $itp_stream, $EarthSciData.interp!)
suite["GEOSFP"]["stream"]["Interpolation threaded"] = @benchmarkable interpfunc_threads(
    $itp_stream, $EarthSciData.interp!)
suite["GEOSFP"]["nostream"]["Interpolation serial"] = @benchmarkable interpfunc_serial(
    $itp_nostream, $EarthSciData.interp_unsafe)
suite["GEOSFP"]["nostream"]["Interpolation threaded"] = @benchmarkable interpfunc_threads(
    $itp_nostream, $EarthSciData.interp_unsafe)

using EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t, D
using DomainSets, Dates
using DifferentialEquations
using DynamicQuantities

struct SysCoupler
    sys::Any
end
function EarthSciMLBase.couple2(
        sys::SysCoupler,
        emis::EarthSciData.NEI2016MonthlyEmisCoupler
)
    sys, emis = sys.sys, emis.sys
    operator_compose(sys, emis)
end

@parameters lat=deg2rad(40.0) lon=deg2rad(-97.0) lev=1.0
@variables ACET(t) = 0.0 [unit = u"kg*m^-3"]
@constants c = 1000 [unit = u"s"]

@named sys = ODESystem([D(ACET) ~ 0], t, metadata = Dict(:coupletype => SysCoupler))

starttime = datetime2unix(DateTime(2016, 5, 1))
endtime = datetime2unix(DateTime(2016, 5, 2))
domain = DomainInfo(
    constIC(16.0, t ∈ Interval(starttime, endtime)),
    constBC(
        16.0,
        lon ∈ Interval(deg2rad(-115), deg2rad(-68.75)),
        lat ∈ Interval(deg2rad(25), deg2rad(53.7)),
        lev ∈ Interval(1, 2)
    );
    grid_spacing = [deg2rad(1.25), deg2rad(1.2), 1]
)

emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", domain)
csys = couple(sys, emis, domain)

suite["NEI Simulator"] = BenchmarkGroup()
st = SolverStrangSerial(Tsit5(), 100.0)
prob_serial = ODEProblem(csys, st)
suite["NEI Simulator"]["Serial"] = @benchmarkable solve(
    $prob_serial,
    Euler(),
    dt = 100.0,
    save_on = false,
    save_start = false,
    save_end = false,
    initialize_save = false
)

st = SolverStrangThreads(Tsit5(), 100.0)
prob_threads = ODEProblem(csys, st)
suite["NEI Simulator"]["Threads"] = @benchmarkable solve(
    $prob_serial,
    Euler(),
    dt = 100.0,
    save_on = false,
    save_start = false,
    save_end = false,
    initialize_save = false
)

tune!(suite, verbose = true)
results = run(suite, verbose = true)

BenchmarkTools.save("output.json", median(results))
