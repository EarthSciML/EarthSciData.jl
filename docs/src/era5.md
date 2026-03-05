# ERA5 Reanalysis

## Overview

ERA5 is the fifth generation ECMWF atmospheric reanalysis of the global climate, covering 1940 to the present with hourly temporal resolution and 0.25° x 0.25° spatial resolution on 37 pressure levels.

This data loader provides access to ERA5 pressure-level data via the [Copernicus Climate Data Store (CDS) API](https://cds.climate.copernicus.eu/) or from pre-downloaded local NetCDF files.

**Reference**: Hersbach, H., et al. (2020). The ERA5 global reanalysis. *Quarterly Journal of the Royal Meteorological Society*, 146(730), 1999-2049. doi:10.1002/qj.3803

```@docs
ERA5
```

## Setup

### CDS API Key

To download ERA5 data automatically, you need a free CDS account:

1. Register at [https://cds.climate.copernicus.eu/](https://cds.climate.copernicus.eu/)
2. Accept the ERA5 data licence
3. Create `~/.cdsapirc` with:
```
url: https://cds.climate.copernicus.eu/api
key: <your-api-key>
```

Alternatively, set the `CDSAPI_KEY` environment variable.

### Pre-downloaded Data

If you already have ERA5 data as NetCDF files, use `mirror="file:///path/to/data"`.
Files should be named `era5_pl_YYYY_MM.nc` (one file per month, containing all variables).

## Implementation

```@example era5
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DataFrames
using ModelingToolkit: t
using Dates
using DynamicQuantities
using DynamicQuantities: dimension

domain = DomainInfo(DateTime(2022, 1, 1), DateTime(2022, 1, 3);
    latrange = deg2rad(20.0f0):deg2rad(0.25):deg2rad(50.0f0),
    lonrange = deg2rad(-130.0f0):deg2rad(0.25):deg2rad(-60.0f0),
    levrange = 1:4,
)

era5 = ERA5(domain; mirror="file:///tmp/era5_local_test")
```

### State Variables

```@example era5
vars = unknowns(era5)
DataFrame(
    :Name => [string(Symbolics.tosymbol(v, escape = false)) for v in vars],
    :Units => [dimension(ModelingToolkit.get_unit(v)) for v in vars],
    :Description => [ModelingToolkit.getdescription(v) for v in vars]
)
```

### Equations

```@example era5
eqs = equations(era5)
```

## Available Variables

ERA5 pressure-level variables include:

| Short Name | Long Name | Units |
|:-----------|:----------|:------|
| t | Temperature | K |
| u | U component of wind | m s⁻¹ |
| v | V component of wind | m s⁻¹ |
| w | Vertical velocity | Pa s⁻¹ |
| q | Specific humidity | kg kg⁻¹ |
| r | Relative humidity | % |
| z | Geopotential | m² s⁻² |
| d | Divergence | s⁻¹ |
| vo | Vorticity | s⁻¹ |
| o3 | Ozone mass mixing ratio | kg kg⁻¹ |
| cc | Fraction of cloud cover | (0-1) |
| ciwc | Specific cloud ice water content | kg kg⁻¹ |
| clwc | Specific cloud liquid water content | kg kg⁻¹ |
| crwc | Specific rain water content | kg kg⁻¹ |
| cswc | Specific snow water content | kg kg⁻¹ |
| pv | Potential vorticity | K m² kg⁻¹ s⁻¹ |

## Pressure Levels

ERA5 provides data on 37 pressure levels from 1000 hPa (surface) to 1 hPa (stratosphere). The level index maps to pressure as follows:

| Index | Pressure (hPa) | Index | Pressure (hPa) |
|:------|:---------------|:------|:---------------|
| 1 | 1000 | 20 | 300 |
| 2 | 975 | 21 | 250 |
| 3 | 950 | 22 | 225 |
| 4 | 925 | 23 | 200 |
| 5 | 900 | 24 | 175 |
| 6 | 875 | 25 | 150 |
| 7 | 850 | 26 | 125 |
| 8 | 825 | 27 | 100 |
| 9 | 800 | 28 | 70 |
| 10 | 775 | 29 | 50 |
| 11 | 750 | 30 | 30 |
| 12 | 700 | 31 | 20 |
| 13 | 650 | 32 | 10 |
| 14 | 600 | 33 | 7 |
| 15 | 550 | 34 | 5 |
| 16 | 500 | 35 | 3 |
| 17 | 450 | 36 | 2 |
| 18 | 400 | 37 | 1 |
| 19 | 350 | | |
