export NEI2016InlineEmis

# ----------------------------------------------------------------------------
# Baked mean vertical grid (GEOS-FP hybrid Ap/Bp at reference Ps = 1013.25 hPa,
# US-Standard-Atmosphere hypsometric integration). Used to place an elevated
# plume at altitude H [m AGL] into the model layer at that altitude and to
# normalize the areal flux by that layer's air mass. This is the mean-profile
# analog of the surface loader's baked `delp_dry_surface`; the real-time layer
# altitude (GEOSFP Z_agl) is the documented follow-up for full state dependence.
# Computed from the GEOS-FP 72-level hybrid-sigma Ap/Bp coefficients.
# ----------------------------------------------------------------------------
const _INLINE_MIDALT = [63.7, 192.4, 323.0, 455.3, 589.3, 725.1, 862.7, 1002.2,
    1143.6, 1287.0, 1432.4, 1580.0, 1755.2, 1985.3, 2247.1, 2515.9, 2792.3,
    3076.7, 3446.3, 3907.9, 4393.0, 4904.5, 5445.7, 6020.9, 6635.2, 7295.0,
    8008.6, 8926.7, 10016.9, 11085.9]
const _INLINE_DELP = [15.199, 15.286, 15.285, 15.284, 15.285, 15.285, 15.283,
    15.283, 15.283, 15.283, 15.282, 15.282, 20.374, 25.468, 25.467, 25.461,
    25.461, 25.46, 38.185, 38.174, 38.174, 38.156, 38.149, 38.132, 38.115,
    38.085, 38.065, 50.078, 43.681, 37.002]

# Nearest 1-based model level for an altitude H [m AGL] (mean profile). Clamped
# to [1, 30]. Registered symbolic; unit fallback returns level 1.
function inline_target_lev(H::Real)
    isfinite(H) || return 1.0
    best = 1; bd = Inf
    @inbounds for l in 1:length(_INLINE_MIDALT)
        d = abs(_INLINE_MIDALT[l] - H)
        d < bd && (bd = d; best = l)
    end
    return float(best)
end
# Mean dry pressure thickness [hPa, treated unitless] at (rounded) level `levf`.
function inline_delp_hpa(levf::Real)
    l = clamp(round(Int, levf), 1, length(_INLINE_DELP))
    return _INLINE_DELP[l]
end
@register_symbolic inline_target_lev(H)
@register_symbolic inline_delp_hpa(levf)
inline_target_lev(H::DynamicQuantities.Quantity) = 1.0
inline_delp_hpa(levf::DynamicQuantities.Quantity) = 1.0

# ============================================================================
# NEI 2016 INLINE elevated point-source emissions (EGU power plants, oil & gas,
# large fires, C3 marine, ...).
#
# Counterpart to `NEI2016MonthlyEmis` (the 2-D surface-gridded merge), addressing
# EarthSciML/EarthSciData.jl#211: the surface merge `mrggrid_withbeis_withrwc`
# EXCLUDES every "inline-only" elevated point sector. `ptegu` alone (EGU power
# plants) injects a loader-measured 32.3 kg SO2/s in March 2016 (~1.0 Tg/yr
# annualized, ~40% of the ~2.5 Tg/yr CONUS anthropogenic SO2 budget — the
# largest single missing share of the inventory) and contributes ZERO to the
# layer-1 surface merge. Those emissions exist only as CMAQ INLINE point sources:
#
#   merged/12US1_inln/2016fh_12US1_<sector>_inln.zip
#
# which bundle, on the 12US1 Lambert-Conformal grid (459 col x 299 row):
#   * stack_groups_<sector>_..._16j.ncf  — one record per stack (LATITUDE,
#     LONGITUDE, STKHT, STKDM, STKTK, STKVE, STKFLW, ROW, COL, ...), time-invariant
#     geometry. NETCDF3_64BIT_OFFSET; stacks are stored along the ROW dimension
#     (ROW = NSTACKS, COL = 1).
#   * inln_mole_<sector>_YYYYMMDD_..._16j.ncf — per representative day, hourly
#     (TSTEP = 25), per-species emission rate in **mole/s**, indexed by the SAME
#     stack ordering (EMIS dims TSTEP x LAY(=1) x ROW(=NSTACKS) x COL(=1)).
#
# DESIGN (the seam that lets point sources reuse the gridded machinery):
#  - HORIZONTAL placement is STATIC: each stack maps to a fixed 12US1 grid cell
#    (its integer ROW/COL). `loadslice!` SCATTERS the per-stack emissions into a
#    dense 12US1 grid array, so the EXISTING conservative regridder (source-cell
#    polygon -> model-cell polygon) carries it to the simulation grid unchanged.
#    After the scatter this FileSet is an ordinary gridded 12US1 source, so
#    `loadmetadata` / `get_geometry` mirror `NEI2016MonthlyEmis` (same grid).
#  - VERTICAL placement is DYNAMIC (plume rise depends on the meteorological state
#    at solve time) and is therefore NOT done in the FileSet. It is applied in the
#    System builder's per-cell `wrapper_f` (`NEI2016InlineEmis`, added separately)
#    using gridded stack parameters + GEOSFP meteorology (Z_agl, T, wind), i.e. a
#    state-dependent generalization of the surface loader's `ifelse(lev<2, …)`.
#  - mole/s -> kg/s via per-species molecular weights (`_INLINE_MW`); the inline
#    files are mole speciation, unlike the mass (`tons/day`) surface merge.
#  - The #209 days-in-month fix and the synthetic diurnal/day-of-week scaling of
#    `NEI2016MonthlyEmis` DO NOT apply here: the inline files are already true
#    hourly rates, so neither correction is used (applying them would double-count).
# ============================================================================

