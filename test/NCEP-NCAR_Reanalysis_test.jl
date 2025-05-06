using Dates
using ModelingToolkit: D, t
using ModelingToolkit
using EarthSciData
using EarthSciMLBase
using DynamicQuantities
using Proj
using Test


domain = DomainInfo(
    DateTime(2019, 1, 1, 0, 0, 0),
    DateTime(2019, 1, 3, 0, 0, 0);
    latrange = range(deg2rad(-90.0), deg2rad(90.0), step=deg2rad(2.5)),
    lonrange = range(deg2rad(0.0), deg2rad(360.0), step=deg2rad(2.5)),
    levrange = 1:17,
    dtype = Float64
)

lonv = deg2rad(262.5)
latv = deg2rad(40)
levv = 5.0
tt = DateTime(2019, 1, 2, 0, 0, 0)

mirror = "https://downloads.psl.noaa.gov/Datasets/ncep.reanalysis/pressure/"

# Use the following if files are stored locally:
#mirror = "file:///path/to/NCEP-NCAR-Reanalysis/"  # Example: "file:///home/user/data/NCEP-NCAR-Reanalysis/"

@parameters lat [unit=u"rad"] lon [unit=u"rad"] lev
ncep_sys = NCEPNCARReanalysis(mirror, domain)
fs = EarthSciData.NCEPNCARReanalysisFileSet(mirror, domain)

@testset "coordinates" begin

    mdU = EarthSciData.loadmetadata(fs, "uwnd")
    @test mdU.staggering == (false, false, false)

    @testset "uwnd" begin
        mdU = EarthSciData.loadmetadata(fs, "uwnd")
        latvals = deg2rad.(reverse(fs.ds[:uwnd]["lat"][:]))
        lonvals = deg2rad.(fs.ds[:uwnd]["lon"][:])

        @test mdU.coords[mdU.ydim][1] ≈ latvals[1] rtol=1e-5
        @test mdU.coords[mdU.ydim][end] ≈ latvals[end] rtol=1e-5
        @test mdU.coords[mdU.xdim][1] ≈ lonvals[1] rtol=1e-5
        @test mdU.coords[mdU.xdim][end] ≈ lonvals[end] rtol=1e-5
    end

    @testset "vwnd" begin
        mdV = EarthSciData.loadmetadata(fs, "vwnd")
        latvals = deg2rad.(reverse(fs.ds[:vwnd]["lat"][:]))
        lonvals = deg2rad.(fs.ds[:vwnd]["lon"][:])

        @test mdV.coords[mdV.ydim][1] ≈ latvals[1] rtol=1e-5
        @test mdV.coords[mdV.ydim][end] ≈ latvals[end] rtol=1e-5
        @test mdV.coords[mdV.xdim][1] ≈ lonvals[1] rtol=1e-5
        @test mdV.coords[mdV.xdim][end] ≈ lonvals[end] rtol=1e-5
    end

end

@testset "ncepncar" begin

    lon, lat, lev = EarthSciMLBase.pvars(domain)
    @constants c_unit = 6.0 [unit = u"rad" description = "constant to make units cancel out"]

    struct ExampleCoupler
        sys
    end

    function Example()
        @variables c(t) [unit = u"mol/m^3"]
        eqs = [D(c) ~ (sin(lat * c_unit) + sin(lon * c_unit)) * c / t]
        return ODESystem(eqs, t; name=:ExampleSys, metadata=Dict(:coupletype => ExampleCoupler))
    end

    function EarthSciMLBase.couple2(e::ExampleCoupler, w::EarthSciData.NCEPNCARReanalysisCoupler)
        e, w = e.sys, w.sys
        e = EarthSciMLBase.param_to_var(e, :lat, :lon)
        ConnectorSystem([
                e.lat ~ w.lat,
                e.lon ~ w.lon,
            ], e, w)
    end

    examplesys = Example()

    composed_sys = couple(examplesys, domain, Advection(), ncep_sys)
    pde_sys = convert(PDESystem, composed_sys)

    eqs = equations(pde_sys)

    want_terms = [
        "MeanWind₊v_lon(t, lon, lat, lev)", "NCEPNCARReanalysis₊uwnd(t, lon, lat, lev)",
        "MeanWind₊v_lat(t, lon, lat, lev)", "NCEPNCARReanalysis₊vwnd(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊air(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊omega(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊hgt(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊uwnd_itp(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊vwnd_itp(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊air_itp(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊omega_itp(t, lon, lat, lev)",
        "NCEPNCARReanalysis₊hgt_itp(t, lon, lat, lev)",
        "lon2m", "lat2meters",
        "Differential(lat)(ExampleSys₊c(t, lon, lat, lev))",
        "Differential(t)(ExampleSys₊c(t, lon, lat, lev))",
        "Differential(lon)(ExampleSys₊c(t, lon, lat, lev))",
        "sin(ExampleSys₊c_unit*ExampleSys₊lat(t, lon, lat, lev))",
        "sin(ExampleSys₊c_unit*ExampleSys₊lon(t, lon, lat, lev))",
        "ExampleSys₊c(t, lon, lat, lev)", "t",
        "Differential(lev)(ExampleSys₊c(t, lon, lat, lev))",
    ]

    have_eqs = string.(eqs)
    have_eqs = replace.(have_eqs, ("Main." => "",))

    for term ∈ want_terms
        @test any(occursin.((term,), have_eqs))
    end

