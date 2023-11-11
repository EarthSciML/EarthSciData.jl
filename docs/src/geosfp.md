# Using data from GEOS-FP

``` example 1
using EarthSciData, EarthSciMLBase
using DomainSets, ModelingToolkit, MethodOfLines, DifferentialEquations
using Dates, Plots

# Set up system
@parameters t lev lon lat
geosfp = GEOSFP("4x5", t)

struct Example <: EarthSciMLODESystem
    sys
    function Example(t; name)
        @variables c(t) = 5.0
        D = Differential(t)
        new(ODESystem([D(c) ~ sin(lat * π / 180.0 * 6) + sin(lon * π / 180 * 6)], t, name=name))
    end
end
@named examplesys = Example(t)

domain = DomainInfo(
    partialderivatives_lonlat2xymeters,
    constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),
    zerogradBC(lat ∈ Interval(-85.0f0, 85.0f0)),
    periodicBC(lon ∈ Interval(-180.0f0, 175.0f0)),
    zerogradBC(lev ∈ Interval(1.0f0, 10.0f0)),
)

composed_sys = examplesys + domain + Advection() + geosfp;
pde_sys = get_mtk(composed_sys)

# Solve
discretization = MOLFiniteDifference([lat => 6, lon => 6, lev => 6], t, approx_order=2)
@time pdeprob = discretize(pde_sys, discretization)

#@run pdesol = solve(pdeprob, Tsit5(), saveat=3600.0)
@profview pdesol = solve(pdeprob, Tsit5(), saveat=36000.0)
@time pdesol = solve(pdeprob, Tsit5(), saveat=3600.0)

# Plot
discrete_lon = pdesol[lon]
discrete_lat = pdesol[lat]
discrete_lev = pdesol[lev]
discrete_t = pdesol[t]

@variables meanwind₊u(..) meanwind₊v(..) examplesys₊c(..)
sol_u = pdesol[meanwind₊u(t, lat, lon, lev)]
sol_v = pdesol[meanwind₊v(t, lat, lon, lev)]
sol_c = pdesol[examplesys₊c(t, lat, lon, lev)]

anim = @animate for k in 1:length(discrete_t)
    p1 = heatmap(discrete_lon, discrete_lat, sol_c[k, 1:end, 1:end, 2], clim=(minimum(sol_c[:, :, :, 2]), maximum(sol_c[:, :, :, 2])),
            xlabel="Longitude", ylabel="Latitude", title="examplesys.c: $(Dates.unix2datetime(discrete_t[k]))")
    p2 = heatmap(discrete_lon, discrete_lat, sol_u[k, 1:end, 1:end, 2], clim=(minimum(sol_u[:, :, :, 2]), maximum(sol_u[:, :, :, 2])), 
            title="U")
    p3 = heatmap(discrete_lon, discrete_lat, sol_v[k, 1:end, 1:end, 2], clim=(minimum(sol_v[:, :, :, 2]), maximum(sol_v[:, :, :, 2])),
            title="V")
    plot(p1, p2, p3, size=(1200, 700))
end
gif(anim, "animation.gif", fps = 8)
```