# Molecular weights [g/mol] for converting the mole-speciation inline emissions
# to mass. Covers the GEOS-Chem-relevant CB6 inline species; lumped CB6 species
# (PAR, OLE, ...) use the CMAQ-convention carbon/representative weights. Extend as
# needed — `loadslice!` warns (once) for any emitted species missing here.
const _INLINE_MW = Dict{String, Float64}(
    "NO" => 30.006, "NO2" => 46.006, "HONO" => 47.013, "SO2" => 64.066,
    "SULF" => 98.079, "CO" => 28.010, "NH3" => 17.031, "CO2" => 44.009,
    "FORM" => 30.026, "FORM_PRIMARY" => 30.026, "ALD2" => 44.053,
    "ALD2_PRIMARY" => 44.053, "ALDX" => 58.080, "ACET" => 58.080,
    "ETH" => 28.054, "ETHA" => 30.070, "ETHY" => 26.038, "ETOH" => 46.069,
    "MEOH" => 32.042, "PAR" => 14.043, "OLE" => 27.000, "IOLE" => 56.108,
    "ISOP" => 68.117, "TERP" => 136.234, "BENZ" => 78.114, "TOL" => 92.140,
    "XYLMN" => 106.165, "NAPH" => 128.171, "PRPA" => 44.096, "KET" => 72.000,
    "CH4" => 16.043, "ACROLEIN" => 56.064, "BUTADIENE13" => 54.092,
    "CL2" => 70.906, "HCL" => 36.461, "GLY" => 58.036, "GLYD" => 60.052,
    "MGLY" => 72.063,
)

# ----------------------------------------------------------------------------
# StackTable: per-stack geometry, read once from the stack_groups file. Holds the
# horizontal cell index (col/row into the 12US1 grid) used by `loadslice!`'s
# scatter, and the stack parameters used later for plume rise.
# ----------------------------------------------------------------------------
struct StackTable
    n::Int
    lon::Vector{Float64}    # degrees
    lat::Vector{Float64}    # degrees
    col::Vector{Int}        # 1-based 12US1 grid column index
    row::Vector{Int}        # 1-based 12US1 grid row index
    stkht::Vector{Float64}  # stack height above ground [m]
    stkdm::Vector{Float64}  # inside stack diameter [m]
    stktk::Vector{Float64}  # exit temperature [K]
    stkve::Vector{Float64}  # exit velocity [m/s]
end

# Read the (TSTEP=1, LAY=1, ROW=NSTACKS, COL=1) stack-groups variables into flat
# per-stack vectors. NCDatasets presents the IOAPI dims reversed (COL, ROW, LAY,
# TSTEP); each geometry variable is singleton in every dim except ROW, so `vec`
# yields the NSTACKS-length vector.
function _read_stack_groups(ds)
    g(name) = Float64.(vec(Array(ds[name])))
    lon = g("LONGITUDE")
    n = length(lon)
    return StackTable(
        n, lon, g("LATITUDE"),
        round.(Int, g("COL")), round.(Int, g("ROW")),
        g("STKHT"), g("STKDM"), g("STKTK"), g("STKVE"),
    )
end

# ----------------------------------------------------------------------------
# FileSet
# ----------------------------------------------------------------------------
"""
$(SIGNATURES)

`FileSet` for CMAQ inline (elevated) NEI 2016 point-source emissions for one
sector. See the file header for the data layout and design. Parameterized on the
inline-emissions dataset type `D` for type-stable NetCDF reads.
"""
# Special (non-species) gridded fields the loader also exposes for the vertical
# wrapper (NOT emitted as species):
#   WEMIS = static per-cell emission-weight flux density (day-mean SO2 kg/m2/s
#           equivalent; the plume-altitude weighting field), and
#   HINJW = plume altitude x that SAME weight flux [m * kg/m2/s].
# Both are EXTENSIVE (flux-like), so the conservative area-weighted regridder is
# the correct operator for each; their per-model-cell RATIO HINJW/WEMIS is then
# exactly the emission-weighted mean plume altitude. (Regridding the altitude
# directly would dilute it with the zeros of stack-free source cells — an
# intensive/extensive mismatch).
const _INLINE_HINJW = "HINJW"
const _INLINE_WEMIS = "WEMIS"

struct NEI2016InlineEmisFileSet{D} <: FileSet
    mirror::String
    sector::String
    stacks::StackTable
    ds::D                       # aggregated inln_mole dataset (representative days)
    freq_info::DataFrequencyInfo
    # 12US1 target grid + LCC projection (from the stack_groups global attrs;
    # NCOLS/NROWS are the full grid, GDNAM "12US1_459X299").
    ncols::Int
    nrows::Int
    x0::Float64
    y0::Float64
    dx::Float64
    dy::Float64
    native_sr::String
    year_proxy::Int             # calendar year of the inline files (2017 EQUATES proxy)
    w_grid::Matrix{Float64}     # [ncols, nrows] static emission-weight flux [kg/m^2/s]
    hinjw_grid::Matrix{Float64} # [ncols, nrows] plume altitude x weight flux [m kg/m^2/s]
    # One entry per aggregated TSTEP record (INCLUDING the hour-24 == next-day
    # hour-0 duplicates), in TSTEP order. `loadslice!` indexes the aggregated
    # dataset with `argmin` over THIS list; `freq_info.centerpoints` holds the
    # DEDUPLICATED (uniform hourly) list the interpolator time grid requires.
    record_times::Vector{DateTime}
end

