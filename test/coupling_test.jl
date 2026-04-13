@testsnippet CouplingSetup begin
    using EarthSciData
    using EarthSciMLBase
    using Dates
    using ModelingToolkit
    using NCDatasets

    # --- Synthetic ERA5 test data for coupling tests ---
    era5_coupling_dir = mktempdir()

    lon_vals = Float64.(-10.0:5.0:30.0)
    lat_vals = Float64.(40.0:5.0:60.0)
    plev_vals = Float64.([1000, 975, 950, 925])

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

    nlon = length(lon_vals)
    nlat = length(lat_vals)
    nplev = length(plev_vals)

    for mo in [6, 7]  # June-July 2020 for EDGAR overlap
        yr = 2020
        fname = "era5_pl_$(yr)_$(lpad(mo, 2, '0')).nc"
        fpath = joinpath(era5_coupling_dir, fname)

        time_vals = DateTime[]
        for d in 1:Dates.daysinmonth(yr, mo), h in 0:6:18

            push!(time_vals, DateTime(yr, mo, d, h))
        end
        ntime = length(time_vals)

        NCDataset(fpath, "c") do ds
            defDim(ds, "longitude", nlon)
            defDim(ds, "latitude", nlat)
            defDim(ds, "pressure_level", nplev)
            defDim(ds, "valid_time", ntime)

            defVar(ds, "longitude", Float64, ("longitude",))[:] = lon_vals
            defVar(ds, "latitude", Float64, ("latitude",))[:] = lat_vals
            defVar(ds, "pressure_level", Float64, ("pressure_level",))[:] = plev_vals

            nctime = defVar(ds, "valid_time", Float64, ("valid_time",),
                attrib = Dict("units" => "hours since 1900-01-01 00:00:00",
                    "calendar" => "proleptic_gregorian"))
            nctime[:] = time_vals

            for (varname, (unit_str, long_name, vmin, vmax)) in era5_vars
                ncvar = defVar(ds, varname, Float32,
                    ("longitude", "latitude", "pressure_level", "valid_time"),
                    attrib = Dict("units" => unit_str, "long_name" => long_name))
                data = Array{Float32}(undef, nlon, nlat, nplev, ntime)
                for ti in 1:ntime, k in 1:nplev, j in 1:nlat, i in 1:nlon
                    frac = (i + j + k + ti) / (nlon + nlat + nplev + ntime)
                    data[i, j, k, ti] = Float32(vmin + (vmax - vmin) * frac)
                end
                ncvar[:, :, :, :] = data
            end
        end
    end

    era5_coupling_mirror = "file://$(era5_coupling_dir)"

    coupling_domain = DomainInfo(
        DateTime(2020, 6, 1),
        DateTime(2020, 7, 1);
        latrange = deg2rad(40.0f0):deg2rad(2):deg2rad(60.0f0),
        lonrange = deg2rad(-10.0f0):deg2rad(2.5):deg2rad(30.0f0),
        levrange = 1:4
    )
end

@testitem "EDGAR + ERA5 coupling" setup=[CouplingSetup] tags=[:coupling] begin
    using ModelingToolkit

    emis=EDGARv81MonthlyEmis("NOx", "POWER_INDUSTRY", coupling_domain)
    era5=ERA5(coupling_domain; mirror = era5_coupling_mirror)

    csys=couple(emis, era5)
    sys=convert(System, csys)
    eqs=observed(sys)
    eqs_str=string(eqs)

    # Coupling should connect lat, lon, lev from emissions to ERA5.
    @test occursin("EDGARv81MonthlyEmis₊lat(t) ~ ERA5₊lat", eqs_str)
    @test occursin("EDGARv81MonthlyEmis₊lon(t) ~ ERA5₊lon", eqs_str)
    @test occursin("EDGARv81MonthlyEmis₊lev(t) ~ ERA5₊lev", eqs_str)
end
