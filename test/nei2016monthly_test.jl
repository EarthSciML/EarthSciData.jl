using Test
using EarthSciData, Unitful, EarthSciMLBase, ModelingToolkit
using Dates
#@test_broken begin # This test works locally but on github it gives the error: RequestError: Cert verify failed: BADCERT_NOT_TRUSTED while requesting https://gaftp.epa.gov/Air/emismod/2016/v1/gridded/monthly_netCDF/2016fh_16j_mrggrid_withbeis_withrwc_12US1_month_05.ncf
@parameters t lat lon lev
@parameters Δz = 60 [unit=u"m"]
emis = NEI2016MonthlyEmis{Float64}("mrggrid_withbeis_withrwc", t, lon, lat, lev, Δz)

eqs = equations(emis.sys)
@test length(eqs) == 69
@test contains(string(eqs[1].rhs), "/ Δz")

sample_time = DateTime(2016, 5, 1)
@testset "correct projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX"; spatial_ref="EPSG:4326")
    @test interp!(itp, sample_time, -97, 40, 1) ≈ 8.198218f-10
    @test interp!(itp, sample_time, -97, 40, 2) == 0
end

@testset "incorrect projection" begin
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX"; spatial_ref="EPSG:3857")
    @test interp!(itp, sample_time, -97, 40, 1) == 0.0
end

@testset "monthly frequency" begin
    sample_time = DateTime(2016, 5, 1)
    itp = EarthSciData.DataSetInterpolator{Float32}(emis.fileset, "NOX"; spatial_ref="EPSG:4326")
    EarthSciData.initialize!(itp, sample_time)
    @test_broken month(itp.time1) == 4 #TODO(CT): Fix by adding next() and previous() methods instead of adding and subtracting frequency.
    @test month(itp.time2) == 5

    sample_time = DateTime(2016, 5, 31)
    EarthSciData.initialize!(itp, sample_time)
    @test month(itp.time1) == 5
    @test_broken month(itp.time2) == 6
end
#end