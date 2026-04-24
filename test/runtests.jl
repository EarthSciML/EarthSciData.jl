using Test

# Each test file is run in its own Julia subprocess so that memory (netCDF
# handles, cached regridders, MTK symbolic state) is released before the next
# file starts.  The previous in-process layout accumulated enough resident
# memory to get the CI runner OOM-killed partway through `era5_test.jl` /
# `wrf_test.jl`.  Subprocess isolation is cheaper than parallel workers and
# preserves the existing plain-`@testset` style in each file.
#
# Set `EARTHSCIDATA_TEST_FILES=file1.jl,file2.jl` to run only a subset.

const TEST_FILES = [
    "utils_test.jl",
    "regridding.jl",
    "load_test.jl",
    "netcdf_output_test.jl",
    "solve_test.jl",
    "ceds_test.jl",
    "edgar_v81_monthly_test.jl",
    "nei2016monthly_test.jl",
    "openaq_test.jl",
    "geosfp_test.jl",
    "era5_test.jl",
    "wrf_test.jl",
    "NCEP-NCAR_Reanalysis_test.jl",
    "landfire_test.jl",
    "usgs3dep_test.jl",
    "coupling_test.jl"
]

const SELECTED = let raw = get(ENV, "EARTHSCIDATA_TEST_FILES", "")
    isempty(raw) ? TEST_FILES : split(raw, ',')
end

# `Base.julia_cmd()` inherits `--code-coverage`, depwarn, sysimage, etc. from
# the parent invocation, so `julia-actions/julia-runtest` continues to collect
# coverage across the subprocesses.  We still need to pass `--project`
# explicitly because that is resolved at startup from env/CLI, not from
# JLOptions.
const CHILD_JULIA = let cmd = `$(Base.julia_cmd()) --startup-file=no --color=yes`
    proj = Base.active_project()
    proj === nothing ? cmd : `$cmd --project=$proj`
end

function run_test_file(file::AbstractString)
    path = joinpath(@__DIR__, file)
    return success(run(ignorestatus(`$CHILD_JULIA $path`)))
end

@testset "EarthSciData" begin
    for file in SELECTED
        @testset "$file" begin
            @test run_test_file(file)
        end
    end
end
