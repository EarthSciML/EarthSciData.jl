# Using data from GEOS-FP

This example demonstrates how to use the GEOS-FP data loader in the EarthSciML ecosystem. The GEOS-FP data loader is used to load data from the [GEOS-FP](https://gmao.gsfc.nasa.gov/GMAO_products/NRT_products.php) dataset.

First, let's initialize some packages and set up the [GEOS-FP](@ref GEOSFP) equation system.

```@example geosfp
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DifferentialEquations
using ModelingToolkit: t, D
using Dates, Plots, DataFrames
using DynamicQuantities
using DynamicQuantities: dimension

# Set up system
domain = DomainInfo(DateTime(2022, 1, 1), DateTime(2022, 1, 3);
    latrange = deg2rad(-85.0f0):deg2rad(2):deg2rad(85.0f0),
    lonrange = deg2rad(-180.0f0):deg2rad(2.5):deg2rad(175.0f0),
    levrange = 1:11,
    u_proto = zeros(Float32, 1, 1, 1, 1)
)

geosfp = GEOSFP("4x5", domain)
```

Note that the [`GEOSFP`](@ref) function returns to things, an equation system and an object that can used to update the time in the underlying data loaders.
We can see above the different variables that are available in the GEOS-FP dataset.
But also, here they are in table form:

```@example geosfp
vars = unknowns(geosfp)
DataFrame(
    :Name => [string(Symbolics.tosymbol(v, escape = false)) for v in vars],
    :Units => [dimension(ModelingToolkit.get_unit(v)) for v in vars],
    :Description => [ModelingToolkit.getdescription(v) for v in vars]
)
```

The GEOS-FP equation system isn't an ordinary differential equation (ODE) system, so we can't run it by itself.
To fix this, we create another equation system that is an ODE.
(We don't actually end up using this system for anything, it's just necessary to get the system to compile.)

```@example geosfp
struct ExampleCoupler
    sys
end
function Example()
    @parameters lat=0.0 [unit=u"rad"]
    @parameters lon=0.0 [unit=u"rad"]
    @variables c(t) = 5.0 [unit=u"s"]
    ODESystem([D(c) ~ sin(lat * 6) + sin(lon * 6)], t;
        name = :Docs₊Example, metadata = Dict(:coupletype => ExampleCoupler))
end
function EarthSciMLBase.couple2(e::ExampleCoupler, g::EarthSciData.GEOSFPCoupler)
    e, g = e.sys, g.sys
    e = param_to_var(e, :lat, :lon)
    ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon], e, g)
end
examplesys = Example()
```

Now, let's couple these two systems together, and also add in advection and some information about the domain:

```@example geosfp
composed_sys = couple(examplesys, domain, geosfp)
pde_sys = convert(PDESystem, composed_sys)
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