end

@testset "ncep vertical velocity wwnd" begin

    iipt = findfirst(eq -> string(Symbolics.tosymbol(eq.lhs)) == "wwnd(t)", equations(ncep_sys))
    W_eq = equations(ncep_sys)[iipt]

    W_sub = ModelingToolkit.subs_constants(W_eq.rhs)
    vars_in_expr = get_variables(W_sub)

    omega_itp = vars_in_expr[findfirst(isequal(:omega_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]
    air_itp = vars_in_expr[findfirst(isequal(:air_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    W_expr = build_function(W_sub, [t, lon, lat, lev, omega_itp, air_itp])
    myf = eval(W_expr)

    events = ModelingToolkit.get_discrete_events(ncep_sys)
    event_omega = only(events[[only(e.affects.pars_syms) == :omega_itp for e in events]])
    event_air = only(events[[only(e.affects.pars_syms) == :air_itp for e in events]])

    Main.EarthSciData.lazyload!(event_omega.affects.ctx, tt)
    Main.EarthSciData.lazyload!(event_air.affects.ctx, tt)

    itp_omega = EarthSciData.ITPWrapper(event_omega.affects.ctx)
    itp_air = EarthSciData.ITPWrapper(event_air.affects.ctx)

    W_val_want = [0.00525, 0.00255, -0.01597, -0.00248, 0.01633, 0.08086]

    W_val= [myf([tt, lonv, latv, levv, itp_omega, itp_air]) for levv in [1, 2, 5, 7.5, 12, 16]]

    @test W_val ≈ W_val_want rtol=1e-3

end

@testset "ncep pressure" begin

    eqs = equations(ncep_sys)
    p_var = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :p, eqs)].rhs
    p_sub = ModelingToolkit.subs_constants(p_var)

    p_expr = build_function(p_sub, [t, lon, lat, lev])
    p_f = eval(p_expr)

    p_want = [100000, 92500, 60000, 35000, 10000, 2000]
    p_vals = [p_f([tt, lonv, latv, levv]) for levv in [1, 2, 5, 7.5, 12, 16]]
    @test p_vals ≈ p_want rtol=1e-2

end

@testset "ncep δzδlev" begin
    
    events = ModelingToolkit.get_discrete_events(ncep_sys)
    e_hgt = only(events[[only(e.affects.pars_syms) == :hgt_itp for e in events]])

    EarthSciData.lazyload!(e_hgt.affects.ctx, tt)

    itp_hgt = EarthSciData.ITPWrapper(e_hgt.affects.ctx)

    eqs = equations(ncep_sys)
    δzδlev_var = eqs[findfirst(x -> EarthSciMLBase.var2symbol(x.lhs) == :δzδlev, eqs)].rhs
    δzδlev_sub = ModelingToolkit.subs_constants(δzδlev_var)

    vars_in_expr = get_variables(δzδlev_sub)
    hgt_itp = vars_in_expr[findfirst(isequal(:hgt_itp), EarthSciMLBase.var2symbol.(vars_in_expr))]

    δzδlev_expr = build_function(δzδlev_sub, [t, lon, lat, lev, hgt_itp])
    δzδlev_f = eval(δzδlev_expr)

    δzδlev_want = [598, 649, 1358, 1583, 2232, 4410]
    δzδlev_vals = [δzδlev_f([tt, lonv, latv, levv, itp_hgt]) for levv in [1, 2, 5, 7.5, 12, 16]]
    @test δzδlev_vals ≈ δzδlev_want rtol=1e-3

end
