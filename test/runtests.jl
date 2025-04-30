using EarthSciData
using Test, SafeTestsets

@testset "EarthSciData.jl" begin
    @safetestset "load" begin include("load_test.jl") end
    @safetestset "geosfp" begin include("geosfp_test.jl") end
    @safetestset "wrf" begin include("wrf_test.jl") end
    @safetestset "nei2016monthly" begin include("nei2016monthly_test.jl") end
    @safetestset "NetCDFOutputter" begin include("netcdf_output_test.jl") end
    @safetestset "Solve" begin include("solve_test.jl") end
    @safetestset "NCEP-NCAR Reanalysis" begin include("NCEP-NCAR_Reanalysis_test.jl") end
end