DataFrequencyInfo(fs::NEI2016InlineEmisFileSet) = fs.freq_info
Base.close(fs::NEI2016InlineEmisFileSet) = lock(nclock) do; close(fs.ds); end

"""
$(SIGNATURES)

Server path (relative to the host root / local cache) of the inline zip archive
for this sector. Sector-agnostic: the same layout holds for every inline sector
(ptegu, ptnonipm, pt_oilgas, cmv_c3, ptfire, ptagfire, ...).
"""
function relpath(fs::NEI2016InlineEmisFileSet, t::DateTime)
    @assert Dates.year(t)==2016 "Only 2016 emissions are available with `NEI2016InlineEmis`."
    return "emismod/2016/v1/merged/12US1_inln/2016fh_12US1_$(fs.sector)_inln.zip"
end

"""
$(SIGNATURES)

Build the metadata describing the 12US1 grid that `loadslice!` scatters the
point emissions onto. Identical in spirit to `NEI2016MonthlyEmis` — the scattered
field IS a 12US1 gridded field — so the shared conservative regridder applies.
The species emission units after scatter + mole->mass are kg/m²/s.
"""
function loadmetadata(fs::NEI2016InlineEmisFileSet, varname)::MetaData
    xs = fs.x0 + fs.dx / 2 .+ fs.dx .* (0:(fs.ncols - 1))
    ys = fs.y0 + fs.dy / 2 .+ fs.dy .* (0:(fs.nrows - 1))
    # Unit strings must be registered `to_unit` keys with conversion factor 1
    # (the mole/g -> kg conversion is done in `loadslice!`, so no extra scaling).
    # HINJW carries m * kg/m^2/s = "kg m-1 s-1" (registered in utils.jl).
    units = String(varname) == _INLINE_HINJW ? "kg m-1 s-1" : "kg m-2 s-1"
    return MetaData(
        [xs, ys],
        units,
        "NEI 2016 inline point-source emissions of $(varname) (scattered to 12US1)",
        ["COL", "ROW"],
        [fs.ncols, fs.nrows],
        fs.native_sr,
        1,        # xdim (COL)
        2,        # ydim (ROW)
        -1,       # zdim (none — vertical placement is in the System wrapper)
        (false, false, false),
    )
end

"""
$(SIGNATURES)

12US1 source-cell polygons for conservative regridding (column-major, x-fastest,
matching `vec` on the scattered data array). Mirrors `NEI2016MonthlyEmis`.
"""
function get_geometry(fs::NEI2016InlineEmisFileSet, m::MetaData)
    x = range(start = fs.x0, step = fs.dx, length = fs.ncols + 1)
    y = range(start = fs.y0, step = fs.dy, length = fs.nrows + 1)
    polys = Vector{Vector{NTuple{2, Float64}}}(undef, fs.ncols * fs.nrows)
    for j in 1:(fs.nrows), i in 1:(fs.ncols)
        polys[(j - 1) * fs.ncols + i] = [(x[i], y[j]), (x[i + 1], y[j]),
            (x[i + 1], y[j + 1]), (x[i], y[j + 1]), (x[i], y[j])]
    end
    return polys
end

"""
$(SIGNATURES)

Species variable names in the inline file (excludes TFLAG and dimension vars).
"""
function varnames(fs::NEI2016InlineEmisFileSet)
    lock(nclock) do
        return [setdiff(keys(fs.ds), ["TFLAG"; keys(fs.ds.dim)])...]
    end
end

"""
$(SIGNATURES)

Load one species' inline emissions at time `t` and SCATTER it onto the 12US1
grid: read the per-stack mole/s vector, convert to kg/s with the species
molecular weight, accumulate each stack into its (col,row) cell, then divide by
cell area to get the kg/m²/s flux density the conservative regridder expects.
"""
function loadslice!(data::AbstractArray, fs::NEI2016InlineEmisFileSet, t::DateTime, varname)
    # Special static fields for the vertical wrapper (see _INLINE_HINJW note).
    if String(varname) == _INLINE_HINJW
        @assert size(data) == (fs.ncols, fs.nrows)
        copyto!(data, fs.hinjw_grid)
        return nothing
    elseif String(varname) == _INLINE_WEMIS
        @assert size(data) == (fs.ncols, fs.nrows)
        copyto!(data, fs.w_grid)
        return nothing
    end
    lock(nclock) do
        fill!(data, 0)
        ti = _inline_time_index(fs, t)              # proxy-year day + hour index
        var = fs.ds[varname]
        # Units-aware source->kg/s factor: CMAQ inline files carry GAS species in
        # "moles/s" (need molecular weight) and PARTICULATE (PM) species in "g/s"
        # (mass already — just g->kg, no MW). Missing/other units -> emit 0.
        u = strip(get(var.attrib, "units", ""))
        tokg = if u == "moles/s" || u == "mole/s" || u == "mol/s"
            mw = get(_INLINE_MW, String(varname), NaN)
            isnan(mw) && (@warn "No molecular weight for inline gas species $(varname); emitting 0." maxlog=1)
            isnan(mw) ? 0.0 : mw * 1.0e-3           # mole/s * g/mol * 1e-3 = kg/s
        elseif u == "g/s"
            1.0e-3                                    # g/s -> kg/s
        else
            @warn "Unhandled inline units '$(u)' for $(varname); emitting 0." maxlog=1
            0.0
        end
        # EMIS dims (NCDatasets order): COL(=1) x ROW(=NSTACKS) x LAY(=1) x TSTEP.
        emis = Float64.(vec(Array(var[:, :, :, ti])))
        st = fs.stacks
        @assert length(emis)==st.n "inline EMIS length $(length(emis)) != NSTACKS $(st.n)"
        if tokg != 0.0
            @inbounds for s in 1:st.n
                c = st.col[s]; r = st.row[s]
                (1 <= c <= fs.ncols && 1 <= r <= fs.nrows) || continue
                data[c, r] += emis[s] * tokg         # kg/s accumulated into the cell
            end
        end
        data ./= (fs.dx * fs.dy)                     # kg/s -> kg/m²/s
    end
    nothing
