# EDGAR v8.1 Global Air Pollutant Emissions

## Overview

We have a data loader for [EDGAR v8.1](https://edgar.jrc.ec.europa.eu/dataset_ap81) monthly global air pollutant emissions, [`EDGARv81MonthlyEmis`](@ref).

EDGAR (Emissions Database for Global Atmospheric Research) provides global gridded emissions at 0.1°×0.1° resolution for 2000-2022. Monthly flux data (kg m⁻² s⁻¹) is available for 9 pollutants (BC, CO, NH3, NMVOC, NOx, OC, PM10, PM2.5, SO2) across multiple emission sectors.

**Reference**: Crippa, M., et al. (2024). EDGAR v8.1 Global Air Pollutant Emissions. European Commission, Joint Research Centre (JRC). [https://edgar.jrc.ec.europa.eu/dataset_ap81](https://edgar.jrc.ec.europa.eu/dataset_ap81)

```@docs
EDGARv81MonthlyEmis
```

## Equations

This is what its equation system looks like:

```@example edgar_v81
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DynamicQuantities, DataFrames
using ModelingToolkit: t
using DynamicQuantities: dimension
using Dates

domain = DomainInfo(
    DateTime(2020, 6, 1), DateTime(2020, 7, 1);
    lonrange = deg2rad(-10.0):deg2rad(2.5):deg2rad(30.0),
    latrange = deg2rad(40.0):deg2rad(2):deg2rad(60.0),
    levrange = 1:10,
)

emis = EDGARv81MonthlyEmis("NOx", "POWER_INDUSTRY", domain)
```

## Variables

Here are the variables in tabular format:

```@example edgar_v81
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

```@example edgar_v81
table(parameters(emis))
```
