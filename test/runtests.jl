using Test

# Keep memory bounded: each test file lives inside one outer @testset (a `let`
# block), so its locals become unreachable when the block ends.  Running
# `GC.gc()` between includes ensures the freed memory is actually reclaimed
# before the next file's peak allocation, rather than racing against the
# allocator across file boundaries.
macro include_gc(path)
    quote
        include($path)
        GC.gc(true)
    end
end

@testset "EarthSciData" begin
    @include_gc "utils_test.jl"
    @include_gc "regridding.jl"
    @include_gc "load_test.jl"
    @include_gc "netcdf_output_test.jl"
    @include_gc "solve_test.jl"
    @include_gc "ceds_test.jl"
    @include_gc "edgar_v81_monthly_test.jl"
    @include_gc "nei2016monthly_test.jl"
    @include_gc "openaq_test.jl"
    @include_gc "geosfp_test.jl"
    @include_gc "era5_test.jl"
    @include_gc "wrf_test.jl"
    @include_gc "NCEP-NCAR_Reanalysis_test.jl"
    @include_gc "landfire_test.jl"
    @include_gc "usgs3dep_test.jl"
    @include_gc "coupling_test.jl"
end