end

# 1-based time index into the aggregated inline dataset for model time `t`.
# The EQUATES ptegu inline files are TRUE daily hourly data (a file per calendar
# day, TSTEP = 25 = hours 0..24). Model time `t` (year 2016) is mapped to the
# proxy year (2017) with the same month/day/hour, then matched to the nearest
# aggregated centerpoint. (Sectors published only as representative days — othpt,
# pt_oilgas — fall back to nearest-centerpoint, which for a single representative
# day is that day's matching hour.)
function _inline_time_index(fs::NEI2016InlineEmisFileSet, t::DateTime)
    # Record times are stored in the MODEL year (proxy remapped at construction)
    # and include the hour-24 duplicates, so `argmin` here is a valid index into
    # the aggregated dataset's TSTEP axis (midnight ties resolve to the earlier
    # record, whose values coincide with the next file's hour 0).
    return argmin(abs.(Dates.value.(fs.record_times .- t)))
end

# ----------------------------------------------------------------------------
# Briggs (1969/1971) buoyant final plume rise, neutral/unstable stability.
# Δh_final = C · F^p / U with F the stack buoyancy flux; H_plume = STKHT + Δh.
# Used at LOAD time with reference met (U_ref, T_a_ref) to precompute a static
# per-cell effective injection altitude. The dynamic part — which model layer
# sits at that altitude — is resolved at solve time from GEOSFP Z_agl in the
# System builder's wrapper. Reference met is a documented approximation; the
# stack parameters (STKHT/STKTK/STKVE/STKDM) and the Briggs formula are real.
# ----------------------------------------------------------------------------
const _BRIGGS_G = 9.80665          # m/s²
function _briggs_plume_rise(stkht, stkdm, stktk, stkve; U_ref = 5.0, T_a = 280.0)
    (stkve <= 0 || stkdm <= 0 || stktk <= T_a) && return stkht  # no buoyancy
    # Buoyancy flux F = g · v_s · (d_s/2)² · (T_s − T_a)/T_s   [m⁴/s³]
    F = _BRIGGS_G * stkve * (stkdm / 2)^2 * (stktk - T_a) / stktk
    Δh = F < 55.0 ? 21.425 * F^(0.75) / U_ref : 38.71 * F^(0.6) / U_ref
    return stkht + Δh
end

# ----------------------------------------------------------------------------
# Construction: fetch + open the inline archive for the sector.
#
# The inline zips are large (multi-GB; pt_oilgas ~4.7 GB) and bundle one
# stack_groups file + many representative-day inln_mole files. Two access modes:
#   (a) cached extracted files under `download_cache()` (preferred for repeat
#       runs and for tests that pre-stage a small fixture);
#   (b) download + extract the needed members.
# For the multi-GB bundles the production path Range-extracts only the needed
# members (stack_groups + the required day files); this whole-archive extract is
# a simple fallback.
# ----------------------------------------------------------------------------
function NEI2016InlineEmisFileSet(sector::AbstractString, starttime::DateTime, endtime::DateTime;
        platform::Symbol = :equates2017, mirror = "https://gaftp.epa.gov/Air/",
        stage_dir = nothing)
    extract_dir = something(stage_dir,
        joinpath(download_cache(), "nei2016_inline", String(sector)))
    year_proxy = platform === :equates2017 ? 2017 : Dates.year(starttime)

    if platform === :equates2017
        # Idempotent per-day staging: fetches only missing days, so it also
        # heals a partially staged directory (the padded domain tspan may need
        # more days than a previous run staged).
        _equates_ensure_extracted(sector, starttime, endtime, extract_dir)
    else
        stk0 = _inline_find(extract_dir, "stack_groups_$(sector)")
        inl0 = _inline_find_all(extract_dir, "inln_mole_$(sector)_")
        (isnothing(stk0) || isempty(inl0)) &&
            _inline_ensure_extracted(mirror, sector, starttime, endtime, extract_dir)
    end
    stk_path = _inline_find(extract_dir, "stack_groups_$(sector)")
    inln_paths = _inline_find_all(extract_dir, "inln_mole_$(sector)_")
    @assert !isnothing(stk_path) "stack_groups file for sector $(sector) not found in $(extract_dir)"
    @assert !isempty(inln_paths) "no inln_mole files for sector $(sector) found in $(extract_dir)"

    lock(nclock) do
        stkds = NCDataset(stk_path)
        stacks = _read_stack_groups(stkds)
        # 12US1 grid + LCC projection from the stack_groups global attributes.
        a = stkds.attrib
        p_alp = a["P_ALP"]; p_bet = a["P_BET"]; xcent = a["XCENT"]; ycent = a["YCENT"]
        native_sr = "+proj=lcc +lat_1=$(p_alp) +lat_2=$(p_bet) +lat_0=$(ycent) " *
                    "+lon_0=$(xcent) +x_0=0 +y_0=0 +a=6370997.0 +b=6370997.0 +to_meter=1"
        x0 = a["XORIG"]; y0 = a["YORIG"]; dx = a["XCELL"]; dy = a["YCELL"]
        # NCOLS/NROWS in the sparse stack_groups are (1, NSTACKS); the full target
        # grid size comes from GDNAM ("12US1_459X299") -> 459 x 299.
        ncols, nrows = _parse_gdnam_size(get(a, "GDNAM", "12US1_459X299"))
        close(stkds)

        ds = NCDataset(sort(inln_paths), aggdim = "TSTEP")
        model_year = Dates.year(starttime)
        rec_times = _inline_centerpoints(ds, model_year)
        @assert issorted(rec_times) "inline TFLAG records not chronological across aggregated files"
        cps = unique(rec_times)     # uniform hourly grid for the interpolator
        start = DateTime(model_year, Dates.month(starttime))
        dfi = DataFrequencyInfo(start, Hour(1), cps)

        w_grid, hinjw_grid = _compute_hinj_grids(ds, stacks, ncols, nrows, dx * dy)

        NEI2016InlineEmisFileSet{typeof(ds)}(String(mirror), String(sector), stacks,
            ds, dfi, ncols, nrows, x0, y0, dx, dy, native_sr, year_proxy,
            w_grid, hinjw_grid, rec_times)
    end
