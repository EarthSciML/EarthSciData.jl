using Test, Dates, NCDatasets
using EarthSciData
using EarthSciData: _briggs_plume_rise, inline_target_lev, inline_delp_hpa,
                    _INLINE_MIDALT, _INLINE_DELP, _tar_member_offsets,
                    _read_stack_groups, _inline_centerpoints,
                    NEI2016InlineEmisFileSet, loadslice!, loadmetadata
using EarthSciMLBase
using ModelingToolkit
using ModelingToolkit: t, D
using DynamicQuantities
using OrdinaryDiffEqTsit5
import Proj

# Receiver species for `operator_compose` coupling in the System-builder
# testset below (struct + couple2 method must be top-level; same pattern as
# solve_test.jl's SysCoupler).
struct InlineSysCoupler
    sys::Any
end
function EarthSciMLBase.couple2(
        sys::InlineSysCoupler, emis::EarthSciData.NEI2016InlineEmisCoupler)
    sys, emis = sys.sys, emis.sys
    operator_compose(sys, emis)
end

# ============================================================================
# Synthetic fixtures (fully offline). File names/attrs mirror the EQUATES
# layout exactly so the FileSet constructor's idempotent staging finds every
# file and never touches the network.
# ============================================================================
const TEST_SECTOR = "testegu"

"Write a minimal stack_groups nc4: 3 stacks in 2 distinct 12US1 cells."
function write_stack_groups(dir)
    path = joinpath(dir, "stack_groups_$(TEST_SECTOR)_12US1_WR413_MYR_2017.nc4")
    ds = NCDataset(path, "c")
    defDim(ds, "TSTEP", 1); defDim(ds, "DATE-TIME", 2); defDim(ds, "LAY", 1)
    defDim(ds, "VAR", 8); defDim(ds, "ROW", 3); defDim(ds, "COL", 1)
    # 12US1 LCC attributes (as in the real files)
    ds.attrib["P_ALP"] = 33.0; ds.attrib["P_BET"] = 45.0
    ds.attrib["XCENT"] = -97.0; ds.attrib["YCENT"] = 40.0
    ds.attrib["XORIG"] = -2556000.0; ds.attrib["YORIG"] = -1728000.0
    ds.attrib["XCELL"] = 12000.0; ds.attrib["YCELL"] = 12000.0
    ds.attrib["GDNAM"] = "12US1_459X299"
    v(n, x) = (vv = defVar(ds, n, Float64, ("COL", "ROW", "LAY", "TSTEP")); vv[:] = reshape(x, 1, 3, 1, 1))
    # stacks 1+2 share cell (100, 150); stack 3 alone in (200, 250)
    v("LATITUDE", [39.0, 39.0, 41.0]); v("LONGITUDE", [-97.0, -97.0, -90.0])
    v("COL", [100.0, 100.0, 200.0]);   v("ROW", [150.0, 150.0, 250.0])
    v("STKHT", [200.0, 50.0, 100.0])   # tall coal / short gas / medium
    v("STKDM", [8.0, 3.0, 5.0]); v("STKTK", [420.0, 350.0, 400.0])
    v("STKVE", [25.0, 10.0, 15.0])
    close(ds)
    return path
end

"Write a daily inln_mole nc4 (25 hourly steps) for proxy date `d` (2017)."
function write_inln_day(dir, d::Date; so2 = (12.0, 0.0, 3.0), no = (5.0, 2.0, 1.0))
    ymd = Dates.format(d, "yyyymmdd")
    path = joinpath(dir, "inln_mole_$(TEST_SECTOR)_$(ymd)_12US1_WR413_MYR_2017.nc4")
    ds = NCDataset(path, "c")
    defDim(ds, "TSTEP", 25); defDim(ds, "DATE-TIME", 2); defDim(ds, "LAY", 1)
    defDim(ds, "VAR", 2); defDim(ds, "ROW", 3); defDim(ds, "COL", 1)
    tf = defVar(ds, "TFLAG", Int32, ("DATE-TIME", "VAR", "TSTEP"))
    for k in 1:25
        dt = DateTime(d) + Hour(k - 1)
        tf[1, :, k] .= Int32(year(dt) * 1000 + dayofyear(dt))
        tf[2, :, k] .= Int32(hour(dt) * 10000)
    end
    for (name, vals) in (("SO2", so2), ("NO", no))
        vv = defVar(ds, name, Float64, ("COL", "ROW", "LAY", "TSTEP"))
        vv.attrib["units"] = "moles/s"
        for k in 1:25
            vv[1, :, 1, k] = collect(vals)   # constant-in-time per-stack rates
        end
    end
    close(ds)
    return path
