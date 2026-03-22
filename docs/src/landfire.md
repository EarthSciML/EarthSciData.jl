# LANDFIRE Fuel Models

## Overview

[LANDFIRE](https://landfire.gov/) (Landscape Fire and Resource Management Planning Tools) provides
geospatial data for wildland fire management across the United States. This data loader provides
fire behavior fuel model (FBFM) classifications at 30m resolution over the contiguous United States (CONUS).

Two fuel model products are available:

  - **FBFM13**: Anderson 13 fire behavior fuel models (codes 1--13), the classic fuel classification system.
  - **FBFM40**: Scott & Burgan 40 fuel models (codes 101--204), a more detailed classification.

Both products include non-burnable codes: 91 (urban/developed), 92 (snow/ice), 93 (agriculture),
98 (water), and 99 (barren). Code 0 indicates no fuel data.

The fuel model codes from LANDFIRE map directly to fuel property dictionaries (e.g., fuel bed depth,
moisture of extinction, surface-area-to-volume ratios) used in fire spread models such as the
Rothermel model.

**Reference**: LANDFIRE: Landscape Fire and Resource Management Planning Tools. U.S. Department of
the Interior, Geological Survey. [https://landfire.gov/](https://landfire.gov/)

```@docs
LANDFIRE
```

## Implementation

Data is downloaded from the LANDFIRE ImageServer REST API as GeoTIFF files. Because this is
categorical (integer-valued) data, nearest-neighbour interpolation (`BSpline(Constant())`) is used
for regridding instead of the bilinear interpolation used by other data sources. This preserves the
integer fuel model codes.

### Variables

```@example landfire
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DynamicQuantities, DataFrames
using ModelingToolkit: t
using DynamicQuantities: dimension
using Dates

domain = DomainInfo(
    DateTime(2018, 11, 8), DateTime(2018, 11, 9);
    lonrange = deg2rad(-121.7):deg2rad(0.01):deg2rad(-121.5),
    latrange = deg2rad(39.7):deg2rad(0.01):deg2rad(39.8),
    levrange = 1:1
)

landfire = LANDFIRE(domain; resolution = 10.0)

function table(vars)
    DataFrame(
        :Name => [string(Symbolics.tosymbol(v, escape = false)) for v in vars],
        :Units => [dimension(ModelingToolkit.get_unit(v)) for v in vars],
        :Description => [ModelingToolkit.getdescription(v) for v in vars]
    )
end
table(unknowns(landfire))
```

### Parameters

```@example landfire
table(parameters(landfire))
```

### Equations

```@example landfire
equations(landfire)
```