end

# Static emission-weight flux + (altitude x weight) flux per 12US1 cell.
# Weight = each stack's time-mean SO2 emission in kg/s (fallback: equal weight),
# divided by the cell area so both fields are flux densities the conservative
# regridder treats exactly like the species. Called with nclock held.
function _compute_hinj_grids(ds, st::StackTable, ncols, nrows, cellarea)
    w = ones(Float64, st.n)
    if haskey(ds, "SO2")
        so2 = Float64.(Array(ds["SO2"]))            # (COL=1, ROW=NSTACKS, LAY=1, TSTEP)
        nt = size(so2)[end]
        w = vec(sum(so2; dims = ndims(so2))) .* (0.064066 / nt)  # mean mole/s -> kg/s
        w = max.(w, 0.0)
        all(iszero, w) && (w .= 1.0)
    end
    hp = _briggs_plume_rise.(st.stkht, st.stkdm, st.stktk, st.stkve)
    wg = zeros(Float64, ncols, nrows)
    hw = zeros(Float64, ncols, nrows)
    wg1 = zeros(Float64, ncols, nrows)   # equal-weight fallback
    hw1 = zeros(Float64, ncols, nrows)
    @inbounds for s in 1:st.n
        c = st.col[s]; r = st.row[s]
        (1 <= c <= ncols && 1 <= r <= nrows) || continue
        wg[c, r] += w[s] / cellarea
        hw[c, r] += w[s] * hp[s] / cellarea
        wg1[c, r] += 1.0 / cellarea
        hw1[c, r] += hp[s] / cellarea
    end
    # Cells whose stacks are all SO2-free (e.g. gas-fired EGUs emitting NOx/CO)
    # would otherwise carry zero weight and degenerate to surface injection for
    # the species they DO emit; fall back to the equal-weight plume altitude.
    @inbounds for i in eachindex(wg)
        if wg[i] <= 0 && wg1[i] > 0
            wg[i] = wg1[i]
            hw[i] = hw1[i]
        end
    end
    return wg, hw
end

# Parse "12US1_459X299" -> (459, 299). Falls back to the standard 12US1 size.
function _parse_gdnam_size(gdnam)
    m = match(r"_(\d+)X(\d+)", strip(String(gdnam)))
    isnothing(m) ? (459, 299) : (parse(Int, m[1]), parse(Int, m[2]))
end

# Hourly centerpoints from the inline dataset's TFLAG (YYYYDDD, HHMMSS), remapped
# from the data (proxy) year to `model_year` by MONTH/DAY. Month/day (not
# day-of-year) is used so a proxy-year vs model-year leap-day offset does not
# shift the calendar date (e.g. proxy 2017 non-leap DOY 69 = Mar 10 must stay
# Mar 10 in leap-year 2016, not become Mar 9).
function _inline_centerpoints(ds, model_year::Integer)
    tf = Array(ds["TFLAG"])           # (DATE-TIME=2, VAR, TSTEP) in NCDatasets order
    nt = size(tf)[end]
    base_yr = Int(tf[1, 1, 1]) ÷ 1000   # proxy base year (e.g. 2017)
    out = DateTime[]
    for k in 1:nt
        yyyyddd = Int(tf[1, 1, k]); hhmmss = Int(tf[2, 1, k])
        yr = yyyyddd ÷ 1000; doy = yyyyddd % 1000
        hh = hhmmss ÷ 10000
        dt = DateTime(yr, 1, 1) + Day(doy - 1) + Hour(hh)
        # Preserve any year offset relative to the file set's base proxy year so
        # the Dec-31 hour-24 wrap maps to model_year+1 Jan 1 (keeps the vector
        # monotonic = TSTEP order), instead of jumping back to model-year Jan 1.
        push!(out, DateTime(model_year + (yr - base_yr),
            Dates.month(dt), Dates.day(dt), Dates.hour(dt)))
    end
    return out
end

_inline_isnc(f) = endswith(f, ".ncf") || endswith(f, ".nc4")

function _inline_find(dir, prefix)
    isdir(dir) || return nothing
    for f in readdir(dir, join = true)
        startswith(basename(f), prefix) && _inline_isnc(f) && return f
    end
    return nothing
end

function _inline_find_all(dir, prefix)
    isdir(dir) || return String[]
    return filter(f -> startswith(basename(f), prefix) && _inline_isnc(f),
        readdir(dir, join = true))
end

