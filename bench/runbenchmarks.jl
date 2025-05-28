using BenchmarkTools
using EarthSciData
using EarthSciMLBase
using Dates
using OrdinaryDiffEqLowOrderRK, OrdinaryDiffEqTsit5
using ModelingToolkit
using DomainSets
using ModelingToolkit: t, D
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

suite = BenchmarkGroup()
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