end

@testset "NEI2016InlineEmis (offline synthetic)" begin

@testset "Briggs plume rise" begin
    h_tall = _briggs_plume_rise(200.0, 8.0, 420.0, 25.0)
    h_short = _briggs_plume_rise(50.0, 3.0, 350.0, 10.0)
    @test h_tall > 200.0        # rise added to stack height
    @test h_tall > h_short      # buoyant tall stack tops the short one
    # monotonic in exit velocity (more momentum/buoyancy flux -> higher plume)
    hs = [_briggs_plume_rise(100.0, 5.0, 400.0, v) for v in (5.0, 15.0, 30.0)]
    @test issorted(hs)
    # zero-velocity stack degenerates to (approximately) the physical height
    @test _briggs_plume_rise(100.0, 5.0, 400.0, 0.0) ≈ 100.0 atol = 1e-6
end

@testset "altitude -> level mapping" begin
    @test inline_target_lev(0.0) == 1.0
    @test inline_target_lev(_INLINE_MIDALT[5]) == 5.0
    @test inline_target_lev(1.0e6) == Float64(length(_INLINE_MIDALT))  # table clamp
    @test inline_delp_hpa(5.0) == _INLINE_DELP[5]
    @test inline_delp_hpa(999.0) == _INLINE_DELP[end]                  # index clamp
end

@testset "tar member offset parser" begin
    # tar layout: each member = 512 B header + ceil(size/512)*512 B data
    contents = join([
        "-rw-r--r-- u/g      700 2020-09-10 16:54 2017/x/aaa.nc4",
        "-rw-r--r-- u/g     1024 2020-09-10 16:54 2017/x/bbb.nc4",
    ], "\n")
    offs = _tar_member_offsets(contents)     # Dict{name => (data_offset, size)}
    @test offs["2017/x/aaa.nc4"] == (512, 700)
    @test offs["2017/x/bbb.nc4"] == (512 + 1024 + 512, 1024)  # hdr + padded(700) + hdr
end

