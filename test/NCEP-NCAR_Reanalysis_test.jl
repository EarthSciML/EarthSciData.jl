@testsnippet NCEPSetup begin
    using EarthSciMLBase: DomainInfo
    using Dates: DateTime
    using ModelingToolkit: mtkcompile
    domain = DomainInfo(
        DateTime(2019, 1, 1, 0, 0, 0),
        DateTime(2019, 1, 3, 0, 0, 0);
        latrange = range(deg2rad(-90.0), deg2rad(90.0), step = deg2rad(2.5)),
        lonrange = range(deg2rad(0.0), deg2rad(360.0), step = deg2rad(2.5)),
        levrange = 1:17
    )

    lonv = deg2rad(262.5)
    latv = deg2rad(40)
    levv = 5.0
    tt = DateTime(2019, 1, 2, 0, 0, 0)

    mirror = "https://downloads.psl.noaa.gov/Datasets/ncep.reanalysis/"

    ncep_sys = NCEPNCARReanalysis(mirror, domain)
    fs = EarthSciData.NCEPNCARReanalysisFileSet(mirror, domain)
end

@testitem "verify_fileset_interface" begin
    @test EarthSciData.verify_fileset_interface(EarthSciData.NCEPNCARReanalysisFileSet)
end

@testitem "coordinates" setup=[NCEPSetup] begin
    mdU = EarthSciData.loadmetadata(fs, "uwnd")
    @test mdU.staggering == (true, false, false)

    @testset "uwnd" begin
        mdU = EarthSciData.loadmetadata(fs, "uwnd")
        latvals = deg2rad.(reverse(fs.ds[:uwnd]["lat"][:]))
        lonvals = deg2rad.(fs.ds[:uwnd]["lon"][:])

        @test mdU.coords[mdU.ydim][1]≈latvals[1] rtol=1e-5
        @test mdU.coords[mdU.ydim][end]≈latvals[end] rtol=1e-5
        @test mdU.coords[mdU.xdim][1]≈lonvals[1] rtol=1e-5
        @test mdU.coords[mdU.xdim][end]≈lonvals[end] rtol=1e-5
    end

    @testset "vwnd" begin
        mdV = EarthSciData.loadmetadata(fs, "vwnd")
        latvals = deg2rad.(reverse(fs.ds[:vwnd]["lat"][:]))
        lonvals = deg2rad.(fs.ds[:vwnd]["lon"][:])

        @test mdV.coords[mdV.ydim][1]≈latvals[1] rtol=1e-5
        @test mdV.coords[mdV.ydim][end]≈latvals[end] rtol=1e-5
        @test mdV.coords[mdV.xdim][1]≈lonvals[1] rtol=1e-5
        @test mdV.coords[mdV.xdim][end]≈lonvals[end] rtol=1e-5
    end
end

@testitem "ncepncar" setup=[NCEPSetup] begin
    using EarthSciMLBase
    using ModelingToolkit: @constants, @variables, D, PDESystem, System, t, equations
    using DynamicQuantities: @u_str

    struct ExampleCoupler
        sys::Any
    end

    function Example()
        lon, lat, _ = EarthSciMLBase.pvars(domain)
        @constants c_unit=6.0 [unit = u"rad" description = "constant to make units cancel out"]
        @variables c(t) [unit = u"mol/m^3"]
        eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
        return System(
            eqs,
            t;
            name = :ExampleSys,
            metadata = Dict(CoupleType => ExampleCoupler)
        )
    end

    function EarthSciMLBase.couple2(
            e::ExampleCoupler,
            w::EarthSciData.NCEPNCARReanalysisCoupler
    )
        e, w = e.sys, w.sys
        e = EarthSciMLBase.param_to_var(e, :lat, :lon)
        ConnectorSystem([e.lat ~ w.lat, e.lon ~ w.lon], e, w)
    end

    examplesys = Example()

    composed_sys = couple(examplesys, domain, Advection(), ncep_sys)
    pde_sys = convert(PDESystem, composed_sys)

    eqs = equations(pde_sys)

    want_terms = [
        "MeanWind₊v_lon(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊uwnd(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊vwnd(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊air(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊omega(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊hgt(t, lon, lat, lev)",
        "interp_unsafe(NCEPNCARReanalysis₊uwnd_data",
        "interp_unsafe(NCEPNCARReanalysis₊vwnd_data",
        "interp_unsafe(NCEPNCARReanalysis₊air_data",
        "interp_unsafe(NCEPNCARReanalysis₊omega_data",
        "interp_unsafe(NCEPNCARReanalysis₊hgt_data",
        "lon2m",
        "lat2meters",
        "Differential(lat, 1)(ExampleSys₊c(t, lon, lat, lev))",
        "Differential(t, 1)(ExampleSys₊c(t, lon, lat, lev))",
        "Differential(lon, 1)(ExampleSys₊c(t, lon, lat, lev))",
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

@testsnippet NCEPProb begin
    using ModelingToolkit: t, D
    using SymbolicIndexingInterface: setp, getsym, parameter_values
    using SciMLBase: ODEProblem
    using OrdinaryDiffEqTsit5

    # Wrap with a dummy state variable so init/solve work.
    @variables _dummy(t) = 0.0
    _sys = compose(System([D(_dummy) ~ 0], t; name = :_w), ncep_sys)
    compiled = mtkcompile(_sys)
    prob = ODEProblem(compiled, [], (24.0 * 3600, 48.0 * 3600))
    integ = init(prob, Tsit5())
    setter = setp(integ,
        [compiled.NCEPNCARReanalysis.lon, compiled.NCEPNCARReanalysis.lat,
            compiled.NCEPNCARReanalysis.lev])
end

@testitem "ncep vertical velocity wwnd" setup=[NCEPSetup, NCEPProb] begin
    f = getsym(integ, compiled.NCEPNCARReanalysis.wwnd)
    W_val = map([1, 2, 5, 7.5, 12, 16]) do lev
        setter(integ, [lonv, latv, lev])
        f(integ)
    end
    W_val_want = [0.0019118377540854117, 0.0016255623000058477, -0.015113770574739198,
        -0.002477431693133608, 0.015227246265886294, -0.0]
    @test W_val≈W_val_want
end

@testitem "ncep pressure" setup=[NCEPSetup, NCEPProb] begin
    f = getsym(integ, compiled.NCEPNCARReanalysis.p)
    p_vals = map([1, 2, 5, 7.5, 12, 16]) do lev
        setter(integ, [lonv, latv, lev])
        f(integ)
    end
    p_want = [100000, 92500, 60000, 35000, 10000, 2000]
    @test p_vals≈p_want rtol=1e-2
end

@testitem "ncep δzδlev" setup=[NCEPSetup, NCEPProb] begin
    f = getsym(integ, compiled.NCEPNCARReanalysis.δzδlev)
    δzδlev_vals = map([1, 2, 5, 7.5, 12, 16]) do lev
        setter(integ, [lonv, latv, lev])
        f(integ)
    end
    δzδlev_want = [598, 649, 1358, 1583, 2232, 4410]
    @test δzδlev_vals≈δzδlev_want rtol=1e-3
end

@testitem "ncep ground level vertical velocity" setup=[NCEPSetup, NCEPProb] begin
    f = getsym(integ, compiled.NCEPNCARReanalysis.omega)
    omega_vals = map([0.5, 1]) do lev
        setter(integ, [lonv, latv, lev])
        f(integ)
    end
    omega_want = [0.0, -0.024750000797212124]
    @test omega_vals≈omega_want
end
