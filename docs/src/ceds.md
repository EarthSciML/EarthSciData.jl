# CEDS Global Emissions

We have a data loader for [CEDS (Community Emissions Data System)](https://www.pnnl.gov/projects/ceds) global gridded anthropogenic emissions, [`CEDS`](@ref).

CEDS provides monthly global anthropogenic emissions at 0.5° × 0.5° resolution from 1750 to 2023 in units of kg m⁻² s⁻¹, with 8 anthropogenic sectors.

**Reference**: Hoesly, R. M., et al. (2018). Historical (1750–2014) anthropogenic emissions of reactive gases and aerosols from the Community Emissions Data System (CEDS). *Geoscientific Model Development*, 11, 369–408. [https://doi.org/10.5194/gmd-11-369-2018](https://doi.org/10.5194/gmd-11-369-2018)

## Equations

This is what its equation system looks like:

```@example ceds
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DynamicQuantities, DataFrames
using ModelingToolkit: t
using DynamicQuantities: dimension
using Dates

domain = DomainInfo(
    DateTime(2016, 5, 1), DateTime(2016, 5, 2);
    lonrange = deg2rad(-180):deg2rad(2.5):deg2rad(175),
    latrange = deg2rad(-85):deg2rad(2):deg2rad(85),
    levrange = 1:10,
    u_proto = zeros(Float32, 1, 1, 1, 1)
)

emis = CEDS(domain; species = ["SO2", "NOx", "CO"])
```

## Variables

Here are the variables in tabular format:

```@example ceds
function table(vars)
    DataFrame(
        :Name => [string(Symbolics.tosymbol(v, escape = false)) for v in vars],
        :Units => [dimension(ModelingToolkit.get_unit(v)) for v in vars],
        :Description => [ModelingToolkit.getdescription(v) for v in vars]
    )
end
table(unknowns(emis))
```

## Parameters

Finally, here are the parameters in tabular format:

```@example ceds
table(parameters(emis))
```