mktempdir() do dir
    write_stack_groups(dir)
    # model window Mar 10-11 2016 with padding needs proxy days Mar 10-13 2017
    for d in Date(2017, 3, 10):Day(1):Date(2017, 3, 13)
        write_inln_day(dir, d)
    end
    t0 = DateTime(2016, 3, 10)
    fs = NEI2016InlineEmisFileSet(TEST_SECTOR, t0, t0 + Hour(24) + Hour(36);
        stage_dir = dir)

    @testset "stack table + proxy-year time mapping" begin
        st = fs.stacks
        @test st.n == 3 && st.col == [100, 100, 200] && st.row == [150, 150, 250]
        cps = fs.freq_info.centerpoints
        @test issorted(cps) && allunique(cps)
        @test Dates.year(first(cps)) == 2016            # remapped to the model year
        @test first(cps) == DateTime(2016, 3, 10)
        @test fs.record_times[26] == DateTime(2016, 3, 11)  # day-2 hour-0 record
    end

    @testset "loadslice!: mass conservation + units" begin
        md = loadmetadata(fs, "SO2")
        @test occursin("kg", string(md.unit_str))                  # registered flux key
        data = zeros(Float64, fs.ncols, fs.nrows)
        loadslice!(data, fs, DateTime(2016, 3, 10, 6), "SO2")
        cellarea = fs.dx * fs.dy
        total_kg = sum(data) * cellarea
        expected = (12.0 + 0.0 + 3.0) * 0.064066        # mole/s x MW(SO2) kg/mol
        @test total_kg ≈ expected rtol = 1e-10           # scatter conserves mass
        @test count(!iszero, data) == 2                  # exactly the two source cells
        @test data[100, 150] ≈ 12.0 * 0.064066 / cellarea rtol = 1e-10
    end

    @testset "plume-placement fields (HINJW/WEMIS ratio + zero-SO2 fallback)" begin
        w = zeros(Float64, fs.ncols, fs.nrows)
        hw = zeros(Float64, fs.ncols, fs.nrows)
        loadslice!(w, fs, DateTime(2016, 3, 10, 6), "WEMIS")
        loadslice!(hw, fs, DateTime(2016, 3, 10, 6), "HINJW")
        # single-stack cell: ratio == that stack's Briggs altitude exactly
        h3 = _briggs_plume_rise(100.0, 5.0, 400.0, 15.0)
        @test hw[200, 250] / w[200, 250] ≈ h3 rtol = 1e-10
        # two-stack cell: SO2-weighted mean (stack 2 has zero SO2 -> stack 1 dominates)
        h1 = _briggs_plume_rise(200.0, 8.0, 420.0, 25.0)
        @test hw[100, 150] / w[100, 150] ≈ h1 rtol = 1e-10
        # a cell whose stacks are ALL SO2-free must still get a weight (fallback):
        # rebuild with SO2 zeroed on stack 3
        mktempdir() do dir2
            write_stack_groups(dir2)
            for d in Date(2017, 3, 10):Day(1):Date(2017, 3, 13)
                write_inln_day(dir2, d; so2 = (12.0, 0.0, 0.0))
            end
            fs2 = NEI2016InlineEmisFileSet(TEST_SECTOR, t0, t0 + Hour(24) + Hour(36);
                stage_dir = dir2)
            w2 = zeros(Float64, fs2.ncols, fs2.nrows)
            hw2 = zeros(Float64, fs2.ncols, fs2.nrows)
            loadslice!(w2, fs2, DateTime(2016, 3, 10, 6), "WEMIS")
            loadslice!(hw2, fs2, DateTime(2016, 3, 10, 6), "HINJW")
            @test w2[200, 250] > 0                                   # equal-weight fallback
            @test hw2[200, 250] / w2[200, 250] ≈ h3 rtol = 1e-10      # its NO still injects at plume height
        end
    end
end

@testset "proxy-year edge cases (leap day + Dec-31 wrap)" begin
    mktempdir() do dir
        write_stack_groups(dir)
        for d in (Date(2017, 12, 30), Date(2017, 12, 31))
            write_inln_day(dir, d)
        end
        t0 = DateTime(2016, 12, 30)
        fs = NEI2016InlineEmisFileSet(TEST_SECTOR, t0, t0 + Hour(24);
            stage_dir = dir)
        rt = fs.record_times
        @test issorted(rt)                                # Dec-31 h24 wraps to Jan 1 ...
        @test last(rt) == DateTime(2017, 1, 1)            # ... of model_year+1 (monotonic)
    end
    # Feb-29 model window (2016 leap; proxy 2017 has no Feb 29) must not throw:
    mktempdir() do dir
        write_stack_groups(dir)
        for d in (Date(2017, 2, 27), Date(2017, 2, 28))
            write_inln_day(dir, d)
        end
        fs = NEI2016InlineEmisFileSet(TEST_SECTOR,
            DateTime(2016, 2, 27), DateTime(2016, 2, 29, 12); stage_dir = dir)
        @test fs.stacks.n == 3                            # constructed without error
    end
end

