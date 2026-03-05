@testsnippet OpenAQSetup begin
    using EarthSciData
    using Dates
    using EarthSciMLBase
end

# --- Unit tests for internal helpers (no network needed) ---

@testitem "JSON parser" setup=[OpenAQSetup] begin
    parse_json = EarthSciData._parse_json_string

    @test parse_json("42") == 42
    @test parse_json("3.14") ≈ 3.14
    @test parse_json("\"hello\"") == "hello"
    @test parse_json("true") == true
    @test parse_json("false") == false
    @test parse_json("null") === nothing
    @test parse_json("[1,2,3]") == [1, 2, 3]
    @test parse_json("{\"a\":1,\"b\":\"c\"}") == Dict("a" => 1, "b" => "c")

    nested = parse_json("{\"results\":[{\"id\":123,\"coordinates\":{\"longitude\":-73.5,\"latitude\":40.7}}]}")
    @test nested["results"][1]["id"] == 123
    @test nested["results"][1]["coordinates"]["longitude"] ≈ -73.5

    # Round-trip
    io = IOBuffer()
    EarthSciData._json_write(io, nested)
    rt = parse_json(String(take!(io)))
    @test rt["results"][1]["id"] == 123
end

@testitem "JSON write/read round-trip" setup=[OpenAQSetup] begin
    data = [
        Dict{String,Any}("id" => 1, "name" => "Station A",
            "coordinates" => Dict{String,Any}("longitude" => -120.5, "latitude" => 37.8)),
        Dict{String,Any}("id" => 2, "name" => "Station B",
            "coordinates" => Dict{String,Any}("longitude" => -118.2, "latitude" => 34.1)),
    ]
    tmpfile = tempname() * ".json"
    EarthSciData._write_json_file(tmpfile, data)
    result = EarthSciData._parse_json_file(tmpfile)
    @test length(result) == 2
    @test result[1]["id"] == 1
    @test result[2]["coordinates"]["latitude"] ≈ 34.1
    rm(tmpfile; force=true)
end

@testitem "CSV line splitting" setup=[OpenAQSetup] begin
    split_csv = EarthSciData._split_csv_line

    @test split_csv("a,b,c") == ["a", "b", "c"]
    @test split_csv("\"quoted\",b,c") == ["quoted", "b", "c"]
    @test split_csv("a,\"has,comma\",c") == ["a", "has,comma", "c"]
    @test split_csv("123,45.6,hello") == ["123", "45.6", "hello"]
    @test split_csv("a,\"with \"\"quotes\"\"\",c") == ["a", "with \"quotes\"", "c"]
end

@testitem "OpenAQ datetime parsing" setup=[OpenAQSetup] begin
    parse_dt = EarthSciData._parse_openaq_datetime

    @test parse_dt("2024-01-15T12:00:00+00:00") == DateTime(2024, 1, 15, 12, 0, 0)
    @test parse_dt("2024-06-01T08:30:00Z") == DateTime(2024, 6, 1, 8, 30, 0)
    @test parse_dt("2023-12-31T23:59:59-05:00") == DateTime(2023, 12, 31, 23, 59, 59)
    @test parse_dt("invalid") === nothing
end

