using Dates
using DynamicQuantities
using EarthSciMLBase
using EarthSciData
using ModelingToolkit
using ModelingToolkit: t, D
using NCDatasets
using OrdinaryDiffEqTsit5
using Test

# When a multi-variable data loader is composed into a parent system that
# references only a subset of its variables, `EarthSciData.prune_unused_interps!`
# (opt-in) marks the unreferenced ones as dead so the discrete update event's
# affect skips their `lazyload!`, leaving the sentinel buffers in place.  This
# test verifies that gating works for the simple `ODEProblem(sys, ...)` path.
@testset "Interpolator pruning under partial use" begin
    era5_dir = mktempdir()

    lon_vals = Float64.(-130.0:2.0:-60.0)
    lat_vals = Float64.(20.0:2.0:50.0)
    plev_vals = Float64.([1000, 975, 950, 925])
    hours_per_day = 0:6:18

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

    nlon, nlat, nplev = length(lon_vals), length(lat_vals), length(plev_vals)
    fpath = joinpath(era5_dir, "era5_pl_2022_01.nc")
    time_vals = DateTime[]
    for d in 1:Dates.daysinmonth(2022, 1), h in hours_per_day
        push!(time_vals, DateTime(2022, 1, d, h))
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

    domain = DomainInfo(
        DateTime(2022, 1, 1), DateTime(2022, 1, 2);
        latrange = deg2rad(20.0f0):deg2rad(2.0):deg2rad(50.0f0),
        lonrange = deg2rad(-130.0f0):deg2rad(2.0):deg2rad(-60.0f0),
        levrange = 1:4
    )
    era5 = ERA5(domain; mirror = "file://$(era5_dir)")

    infos = ModelingToolkit.getmetadata(era5, EarthSciData.InterpInfos, nothing)
    @test length(infos) == length(era5_vars)
    for info in infos
        @test info.itp.cache.initialized == false
    end

    # Auto-registration check: every loader's metadata should carry a
    # `SysDiscreteEvent` factory so EarthSciMLBase's
    # `convert(::Type{System}, ::CoupledSystem)` walks it automatically.
    auto_factory = ModelingToolkit.getmetadata(
        era5, EarthSciMLBase.SysDiscreteEvent, nothing)
    @test auto_factory !== nothing
    @test auto_factory isa Function
    @test hasmethod(auto_factory, (ModelingToolkit.AbstractSystem,))

    # Parent state references only the temperature interpolator (`pl₊t`).
    # All other ERA5 variables (u, v, w, q, ...) are unreferenced.
    @variables C(t)=0.0 [unit = u"K*s"]
    eq = D(C) ~ era5.pl₊t
    sys_unsimp = compose(System([eq], t, [C], []; name = :state), era5)
    sys = mtkcompile(sys_unsimp)

    # `compose` + `mtkcompile` bypasses `convert(::Type{System}, ::CoupledSystem)`,
    # so the auto-registered `SysDiscreteEvent` walk doesn't fire.  Invoke
    # the factory manually here so the test exercises the same prune logic
    # that auto-registration runs on the coupled-system path.
    auto_factory(sys)

    ps = parameters(sys)
    lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
    lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))
    lev_p = only(filter(p -> endswith(string(Symbol(p)), "₊lev"), ps))

    prob = ODEProblem(
        sys,
        [lat_p => deg2rad(35.0), lon_p => deg2rad(-90.0), lev_p => 1.0],
        (0.0, 60.0)
    )
    integ = init(prob, Tsit5())

    initialized = sort([String(info.itp.varname)
                        for info in infos if info.itp.cache.initialized])
    not_initialized = sort([String(info.itp.varname)
                            for info in infos if !info.itp.cache.initialized])

    @info "After init(prob): $(length(initialized)) of $(length(infos)) interpolators loaded" initialized not_initialized

    # Sanity: the variable referenced by the state RHS must be loaded.
    @test "t" in initialized

    # Per-variable gating: variables that no compiled equation references
    # must NOT have their full-grid `cache.data_buffer` allocated by the
    # discrete event firing during `init`.  The init affect prunes them via
    # `needed_vars(integ.f.sys)` so subsequent fires (and the init fire
    # itself) skip `lazyload!` on dead interpolators.
    for v in ["u", "v", "w", "q", "r", "z", "d", "vo", "o3", "cc",
              "ciwc", "clwc", "crwc", "cswc", "pv"]
        @test v in not_initialized
    end
    @test length(initialized) == 1
end