# ============================================================================
# EQUATES layout (AWS Open Data, public bucket `cmas-equates`).
#
# The gaftp 2016v1 platform does NOT publish model-ready inline point sources
# (only the 2-D surface merge + raw FF10 inventories). EPA's EQUATES release is
# the public source of CMAQ-ready inline point emissions, but only for years
# 2002-2019 — no 2016fh model-ready inline exists publicly. We therefore use the
# 2017 EGU inline as a proxy for 2016 (EGU fleet changes are gradual and this is
# documented). Native grid + IOAPI stack/inline formats are identical to the
# v1 platform, so once staged as local nc4 the reader logic is unchanged.
#
# Layout on S3:
#   * static per-sector stack geometry, all sectors in ONE tar (~176 MB):
#       CMAQ_12US1/INPUT/2017/emis/model_ready_emis_2017_stackgroups_epicsoil_EQUATES_v1.0.tar
#       member  2017/<sector>/stack_groups_<sector>_12US1_WR413_MYR_2017.nc4
#   * per-day hourly inline emissions, bundled by MONTH (~15 GB/month tar):
#       .../model_ready_emis_ptsectors_plus_rwc_2017_MM_EQUATES_v1.0.tar
#       member  2017/<sector>/inln_mole_<sector>_YYYYMMDD_12US1_cmaq_cb6_WR413_MYR_2017.nc4
#
# A `.contents.txt` (== `tar -tvf` order == archive order) accompanies each tar,
# so a member's byte offset is computed without reading the 15 GB tar, and a
# single HTTP Range GET pulls just the needed ~13 MB day file.
# ============================================================================
const _EQUATES_BUCKET = "https://cmas-equates.s3.amazonaws.com"
const _EQUATES_EMIS = "CMAQ_12US1/INPUT/2017/emis"
const _EQUATES_STACKGROUPS_TAR =
    "model_ready_emis_2017_stackgroups_epicsoil_EQUATES_v1.0.tar"
_equates_month_tar(mm) = "model_ready_emis_ptsectors_plus_rwc_2017_$(lpad(mm,2,'0'))_EQUATES_v1.0.tar"

# Parse a `tar -tvf`-style contents listing into (member_name => (data_offset, size)).
# GNU tar stores a name > 100 bytes as a preceding `././@LongLink` header+data
# block (512-byte header + ceil(namelen/512)*512 data), then the real 512-byte
# header, then the file data padded to 512. The EQUATES member paths (~70 chars)
# are under 100, so the common path is a plain 512-byte header; the long-name
# branch is handled for safety.
function _tar_member_offsets(contents::AbstractString)
    offsets = Dict{String, Tuple{Int, Int}}()
    off = 0
    for ln in eachline(IOBuffer(contents))
        m = match(r"^\S+\s+\S+\s+(\d+)\s+\S+\s+\S+\s+(.+?)\s*$", ln)
        m === nothing && continue
        size = parse(Int, m.captures[1])
        name = String(m.captures[2])
        hdr = 512
        if length(name) > 100
            hdr += 512 + cld(length(name) + 1, 512) * 512  # @LongLink header + name data
        end
        data_start = off + hdr
        offsets[name] = (data_start, size)
        off = data_start + cld(size, 512) * 512
    end
    return offsets
end

# Verify a Range-extracted tar member payload then write it via a temp file +
# atomic rename, so an interrupted/concurrent staging never leaves a truncated
# file at the final path (a bare `isfile` gate would then trust it forever).
function _atomic_write_member(out, bytes, expected_size)
    length(bytes) == expected_size || error(
        "staging $(basename(out)): got $(length(bytes)) bytes, expected $(expected_size) " *
        "(server ignored Range, short read, or stale .contents.txt offsets)")
    looks_nc = length(bytes) >= 4 && (bytes[1:4] == UInt8[0x89, 0x48, 0x44, 0x46] ||  # \x89HDF (nc4)
                                      bytes[1:3] == UInt8[0x43, 0x44, 0x46])          # CDF (classic)
    looks_nc || error("staging $(basename(out)): payload is not NetCDF — tar offset table misaligned")
    tmp = out * ".tmp-$(getpid())-$(rand(UInt32))"
    open(tmp, "w") do io; write(io, bytes); end
    mv(tmp, out; force = true)
    return out
end

function _http_get_bytes(url; headers = Pair{String, String}[])
    io = IOBuffer()
    Downloads.download(url, io; headers = headers)
    return take!(io)
end

# Range-extract one tar member (identified by a substring of its path) into `out`.
function _equates_extract_member(tar_url, contents_url, name_substr, out)
    isfile(out) && return out
    contents = String(_http_get_bytes(contents_url))
    offsets = _tar_member_offsets(contents)
    hit = nothing
    for (name, off) in offsets
        occursin(name_substr, name) && (hit = (name, off); break)
    end
    hit === nothing && error("tar member matching '$name_substr' not found in $contents_url")
    (data_start, size) = hit[2]
    mkpath(dirname(out))
    @info "Range-extracting $(hit[1]) ($(round(size/1e6, digits=1)) MB) from EQUATES tar"
    bytes = _http_get_bytes(tar_url;
        headers = ["Range" => "bytes=$(data_start)-$(data_start + size - 1)"])
    _atomic_write_member(out, bytes, size)
    return out
end

