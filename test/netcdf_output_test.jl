@testitem "NetCDF Output" begin
    using EarthSciMLBase, ModelingToolkit, DomainSets
    using ModelingToolkit: t, D
    using NCDatasets, DynamicQuantities, Dates
    using OrdinaryDiffEqLowOrderRK, OrdinaryDiffEqTsit5

    @parameters lev = 1.0
    @parameters y=2.0 [unit = u"kg"]
    @parameters x=1.0 [unit = u"kg", description = "x coordinate"]
    @variables u(t)=1.0 [unit = u"kg", description = "u value"]
    @variables v(t) [unit = u"kg", description = "v value"]
    @constants c=1.0 [unit = u"kg^2"]
    @constants p=1.0 [unit = u"kg/s"]

    eqs = [D(u) ~ p + 1e-20 * lev * p * x * y / c # Need to make sure all coordinates are included in model.
           v ~ (x + y) * lev]

    sys = System(eqs, t; name = :sys)

    domain = DomainInfo(
        DateTime(2000, 1, 1, 0, 0, 0),
        DateTime(2000, 1, 1, 0, 0, 2);
        xrange = -1:0.1:1,
        yrange = -2:0.1:2,
        levrange = 1:3
    )

    file = tempname() * ".nc"

    csys = couple(sys, domain)

    o = NetCDFOutputter(file, 1.0; extra_vars = [sys.v])

    csys = couple(csys, o)

    dt = 0.01
    st = SolverStrangThreads(Tsit5(), dt)
    prob = ODEProblem(csys, st)

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
        DateTime("2000-01-01T00:00:00"),
        DateTime("2000-01-01T00:00:01"),
        DateTime("2000-01-01T00:00:02")
    ]
    @test ds["x"][:] ≈ -1.0:0.1:1.0
    @test ds["y"][:] ≈ -2.0:0.1:2.0
    @test ds["lev"] ≈ 1:3

    @test ds["x"].attrib["description"] == "East-West Distance"
    @test ds["x"].attrib["units"] == "m"

    @test ds["sys₊u"].attrib["description"] == "u value"
    @test ds["sys₊u"].attrib["units"] == "kg"

    close(ds)

    rm(file, force = true)
end
