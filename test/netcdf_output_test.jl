using EarthSciData
using Test
using EarthSciMLBase, ModelingToolkit, DomainSets
using NCDatasets, Unitful, DifferentialEquations, Dates

@parameters t [unit = u"s", description = "time"]
@parameters lev = 1.0
@parameters y = 2.0 [unit = u"kg"]
@parameters x = 1.0 [unit = u"kg", description = "x coordinate"]
x = GlobalScope(x)
y = GlobalScope(y)
lev = GlobalScope(lev)
@variables u(t) = 1.0 [unit = u"kg", description = "u value"]
@variables v(t) = 2.0 [unit = u"kg", description = "v value"]
@constants p = 1.0 [unit = u"kg/s"]
D = Differential(t)

eqs = [
    D(u) ~ p
    v ~ (x + y) * lev
]

sys = ODESystem(eqs, t; name=:Test₊sys)

domain = DomainInfo(
    constIC(0.0, t ∈ Interval(0.0, 2.0)),
    constBC(16.0, x ∈ Interval(-1.0, 1.0),
        y ∈ Interval(-2.0, 2.0),
        lev ∈ Interval(1, 3)))

file = tempname() * ".nc"

csys = couple(sys, domain)

o = NetCDFOutputter(file, 1.0; extra_vars=[
    structural_simplify(EarthSciMLBase.get_mtk_ode(csys)).Test₊sys.v
])

csys = couple(csys, o)

sim = Simulator(csys, [0.1, 0.1, 1], Tsit5())

run!(sim)

ds = NCDataset(file, "r")

@test size(ds["Test₊sys₊u"], 4) == 3
@test all(ds["Test₊sys₊u"][:, :, :, 1] .≈ 2.0)
@test sum(abs.(ds["Test₊sys₊v"][:, :, :, 1])) ≈ 5754.0f0
@test all(ds["Test₊sys₊u"][:, :, :, 2] .≈ 3.0)
@test sum(abs.(ds["Test₊sys₊v"][:, :, :, 2])) ≈ 5754.0f0
@test all(ds["Test₊sys₊u"][:, :, :, 3] .≈ 4.0)
@test sum(abs.(ds["Test₊sys₊v"][:, :, :, 3])) ≈ 5754.0f0
@test size(ds["Test₊sys₊u"]) == (21, 41, 3, 3)

@test ds["time"][:] == [DateTime("1970-01-01T00:00:00"), DateTime("1970-01-01T00:00:01"), DateTime("1970-01-01T00:00:02")]
@test ds["x"][:] ≈ -1.0:0.1:1.0
@test ds["y"][:] ≈ -2.0:0.1:2.0
@test ds["lev"] ≈ 1:3

@test ds["x"].attrib["description"] == "x coordinate"
@test ds["x"].attrib["units"] == "kg"

@test ds["Test₊sys₊u"].attrib["description"] == "u value"
@test ds["Test₊sys₊u"].attrib["units"] == "kg"

rm(file, force=true)