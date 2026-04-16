using Test

@testset "EarthSciData" begin
    include("utils_test.jl")
    include("regridding.jl")
    include("load_test.jl")
    include("netcdf_output_test.jl")
    include("solve_test.jl")
    include("ceds_test.jl")
    include("edgar_v81_monthly_test.jl")
    include("nei2016monthly_test.jl")
    include("openaq_test.jl")
    include("geosfp_test.jl")
    include("era5_test.jl")
    include("wrf_test.jl")
    include("NCEP-NCAR_Reanalysis_test.jl")
    include("landfire_test.jl")
    include("usgs3dep_test.jl")
    include("coupling_test.jl")
end
