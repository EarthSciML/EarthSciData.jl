using EarthSciData
using Dates
using EarthSciMLBase
using CodecZlib
using JSON3
using ModelingToolkit
using DynamicQuantities
using Test

@testset "OpenAQ" begin
    # --- Unit tests for internal helpers (no network needed) ---

    @testset "CSV line splitting" begin
        split_csv = EarthSciData._split_csv_line

        @test split_csv("a,b,c") == ["a", "b", "c"]
        @test split_csv("\"quoted\",b,c") == ["quoted", "b", "c"]
        @test split_csv("a,\"has,comma\",c") == ["a", "has,comma", "c"]
        @test split_csv("123,45.6,hello") == ["123", "45.6", "hello"]
        @test split_csv("a,\"with \"\"quotes\"\"\",c") == ["a", "with \"quotes\"", "c"]
    end

    @testset "OpenAQ datetime parsing" begin
        parse_dt = EarthSciData._parse_openaq_datetime

        @test parse_dt("2024-01-15T12:00:00+00:00") == DateTime(2024, 1, 15, 12, 0, 0)
        @test parse_dt("2024-06-01T08:30:00Z") == DateTime(2024, 6, 1, 8, 30, 0)
        # UTC-5 offset: 23:59:59-05:00 is 2024-01-01T04:59:59 UTC
        @test parse_dt("2023-12-31T23:59:59-05:00") == DateTime(2024, 1, 1, 4, 59, 59)
        # Positive offset: 10:00:00+05:30 is 04:30:00 UTC
        @test parse_dt("2024-01-15T10:00:00+05:30") == DateTime(2024, 1, 15, 4, 30, 0)
        @test parse_dt("invalid") === nothing
    end

    @testset "Cell-station mapping" begin
        stations = [
            EarthSciData.OpenAQStation(1, "A", deg2rad(-73.0), deg2rad(40.0)),
            EarthSciData.OpenAQStation(2, "B", deg2rad(-73.5), deg2rad(40.5)),
            EarthSciData.OpenAQStation(3, "C", deg2rad(-73.0), deg2rad(40.0)),  # Same cell as A
            EarthSciData.OpenAQStation(4, "D", deg2rad(-100.0), deg2rad(20.0)) # Outside grid
        ]

        # Grid edges in radians: 2 cells in each direction
        lon_edges = deg2rad.([-74.0, -73.25, -72.5])
        lat_edges = deg2rad.([39.5, 40.25, 41.0])

        cell_map = EarthSciData._build_cell_station_map(stations, collect(lon_edges), collect(lat_edges))

        # Station A (lon=-73.0°, lat=40.0°):
        #   lon: -73.0 is between -73.25 and -72.5 → bin 2
        #   lat: 40.0 is between 39.5 and 40.25 → bin 1
        #   → cell (2, 1)
        @test haskey(cell_map, (2, 1))
        @test 1 in cell_map[(2, 1)]
        @test 3 in cell_map[(2, 1)]  # Same cell as A

        # Station B (lon=-73.5°, lat=40.5°):
        #   lon: -73.5 is between -74.0 and -73.25 → bin 1
        #   lat: 40.5 is between 40.25 and 41.0 → bin 2
        #   → cell (1, 2)
        @test haskey(cell_map, (1, 2))
        @test cell_map[(1, 2)] == [2]

        # Station D is outside grid
        for (k, v) in cell_map
            @test !(4 in v)
        end
    end

    @testset "Parameter IDs" begin
        @test EarthSciData._parameter_id("pm25") == 2
        @test EarthSciData._parameter_id("o3") == 3
        @test_throws ErrorException EarthSciData._parameter_id("unknown_param")
    end

    @testset "S3 URL construction" begin
        d = Date(2024, 3, 15)
        url = EarthSciData._s3_url(12345, d)
        @test url ==
              "https://openaq-data-archive.s3.amazonaws.com/records/csv.gz/locationid=12345/year=2024/month=03/location-12345-20240315.csv.gz"

        path = EarthSciData._s3_localpath(12345, d)
        @test endswith(path,
            joinpath("openaq_data", "locationid=12345", "year=2024",
                "month=03", "location-12345-20240315.csv.gz"))
    end

    @testset "loadmetadata" begin
        stations = EarthSciData.OpenAQStation[]
        lon_edges = deg2rad.([-74.0, -73.0, -72.0])
        lat_edges = deg2rad.([39.0, 40.0, 41.0])
        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 1, 1), Hour(1),
            collect(DateTime(2024, 1, 1):Hour(1):DateTime(2024, 1, 2))
        )
        fs = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            collect(lon_edges), collect(lat_edges), NaN, 1e-6,
            Dict{Tuple{Int, Int}, Vector{Int}}(),
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )

        md = EarthSciData.loadmetadata(fs, "pm25")
        @test md.varsize == [2, 2]
        @test md.dimnames == ["lon", "lat"]
        @test md.xdim == 1
        @test md.ydim == 2
        @test md.zdim == -1
        @test md.native_sr == "+proj=longlat +datum=WGS84 +no_defs"
        @test length(md.coords[1]) == 2
        @test length(md.coords[2]) == 2
    end

    @testset "loadslice! with synthetic data" begin
        tmpdir = mktempdir()
        ENV["EARTHSCIDATADIR"] = tmpdir

        # Station 1001 and 1002 at lon=-73.5°, lat=40.2° (same cell)
        # Station 1003 at lon=-72.5°, lat=40.8° (different cell)
        stations = [
            EarthSciData.OpenAQStation(1001, "StationA", deg2rad(-73.5), deg2rad(40.2)),
            EarthSciData.OpenAQStation(1002, "StationB", deg2rad(-73.5), deg2rad(40.2)),
            EarthSciData.OpenAQStation(1003, "StationC", deg2rad(-72.5), deg2rad(40.8))
        ]

        d = Date(2024, 6, 15)
        csv_header = "location_id,sensor_id,location,datetime,lat,lon,parameter,unit,value"

        csv_1001 = """$csv_header
1001,5001,StationA,2024-06-15T12:00:00+00:00,40.2,-73.5,pm25,µg/m³,10.0
1001,5001,StationA,2024-06-15T12:30:00+00:00,40.2,-73.5,pm25,µg/m³,20.0
1001,5001,StationA,2024-06-15T13:00:00+00:00,40.2,-73.5,pm25,µg/m³,99.0"""

        csv_1002 = """$csv_header
1002,5002,StationB,2024-06-15T12:15:00+00:00,40.2,-73.5,pm25,µg/m³,30.0"""

        csv_1003 = """$csv_header
1003,5003,StationC,2024-06-15T12:00:00+00:00,40.8,-72.5,pm25,µg/m³,50.0"""

        for (id, csv_content) in [(1001, csv_1001), (1002, csv_1002), (1003, csv_1003)]
            path = EarthSciData._s3_localpath(id, d)
            mkpath(dirname(path))
            open(GzipCompressorStream, path, "w") do io
                write(io, csv_content)
            end
        end

        # Grid: 2x2 cells
        # lon edges: [-74.0, -73.0, -72.0] in degrees → bins: [-74,-73], [-73,-72]
        # lat edges: [39.5, 40.5, 41.0] in degrees → bins: [39.5,40.5], [40.5,41.0]
        lon_edges = deg2rad.([-74.0, -73.0, -72.0])
        lat_edges = deg2rad.([39.5, 40.5, 41.0])

        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 6, 15), Hour(1),
            collect(DateTime(2024, 6, 15):Hour(1):DateTime(2024, 6, 16))
        )

        cell_stations = EarthSciData._build_cell_station_map(stations, collect(lon_edges), collect(lat_edges))
        fs = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            collect(lon_edges), collect(lat_edges), NaN, 1e-6,
            cell_stations,
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )

        data = zeros(Float64, 2, 2)
        EarthSciData.loadslice!(data, fs, DateTime(2024, 6, 15, 12), "pm25")

        # Station 1001 (lon=-73.5°) → lon bin 1 (between -74 and -73)
        # Station 1001 (lat=40.2°) → lat bin 1 (between 39.5 and 40.5)
        # Station 1002 same cell → (1,1)
        # Values at hour 12: station 1001 has 10.0 and 20.0, station 1002 has 30.0
        # Average = (10+20+30)/3 = 20.0; unit conversion: 20.0 * 1e-6 = 2e-5
        @test data[1, 1] ≈ 20.0e-6

        # Station 1003 (lon=-72.5°) → lon bin 2 (between -73 and -72)
        # lat 40.8° is between 40.5° and 41.0° → lat bin 2
        # → cell (2, 2)
        @test data[2, 2] ≈ 50.0e-6

        # Other cells should be NaN
        @test isnan(data[2, 1])
        @test isnan(data[1, 2])

        # Test with custom fill_value (fresh cache per instance, no global to clear)
        fs_zero = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            collect(lon_edges), collect(lat_edges), 0.0, 1e-6,
            cell_stations,
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )
        data2 = zeros(Float64, 2, 2)
        EarthSciData.loadslice!(data2, fs_zero, DateTime(2024, 6, 15, 12), "pm25")
        @test data2[2, 1] == 0.0
        @test data2[1, 2] == 0.0

        delete!(ENV, "EARTHSCIDATADIR")
    end

    @testset "varnames" begin
        stations = EarthSciData.OpenAQStation[]
        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 1, 1), Hour(1),
            collect(DateTime(2024, 1, 1):Hour(1):DateTime(2024, 1, 2))
        )
        fs = EarthSciData.OpenAQFileSet(
            "o3", stations, freq_info,
            [0.0, 1.0], [0.0, 1.0], NaN, 1e-6,
            Dict{Tuple{Int, Int}, Vector{Int}}(),
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )
        @test EarthSciData.varnames(fs) == ["o3"]
    end

    @testset "get_geometry" begin
        stations = EarthSciData.OpenAQStation[]
        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 1, 1), Hour(1),
            collect(DateTime(2024, 1, 1):Hour(1):DateTime(2024, 1, 2))
        )
        lon_edges = [0.0, 1.0, 2.0]
        lat_edges = [0.0, 1.0, 2.0]
        fs = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            lon_edges, lat_edges, NaN, 1e-6,
            Dict{Tuple{Int, Int}, Vector{Int}}(),
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )
        md = EarthSciData.loadmetadata(fs, "pm25")
        polys = EarthSciData.get_geometry(fs, md)
        @test length(polys) == 4  # 2x2 grid
        @test polys[1] == [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.0)]
    end

    @testset "station_filter in discover_stations" begin
        tmpdir = mktempdir()
        ENV["EARTHSCIDATADIR"] = tmpdir

        # Create a fake cached station JSON file with 3 stations
        cache_dir = joinpath(tmpdir, "openaq_stations")
        mkpath(cache_dir)
        bbox = (lon_min = -74.0, lat_min = 39.0, lon_max = -72.0, lat_max = 41.0)
        bbox_str = "$(bbox.lon_min)_$(bbox.lat_min)_$(bbox.lon_max)_$(bbox.lat_max)"
        cache_file = joinpath(cache_dir, "pm25_$(bbox_str).json")
        raw_stations = [
            Dict("id" => 1, "name" => "Good Station",
                "coordinates" => Dict("longitude" => -73.0, "latitude" => 40.0)),
            Dict("id" => 2, "name" => "Bad Station",
                "coordinates" => Dict("longitude" => -73.5, "latitude" => 40.5)),
            Dict("id" => 3, "name" => "Good Station 2",
                "coordinates" => Dict("longitude" => -72.5, "latitude" => 40.8))
        ]
        open(cache_file, "w") do io
            JSON3.write(io, raw_stations)
        end

        # Test without filter: all 3 stations returned
        stations_all = EarthSciData.discover_stations("pm25", bbox, "fake_key", (_) -> true)
        @test length(stations_all) == 3

        # Test with filter: exclude "Bad Station"
        stations_filtered = EarthSciData.discover_stations(
            "pm25", bbox, "fake_key",
            s -> !occursin("Bad", s.name)
        )
        @test length(stations_filtered) == 2
        @test all(s -> !occursin("Bad", s.name), stations_filtered)

        # Verify coordinates are converted to radians
        st1 = stations_all[findfirst(s -> s.id == 1, stations_all)]
        @test st1.lon ≈ deg2rad(-73.0)
        @test st1.lat ≈ deg2rad(40.0)

        delete!(ENV, "EARTHSCIDATADIR")
    end

    @testset "verify_fileset_interface" begin
        @test EarthSciData.verify_fileset_interface(EarthSciData.OpenAQFileSet) === true
    end

    @testset "loadslice! with timezone offsets" begin
        tmpdir = mktempdir()
        ENV["EARTHSCIDATADIR"] = tmpdir

        # Station with data reported in UTC+5:30 timezone
        # 2024-06-15T17:30:00+05:30 = 2024-06-15T12:00:00 UTC (hour 12)
        # 2024-06-15T18:00:00+05:30 = 2024-06-15T12:30:00 UTC (hour 12)
        # 2024-06-15T18:30:00+05:30 = 2024-06-15T13:00:00 UTC (hour 13, different hour)
        stations = [
            EarthSciData.OpenAQStation(2001, "TZ Station", deg2rad(-73.5), deg2rad(40.2)),
        ]

        d = Date(2024, 6, 15)
        csv_header = "location_id,sensor_id,location,datetime,lat,lon,parameter,unit,value"
        csv_2001 = """$csv_header
2001,6001,TZ Station,2024-06-15T17:30:00+05:30,40.2,-73.5,pm25,µg/m³,100.0
2001,6001,TZ Station,2024-06-15T18:00:00+05:30,40.2,-73.5,pm25,µg/m³,200.0
2001,6001,TZ Station,2024-06-15T18:30:00+05:30,40.2,-73.5,pm25,µg/m³,999.0"""

        path = EarthSciData._s3_localpath(2001, d)
        mkpath(dirname(path))
        open(GzipCompressorStream, path, "w") do io
            write(io, csv_2001)
        end

        lon_edges = deg2rad.([-74.0, -73.0])
        lat_edges = deg2rad.([39.5, 40.5])

        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 6, 15), Hour(1),
            collect(DateTime(2024, 6, 15):Hour(1):DateTime(2024, 6, 16))
        )

        cell_stations = EarthSciData._build_cell_station_map(stations, collect(lon_edges), collect(lat_edges))
        fs = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            collect(lon_edges), collect(lat_edges), NaN, 1e-6,
            cell_stations,
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )

        # At hour 12 UTC: should get average of 100.0 and 200.0 (the +05:30 values mapped to UTC 12:00 and 12:30)
        data = zeros(Float64, 1, 1)
        EarthSciData.loadslice!(data, fs, DateTime(2024, 6, 15, 12), "pm25")
        @test data[1, 1] ≈ 150.0e-6

        # At hour 13 UTC: should get 999.0 only (the +05:30 value mapped to UTC 13:00)
        EarthSciData.loadslice!(data, fs, DateTime(2024, 6, 15, 13), "pm25")
        @test data[1, 1] ≈ 999.0e-6

        delete!(ENV, "EARTHSCIDATADIR")
    end

    @testset "loadslice! parameter filtering" begin
        tmpdir = mktempdir()
        ENV["EARTHSCIDATADIR"] = tmpdir

        # CSV with mixed parameters: pm25 and o3
        stations = [
            EarthSciData.OpenAQStation(3001, "Multi", deg2rad(-73.5), deg2rad(40.2)),
        ]

        d = Date(2024, 6, 15)
        csv_header = "location_id,sensor_id,location,datetime,lat,lon,parameter,unit,value"
        csv_3001 = """$csv_header
3001,7001,Multi,2024-06-15T12:00:00+00:00,40.2,-73.5,pm25,µg/m³,10.0
3001,7001,Multi,2024-06-15T12:00:00+00:00,40.2,-73.5,o3,µg/m³,80.0
3001,7001,Multi,2024-06-15T12:30:00+00:00,40.2,-73.5,pm25,µg/m³,30.0"""

        path = EarthSciData._s3_localpath(3001, d)
        mkpath(dirname(path))
        open(GzipCompressorStream, path, "w") do io
            write(io, csv_3001)
        end

        lon_edges = deg2rad.([-74.0, -73.0])
        lat_edges = deg2rad.([39.5, 40.5])
        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 6, 15), Hour(1),
            collect(DateTime(2024, 6, 15):Hour(1):DateTime(2024, 6, 16))
        )
        cell_stations = EarthSciData._build_cell_station_map(stations, collect(lon_edges), collect(lat_edges))

        # FileSet for pm25: should only see pm25 values (10 + 30) / 2 = 20
        fs_pm25 = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            collect(lon_edges), collect(lat_edges), NaN, 1e-6,
            cell_stations,
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )
        data = zeros(Float64, 1, 1)
        EarthSciData.loadslice!(data, fs_pm25, DateTime(2024, 6, 15, 12), "pm25")
        @test data[1, 1] ≈ 20.0e-6

        # FileSet for o3: should only see o3 value = 80
        fs_o3 = EarthSciData.OpenAQFileSet(
            "o3", stations, freq_info,
            collect(lon_edges), collect(lat_edges), NaN, 1e-6,
            cell_stations,
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )
        data_o3 = zeros(Float64, 1, 1)
        EarthSciData.loadslice!(data_o3, fs_o3, DateTime(2024, 6, 15, 12), "o3")
        @test data_o3[1, 1] ≈ 80.0e-6

        delete!(ENV, "EARTHSCIDATADIR")
    end

    @testset "DataSetInterpolator integration" begin
        tmpdir = mktempdir()
        ENV["EARTHSCIDATADIR"] = tmpdir

        # Need at least 2 cells per dimension for BSpline interpolation.
        # Place a station in each cell of a 2x2 grid to avoid NaN fill values.
        stations = [
            EarthSciData.OpenAQStation(4001, "SW", deg2rad(-73.5), deg2rad(40.0)),
            EarthSciData.OpenAQStation(4002, "NW", deg2rad(-73.5), deg2rad(40.7)),
            EarthSciData.OpenAQStation(4003, "SE", deg2rad(-72.5), deg2rad(40.0)),
            EarthSciData.OpenAQStation(4004, "NE", deg2rad(-72.5), deg2rad(40.7))
        ]

        d = Date(2024, 6, 15)
        csv_header = "location_id,sensor_id,location,datetime,lat,lon,parameter,unit,value"

        # All stations report the same values so interpolation result is uniform
        for (id, name, lat, lon) in [(4001, "SW", 40.0, -73.5), (4002, "NW", 40.7, -73.5),
            (4003, "SE", 40.0, -72.5), (4004, "NE", 40.7, -72.5)]
            csv_content = """$csv_header
$id,8001,$name,2024-06-15T12:00:00+00:00,$lat,$lon,pm25,µg/m³,100.0
$id,8001,$name,2024-06-15T13:00:00+00:00,$lat,$lon,pm25,µg/m³,200.0
$id,8001,$name,2024-06-15T14:00:00+00:00,$lat,$lon,pm25,µg/m³,300.0"""
            path = EarthSciData._s3_localpath(id, d)
            mkpath(dirname(path))
            open(GzipCompressorStream, path, "w") do io
                write(io, csv_content)
            end
        end

        # 2x2 grid edges in radians
        lon_edges = deg2rad.([-74.0, -73.0, -72.0])
        lat_edges = deg2rad.([39.5, 40.5, 41.0])
        freq_info = EarthSciData.DataFrequencyInfo(
            DateTime(2024, 6, 15), Hour(1),
            collect(DateTime(2024, 6, 15):Hour(1):DateTime(2024, 6, 16))
        )
        cell_stations = EarthSciData._build_cell_station_map(stations, collect(lon_edges), collect(lat_edges))
        fs = EarthSciData.OpenAQFileSet(
            "pm25", stations, freq_info,
            collect(lon_edges), collect(lat_edges), NaN, 1e-6,
            cell_stations,
            Dict{Tuple{Int, Date}, Vector{Tuple{DateTime, Float64}}}(),
            ReentrantLock()
        )

        # Create a DomainInfo matching our 2x2 grid
        domain = DomainInfo(
            DateTime(2024, 6, 15, 12),
            DateTime(2024, 6, 15, 15);
            lonrange = deg2rad(-74.0):deg2rad(1.0):deg2rad(-72.0),
            latrange = deg2rad(39.5):deg2rad(0.75):deg2rad(41.0),
            levrange = 1:1
        )
        starttime, endtime = get_tspan_datetime(domain)

        itp = EarthSciData.DataSetInterpolator{Float64}(fs, "pm25", starttime, endtime, domain)

        # Interpolate at grid center at hour 12: all stations report 100 µg/m³ = 100e-6 kg/m³
        result = EarthSciData.interp!(itp, DateTime(2024, 6, 15, 12),
            deg2rad(-73.5), deg2rad(40.0))
        @test result > 0
        @test result ≈ 100.0e-6 rtol=0.5

        # Interpolate at hour 13: all stations report 200 µg/m³
        result2 = EarthSciData.interp!(itp, DateTime(2024, 6, 15, 13),
            deg2rad(-73.5), deg2rad(40.0))
        @test result2 > result  # Should increase over time

        delete!(ENV, "EARTHSCIDATADIR")
    end

    @testset "OpenAQ MTK constructor" begin
        tmpdir = mktempdir()
        ENV["EARTHSCIDATADIR"] = tmpdir

        # Pre-seed station cache so discover_stations doesn't need network
        lon_min, lon_max = -74.0, -72.0
        lat_min, lat_max = 39.0, 41.0

        domain = DomainInfo(
            DateTime(2024, 6, 15, 12),
            DateTime(2024, 6, 15, 14);
            lonrange = deg2rad(lon_min):deg2rad(1.0):deg2rad(lon_max),
            latrange = deg2rad(lat_min):deg2rad(1.0):deg2rad(lat_max),
            levrange = 1:1
        )

        # The OpenAQ constructor computes bbox from grid edges, which uses staggered=true.
        # We need to pre-compute the same bbox to create the correct cache file name.
        grid_edges = EarthSciMLBase.grid(domain, (true, true, true))
        bbox_lon_min = rad2deg(minimum(grid_edges[1]))
        bbox_lat_min = rad2deg(minimum(grid_edges[2]))
        bbox_lon_max = rad2deg(maximum(grid_edges[1]))
        bbox_lat_max = rad2deg(maximum(grid_edges[2]))

        cache_dir = joinpath(tmpdir, "openaq_stations")
        mkpath(cache_dir)
        bbox_str = "$(bbox_lon_min)_$(bbox_lat_min)_$(bbox_lon_max)_$(bbox_lat_max)"
        cache_file = joinpath(cache_dir, "pm25_$(bbox_str).json")

        raw_stations = [
            Dict("id" => 5001, "name" => "TestStation",
            "coordinates" => Dict("longitude" => -73.0, "latitude" => 40.0)),
        ]
        open(cache_file, "w") do io
            JSON3.write(io, raw_stations)
        end

        # Pre-seed CSV data for station 5001
        d = Date(2024, 6, 15)
        csv_header = "location_id,sensor_id,location,datetime,lat,lon,parameter,unit,value"
        csv_data = """$csv_header
5001,9001,TestStation,2024-06-15T12:00:00+00:00,40.0,-73.0,pm25,µg/m³,42.0
5001,9001,TestStation,2024-06-15T13:00:00+00:00,40.0,-73.0,pm25,µg/m³,84.0"""

        path = EarthSciData._s3_localpath(5001, d)
        mkpath(dirname(path))
        open(GzipCompressorStream, path, "w") do io
            write(io, csv_data)
        end

        # Call the actual OpenAQ() constructor
        sys = OpenAQ("pm25", domain; api_key = "fake_key_for_test")

        # Verify it returns a System with expected structure
        @test sys isa ModelingToolkit.System

        # Should have exactly one equation (for pm25)
        eqs = equations(sys)
        @test length(eqs) == 1

        # The variable should be named :pm25
        vars = unknowns(sys)
        @test length(vars) == 1
        @test any(v -> occursin("pm25", string(v)), vars)

        # The variable should have units of kg/m^3 (converted from ug/m3)
        var_unit = ModelingToolkit.get_unit(vars[1])
        @test DynamicQuantities.dimension(var_unit) == DynamicQuantities.dimension(u"kg/m^3")

        delete!(ENV, "EARTHSCIDATADIR")
    end
end
