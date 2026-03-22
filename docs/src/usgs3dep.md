# USGS 3DEP Elevation Data

## Overview

The [USGS 3D Elevation Program (3DEP)](https://www.usgs.gov/3d-elevation-program) provides high-resolution terrain elevation data for the United States (CONUS, Alaska, Hawaii, and US territories). The default resolution is 1/3 arc-second (~10m).

Data is downloaded on-demand from the USGS National Map [ImageServer REST API](https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer) as GeoTIFF tiles and read with TiffImages.jl (no GDAL dependency required). This is a static (time-invariant) dataset -- the elevation values do not change over the simulation time span.

```@docs
USGS3DEP
```

## Usage

```@example usgs3dep
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DataFrames
using ModelingToolkit: t
using Dates
using DynamicQuantities
using DynamicQuantities: dimension

# Define a domain near Paradise, CA
domain = DomainInfo(
    DateTime(2018, 11, 8), DateTime(2018, 11, 9);
    lonrange = deg2rad(-121.7):deg2rad(0.01):deg2rad(-121.5),
    latrange = deg2rad(39.7):deg2rad(0.01):deg2rad(39.8),
    levrange = 1:1,
)

elev = USGS3DEP(domain; resolution=10.0)
```

### Variables

```@example usgs3dep
vars = unknowns(elev)
DataFrame(
    :Name => [string(Symbolics.tosymbol(v, escape = false)) for v in vars],
    :Units => [dimension(ModelingToolkit.get_unit(v)) for v in vars],
    :Description => [ModelingToolkit.getdescription(v) for v in vars]
)
```

### Parameters

```@example usgs3dep
function table(vars)
    DataFrame(
        :Name => [string(Symbolics.tosymbol(v, escape = false)) for v in vars],
        :Units => [dimension(ModelingToolkit.get_unit(v)) for v in vars],
        :Description => [ModelingToolkit.getdescription(v) for v in vars]
    )
end
table(parameters(elev))
```

### Equations

```@example usgs3dep
eqs = equations(elev)
```

## How It Works

1. **Bounding box**: The spatial extent of the domain is converted to a WGS84 (EPSG:4326) longitude/latitude bounding box with a one-pixel buffer.

2. **Download**: A single GeoTIFF tile covering the bounding box is requested from the USGS ImageServer `exportImage` endpoint. Pixel dimensions are computed from the requested resolution, capped at 4000x4000 to limit download size. The tile is cached locally.

3. **Coordinate mapping**: Pixel-centre coordinates are computed analytically from the bounding box and pixel dimensions (no GeoTIFF metadata parsing needed). Coordinates are stored in radians for consistency with the EarthSciML coordinate system.

4. **Interpolation**: The elevation field is provided as a `DataSetInterpolator` that maps simulation coordinates to elevation values via bilinear interpolation.

## Coverage

!!! warning "US coverage only"
    3DEP provides elevation data for the United States only. If the domain falls outside US coverage, a warning is issued and the returned data may contain nodata values. Approximate coverage bounds: longitude -180 to -60, latitude 17 to 72.