@testitem "Cell-station mapping" setup=[OpenAQSetup] begin
    stations = [
        EarthSciData.OpenAQStation(1, "A", deg2rad(-73.0), deg2rad(40.0)),
        EarthSciData.OpenAQStation(2, "B", deg2rad(-73.5), deg2rad(40.5)),
        EarthSciData.OpenAQStation(3, "C", deg2rad(-73.0), deg2rad(40.0)),  # Same cell as A
        EarthSciData.OpenAQStation(4, "D", deg2rad(-100.0), deg2rad(20.0)), # Outside grid
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

@testitem "Parameter IDs" setup=[OpenAQSetup] begin
    @test EarthSciData._parameter_id("pm25") == 2
    @test EarthSciData._parameter_id("o3") == 3
    @test_throws ErrorException EarthSciData._parameter_id("unknown_param")
end

@testitem "S3 URL construction" setup=[OpenAQSetup] begin
    d = Date(2024, 3, 15)
    url = EarthSciData._s3_url(12345, d)
    @test url == "https://openaq-data-archive.s3.amazonaws.com/records/csv.gz/locationid=12345/year=2024/month=03/location-12345-2024-03-15.csv.gz"

    path = EarthSciData._s3_localpath(12345, d)
    @test endswith(path, joinpath("openaq_data", "locationid=12345", "year=2024", "month=03", "location-12345-2024-03-15.csv.gz"))
end

@testitem "loadmetadata" setup=[OpenAQSetup] begin
    stations = EarthSciData.OpenAQStation[]
    lon_edges = deg2rad.([-74.0, -73.0, -72.0])
    lat_edges = deg2rad.([39.0, 40.0, 41.0])
    freq_info = EarthSciData.DataFrequencyInfo(
        DateTime(2024, 1, 1), Hour(1),
        collect(DateTime(2024, 1, 1):Hour(1):DateTime(2024, 1, 2)),
    )
    fs = EarthSciData.OpenAQFileSet(
        EarthSciData.OPENAQ_S3_MIRROR, "pm25", stations, freq_info,
        collect(lon_edges), collect(lat_edges), NaN,
        Dict{Tuple{Int,Int}, Vector{Int}}(),
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

@testitem "loadslice! with synthetic data" setup=[OpenAQSetup] begin
    using CodecZlib

    tmpdir = mktempdir()
    ENV["EARTHSCIDATADIR"] = tmpdir

    # Station 1001 and 1002 at lon=-73.5°, lat=40.2° (same cell)
    # Station 1003 at lon=-72.5°, lat=40.8° (different cell)
    stations = [
        EarthSciData.OpenAQStation(1001, "StationA", deg2rad(-73.5), deg2rad(40.2)),
        EarthSciData.OpenAQStation(1002, "StationB", deg2rad(-73.5), deg2rad(40.2)),
        EarthSciData.OpenAQStation(1003, "StationC", deg2rad(-72.5), deg2rad(40.8)),
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
        collect(DateTime(2024, 6, 15):Hour(1):DateTime(2024, 6, 16)),
    )

    cell_stations = EarthSciData._build_cell_station_map(stations, collect(lon_edges), collect(lat_edges))
    fs = EarthSciData.OpenAQFileSet(
        EarthSciData.OPENAQ_S3_MIRROR, "pm25", stations, freq_info,
        collect(lon_edges), collect(lat_edges), NaN,
        cell_stations,
    )

    data = zeros(Float64, 2, 2)
    EarthSciData.loadslice!(data, fs, DateTime(2024, 6, 15, 12), "pm25")

    # Station 1001 (lon=-73.5°) → lon bin 1 (between -74 and -73)
    # Station 1001 (lat=40.2°) → lat bin 1 (between 39.5 and 40.5)
    # Station 1002 same cell → (1,1)
    # Values at hour 12: station 1001 has 10.0 and 20.0, station 1002 has 30.0
    # Average = (10+20+30)/3 = 20.0; unit conversion: 20.0 * 1e-6 = 2e-5
    @test data[1, 1] ≈ 20.0e-6

    # Station 1003 (lon=-72.5°) → lon bin 2 (between -73 and -72)... wait
    # -72.5° is between -73.0 and -72.0 → searchsortedlast = 1? No:
    # lon_edges in deg: [-74, -73, -72]. In radians these are sorted ascending (negative).
    # deg2rad(-74) < deg2rad(-73) < deg2rad(-72)
    # deg2rad(-72.5) is between deg2rad(-73) and deg2rad(-72) → searchsortedlast = 2
    # lat 40.8° is between 40.5° and 41.0° → lat bin 2
    # → cell (2, 2)
    @test data[2, 2] ≈ 50.0e-6

    # Other cells should be NaN
    @test isnan(data[2, 1])
    @test isnan(data[1, 2])

    # Test with custom fill_value
    fs_zero = EarthSciData.OpenAQFileSet(
        EarthSciData.OPENAQ_S3_MIRROR, "pm25", stations, freq_info,
        collect(lon_edges), collect(lat_edges), 0.0,
        cell_stations,
    )
    data2 = zeros(Float64, 2, 2)
    EarthSciData.loadslice!(data2, fs_zero, DateTime(2024, 6, 15, 12), "pm25")
    @test data2[2, 1] == 0.0
    @test data2[1, 2] == 0.0

    delete!(ENV, "EARTHSCIDATADIR")
end

@testitem "varnames" setup=[OpenAQSetup] begin
    stations = EarthSciData.OpenAQStation[]
    freq_info = EarthSciData.DataFrequencyInfo(
        DateTime(2024, 1, 1), Hour(1),
        collect(DateTime(2024, 1, 1):Hour(1):DateTime(2024, 1, 2)),
    )
    fs = EarthSciData.OpenAQFileSet(
        EarthSciData.OPENAQ_S3_MIRROR, "o3", stations, freq_info,
        [0.0, 1.0], [0.0, 1.0], NaN,
        Dict{Tuple{Int,Int}, Vector{Int}}(),
    )
    @test EarthSciData.varnames(fs) == ["o3"]
end

@testitem "get_geometry" setup=[OpenAQSetup] begin
    stations = EarthSciData.OpenAQStation[]
    freq_info = EarthSciData.DataFrequencyInfo(
        DateTime(2024, 1, 1), Hour(1),
        collect(DateTime(2024, 1, 1):Hour(1):DateTime(2024, 1, 2)),
    )
    lon_edges = [0.0, 1.0, 2.0]
    lat_edges = [0.0, 1.0, 2.0]
    fs = EarthSciData.OpenAQFileSet(
        EarthSciData.OPENAQ_S3_MIRROR, "pm25", stations, freq_info,
        lon_edges, lat_edges, NaN,
        Dict{Tuple{Int,Int}, Vector{Int}}(),
    )
    md = EarthSciData.loadmetadata(fs, "pm25")
    polys = EarthSciData.get_geometry(fs, md)
    @test length(polys) == 4  # 2x2 grid
    @test polys[1] == [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.0)]
end

@testitem "station_filter" setup=[OpenAQSetup] begin
    stations = [
        EarthSciData.OpenAQStation(1, "Good Station", deg2rad(-73.0), deg2rad(40.0)),
        EarthSciData.OpenAQStation(2, "Bad Station", deg2rad(-73.5), deg2rad(40.5)),
        EarthSciData.OpenAQStation(3, "Good Station 2", deg2rad(-72.5), deg2rad(40.8)),
    ]

    filtered = filter(s -> !occursin("Bad", s.name), stations)
    @test length(filtered) == 2
    @test all(s -> !occursin("Bad", s.name), filtered)
end