# Stage the EQUATES stack_groups + the daily inline files spanning [start,end]
# (mapped to 2017) for `sector` into `extract_dir` as local nc4 (idempotent).
function _equates_ensure_extracted(sector, starttime::DateTime, endtime::DateTime, extract_dir)
    mkpath(extract_dir)
    # 1) static stack geometry (small tar, shared across sectors) -> nc4
    stk_out = joinpath(extract_dir, "stack_groups_$(sector)_12US1_WR413_MYR_2017.nc4")
    if !isfile(stk_out)
        stk_tar = "$(_EQUATES_BUCKET)/$(_EQUATES_EMIS)/$(_EQUATES_STACKGROUPS_TAR)"
        _equates_extract_member(stk_tar, replace(stk_tar, ".tar" => ".contents.txt"),
            "2017/$(sector)/stack_groups_$(sector)", stk_out)
    end
    # 2) daily inline files for each proxy-2017 calendar day in the window.
    # Clamp the day to the proxy month length: a leap-day (Feb 29 2016) endpoint
    # maps to Feb 28 2017 — the file the runtime nearest-record lookup consumes
    # for the leap-day hours anyway.
    _proxyday(t) = Date(2017, Dates.month(t),
        min(Dates.day(t), Dates.daysinmonth(Date(2017, Dates.month(t)))))
    d = _proxyday(starttime)
    dend = _proxyday(endtime)
    months_seen = Set{Int}()
    contents_cache = Dict{String, String}()
    while d <= dend
        mm = Dates.month(d)
        tar = "$(_EQUATES_BUCKET)/$(_EQUATES_EMIS)/$(_equates_month_tar(mm))"
        contents_url = replace(tar, ".tar" => ".contents.txt")
        ymd = Dates.format(d, "yyyymmdd")
        out = joinpath(extract_dir, "inln_mole_$(sector)_$(ymd)_12US1_WR413_MYR_2017.nc4")
        if !isfile(out)
            contents = get!(contents_cache, contents_url) do
                String(_http_get_bytes(contents_url))
            end
            offsets = _tar_member_offsets(contents)
            name_substr = "2017/$(sector)/inln_mole_$(sector)_$(ymd)"
            hit = nothing
            for (name, o) in offsets
                occursin(name_substr, name) && (hit = (name, o); break)
            end
            hit === nothing && error("EQUATES inline day $ymd for sector $sector not in $contents_url")
            (data_start, size) = hit[2]
            @info "Range-extracting inln_mole_$(sector)_$(ymd) ($(round(size/1e6, digits=1)) MB)"
            bytes = _http_get_bytes(tar;
                headers = ["Range" => "bytes=$(data_start)-$(data_start + size - 1)"])
            _atomic_write_member(out, bytes, size)
        end
        push!(months_seen, mm)
        d += Day(1)
    end
    return nothing
end

# Download the sector's inline zip and extract its .ncf members (EDGAR idiom).
# Whole-archive fallback used only when member-range extraction is unavailable.
function _inline_ensure_extracted(mirror, sector, starttime, endtime, extract_dir)
    rel = "emismod/2016/v1/merged/12US1_inln/2016fh_12US1_$(sector)_inln.zip"
    zip_url = rstrip(mirror, '/') * "/" * rel
    zip_local = joinpath(download_cache(), "nei2016_inline", "$(sector).zip")
    if !isfile(zip_local)
        mkpath(dirname(zip_local))
        @info "Downloading NEI inline archive (large) from $zip_url"
        _download_with_progress(zip_url, zip_local)
    end
    mkpath(extract_dir)
    @info "Extracting NEI inline .ncf members to $extract_dir"
    r = ZipFile.Reader(zip_local)
    try
        for f in r.files
            fn = basename(f.name)
            (endswith(fn, ".ncf") && !startswith(fn, ".")) || continue
            out = joinpath(extract_dir, fn)
            isfile(out) || open(out, "w") do io; write(io, read(f)); end
        end
    finally
        close(r)
    end
end

# ============================================================================
# System builder + coupler
# ============================================================================
struct NEI2016InlineEmisCoupler
    sys::Any
end

# Default coupled species for an inline sector: the combustion gases every
# supported mechanism carries (all stored "moles/s"). VOC/PM species can be
# added via the `species` kwarg once their mechanism mapping is wired.
const _INLINE_DEFAULT_SPECIES = ["SO2", "NO", "NO2", "CO", "NH3"]

