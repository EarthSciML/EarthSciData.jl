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

To use ERA5 data in production, you will need a CDS API key (see [Setup](@ref) above).
The example below uses a small synthetic dataset to demonstrate the API.

```@example era5
using EarthSciData, EarthSciMLBase # hide
using ModelingToolkit, DataFrames # hide
using ModelingToolkit: t # hide
using Dates # hide
using DynamicQuantities # hide
using DynamicQuantities: dimension # hide
using NCDatasets # hide
# hide
# Generate a small synthetic ERA5 NetCDF file for this example. # hide
era5_dir = mktempdir() # hide
lon_vals = Float64.(-130.0:5.0:-60.0) # hide
lat_vals = Float64.(20.0:5.0:50.0) # hide
plev_vals = Float64.([1000, 975, 950, 925]) # hide
time_vals = [DateTime(2022, 1, d, h) for d in 1:31 for h in 0:6:18] # hide
era5_vars = Dict( # hide
    "t" => ("K", "Temperature", 260.0, 300.0), # hide
    "u" => ("m s**-1", "U component of wind", -15.0, 15.0), # hide
    "v" => ("m s**-1", "V component of wind", -15.0, 15.0), # hide
    "w" => ("Pa s**-1", "Vertical velocity", -1.0, 1.0), # hide
    "q" => ("kg kg**-1", "Specific humidity", 0.0, 0.02), # hide
    "r" => ("%", "Relative humidity", 0.0, 100.0), # hide
    "z" => ("m**2 s**-2", "Geopotential", 0.0, 1e5), # hide
    "d" => ("s**-1", "Divergence", -1e-5, 1e-5), # hide
    "vo" => ("s**-1", "Vorticity (relative)", -1e-5, 1e-5), # hide
    "o3" => ("kg kg**-1", "Ozone mass mixing ratio", 0.0, 1e-5), # hide
    "cc" => ("(0 - 1)", "Fraction of cloud cover", 0.0, 1.0), # hide
    "ciwc" => ("kg kg**-1", "Specific cloud ice water content", 0.0, 1e-5), # hide
    "clwc" => ("kg kg**-1", "Specific cloud liquid water content", 0.0, 1e-5), # hide
    "crwc" => ("kg kg**-1", "Specific rain water content", 0.0, 1e-5), # hide
    "cswc" => ("kg kg**-1", "Specific snow water content", 0.0, 1e-5), # hide
    "pv" => ("K m**2 kg**-1 s**-1", "Potential vorticity", -1e-5, 1e-5) # hide
) # hide
NCDataset(joinpath(era5_dir, "era5_pl_2022_01.nc"), "c") do ds # hide
    nlon, nlat,
    nplev, ntime = length(lon_vals), length(lat_vals), length(plev_vals), length(time_vals) # hide
    defDim(ds, "longitude", nlon) # hide
    defDim(ds, "latitude", nlat) # hide
    defDim(ds, "pressure_level", nplev) # hide
    defDim(ds, "valid_time", ntime) # hide
    defVar(ds, "longitude", Float64, ("longitude",))[:] = lon_vals # hide
    defVar(ds, "latitude", Float64, ("latitude",))[:] = lat_vals # hide
    defVar(ds, "pressure_level", Float64, ("pressure_level",))[:] = plev_vals # hide
    nctime = defVar(ds, "valid_time", Float64, ("valid_time",), # hide
        attrib = Dict("units" => "hours since 1900-01-01 00:00:00", # hide
            "calendar" => "proleptic_gregorian")) # hide
    nctime[:] = time_vals # hide
    for (vname, (units, long_name, vmin, vmax)) in era5_vars # hide
        ncvar = defVar(ds, vname, Float32, # hide
            ("longitude", "latitude", "pressure_level", "valid_time"), # hide
            attrib = Dict("units" => units, "long_name" => long_name)) # hide
        data = [Float32(vmin +
                        (vmax - vmin) * (i + j + k + ti) / (nlon + nlat + nplev + ntime)) # hide
                for i in 1:nlon, j in 1:nlat, k in 1:nplev, ti in 1:ntime] # hide
        ncvar[:, :, :, :] = data # hide
    end # hide
end # hide
nothing # hide
```

```@example era5
using EarthSciData, EarthSciMLBase
using ModelingToolkit, DataFrames
using ModelingToolkit: t
using Dates
using DynamicQuantities
using DynamicQuantities: dimension

domain = DomainInfo(DateTime(2022, 1, 1), DateTime(2022, 1, 3);
    latrange = deg2rad(20.0f0):deg2rad(5.0):deg2rad(50.0f0),
    lonrange = deg2rad(-130.0f0):deg2rad(5.0):deg2rad(-60.0f0),
    levrange = 1:4
)

era5 = ERA5(domain; mirror = "file://$(era5_dir)")
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

| Short Name | Long Name                           | Units         |
|:---------- |:----------------------------------- |:------------- |
| t          | Temperature                         | K             |
| u          | U component of wind                 | m s⁻¹         |
| v          | V component of wind                 | m s⁻¹         |
| w          | Vertical velocity                   | Pa s⁻¹        |
| q          | Specific humidity                   | kg kg⁻¹       |
| r          | Relative humidity                   | %             |
| z          | Geopotential                        | m² s⁻²        |
| d          | Divergence                          | s⁻¹           |
| vo         | Vorticity                           | s⁻¹           |
| o3         | Ozone mass mixing ratio             | kg kg⁻¹       |
| cc         | Fraction of cloud cover             | (0-1)         |
| ciwc       | Specific cloud ice water content    | kg kg⁻¹       |
| clwc       | Specific cloud liquid water content | kg kg⁻¹       |
| crwc       | Specific rain water content         | kg kg⁻¹       |
| cswc       | Specific snow water content         | kg kg⁻¹       |
| pv         | Potential vorticity                 | K m² kg⁻¹ s⁻¹ |

## Pressure Levels

ERA5 provides data on 37 pressure levels from 1000 hPa (surface) to 1 hPa (stratosphere). The level index maps to pressure as follows:

| Index | Pressure (hPa) | Index | Pressure (hPa) |
|:----- |:-------------- |:----- |:-------------- |
| 1     | 1000           | 20    | 300            |
| 2     | 975            | 21    | 250            |
| 3     | 950            | 22    | 225            |
| 4     | 925            | 23    | 200            |
| 5     | 900            | 24    | 175            |
| 6     | 875            | 25    | 150            |
| 7     | 850            | 26    | 125            |
| 8     | 825            | 27    | 100            |
| 9     | 800            | 28    | 70             |
| 10    | 775            | 29    | 50             |
| 11    | 750            | 30    | 30             |
| 12    | 700            | 31    | 20             |
| 13    | 650            | 32    | 10             |
| 14    | 600            | 33    | 7              |
| 15    | 550            | 34    | 5              |
| 16    | 500            | 35    | 3              |
| 17    | 450            | 36    | 2              |
| 18    | 400            | 37    | 1              |
| 19    | 350            |       |                |
