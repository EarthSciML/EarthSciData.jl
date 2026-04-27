using Dates
using ModelingToolkit: D, t
using ModelingToolkit
using EarthSciMLBase
using EarthSciData
using DynamicQuantities
using Proj
using OrdinaryDiffEqTsit5
using SymbolicIndexingInterface: setp, getsym, parameter_values
using Test

struct WRFExampleCoupler
    sys::Any
end

@testset "WRF" begin
    function setup()
        domain = DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            latrange = deg2rad(25.0f0):deg2rad(0.1):deg2rad(50.0f0),
            lonrange = deg2rad(-125.0f0):deg2rad(0.1):deg2rad(-65.0f0),
            levrange = 1:32
        )
        return (; domain)
    end

    # Test that the coordinates that we calculate match the coordinates in the file.
    @testset "coordinates" begin
        (; domain) = setup()
        fs = EarthSciData.WRFFileSet("https://data.rda.ucar.edu/d340000/", domain)
        mdU = EarthSciData.loadmetadata(fs, "U")
        @test mdU.staggering == (true, false, false)
        trans = Proj.Transformation(
            "+proj=pipeline +step " * domain.spatial_ref * " +step " * mdU.native_sr,
        )
        @testset "U" begin
            fc = trans.(deg2rad.(fs.ds["XLONG_U"][1:390]), deg2rad.(fs.ds["XLAT_U"][1:390]))

            @test mdU.coords[mdU.xdim][1]≈fc[1][1] rtol=1e-5
            @test mdU.coords[mdU.xdim][end]≈fc[end][1] rtol=1e-5
            @test mdU.coords[mdU.ydim][1]≈fc[1][2] rtol=1e-5
        end

        @testset "V" begin
            mdV = EarthSciData.loadmetadata(fs, "V")
            fc = trans.(deg2rad.(fs.ds["XLONG_V"][1:389]), deg2rad.(fs.ds["XLAT_V"][1:389]))

            @test mdV.coords[mdV.xdim][1]≈fc[1][1] rtol=1e-5
            @test mdV.coords[mdV.xdim][end]≈fc[end][1] rtol=1e-5
            @test mdV.coords[mdV.ydim][1]≈fc[1][2] rtol=1e-5
        end
    end

    # The `convert(PDESystem, composed_sys)` here drives MTK's symbolic
    # expansion over the Advection PDE with 8 WRF met variables; on Julia
    # 1.10 (LTS) it reproducibly exhausts the 7 GB CI runner's memory ~26 min
    # in and the runner is SIGTERM'd by the Azure host.  Skip on LTS until
    # the upstream symbolic-processing memory regression is fixed; Julia
    # 1.12 still runs it.
    @static if VERSION >= v"1.11"
        @testset "wrf" begin
            (; domain) = setup()
            lon, lat, lev = EarthSciMLBase.pvars(domain)
            @constants c_unit=6.0 [unit = u"rad" description = "constant to make units cancel out"]

            lonv = deg2rad(-118.2707)
            latv = deg2rad(34.0059)
            levv = 1.0
            tt = DateTime(2023, 8, 15, 0, 0, 0)

            wrf_sys = WRF(domain)

            function Example()
                @variables c(t) [unit = u"mol/m^3"]
                eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
                return System(
                    eqs,
                    t;
                    name = :ExampleSys,
                    metadata = Dict(CoupleType => WRFExampleCoupler)
                )
            end

            function EarthSciMLBase.couple2(e::WRFExampleCoupler, w::EarthSciData.WRFCoupler)
                e, w = e.sys, w.sys
                e = EarthSciMLBase.param_to_var(e, :lat, :lon)
                ConnectorSystem([e.lat ~ w.lat, e.lon ~ w.lon], e, w)
            end

            examplesys = Example()

            composed_sys = couple(examplesys, domain, Advection(), wrf_sys)
            pde_sys = convert(PDESystem, composed_sys)

            eqs = equations(pde_sys)

            want_terms = [
                "MeanWind₊v_lon(t, lon, lat, lev)",
                "WRF₊U(t, lon, lat, lev)",
                "MeanWind₊v_lat(t, lon, lat, lev)",
                "WRF₊V(t, lon, lat, lev)",
                "MeanWind₊v_lev(t, lon, lat, lev)",
                "WRF₊W(t, lon, lat, lev)",
                "interp_unsafe(WRF₊U_data",
                "interp_unsafe(WRF₊V_data",
                "interp_unsafe(WRF₊W_data",
                "WRF₊T(t, lon, lat, lev)",
                "WRF₊P(t, lon, lat, lev)",
                "WRF₊PB(t, lon, lat, lev)",
                "WRF₊PH(t, lon, lat, lev)",
                "WRF₊PHB(t, lon, lat, lev)",
                "lon2m",
                "lat2meters",
                "Differential(lat, 1)(ExampleSys₊c(t, lon, lat, lev)",
                "Differential(t, 1)(ExampleSys₊c(t, lon, lat, lev))",
                "Differential(lon, 1)(ExampleSys₊c(t, lon, lat, lev)",
                "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
                "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
                "ExampleSys₊c(t, lon, lat, lev)",
                "t",
                "Differential(lev, 1)(ExampleSys₊c(t, lon, lat, lev))"
            ]

            have_eqs = string.(eqs)
            have_eqs = replace.(have_eqs, ("Main." => "",))

            for term in want_terms
                @test any(occursin.((term,), have_eqs))
            end
        end
    end # @static if VERSION >= v"1.11"

    # The five `wrf <foo>` ODE-solve testsets that used to live here have
    # been moved to `wrf_solve_test.jl` so they run in a separate Julia
    # subprocess.  Compiling 5 WRF systems back-to-back was OOM-killing the
    # 7 GB CI runner even with the heavy `wrf` PDE testset above gated off.
end
