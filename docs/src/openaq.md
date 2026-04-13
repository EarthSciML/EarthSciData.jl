# OpenAQ Air Quality Data

## Overview

[OpenAQ](https://openaq.org/) is a global platform that aggregates and shares open air quality data from governmental and research monitoring stations worldwide. The OpenAQ data loader in EarthSciData.jl provides access to this observational data, mapping point measurements from monitoring stations onto model grid cells.

**Data source**: OpenAQ AWS S3 Archive (`openaq-data-archive.s3.amazonaws.com`)

**Station discovery**: OpenAQ REST API v3 (`api.openaq.org/v3`)

### Available Parameters

| Parameter | Description                |
|:--------- |:-------------------------- |
| `pm25`    | Particulate matter (PM2.5) |
| `pm10`    | Particulate matter (PM10)  |
| `o3`      | Ozone                      |
| `no2`     | Nitrogen dioxide           |
| `so2`     | Sulfur dioxide             |
| `co`      | Carbon monoxide            |
| `bc`      | Black carbon               |
| `pm1`     | Particulate matter (PM1)   |
| `no`      | Nitric oxide               |
| `nox`     | Nitrogen oxides            |

```@docs
OpenAQ
```

## How It Works

### Data Flow

 1. **Station Discovery**: The OpenAQ API is queried to find all monitoring stations within the model domain's bounding box that measure the requested parameter. Results are cached locally as JSON files.

 2. **Data Download**: Daily gzip-compressed CSV files are downloaded from the OpenAQ S3 archive for each station. Files are cached locally under `$EARTHSCIDATADIR/openaq_data/`.

 3. **Point-to-Grid Mapping**: For each hourly time step, measurements from all stations are binned into model grid cells:

      + Each station is assigned to the grid cell that contains its coordinates
      + Multiple stations within the same cell are averaged
      + Multiple readings from the same station within one hour are averaged
      + Grid cells with no stations receive a configurable fill value (default `NaN`)

 4. **Unit Conversion**: OpenAQ data (typically in µg/m³) is converted to SI units (kg/m³) using the standard EarthSciData.jl unit conversion system.

### Authentication

An OpenAQ API key is required for station discovery. Set the `OPENAQ_API_KEY` environment variable or pass the `api_key` keyword argument. Sign up at [explore.openaq.org](https://explore.openaq.org).

Note: No API key is needed for downloading measurement data from S3.

### Station Filtering

Use the `station_filter` keyword argument to filter stations by any criteria:

```julia
# Only include stations with "reference" in their name
OpenAQ("pm25", domain; station_filter = s -> occursin("reference", lowercase(s.name)))

# Exclude specific station IDs
bad_ids = Set([123, 456])
OpenAQ("pm25", domain; station_filter = s -> !(s.id in bad_ids))
```
