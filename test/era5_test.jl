using EarthSciData
using EarthSciMLBase
using EarthSciMLBase: Advection
using Dates
using ModelingToolkit
using ModelingToolkit: t, D
using NCDatasets
using DynamicQuantities
using OrdinaryDiffEqTsit5
using Symbolics
using Test

struct ERA5TestCoupler
    sys::Any
end

struct ERA5XYTestCoupler
    sys::Any
end

@testset "ERA5" begin
    function setup()
        # --- Synthetic ERA5 test data fixture ---
        # Generate minimal NetCDF files matching ERA5 pressure-level format
        # so tests don't depend on pre-provisioned external data.
        era5_test_dir = mktempdir()

        # Small grid for fast tests.
        lon_vals = Float64.(-130.0:2.0:-60.0)  # 36 points
        lat_vals = Float64.(20.0:2.0:50.0)     # 16 points, ascending
        plev_vals = Float64.([1000, 975, 950, 925])  # 4 levels (hPa), ascending
        hours_per_day = 0:6:18  # 4 time steps per day

        # ERA5 short variable names with their units and typical value ranges.
        era5_vars = Dict(
            "t" => ("K", "Temperature", 260.0, 300.0),
            "u" => ("m s**-1", "U component of wind", -15.0, 15.0),
            "v" => ("m s**-1", "V component of wind", -15.0, 15.0),
            "w" => ("Pa s**-1", "Vertical velocity", -1.0, 1.0),
            "q" => ("kg kg**-1", "Specific humidity", 0.0, 0.02),
            "r" => ("%", "Relative humidity", 0.0, 100.0),
            "z" => ("m**2 s**-2", "Geopotential", 0.0, 1e5),
            "d" => ("s**-1", "Divergence", -1e-5, 1e-5),
            "vo" => ("s**-1", "Vorticity (relative)", -1e-5, 1e-5),
            "o3" => ("kg kg**-1", "Ozone mass mixing ratio", 0.0, 1e-5),
            "cc" => ("(0 - 1)", "Fraction of cloud cover", 0.0, 1.0),
            "ciwc" => ("kg kg**-1", "Specific cloud ice water content", 0.0, 1e-5),
            "clwc" => ("kg kg**-1", "Specific cloud liquid water content", 0.0, 1e-5),
            "crwc" => ("kg kg**-1", "Specific rain water content", 0.0, 1e-5),
            "cswc" => ("kg kg**-1", "Specific snow water content", 0.0, 1e-5),
            "pv" => ("K m**2 kg**-1 s**-1", "Potential vorticity", -1e-5, 1e-5)
        )

        for mo in 1:1  # Only January 2022
            fname = "era5_pl_2022_$(lpad(mo, 2, '0')).nc"
            fpath = joinpath(era5_test_dir, fname)

            nlon = length(lon_vals)
            nlat = length(lat_vals)
            nplev = length(plev_vals)
            days_in_month = Dates.daysinmonth(2022, mo)
            time_vals = DateTime[]
            for d in 1:days_in_month, h in hours_per_day

                push!(time_vals, DateTime(2022, mo, d, h))
            end
            ntime = length(time_vals)

            NCDataset(fpath, "c") do ds
                defDim(ds, "longitude", nlon)
                defDim(ds, "latitude", nlat)
                defDim(ds, "pressure_level", nplev)
                defDim(ds, "valid_time", ntime)

                nclon = defVar(ds, "longitude", Float64, ("longitude",))
                nclon[:] = lon_vals

                nclat = defVar(ds, "latitude", Float64, ("latitude",))
                nclat[:] = lat_vals

                ncplev = defVar(ds, "pressure_level", Float64, ("pressure_level",))
                ncplev[:] = plev_vals

                nctime = defVar(ds, "valid_time", Float64, ("valid_time",),
                    attrib = Dict("units" => "hours since 1900-01-01 00:00:00",
                        "calendar" => "proleptic_gregorian"))
                # NCDatasets interprets time automatically if we give DateTimes
                nctime[:] = time_vals

                for (varname, (unit_str, long_name, vmin, vmax)) in era5_vars
                    ncvar = defVar(ds, varname, Float32,
                        ("longitude", "latitude", "pressure_level", "valid_time"),
                        attrib = Dict("units" => unit_str, "long_name" => long_name))
                    # Fill with simple deterministic pattern for reproducibility.
                    data = Array{Float32}(undef, nlon, nlat, nplev, ntime)
                    for ti in 1:ntime, k in 1:nplev, j in 1:nlat, i in 1:nlon
                        frac = (i + j + k + ti) / (nlon + nlat + nplev + ntime)
                        data[i, j, k, ti] = Float32(vmin + (vmax - vmin) * frac)
                    end
                    ncvar[:, :, :, :] = data
                end
            end
        end

        era5_mirror = "file://$(era5_test_dir)"

        domain = DomainInfo(
            DateTime(2022, 1, 1),
            DateTime(2022, 1, 3);
            latrange = deg2rad(20.0f0):deg2rad(2.0):deg2rad(50.0f0),
            lonrange = deg2rad(-130.0f0):deg2rad(2.0):deg2rad(-60.0f0),
            levrange = 1:4  # Corresponding to ERA5 levels: 1000, 975, 950, 925 hPa
        )

        # Lambert Conformal Conic projection centered on the test data domain.
        lcc_sr = "+proj=lcc +lat_0=35 +lon_0=-90 +lat_1=25 +lat_2=45 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

        # xy domain covering approximately 200 km x 200 km centered on (lon=-90, lat=35)
        xy_domain = DomainInfo(
            DateTime(2022, 1, 1),
            DateTime(2022, 1, 3);
            xrange = -100_000.0:50_000.0:100_000.0,
            yrange = -100_000.0:50_000.0:100_000.0,
            levrange = 1:4,
            spatial_ref = lcc_sr
        )
        return (; era5_mirror, domain, xy_domain, lcc_sr)
    end

    @testset "ERA5 structure" begin
        (; era5_mirror, domain) = setup()
        era5=ERA5(domain; mirror = era5_mirror)

        # Check that the system has the expected parameters.
        param_syms=Symbol.(parameters(era5))
        @test :lon in param_syms
        @test :lat in param_syms
        @test :lev in param_syms

        # Check that key variables are present (prefixed with pl₊).
        var_syms=[Symbolics.tosymbol(v, escape = false) for v in unknowns(era5)]
        @test :pl₊t in var_syms  # Temperature
        @test :pl₊u in var_syms  # U wind
        @test :pl₊v in var_syms  # V wind
        @test :pl₊w in var_syms  # Vertical velocity
        @test :pl₊q in var_syms  # Specific humidity
        @test :P in var_syms  # Pressure (derived)
        @test :δxδlon in var_syms
        @test :δyδlat in var_syms
        @test :δPδlev in var_syms
    end

    @testset "ERA5 pressure levels" begin
        (; era5_mirror, domain) = setup()
        # Test the pressure-level mapping directly.
        # ERA5_PRESSURE_LEVELS_HPA: [1000, 975, 950, 925, ...]
        plevs=EarthSciData.ERA5_PRESSURE_LEVELS_HPA
        @test plevs[1] == 1000
        @test plevs[2] == 975
        @test plevs[3] == 950
        @test plevs[4] == 925

        # Test the interpolator: level index → hPa.
        itp=EarthSciData.era5_P_itp
        @test itp(1.0) ≈ 1000.0
        @test itp(2.0) ≈ 975.0
        @test itp(3.0) ≈ 950.0
        @test itp(4.0) ≈ 925.0
        # Midpoint interpolation.
        @test itp(1.5) ≈ 987.5

        # Verify the pressure equation is present in the system.
        era5=ERA5(domain; mirror = era5_mirror)
        eqs=equations(era5)
        idx=findfirst(x->Symbolics.tosymbol(x.lhs, escape = false)==:P, eqs)
        @test idx !== nothing
    end

    @testset "ERA5 interpolation" begin
        (; era5_mirror, domain) = setup()
        era5_fs=EarthSciData.ERA5PressureLevelFileSet(domain; mirror = era5_mirror)

        # Test metadata loading.
        md=EarthSciData.loadmetadata(era5_fs, "t")
        @test md.xdim > 0
        @test md.ydim > 0
        @test md.zdim > 0
        @test md.unit_str == "K"
        @test md.description == "Temperature"

        # Check coordinate ordering.
        @test issorted(md.coords[md.xdim])  # Longitude should be ascending.
        @test issorted(md.coords[md.ydim])  # Latitude should be ascending.

        # Test that we can create a DataSetInterpolator and load data.
        dt=EarthSciMLBase.dtype(domain)
        starttime, endtime=EarthSciMLBase.get_tspan_datetime(domain)
        itp=EarthSciData.DataSetInterpolator{dt}(
            era5_fs, "t", starttime, endtime, domain; stream = true
        )
        @test EarthSciData.units(itp) == u"K"

        # Test interpolation at a specific point.
        tt=DateTime(2022, 1, 1, 12, 0, 0)
        lonv=deg2rad(-90.0)
        latv=deg2rad(35.0)
        levv=1.0
        EarthSciData.lazyload!(itp, tt)
        val=EarthSciData.interp_unsafe(itp, tt, lonv, latv, levv)
        # Temperature should be reasonable (200-320 K at 1000 hPa).
        @test 200.0 < val < 320.0
    end

    @testset "ERA5 varnames" begin
        (; era5_mirror, domain) = setup()
        era5_fs=EarthSciData.ERA5PressureLevelFileSet(domain; mirror = era5_mirror)
        vnames=EarthSciData.varnames(era5_fs)

        # All 16 variables should be present.
        expected=["t", "u", "v", "w", "q", "r", "z", "d", "vo", "o3",
            "cc", "ciwc", "clwc", "crwc", "cswc", "pv"]
        for v in expected
            @test v in vnames
        end
    end

    @testset "ERA5 ODE integration" begin
        (; era5_mirror, domain) = setup()
        era5=ERA5(domain; mirror = era5_mirror)

        # ERA5 has no state variables (only observed/parameter equations), so wrap
        # with a trivial dummy state so that ODEProblem + solve work.
        @variables _dummy(t) = 0.0
        _sys=compose(System([D(_dummy)~0], t; name = :_w), era5)
        compiled=mtkcompile(_sys)

        prob=ODEProblem(compiled, [], (0.0, 60.0))
        sol=solve(prob, Tsit5())
        # Should complete without error and produce multiple time steps.
        @test length(sol.t) >= 2
    end

    @testset "ERA5 MeanWind coupling" begin
        (; era5_mirror, domain) = setup()
        era5=ERA5(domain; mirror = era5_mirror)

        # Add ERA5 partial derivative transform for vertical coordinate (like GEOSFP pattern).
        domain2=EarthSciMLBase.add_partial_derivative_func(
            domain,
            partialderivatives_δPδlev_era5()
        )

        # Create a simple system with lon/lat as parameters (matching the GEOSFP test pattern).
        lon, lat, _=EarthSciMLBase.pvars(domain2)
        @variables c(ModelingToolkit.t) = 5.0 [unit = u"mol/m^3"]
        @constants c_unit = 6.0 [
            unit = u"rad", description = "constant to make units cancel out"]

        exsys=System(
            [ModelingToolkit.D(c)~(sin(lat*c_unit)+sin(lon*c_unit))*c/ModelingToolkit.t],
            ModelingToolkit.t;
            name = :TestSys,
            metadata = Dict(EarthSciMLBase.CoupleType=>ERA5TestCoupler)
        )

        function EarthSciMLBase.couple2(e::ERA5TestCoupler, g::EarthSciData.ERA5Coupler)
            e, g=e.sys, g.sys
            e=EarthSciMLBase.param_to_var(e, :lat, :lon)
            ConnectorSystem([e.lat~g.lat, e.lon~g.lon], e, g)
        end

        composed=couple(exsys, domain2, Advection(), era5)
        pde_sys=convert(PDESystem, composed)
        eqs=equations(pde_sys)
        eqs_str=string.(eqs)
        eqs_joined=join(eqs_str, " ")

        # MeanWind should couple to ERA5's u, v, w wind components.
        @test any(occursin("MeanWind", s) for s in eqs_str)
        @test occursin("pl₊u", eqs_joined)
        @test occursin("pl₊v", eqs_joined)
        @test occursin("pl₊w", eqs_joined)
    end

    # ---- Tests with xy (projected) domains ----

    @testset "ERA5 xy-domain structure" begin
        (; era5_mirror, xy_domain) = setup()
        era5=ERA5(xy_domain; mirror = era5_mirror)

        # Check that the system has x/y parameters (not lon/lat).
        param_syms=Symbol.(parameters(era5))
        @test :x in param_syms
        @test :y in param_syms
        @test :lev in param_syms
        @test !(:lon in param_syms)
        @test !(:lat in param_syms)

        # Key variables should still be present.
        var_syms=[Symbolics.tosymbol(v, escape = false) for v in unknowns(era5)]
        @test :pl₊t in var_syms
        @test :pl₊u in var_syms
        @test :pl₊v in var_syms
        @test :P in var_syms
        @test :δPδlev in var_syms
        # lon/lat coordinate transforms should NOT be present for xy domains.
        @test !(:δxδlon in var_syms)
        @test !(:δyδlat in var_syms)
    end

    @testset "ERA5 xy-domain ODE integration" begin
        (; era5_mirror, xy_domain) = setup()
        era5=ERA5(xy_domain; mirror = era5_mirror)

        # ERA5 has no state variables — wrap with a dummy DV.
        @variables _dummy(t) = 0.0
        _sys=compose(System([D(_dummy)~0], t; name = :_w), era5)
        compiled=mtkcompile(_sys)

        prob=ODEProblem(compiled, [], (0.0, 60.0))
        sol=solve(prob, Tsit5())
        @test length(sol.t) >= 2
    end

    @testset "ERA5 xy-domain MeanWind coupling" begin
        (; era5_mirror, xy_domain) = setup()
        era5=ERA5(xy_domain; mirror = era5_mirror)

        xy_domain2=EarthSciMLBase.add_partial_derivative_func(
            xy_domain,
            partialderivatives_δPδlev_era5()
        )

        x, y, _=EarthSciMLBase.pvars(xy_domain2)
        @variables c(ModelingToolkit.t) = 5.0 [unit = u"mol/m^3"]
        @constants c_unit = 6.0 [unit = u"m", description = "constant to make units cancel out"]

        exsys=System(
            [ModelingToolkit.D(c)~(sin(x/c_unit)+sin(y/c_unit))*c/ModelingToolkit.t],
            ModelingToolkit.t;
            name = :TestSys,
            metadata = Dict(EarthSciMLBase.CoupleType=>ERA5XYTestCoupler)
        )

        function EarthSciMLBase.couple2(e::ERA5XYTestCoupler, g::EarthSciData.ERA5Coupler)
            e, g=e.sys, g.sys
            e=EarthSciMLBase.param_to_var(e, :x, :y)
            ConnectorSystem([e.x~g.x, e.y~g.y], e, g)
        end

        composed=couple(exsys, xy_domain2, Advection(), era5)
        pde_sys=convert(PDESystem, composed)
        eqs=equations(pde_sys)
        eqs_str=string.(eqs)
        eqs_joined=join(eqs_str, " ")

        # MeanWind should couple to ERA5's u, v, w wind components.
        @test any(occursin("MeanWind", s) for s in eqs_str)
        @test occursin("pl₊u", eqs_joined)
        @test occursin("pl₊v", eqs_joined)
        @test occursin("pl₊w", eqs_joined)
    end
end
