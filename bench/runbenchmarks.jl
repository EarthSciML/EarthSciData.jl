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
@variables ACET(t) = 0.0
@constants c = 1000 [unit = u"s"]

@named sys = System([D(ACET) ~ ACET/c], t, metadata = Dict(CoupleType => SysCoupler))

domain = DomainInfo(
    DateTime(2016, 5, 1), DateTime(2016, 5, 2),
    lonrange = deg2rad(-115):deg2rad(1.25):deg2rad(-68.75),
    latrange = deg2rad(25):deg2rad(1.2):deg2rad(53.7),
    levrange = 1:1:2
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
    $prob_threads,
    Euler(),
    dt = 100.0,
    save_on = false,
    save_start = false,
    save_end = false,
    initialize_save = false
)

# -----------------------------------------------------------------------------
# Microbenchmarks of the interpolation hot path.
#
# Compares the full multilinear `interp_unsafe` against the faster
# `interp_time_only` (nearest-neighbour spatial + linear time), which is used
# when the model queries the loader at grid-aligned points.  Both wrap the
# data in `DataBufferType` so the dispatch mirrors what the MTK-generated
# RHS function runs at each step.
# -----------------------------------------------------------------------------
suite["Interpolation hot path"] = BenchmarkGroup()

# Realistic sizes: GEOS-FP 4x5 with ~72 levels, 2-timestep window.
data4 = rand(Float64, 144, 91, 72, 2)
data4_db = EarthSciData.DataBufferType(data4)
fit, fi1, fi2, fi3 = 1.5, 72.3, 45.7, 36.2
extrap = 1.0

suite["Interpolation hot path"]["4D linear"] = @benchmarkable EarthSciData.interp_unsafe(
    $data4_db, $fit, $fi1, $fi2, $fi3, $extrap)
suite["Interpolation hot path"]["4D nearest"] = @benchmarkable EarthSciData.interp_time_only(
    $data4_db, $fit, $fi1, $fi2, $fi3, $extrap)

# Grid-aligned query (integer spatial indices) — the intended use case for
# `interp_time_only`.  Both modes should produce the same result here; the
# benchmark measures the speedup the `:nearest` mode gives for this access
# pattern.
fi1_int, fi2_int, fi3_int = 72.0, 45.0, 36.0
suite["Interpolation hot path"]["4D linear (grid-aligned)"] = @benchmarkable EarthSciData.interp_unsafe(
    $data4_db, $fit, $fi1_int, $fi2_int, $fi3_int, $extrap)
suite["Interpolation hot path"]["4D nearest (grid-aligned)"] = @benchmarkable EarthSciData.interp_time_only(
    $data4_db, $fit, $fi1_int, $fi2_int, $fi3_int, $extrap)

# 3D (2 spatial + time) — emissions grids.
data3 = rand(Float64, 144, 91, 2)
data3_db = EarthSciData.DataBufferType(data3)
suite["Interpolation hot path"]["3D linear"] = @benchmarkable EarthSciData.interp_unsafe(
    $data3_db, $fit, $fi1, $fi2, $extrap)
suite["Interpolation hot path"]["3D nearest"] = @benchmarkable EarthSciData.interp_time_only(
    $data3_db, $fit, $fi1, $fi2, $extrap)

# 2D (1 spatial + time).
data2 = rand(Float64, 144, 2)
data2_db = EarthSciData.DataBufferType(data2)
suite["Interpolation hot path"]["2D linear"] = @benchmarkable EarthSciData.interp_unsafe(
    $data2_db, $fit, $fi1, $extrap)
suite["Interpolation hot path"]["2D nearest"] = @benchmarkable EarthSciData.interp_time_only(
    $data2_db, $fit, $fi1, $extrap)

tune!(suite, verbose = true)
results = run(suite, verbose = true)

BenchmarkTools.save("output.json", median(results))