"""
$(SIGNATURES)

Emissions System for CMAQ inline (elevated) NEI point sources for one `sector`
(e.g. `"ptegu"` — EGU power plants). Companion to [`NEI2016MonthlyEmis`]: the
2-D surface merge excludes every inline-only elevated sector (EarthSciData#211),
so EGU SO2 (a loader-measured 32.3 kg/s in March 2016, ~1.0 Tg/yr annualized —
the largest single missing share of the CONUS SO2 inventory) is entirely absent
from the surface loader. This System adds it back.

Differences from `NEI2016MonthlyEmis`:
  * Emissions are TRUE hourly rates (CEM-driven for EGU), so NEITHER the
    #209 days-in-month correction NOR the synthetic diurnal / day-of-week
    scaling are applied (they would double-count).
  * VERTICAL placement is elevated, not surface: each grid cell's emission is
    injected into the model layer at the cell's emission-weighted Briggs plume
    altitude `H_inj` (from real stack geometry). v1 maps altitude→layer with a
    baked mean vertical grid (`inline_target_lev`); the areal flux is normalized
    by that layer's mean air mass (`inline_delp_hpa`). See file header + the
    `_INLINE_MIDALT` note for the mean-profile approximation and its follow-up.

`platform = :equates2017` (default) sources the public EQUATES 2017 CMAQ-ready
inline files as a documented proxy for 2016 (no 2016 model-ready inline is
published). `scale` multiplies all emissions.
"""
function NEI2016InlineEmis(
        sector::AbstractString,
        domaininfo::DomainInfo;
        scale = 1.0,
        name = :NEI2016InlineEmis,
        platform::Symbol = :equates2017,
        stage_dir = nothing,
        species = _INLINE_DEFAULT_SPECIES,
        stream = true,
        spatial_interp::Symbol = :linear
)
    starttime, endtime = get_tspan_datetime(domaininfo)
    fs = NEI2016InlineEmisFileSet(sector, starttime, endtime;
        platform = platform, stage_dir = stage_dir)
    avail = Set(varnames(fs))
    emit_species = [s for s in species if s in avail]
    @assert !isempty(emit_species) "none of requested species $(species) present in sector $(sector)"

    # Shared conservative regridder built from the emission grid (12US1); the
    # HINJ field shares the identical grid, so the same regridder carries it.
    ref_var = first(emit_species)
    ref_meta = loadmetadata(fs, ref_var)
    shared_regridder = regridder(fs, ref_meta, domaininfo)

    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :x in keys(pvdict)||:lon in keys(pvdict) "x or lon must be in the domaininfo"
    @assert :y in keys(pvdict)||:lat in keys(pvdict) "y or lat must be in the domaininfo"
    @assert :lev in keys(pvdict) "lev must be in the domaininfo"
    x = :x in keys(pvdict) ? pvdict[:x] : pvdict[:lon]
    y = :y in keys(pvdict) ? pvdict[:y] : pvdict[:lat]
    lev = pvdict[:lev]
    # Domain top level: clamp the injection target so reduced-level domains
    # still receive the mass (into their top layer) instead of silently
    # dropping every emission whose plume tops out above the domain (the flux
    # is normalized by the RECEIVING layer's own delp, so this conserves mass).
    levidx = findfirst(v -> Symbol(v) === :lev, EarthSciMLBase.pvars(domaininfo))
    lev_top = Float64(maximum(EarthSciMLBase.grid(domaininfo, (false, false, false))[levidx]))
    lev_top < length(_INLINE_MIDALT) &&
        @warn "NEI2016InlineEmis: domain top level $(Int(lev_top)) < 30; plumes above it are injected into the top layer." maxlog=1

    @parameters Δz=1.0 [description = "unit placeholder (kept for parity with surface loader)"]
    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    @parameters g0_100 = 100.0 / 9.80665 [unit = u"kg/m^2"]
    eqs = Equation[]
    params = Any[t_ref, g0_100]
    all_discretes = Any[]
    all_constants = Any[]
    interp_infos = []
    lhs_vars = Num[]

    dt = EarthSciMLBase.eltype(domaininfo)

    # (1) The two static plume-placement fields, conservatively regridded like
    # the species (both are flux densities); their ratio at the model cell is
    # the emission-weighted plume altitude (see _INLINE_HINJW note in the
    # FileSet section). Identity wrappers: the variables ARE the fields.
    local hinjw_var, wemis_var
    for (fname, store) in ((_INLINE_HINJW, :hinjw), (_INLINE_WEMIS, :wemis))
        fitp = DataSetInterpolator{dt}(fs, fname, starttime, endtime, domaininfo;
            stream = stream, regrid_f = shared_regridder)
        feq, fdisc, fconst, finfo = create_interp_equation(
            fitp, "", t, t_ref, [x, y]; spatial_interp = spatial_interp)
        push!(eqs, feq); append!(all_discretes, fdisc)
        append!(all_constants, fconst); push!(interp_infos, finfo)
        push!(lhs_vars, feq.lhs)
        store === :hinjw ? (hinjw_var = feq.lhs) : (wemis_var = feq.lhs)
    end
    # emission-weighted plume altitude [m]; eps floors the no-emission cells
    # (their species flux is 0 there anyway, so the level choice is inert).
    w_eps = only(@constants w_eps = 1.0e-30 [
        unit = u"kg/m^2/s", description = "weight-flux floor"])
    w_eps = ModelingToolkit.unwrap(w_eps)
    push!(params, w_eps)
    hinj_expr = hinjw_var / (wemis_var + w_eps)

    # (2) One emission variable per coupled species, elevated-injected.
    for varname in emit_species
        itp = DataSetInterpolator{dt}(fs, varname, starttime, endtime, domaininfo;
            stream = stream, regrid_f = shared_regridder)
        converted_units = units(itp) / u"kg/m^2"       # kg/m²/s / kg/m² = 1/s
        ze_name = Symbol(:zero_, varname)
        zero_emis = only(@constants $(ze_name)=0 [unit = converted_units])
        zero_emis = ModelingToolkit.unwrap(zero_emis)
        push!(params, zero_emis)

        # Inject the cell's areal flux into the single model layer nearest the
        # plume altitude, normalized by that layer's mean air mass. Conservative
        # (each cell -> exactly one layer). `inline_target_lev` maps the
        # emission-weighted altitude to the layer; `inline_delp_hpa(lev)` is the
        # layer's mean thickness.
        target_lev = min(inline_target_lev(hinj_expr), lev_top)
        wrapper_f = (eq) -> ifelse(abs(lev - target_lev) < 0.5,
            eq * scale / (g0_100 * inline_delp_hpa(lev)),
            zero_emis)

        eq, discretes, constants, info = create_interp_equation(
            itp, "", t, t_ref, [x, y];
            wrapper_f = wrapper_f, spatial_interp = spatial_interp)
        push!(eqs, eq); append!(all_discretes, discretes)
        append!(all_constants, constants); push!(interp_infos, info)
        push!(lhs_vars, eq.lhs)
    end

    all_params = [x, y, lev, Δz, all_constants..., all_discretes..., params...]
    sys = System(
        eqs, t, lhs_vars, all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        discrete_events = [build_interp_event(interp_infos, starttime)],
        metadata = Dict(CoupleType => NEI2016InlineEmisCoupler,
            SysDomainInfo => domaininfo,
            InterpInfos => interp_infos,
            SysDiscreteEvent => make_prune_factory(interp_infos))
    )
    return sys
end
