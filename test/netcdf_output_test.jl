using EarthSciData
using Test
using EarthSciMLBase, ModelingToolkit, DomainSets
using ModelingToolkit: t, D
using NCDatasets, DynamicQuantities, DifferentialEquations, Dates
using SciMLOperators

@parameters lev = 1.0
@parameters y = 2.0 [unit = u"kg"]
@parameters x = 1.0 [unit = u"kg", description = "x coordinate"]
@variables u(t) = 1.0 [unit = u"kg", description = "u value"]
@variables v(t) = 2.0 [unit = u"kg", description = "v value"]
@constants c = 1.0 [unit = u"kg^2"]
@constants p = 1.0 [unit = u"kg/s"]

eqs = [D(u) ~ p + 1e-20*lev*p*x*y/c # Need to make sure all coordinates are included in model.
       v ~ (x + y) * lev]

sys = ODESystem(eqs, t; name = :sys)

domain = DomainInfo(
    constIC(0.0, t ∈ Interval(0.0, 2.0)),
    constBC(
        16.0,
        x ∈ Interval(-1.0, 1.0),
        y ∈ Interval(-2.0, 2.0),
        lev ∈ Interval(1.0, 3.0)
    ),
    grid_spacing = [0.1, 0.1, 1]
)

file = tempname() * ".nc"

csys = couple(sys, domain)

o = NetCDFOutputter(file, 1.0; extra_vars = [sys.v])

csys = couple(csys, o)

dt = 0.01
st = SolverStrangThreads(Tsit5(), dt)
prob = ODEProblem(csys, st; extra_vars = [sys.v])

solve(prob, Euler(), dt = dt)

ds = NCDataset(file, "r")

@test size(ds["sys₊u"], 4) == 3
@test all(isapprox.(ds["sys₊u"][:, :, :, 1], 1.0, atol = 0.011))
@test sum(abs.(ds["sys₊v"][:, :, :, 1])) ≈ 5754.0f0
@test all(isapprox.(ds["sys₊u"][:, :, :, 2], 2.0, atol = 0.011))
@test sum(abs.(ds["sys₊v"][:, :, :, 2])) ≈ 5754.0f0
@test all(isapprox.(ds["sys₊u"][:, :, :, 3], 3.0, atol = 0.011))
@test sum(abs.(ds["sys₊v"][:, :, :, 3])) ≈ 5754.0f0
@test size(ds["sys₊u"]) == (21, 41, 3, 3)

@test ds["time"][:] == [
    DateTime("1970-01-01T00:00:00"),
    DateTime("1970-01-01T00:00:01"),
    DateTime("1970-01-01T00:00:02")
]
@test ds["x"][:] ≈ -1.0:0.1:1.0
@test ds["y"][:] ≈ -2.0:0.1:2.0
@test ds["lev"] ≈ 1:3

@test ds["x"].attrib["description"] == "x coordinate"
@test ds["x"].attrib["units"] == "kg"

@test ds["sys₊u"].attrib["description"] == "u value"
@test ds["sys₊u"].attrib["units"] == "kg"

close(ds)

rm(file, force = true)
