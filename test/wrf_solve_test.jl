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

# These testsets used to live in `wrf_test.jl` but were moved to their own
# subprocess because each `setup_solved()` call allocates a full set of WRF
# interpolator caches (8 met variables over a 250×600×32 domain ≈ 1 GB) and
# `mtkcompile` adds non-collectable globals to MTK; running 5 of them
# back-to-back in one Julia session OOM-kills the LTS CI runner.

@testset "WRF (solve)" begin
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

    # Compile the WRF + dummy-state system ONCE for the four testsets that
    # share the default lon-lat domain.  Recomputing this per-testset, as the
    # original code did, allocates the WRF interpolator caches and MTK
    # symbolic state four times over and was the proximate cause of the
    # post-skip OOM.  The `wrf lambert projection` testset uses a different
    # domain so it still needs its own compile.
    (; domain) = setup()
    let
        wrf_raw = WRF(domain)
        @variables _dummy(t) = 0.0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), wrf_raw)
        global wrf_compiled = mtkcompile(_sys)
    end

    @testset "wrf total pressures" begin
        prob = ODEProblem(wrf_compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.P_total)
        setter = setp(integ, [
            wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        p_want = [100331.86015842063, 100235.71904432855, 100139.57793023644,
            67846.0833619396, 30679.47156109965, 28729.87012240142]
        @test p_levels ≈ p_want
    end

    @testset "wrf lambert projection" begin
        domain_lcc = DomainInfo(
            DateTime(2023, 8, 15, 0, 0, 0),
            DateTime(2023, 8, 15, 3, 0, 0);
            xrange = -2.334e6:12000:2.334e6,
            yrange = -1.374e6:12000:1.374e6,
            levrange = 1:32,
            spatial_ref = "+proj=lcc +lat_1=30.0 +lat_2=60.0 +lat_0=38.999996 +lon_0=-97.0 +x_0=0 +y_0=0 +a=6370000 +b=6370000 +to_meter=1"
        )

        lonv = deg2rad(-118.2707)
        latv = deg2rad(34.0059)
        trans = Proj.Transformation(
            "+proj=pipeline +step " *
            "+proj=longlat +datum=WGS84 +no_defs" *
            " +step " *
            domain_lcc.spatial_ref,
        )
        xv, yv = trans(lonv, latv)

        wrf_raw = WRF(domain_lcc)
        @variables _dummy(t) = 0.0
        _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), wrf_raw)
        compiled = mtkcompile(_sys)
        prob = ODEProblem(compiled, [], get_tref(domain_lcc))
        integ = init(prob, Tsit5())
        f = getsym(integ, compiled.WRF.P_total)
        setter = setp(integ, [compiled.WRF.x, compiled.WRF.y, compiled.WRF.lev])

        p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [xv, yv, lev])
            f(integ)
        end
        p_want = [
            100099.2143558437, 100003.30283880791, 99907.39132177213, 67693.99609309093,
            30617.55578737014, 28672.612298322314]
        @test p_levels ≈ p_want
    end

    @testset "wrf total pressures at fractional-hour timestamps (minutes/seconds)" begin
        tstart = 25.0 * 60 + 36
        tend = tstart + 1

        prob = ODEProblem(wrf_compiled, [], (tstart, tend))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.P_total)
        setter = setp(integ, [
            wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        p_levels = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        p_want = [
            100295.9284090799, 100199.12630285477, 100102.32419662959, 67826.4962347177,
            30668.59654150301, 28719.783883029562]
        @test p_levels ≈ p_want
    end

    @testset "wrf δzδlev" begin
        prob = ODEProblem(wrf_compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.δzδlev)
        setter = setp(integ, [
            wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        δzδlevs = map([1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        δzδlev_want = [10.605308519529093, 16.96470420154144, 23.33493331829344,
            655.5566269461963, 352.24392973192874, 279.69888985290606]
        @test δzδlevs ≈ δzδlev_want
    end

    @testset "wrf ground level vertical velocity" begin
        prob = ODEProblem(wrf_compiled, [], get_tref(domain))
        integ = init(prob, Tsit5())
        f = getsym(integ, wrf_compiled.WRF.W)
        setter = setp(integ, [
            wrf_compiled.WRF.lon, wrf_compiled.WRF.lat, wrf_compiled.WRF.lev])

        ws = map([0.5, 1, 1.5, 2, 21.5, 30, 31.5]) do lev
            setter(integ, [deg2rad(-118.2707), deg2rad(34.0059), lev])
            f(integ)
        end

        w_want = [0.0, 0.00520469831395109, 0.01040939662790218, 0.011643543143849931,
            -0.016975643831838198, 0.026965458394074104, 0.022436248330301084]
        @test ws ≈ w_want
    end
end