@testset "System builder (NEI2016InlineEmis) + domain-top clamp" begin
    mktempdir() do dir
        write_stack_groups(dir)
        # A day of margin on each side of the model day; the constructor only
        # stages the model window, and the aggregate happily holds more.
        for d in Date(2017, 3, 9):Day(1):Date(2017, 3, 13)
            write_inln_day(dir, d)
        end

        # Model-space (lon/lat radians) center of 12US1 fixture cell (100, 150)
        # — the cell holding the tall stack — by inverting the fixture's LCC
        # (same pipeline idiom as src/load.jl's proj_trans).
        lcc_sr = "+proj=lcc +lat_1=33.0 +lat_2=45.0 +lat_0=40.0 +lon_0=-97.0 " *
                 "+x_0=0 +y_0=0 +a=6370997.0 +b=6370997.0 +to_meter=1"
        to_lonlat = Proj.Transformation("+proj=pipeline +step +inv " * lcc_sr *
                                        " +step +proj=longlat +datum=WGS84 +no_defs")
        lon0, lat0 = to_lonlat(-2556000.0 + 12000.0 * (100 - 0.5),
            -1728000.0 + 12000.0 * (150 - 0.5))

        # The tall stack's Briggs altitude maps to a mean-profile level ABOVE
        # the reduced domain's top level 3, so `min(target, lev_top)` must engage.
        lev_briggs = inline_target_lev(_briggs_plume_rise(200.0, 8.0, 420.0, 25.0))
        @test lev_briggs > 3.0

        function build_sys(levtop)
            domain = DomainInfo(
                DateTime(2016, 3, 10), DateTime(2016, 3, 11);
                lonrange = range(lon0 - deg2rad(2.0), lon0 + deg2rad(2.0), length = 5),
                latrange = range(lat0 - deg2rad(2.0), lat0 + deg2rad(2.0), length = 5),
                levrange = 1:levtop)
            emis = NEI2016InlineEmis(TEST_SECTOR, domain; stage_dir = dir)
            # It builds: the two plume-placement fields + the fixture's
            # available species (SO2, NO) out of the five defaults.
            @test length(equations(emis)) == 4
            @variables SO2(t) = 0.0 [unit = u"kg/kg"]
            recv = System([D(SO2) ~ 0], t; name = :recv,
                metadata = Dict(CoupleType => InlineSysCoupler))
            return convert(System, couple(recv, emis, domain))
        end
        # kg/kg of SO2 accumulated over 1 h at model level `levval`, probed at
        # the tall stack's cell center (fixture rates are constant in time).
        # The converted coupled system is flattened, so fish the coordinate
        # parameters out by their namespaced suffix (the same idiom as
        # nei2016monthly_test.jl); only the emissions subsystem carries them.
        function so2_after(sys, levval)
            ps = parameters(sys)
            lon_p = only(filter(p -> endswith(string(Symbol(p)), "₊lon"), ps))
            lat_p = only(filter(p -> endswith(string(Symbol(p)), "₊lat"), ps))
            lev_p = only(filter(p -> endswith(string(Symbol(p)), "₊lev"), ps))
            prob = ODEProblem(sys,
                [lon_p => lon0, lat_p => lat0, lev_p => Float64(levval)],
                (0.0, 3600.0))
            sol = solve(prob, Tsit5())
            return only(sol.u[end])
        end

        # Reduced-level domain (top level 3 < Briggs target): the clamp routes
        # the plume into the domain's TOP layer; the surface stays clean.
        sys3 = build_sys(3)
        @test so2_after(sys3, 3.0) > 0.0            # effective target_lev == lev_top
        @test so2_after(sys3, 1.0) == 0.0           # nothing at the surface
        # Full-height domain: mass arrives at the (unclamped) Briggs level,
        # confirming the reduced-domain hit at level 3 was the clamp at work.
        sys10 = build_sys(10)
        @test so2_after(sys10, lev_briggs) > 0.0
        @test so2_after(sys10, 3.0) == 0.0
    end
end

end
