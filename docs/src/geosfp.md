# Using data from GEOS-FP

This example demonstrates how to use the GEOS-FP data loader in the EarthSciML ecosystem. The GEOS-FP data loader is used to load data from the [GEOS-FP](https://gmao.gsfc.nasa.gov/GMAO_products/NRT_products.php) dataset.

First, let's initialize some packages and set up the [GEOS-FP](@ref GEOSFP) equation system.

```@example geosfp
using EarthSciData, EarthSciMLBase
using DomainSets, ModelingToolkit, MethodOfLines, DifferentialEquations
using Dates, Plots, DataFrames

# Set up system
@parameters t lev lon lat
geosfp = GEOSFP("4x5", t)
```

We can see above the different variables that are available in the GEOS-FP dataset.
But also, here they are in table form:

```@example geosfp
vars = states(geosfp)
DataFrame(
        :Name => [string(Symbolics.tosymbol(v, escape=false)) for v ∈ vars],
        :Units => [ModelingToolkit.get_unit(v) for v ∈ vars],
        :Description => [ModelingToolkit.getdescription(v) for v ∈ vars],
)
```

The GEOS-FP equation system isn't an ordinary differential equation (ODE) system, so we can't run it by itself.
To fix this, we create another equation system that is an ODE. 
(We don't actually end up using this system for anything, it's just necessary to get the system to compile.)

```@example geosfp
function Example(t)
    @variables c(t) = 5.0
    D = Differential(t)
    ODESystem([D(c) ~ sin(lat * π / 180.0 * 6) + sin(lon * π / 180 * 6)], t, name=:Docs₊Example)
end
examplesys = Example(t)
```

Now, let's couple these two systems together, and also add in advection and some information about the domain:

```@example geosfp
domain = DomainInfo(
    partialderivatives_δxyδlonlat,
    constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),
    zerogradBC(lat ∈ Interval(-80.0f0, 80.0f0)),
    periodicBC(lon ∈ Interval(-180.0f0, 180.0f0)),
    zerogradBC(lev ∈ Interval(1.0f0, 11.0f0)),
)

composed_sys = couple(examplesys, domain, geosfp)
pde_sys = get_mtk(composed_sys)
```

Now, finally, we can run the simulation and plot the GEOS-FP wind fields in the result:

(The code below is commented out because it is very slow right now. A faster solution is coming soon!)
```julia
# discretization = MOLFiniteDifference([lat => 10, lon => 10, lev => 10], t, approx_order=2)
# @time pdeprob = discretize(pde_sys, discretization)

# pdesol = solve(pdeprob, Tsit5(), saveat=3600.0)

# discrete_lon = pdesol[lon]
# discrete_lat = pdesol[lat]
# discrete_lev = pdesol[lev]
# discrete_t = pdesol[t]

# @variables meanwind₊u(..) meanwind₊v(..) examplesys₊c(..)
# sol_u = pdesol[meanwind₊u(t, lat, lon, lev)]
# sol_v = pdesol[meanwind₊v(t, lat, lon, lev)]
# sol_c = pdesol[examplesys₊c(t, lat, lon, lev)]

# anim = @animate for k in 1:length(discrete_t)
#     p1 = heatmap(discrete_lon, discrete_lat, sol_c[k, 1:end, 1:end, 2], clim=(minimum(sol_c[:, :, :, 2]), maximum(sol_c[:, :, :, 2])),
#             xlabel="Longitude", ylabel="Latitude", title="examplesys.c: $(Dates.unix2datetime(discrete_t[k]))")
#     p2 = heatmap(discrete_lon, discrete_lat, sol_u[k, 1:end, 1:end, 2], clim=(minimum(sol_u[:, :, :, 2]), maximum(sol_u[:, :, :, 2])), 
#             title="U")
#     p3 = heatmap(discrete_lon, discrete_lat, sol_v[k, 1:end, 1:end, 2], clim=(minimum(sol_v[:, :, :, 2]), maximum(sol_v[:, :, :, 2])),
#             title="V")
#     plot(p1, p2, p3, size=(800, 500))
# end
# gif(anim, "animation.gif", fps = 8)
```