using Main.EarthSciData

using Test
using EarthSciMLBase, ModelingToolkit
using ModelingToolkit: t, D
using DomainSets, Dates
using DifferentialEquations
using DynamicQuantities

@parameters lat = deg2rad(40.0) lon = deg2rad(-97.0) lev = 0.0
@variables ACET(t) = 0.0 [unit = u"kg*m^-3"]
@constants c = 1000 [unit = u"s"]

struct SysCoupler
    sys
end
@named sys = ODESystem(
    [D(ACET) ~ 0], t,
    metadata=Dict(:coupletype => SysCoupler)
)
function EarthSciMLBase.couple2(sys::SysCoupler, emis::EarthSciData.NEI2016MonthlyEmisCoupler)
    sys, emis = sys.sys, emis.sys
    operator_compose(sys, emis)
end

emis = NEI2016MonthlyEmis("mrggrid_withbeis_withrwc", lon, lat, lev; dtype=Float64)

starttime = datetime2unix(DateTime(2016, 5, 1))
endtime = datetime2unix(DateTime(2016, 5, 2))
domain = DomainInfo(
    constIC(16.0, t ∈ Interval(starttime, endtime)),
    constBC(16.0,
        lon ∈ Interval(deg2rad(-115), deg2rad(-68.75)),
        lat ∈ Interval(deg2rad(25), deg2rad(53.71875)),
        lev ∈ Interval(1, 2)
    ))

csys = couple(sys, emis, domain)

sim = Simulator(csys, [deg2rad(2.0), deg2rad(2.0), 1])

st = SimulatorStrangSerial(Tsit5(), Euler(), 100.0)

sol = run!(sim, st)

@test sum(sol.u[end]) ≈ 6.650039773230552e-5

st = SimulatorStrangThreads(Tsit5(), Euler(), 100.0)

sol = run!(sim, st)

@test sum(sol.u[end]) ≈ 6.650039773230552e-5
