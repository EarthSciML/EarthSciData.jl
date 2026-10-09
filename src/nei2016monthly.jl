export NEI2016MonthlyEmis, NEI2016ElevatedEmis, NEI2016_ELEVATED_SECTORS

# Hourly scale factors, index 1 = local hour 0.
# DIURNAL_FACTORS: HEMCO GEIA_TOD_FOSSIL (CO, formaldehyde), applied by GEOS-Chem at
#   local time UTC + floor(lon/15) h.
# DIURNAL_FACTORS_NOx: profile of HEMCO's EDGAR_TODNOX file, whose built-in shift is
#   round(lon/15) h.
const DIURNAL_FACTORS = [0.45, 0.45, 0.6, 0.6, 0.6, 0.6, 1.45, 1.45, 1.45, 1.45, 1.4, 1.4,
    1.4, 1.4, 1.45, 1.45, 1.45, 1.45, 0.65, 0.65, 0.65, 0.65, 0.45, 0.45]
const DIURNAL_FACTORS_NOx = [
    0.39598674, 0.31852847, 0.30128068, 0.29590213, 0.33177775, 0.43871498,
    0.9094625, 1.5850095, 1.6223788, 1.3429453, 1.2265036, 1.1937649,
    1.254314, 1.3282939, 1.331211, 1.4135737, 1.6848333, 1.710925,
    1.3491899, 1.0586671, 0.84439224, 0.761263, 0.72693235, 0.5741503]
const DIURNAL_FACTORS_ISOP = [
    0, 0, 0, 0, 0, 0, 0.2376, 0.7224, 1.2048, 1.656, 2.0496, 2.3616, 2.5728,
    2.6616, 2.6184, 2.4408, 2.1288, 1.6896, 1.1448, 0.5136, 0, 0, 0, 0]

# Weekday factors, Monday-first (Dates.dayofweek), from HEMCO GEIA_DOW_NOX and GEIA_DOW_CO.
# HEMCO's CO line (Sunday-first: 0.683/1.1076/1.0706/1.0706/1.0706/1.0706/0.779) repeats
# the NOx weekday value 1.0706 on Tue-Fri and sums to 6.852; with 1.1076 on all five
# weekdays it sums to exactly 7, as the NOx line does, so 1.1076 is used on all weekdays.
const DayofWeekFactors_NOx = [1.0706, 1.0706, 1.0706, 1.0706, 1.0706, 0.863, 0.784]
const DayofWeekFactors_CO = [1.1076, 1.1076, 1.1076, 1.1076, 1.1076, 0.779, 0.683]

# Load and create interpolator for delp_dry_surface
const DELP_DRY_SURFACE_ITP = let
    # Load the delp_dry_surface data
    delp_data = load(joinpath(@__DIR__, "mean_domian_delp_dry_surface.jld2"), "mean_domian_delp_dry_surface")

    # Define the grid coordinates
    domain_lon = collect(-125.0:0.625:-66.875)
    domain_lat = collect(25.0:0.5:49.0)

    # Create 2D interpolator with flat extrapolation (use boundary values for out-of-bounds)
    # Note: delp_data should be (lon, lat) ordered to match (domain_lon, domain_lat)
    itp = interpolate((domain_lon, domain_lat), delp_data, Gridded(Linear()))
    extrapolate(itp, Flat())
end

"""
$(SIGNATURES)

Interpolate the delp_dry_surface field at a given longitude and latitude.
Returns the dry pressure thickness value in Pa.
"""
function delp_dry_surface_itp(lon, lat)
    # Convert from radians to degrees if needed
    lon_deg = rad2deg(lon)
    lat_deg = rad2deg(lat)

    # The interpolator now handles out-of-bounds automatically with Flat() extrapolation
    return DELP_DRY_SURFACE_ITP(lon_deg, lat_deg)
end

# Vertical allocation of the NEI "inline" (elevated point) sectors.
#
# The EPA monthly netCDF files are column totals with a single layer. GEOS-Chem reads
# these sectors from 3-D files that its NEI2016 preprocessing (griddedepa2gc.py, B. Henderson)
# built from the same EPA files by multiplying each sector's column total by one
# representative layer profile (after Simpson et al. 2003, EMEP report 1/2003, Table 4.1)
# on the 72-layer GEOS-FP grid, truncated at layer 11 and renormalized. The same fractions
# are applied here, so the emissions land in the same model layers as in GEOS-Chem.
# Sectors GEOS-Chem reads as 2-D (surface sources, othpt) get profile "surface", which
# must stay first in `NEI2016_PROFILE_NAMES`.
const NEI2016_PROFILE_NAMES = ["surface", "ptegu", "ptnonipm", "pt_oilgas", "cmv"]
const NEI2016_LAYER_FRACTIONS = let
    raw = Dict(
        "surface" => [1.0],
        "ptegu" => [0.027331187, 0.12260809, 0.192017292, 0.212736741, 0.167549199,
            0.110491495, 0.063653198, 0.036979211, 0.022844579, 0.013909341, 0.008781226],
        "ptnonipm" => [0.751204553, 0.144224191, 0.052822078, 0.023840537, 0.011000364,
            0.005661267, 0.003165207, 0.00197344, 0.001300664, 0.000861865, 0.000621856],
        "pt_oilgas" => [0.918700528, 0.059678397, 0.013323237, 0.003978944, 0.001724366,
            0.001038275, 0.000633395, 0.000387233, 0.000243355, 0.000122994, 6.48583e-05],
        "cmv" => [0.537538889, 0.338982929, 0.123478182]
    )
    [raw[p] ./ sum(raw[p]) for p in NEI2016_PROFILE_NAMES]
end
# Fraction of each profile at and above every layer, for folding at the domain top.
const NEI2016_LAYER_TAILS = [reverse(cumsum(reverse(f))) for f in NEI2016_LAYER_FRACTIONS]

"""
Default mapping from EPA sector name (as in the file name `2016fh_16j_<sector>_12US1_month_MM.ncf`)
to vertical profile. Sectors not listed here are emitted into the surface layer.
"""
const NEI2016_SECTOR_PROFILES = Dict(
    "emln_ptegu" => "ptegu",
    "emln_ptnonipm" => "ptnonipm",
    "emln_ptnonipm_allinln" => "ptnonipm",
    "emln_pt_oilgas" => "pt_oilgas",
    "emln_pt_oilgas_allinln" => "pt_oilgas",
    "emln_cmv_c3_12" => "cmv",
    "emln_cmv_c1c2_12" => "cmv"
)

# Model layer of the vertical coordinate `lev`: layer k covers k <= lev < k + 1, and values
# below 1 count as layer 1, as in the surface-only loader's former `lev < 2` test. Zero for
# a non-finite `lev`.
@inline _nei_layer(lev) = isfinite(lev) ? max(1, floor(Int, lev)) : 0

"""
$(SIGNATURES)

Fraction of a sector's column emissions that is released into model layer `lev`
(1-based; layer k covers k <= lev < k + 1) for vertical profile number `profile_id` (index
into `NEI2016_PROFILE_NAMES`), in a domain whose top layer is `ktop`: the fractions above
the domain top are added to the top layer, so the column total is kept. Zero above the top
of the profile and above the domain top.
"""
function nei_layer_fraction(profile_id, ktop, lev)
    k = _nei_layer(lev)
    fracs = NEI2016_LAYER_FRACTIONS[profile_id]
    (1 <= k <= min(ktop, length(fracs))) || return 0.0
    return k == ktop ? NEI2016_LAYER_TAILS[profile_id][k] : fracs[k]
end
nei_layer_fraction(profile_id, lev) = nei_layer_fraction(profile_id, typemax(Int), lev)

"""
$(SIGNATURES)

Layer fractions of profile `profile_id` for a domain whose top layer is `ktop`, folded at
the domain top as in [`nei_layer_fraction`](@ref).
"""
function nei_domain_fractions(profile_id, ktop)
    n = min(ktop, length(NEI2016_LAYER_FRACTIONS[profile_id]))
    return [nei_layer_fraction(profile_id, ktop, k) for k in 1:n]
end

# Per-layer differences of the GEOS-FP hybrid-grid coefficients, precomputed so the
# layer thickness costs two table reads. Ap is in Pa; stored in hPa to match the
# surface thickness map.
const NEI_DAP = [(Ap(k) - Ap(k + 1)) / 100 for k in 1:72]
const NEI_DBP = [Bp(k) - Bp(k + 1) for k in 1:72]

"""
$(SIGNATURES)

Dry pressure thickness (hPa, unitless here) of model layer `lev` at the given location
(radians). Layer 1 comes from the stored mean surface map; higher layers are scaled with
the hybrid-grid coefficients `Ap`/`Bp`, using a mean surface pressure backed out of the
layer-1 thickness.
"""
function delp_dry_itp(lon, lat, lev)
    d1 = delp_dry_surface_itp(lon, lat)
    k = _nei_layer(lev)
    k <= 1 && return d1
    ps = (d1 - NEI_DAP[1]) / NEI_DBP[1]
    return NEI_DAP[k] + NEI_DBP[k] * ps
end

# Local time conversion: shift UTC unix time `t` (seconds) by the longitude-derived
# timezone offset (`tz(lon_deg / 15)` hours) and return the resulting `DateTime`.
# Used by every diurnal/day-of-week scaling lookup below. `tz = floor` is HEMCO's
# local-time rule; `tz = round` is the solar time zone built into the EDGAR NOx
# hourly file that GEOS-Chem uses (round half to even at the half-hour meridians).
@inline function _local_datetime(t, lon, tz::F = floor) where {F}
    lon_deg = rad2deg(lon)
    dt = tz(lon_deg / 15) # timezone offset in hours
    return Dates.unix2datetime(t + dt * 3600)
end

# 1-based hour-of-day index (1..24) at the local time corresponding to UTC `t` / `lon`.
@inline _local_hour_index(t, lon, tz = floor) = Dates.hour(_local_datetime(t, lon, tz)) + 1
# 1-based day-of-week index (1..7) at the local time corresponding to UTC `t` / `lon`.
@inline _local_dow_index(t, lon, tz = floor) = Dates.dayofweek(_local_datetime(t, lon, tz))

"""
$(SIGNATURES)

Diurnal scale factor for a given UTC unix time and longitude (radians).
Named variants — one per emission-species profile — are each thin table-lookup
wrappers so that `@register_symbolic` can attach to a distinct top-level
function per profile. CO and formaldehyde use local time UTC + floor(lon/15) h;
NOx and isoprene use UTC + round(lon/15) h (see `_local_datetime`).
"""
diurnal_itp(t, lon) = DIURNAL_FACTORS[_local_hour_index(t, lon)]
diurnal_itp_NOx(t, lon) = DIURNAL_FACTORS_NOx[_local_hour_index(t, lon, round)]
diurnal_itp_ISOP(t, lon) = DIURNAL_FACTORS_ISOP[_local_hour_index(t, lon, round)]

"""
$(SIGNATURES)

Day-of-week scale factor for a given UTC unix time and longitude (radians).
See `diurnal_itp` for the rationale behind the per-profile wrappers and clocks.
"""
dayofweek_itp_CO(t, lon) = DayofWeekFactors_CO[_local_dow_index(t, lon)]
dayofweek_itp_NOx(t, lon) = DayofWeekFactors_NOx[_local_dow_index(t, lon, round)]

# Combined day-of-week × diurnal factors.  Species that need *both* scalings
# (CO, NOx) compose two registered symbolic calls per RHS evaluation in the
# original formulation.  These fused variants do the same table lookups but
# expose a single registered symbolic call to MTK, so the compiled RHS holds
# one wrapper invocation per grid point per stage instead of two.  The plain
# `dayofweek_itp_*` and `diurnal_itp_*` functions above are preserved for
# direct callers / tests.
nei_scale_CO(t, lon) = dayofweek_itp_CO(t, lon) * diurnal_itp(t, lon)
nei_scale_NOx(t, lon) = dayofweek_itp_NOx(t, lon) * diurnal_itp_NOx(t, lon)

# Register the symbolic function
@register_symbolic diurnal_itp(t, lon)
@register_symbolic diurnal_itp_NOx(t, lon)
@register_symbolic diurnal_itp_ISOP(t, lon)
@register_symbolic dayofweek_itp_CO(t, lon)
@register_symbolic dayofweek_itp_NOx(t, lon)
@register_symbolic nei_scale_CO(t, lon)
@register_symbolic nei_scale_NOx(t, lon)
@register_symbolic delp_dry_surface_itp(lon, lat)

# Tell SymbolicUtils these registered functions return scalars (needed for maketerm rebuild
# during substitute to avoid Unknown(-1) shapes breaking ifelse).
for f in (diurnal_itp, diurnal_itp_NOx, diurnal_itp_ISOP,
    dayofweek_itp_CO, dayofweek_itp_NOx,
    nei_scale_CO, nei_scale_NOx, delp_dry_surface_itp)
    @eval Symbolics.SymbolicUtils.promote_shape(::typeof($f),
        ::Symbolics.SymbolicUtils.ShapeT, ::Symbolics.SymbolicUtils.ShapeT) = _scalar_shape
end

# Dummy function for unit validation. ModelingToolkit will call this function
# with a DynamicQuantities.Quantity to get information about the type and units of the output.
diurnal_itp(t::DynamicQuantities.Quantity, lon) = 1.0
diurnal_itp_NOx(t::DynamicQuantities.Quantity, lon) = 1.0
diurnal_itp_ISOP(t::DynamicQuantities.Quantity, lon) = 1.0
dayofweek_itp_CO(t::DynamicQuantities.Quantity, lon) = 1.0
dayofweek_itp_NOx(t::DynamicQuantities.Quantity, lon) = 1.0
nei_scale_CO(t::DynamicQuantities.Quantity, lon) = 1.0
nei_scale_NOx(t::DynamicQuantities.Quantity, lon) = 1.0
delp_dry_surface_itp(lon::DynamicQuantities.Quantity, lat::DynamicQuantities.Quantity) = 1.0

# Per-layer factors of the NEI emissions. Generated code evaluates every branch of an
# `ifelse`, so the layer tests happen inside registered functions, which skip their work
# where a layer gets no emissions. The layer test (`nei_layer_gate`), the profile fractions
# (`nei_layer_fraction`), the layer thickness and the time factors are separate calls, so
# species with the same arguments share one evaluation of each per grid cell.

"""
$(SIGNATURES)

1.0 if model layer `lev` is at or below layer `kemit`, the highest layer a species emits
into, and 0.0 otherwise.
"""
nei_layer_gate(lev, kemit) = 1 <= _nei_layer(lev) <= kemit ? 1.0 : 0.0
nei_layer_gate(lev::DynamicQuantities.AbstractQuantity, kemit) = 1.0

"""
$(SIGNATURES)

Inverse dry pressure thickness (1/hPa, unitless here) of model layer `lev` (see
`delp_dry_itp`), or zero where `gate` (see `nei_layer_gate`) is zero.
"""
nei_inv_delp(lon, lat, lev, gate) = iszero(gate) ? 0.0 : 1 / delp_dry_itp(lon, lat, lev)
nei_inv_delp(lon::DynamicQuantities.Quantity, lat, lev, gate) = 1.0

# Diurnal (× day-of-week) factor of a species at UTC unix time `t` and longitude `lon`, or
# zero where `gate` (see `nei_layer_gate`) is zero.
for (f, clock) in ((:nei_clock_CO, :nei_scale_CO), (:nei_clock_NOx, :nei_scale_NOx),
    (:nei_clock_FORM, :diurnal_itp), (:nei_clock_ISOP, :diurnal_itp_ISOP))
    @eval $f(t, lon, gate) = iszero(gate) ? 0.0 : $clock(t, lon)
    @eval $f(t::DynamicQuantities.Quantity, lon, gate) = 1.0
end

nei_layer_fraction(profile_id, ktop, lev::DynamicQuantities.AbstractQuantity) = 1.0

for (f, n) in ((nei_layer_gate, 2), (nei_inv_delp, 4), (nei_layer_fraction, 3),
    (nei_clock_CO, 3), (nei_clock_NOx, 3), (nei_clock_FORM, 3), (nei_clock_ISOP, 3))
    args = [Symbol(:a, i) for i in 1:n]
    @eval @register_symbolic $(nameof(f))($(args...))
    @eval Symbolics.SymbolicUtils.promote_shape(::typeof($f),
        $(fill(:(::Symbolics.SymbolicUtils.ShapeT), n)...)) = _scalar_shape
end

# Per-species time factor: maps a NEI variable name to the function that supplies its
# diurnal (× day-of-week) factor. Species not listed get no time scaling. Used by the
# equation builder in `NEI2016MonthlyEmis` to keep the species-dispatch in one table
# instead of an `if/elseif` chain.
const _NEI_CLOCK_FN = Dict{String, Function}(
    "CO" => nei_clock_CO,
    "FORM" => nei_clock_FORM,
    "ISOP" => nei_clock_ISOP,
    "NO" => nei_clock_NOx,
    "NO2" => nei_clock_NOx
)

# Column flux of one vertical-profile group, interpolated from its data buffer, times the
# group's fraction `frac` in the current layer (see `nei_layer_fraction`). Where the
# fraction is zero the data are not read. Arguments as for `interp_unsafe`, followed by
# the fraction.
for (f, interp_f) in ((:nei_group_emis, :interp_unsafe),
    (:nei_group_emis_nearest, :interp_time_only))
    @eval begin
        function $f(data::AbstractArray{T, 3}, fit, fi1, fi2, extrap, frac) where {T}
            iszero(frac) && return zero(T)
            return T(frac) * $interp_f(data, fit, fi1, fi2, extrap)
        end
        $f(data::DataBufferType, fit, args...) = $f(data.data, fit, args...)
        # Unit validation, as for `interp_unsafe`: the data are unitless.
        $f(data::Union{DynamicQuantities.AbstractQuantity, Real}, fit, args...) = one(Float64)

        @register_symbolic $f(data::DataBufferType, fit, fi1, fi2, extrap, frac) false
        Symbolics.SymbolicUtils.promote_symtype(::typeof($f),
            ::Type{<:DataBufferType}, $(fill(:(::Type), 5)...)) = Real
        Symbolics.SymbolicUtils.promote_shape(::typeof($f),
            $(fill(:(::Symbolics.SymbolicUtils.ShapeT), 6)...)) = _scalar_shape
        @register_derivative $f(args...) I Symbolics.SConst(zero(Float64))
    end
end

"""
$(SIGNATURES)

Archived CMAQ emissions data.

Currently, only data for year 2016 is available.

Parameterized on the sector type `S` and dataset type `D` so that downstream
dispatch (notably the GPU-targeted `interp_unsafe` hot path) can stay
type-stable. Previously both fields were `::Any`, which erased the element
type of `fs.ds` and forced abstract dispatch in every NetCDF read.
"""
struct NEI2016MonthlyEmisFileSet{S, D} <: FileSet
    mirror::String
    sector::S
    ds::D
    freq_info::DataFrequencyInfo
end

function NEI2016MonthlyEmisFileSet(sector, starttime::DateTime, endtime::DateTime)
    NEI2016MonthlyEmisFileSet("https://gaftp.epa.gov/Air/", sector, starttime, endtime)
end

function NEI2016MonthlyEmisFileSet(mirror::AbstractString, sector,
        starttime::DateTime, endtime::DateTime)
    floormonth(t) = DateTime(Dates.year(t), Dates.month(t))
    check_times = (floormonth(starttime - Day(16))):Month(1):(endtime + Day(16))
    # Temporary fileset with `ds = nothing`, used only to compute download
    # paths via `relpath` / `localpath`.  The `freq_info` here is a stub —
    # the real one is built below from monthly centerpoints.
    tmp = NEI2016MonthlyEmisFileSet{typeof(sector), Nothing}(
        String(mirror), sector, nothing,
        DataFrequencyInfo(starttime, Day(1), check_times))
    filepaths = maybedownload.((tmp,), check_times)

    start = floormonth(starttime)
    frequency = ((start + Dates.Month(1)) - start) # Only true for the first month.
    centerpoints = [t + Second(t + Month(1) - t) / 2 for t in check_times]
    dfi = DataFrequencyInfo(start, frequency, centerpoints)

    ds = _open_aggregated_or_redownload(tmp, filepaths, check_times)
    return NEI2016MonthlyEmisFileSet{typeof(sector), typeof(ds)}(
        String(mirror), sector, ds, dfi)
end

# Open the aggregated monthly-NEI NCDataset, with a single-shot recovery for
# corrupt cached files.  `Downloads.download` already deletes its in-flight
# file on a transport-level error, so the corrupt case here is a previous
# successful download that the filesystem subsequently truncated (kill -9,
# interrupted copy, etc.).  Without recovery, the user sees an opaque HDF5
# error at FileSet construction and has to manually find and `rm` the bad
# file under `$EARTHSCIDATADIR`.
#
# The retry is intentionally a one-shot blanket re-download: pinpointing
# the single bad file would mean opening each NetCDF in isolation, and the
# expected case is "user's cache was once written and now has a problem,"
# not "the upstream is intermittently corrupt."  If the second attempt also
# fails, the second error propagates with a fresh stack.
function _open_aggregated_or_redownload(tmp::NEI2016MonthlyEmisFileSet,
        filepaths, check_times)
    try
        return lock(nclock) do
            NCDataset(filepaths, aggdim = "TSTEP")
        end
    catch e
        @warn "NEI aggregated NCDataset open failed; deleting cache and retrying " *
              "once" exception = (e, catch_backtrace())
        for path in filepaths
            isfile(path) && rm(path; force = true)
        end
        for t in check_times
            maybedownload(tmp, t)
        end
        return lock(nclock) do
            NCDataset(filepaths, aggdim = "TSTEP")
        end
    end
end

"""
$(SIGNATURES)

File path on the server relative to the host root; also path on local disk relative to `ENV["EARTHSCIDATADIR"]`.
"""
function relpath(fs::NEI2016MonthlyEmisFileSet, t::DateTime)
    @assert Dates.year(t)==2016 "Only 2016 emissions data is available with `NEI2016MonthlyEmis`."
    month = lpad(Dates.month(t), 2, '0')
    return "emismod/2016/v1/gridded/monthly_netCDF/2016fh_16j_$(fs.sector)_12US1_month_$(month).ncf"
end

DataFrequencyInfo(fs::NEI2016MonthlyEmisFileSet) = fs.freq_info

"""
$(SIGNATURES)

Load the NEI data for the given variable name at the given time.
This loads data in kg/s/m^2 units on the NEI source grid for regridding.
"""
function loadslice!(
        data::AbstractArray,
        fs::NEI2016MonthlyEmisFileSet,
        t::DateTime,
        varname
)
    lock(nclock) do
        data = reshape(data, size(data)..., 1)
        var = loadslice!(data, fs, fs.ds, t, varname, "TSTEP")

        # Step 1: Normalize the stored monthly totals to a per-day rate.
        # Despite the `units = "tons/day"` attribute, the EPA gridded-merge
        # monthly files store effectively *monthly* totals on a single 24-hour
        # TSTEP, so the labeled `tons/day` value is really a whole month's
        # worth of emissions.  Dividing by the number of days in the month
        # converts it to a true daily rate before the unit conversion below
        # treats it as `tons/day`.  Without this, the constant-rate value is
        # applied on every model day and over-emits by ~daysinmonth (~30×).
        # See https://github.com/EarthSciML/EarthSciData.jl/issues/209.
        data ./= Dates.daysinmonth(t)

        # Step 2: Apply unit conversion from the file (typically tons/day to kg/s)
        scale, _ = to_unit(var.attrib["units"])
        if scale != 1
            data .*= scale  # Now data is in kg/s per grid cell
        end

        # Step 3: Convert from kg/s per grid cell to kg/s/m² for conservative regridding
        # This is the flux density that can be conservatively regridded
        Δx = fs.ds.attrib["XCELL"]  # Cell width in meters
        Δy = fs.ds.attrib["YCELL"]  # Cell height in meters
        data ./= (Δx * Δy)  # Now data is in kg/s/m²
    end
    nothing
end

"""
$(SIGNATURES)

Load the data for the given variable name at the given time.
"""
function loadmetadata(fs::NEI2016MonthlyEmisFileSet, varname)::MetaData
    lock(nclock) do
        timedim = "TSTEP"
        var = fs.ds[varname]
        dims = collect(NCDatasets.dimnames(var))
        @assert timedim ∈ dims "Variable $varname does not have a dimension named '$timedim'."
        time_index = findfirst(isequal(timedim), dims)
        dims = deleteat!(dims, time_index)
        varsize = deleteat!(collect(size(var)), time_index)
        @assert varsize[end]==1 "Only 2D data is supported."
        varsize = varsize[1:(end - 1)] # Last dimension is 1.

        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        _, units = to_unit(var.attrib["units"])
        units /= u"m^2"
        description = var.attrib["var_desc"]

        x₀ = fs.ds.attrib["XORIG"]
        y₀ = fs.ds.attrib["YORIG"]
        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        nx = fs.ds.attrib["NCOLS"]
        ny = fs.ds.attrib["NROWS"]
        xs = x₀ + Δx / 2 .+ Δx .* (0:(nx - 1))
        ys = y₀ + Δy / 2 .+ Δy .* (0:(ny - 1))

        coords = [xs, ys]

        p_alp = fs.ds.attrib["P_ALP"]
        p_bet = fs.ds.attrib["P_BET"]
        #p_gam = fs.ds.attrib["P_GAM"] # Don't think this is used for anything.
        x_cent = fs.ds.attrib["XCENT"]
        y_cent = fs.ds.attrib["YCENT"]
        native_sr = "+proj=lcc +lat_1=$(p_alp) +lat_2=$(p_bet) +lat_0=$(y_cent) +lon_0=$(x_cent) +x_0=0 +y_0=0 +a=6370997.000000 +b=6370997.000000 +to_meter=1"

        xdim = findfirst((x) -> x == "COL", dims)
        ydim = findfirst((x) -> x == "ROW", dims)
        @assert xdim>0 "NEI2016 `COL` dimension not found"
        @assert ydim>0 "NEI2016 `ROW` dimension not found"

        return MetaData(
            coords,
            string(units),
            description,
            dims,
            varsize,
            native_sr,
            xdim,
            ydim,
            -1,
            (false, false, false)
        )
    end
end

function get_geometry(fs::NEI2016MonthlyEmisFileSet, m::MetaData)
    x₀, y₀, Δx, Δy, nx, ny = lock(nclock) do
        x₀ = fs.ds.attrib["XORIG"]
        y₀ = fs.ds.attrib["YORIG"]
        Δx = fs.ds.attrib["XCELL"]
        Δy = fs.ds.attrib["YCELL"]
        nx = fs.ds.attrib["NCOLS"]
        ny = fs.ds.attrib["NROWS"]
        x₀, y₀, Δx, Δy, nx, ny
    end
    # Create edges (nx+1 and ny+1 points) so we get nx*ny cells
    x = range(start = x₀, step = Δx, length = nx+1)
    y = range(start = y₀, step = Δy, length = ny+1)
    # Use column-major (x-fastest) ordering to match vec() on data arrays
    polys = Vector{Vector{NTuple{2, Float64}}}(undef, nx*ny)
    for j in 1:ny, i in 1:nx

        polys[(j - 1) * nx + i] = [(x[i], y[j]), (x[i + 1], y[j]), (x[i + 1], y[j + 1]),
            (x[i], y[j + 1]), (x[i], y[j])]
    end
    return polys
end

"""
$(SIGNATURES)

Return the variable names associated with this FileSet.
"""
function varnames(fs::NEI2016MonthlyEmisFileSet)
    lock(nclock) do
        return [setdiff(keys(fs.ds), ["TFLAG"; keys(fs.ds.dim)])...]
    end
end

Base.close(fs::NEI2016MonthlyEmisFileSet) = lock(nclock) do ;
    close(fs.ds);
end

# Grid attributes of an NEI file; sectors are summed and regridded together only if
# these agree.
const _NEI_GRID_ATTRIBS = ("GDNAM", "XORIG", "YORIG", "XCELL", "YCELL", "NCOLS", "NROWS",
    "P_ALP", "P_BET", "XCENT", "YCENT")
_nei_grid(fs::NEI2016MonthlyEmisFileSet) = lock(nclock) do
    [fs.ds.attrib[k] for k in _NEI_GRID_ATTRIBS]
end

function _check_same_grid(filesets)
    g1 = _nei_grid(first(filesets))
    for fs in filesets
        _nei_grid(fs) == g1 ||
            error("NEI2016 sector $(fs.sector) is not on the same grid as " *
                  "$(first(filesets).sector).")
    end
end

"""
$(SIGNATURES)

Several NEI2016 sectors on the same grid, summed at load time. A variable that is
missing from one sector's file is treated as zero for that sector.
"""
struct NEI2016MonthlyEmisMultiFileSet{F <: NEI2016MonthlyEmisFileSet} <: FileSet
    filesets::Vector{F}
end

function NEI2016MonthlyEmisMultiFileSet(sectors::AbstractVector{<:AbstractString},
        starttime::DateTime, endtime::DateTime)
    isempty(sectors) && error("At least one NEI2016 sector must be given.")
    fss = [NEI2016MonthlyEmisFileSet(String(s), starttime, endtime) for s in sectors]
    _check_same_grid(fss)
    NEI2016MonthlyEmisMultiFileSet(fss)
end

function _first_with(fs::NEI2016MonthlyEmisMultiFileSet, varname)
    i = findfirst(sub -> varname in varnames(sub), fs.filesets)
    isnothing(i) && error("Variable $varname not found in any of the NEI2016 sectors.")
    fs.filesets[i]
end

mirror(fs::NEI2016MonthlyEmisMultiFileSet) = mirror(first(fs.filesets))
relpath(fs::NEI2016MonthlyEmisMultiFileSet, t::DateTime) = relpath(first(fs.filesets), t)
function DataFrequencyInfo(fs::NEI2016MonthlyEmisMultiFileSet)
    DataFrequencyInfo(first(fs.filesets))
end
function loadmetadata(fs::NEI2016MonthlyEmisMultiFileSet, varname)::MetaData
    loadmetadata(_first_with(fs, varname), varname)
end
function get_geometry(fs::NEI2016MonthlyEmisMultiFileSet, m::MetaData)
    get_geometry(first(fs.filesets), m)
end
varnames(fs::NEI2016MonthlyEmisMultiFileSet) = unique(vcat(varnames.(fs.filesets)...))

function loadslice!(data::AbstractArray, fs::NEI2016MonthlyEmisMultiFileSet,
        t::DateTime, varname)
    fill!(data, zero(eltype(data)))
    buf = similar(data)
    for sub in fs.filesets
        varname in varnames(sub) || continue
        loadslice!(buf, sub, t, varname)
        data .+= buf
    end
    nothing
end

Base.close(fs::NEI2016MonthlyEmisMultiFileSet) = foreach(close, fs.filesets)

# Verify that `varname`'s grid metadata matches `ref_meta` on every dimension
# the shared regridder depends on.  Throws if any of {native_sr, xdim, ydim,
# zdim, staggering, varsize, coords} disagree.  Cheap because each
# `loadmetadata` call is just NetCDF attribute reads under `nclock`.
function _validate_shared_grid(fs::FileSet, varname, ref_var, ref_meta)
    m = loadmetadata(fs, varname)
    mismatches = String[]
    m.native_sr == ref_meta.native_sr || push!(mismatches, "native_sr")
    m.xdim == ref_meta.xdim || push!(mismatches, "xdim")
    m.ydim == ref_meta.ydim || push!(mismatches, "ydim")
    m.zdim == ref_meta.zdim || push!(mismatches, "zdim")
    m.staggering == ref_meta.staggering || push!(mismatches, "staggering")
    m.varsize == ref_meta.varsize || push!(mismatches, "varsize")
    m.coords == ref_meta.coords || push!(mismatches, "coords")
    isempty(mismatches) && return nothing
    error("NEI variable `$(varname)` has a different spatial grid than the " *
          "reference variable `$(ref_var)` (mismatched: $(join(mismatches, ", "))).  " *
          "The regridder is shared across all NEI variables and would produce " *
          "incorrect mass mappings here.  Per-variable regridders are not " *
          "currently supported for `NEI2016MonthlyEmis`.")
end

struct NEI2016MonthlyEmisCoupler
    sys::Any
end

"""
$(SIGNATURES)

A data loader for CMAQ-formatted monthly US National Emissions Inventory data for year 2016,
available from: https://gaftp.epa.gov/Air/emismod/2016/v1/gridded/monthly_netCDF/.
The emissions here are monthly averages, so there is no information about diurnal variation etc.

`sectors` is one sector name or a vector of sector names as they appear in the file names
`2016fh_16j_<sector>_12US1_month_MM.ncf`, e.g. `"mrggrid_withbeis_withrwc"` (all surface
sectors merged) or `"emln_ptegu"` (electricity generating units). Emissions from all listed
sectors are summed. The merged surface file does not contain the "inline" elevated point
sectors (`emln_ptegu`, `emln_ptnonipm`, `emln_pt_oilgas`, `emln_othpt`, `emln_cmv_c3_12`,
`emln_cmv_c1c2_12`, and the fire sectors); add them by listing them here, or see
[`NEI2016ElevatedEmis`](@ref).

Elevated sectors are spread over model layers with the same per-sector layer profiles that
GEOS-Chem uses for its NEI2016 3-D input files (see `NEI2016_SECTOR_PROFILES` and
`NEI2016_LAYER_FRACTIONS`). Sectors not listed in `vertical_profiles` are emitted into the
surface layer. Pass a different `vertical_profiles` dictionary (sector name => profile name,
one of $(NEI2016_PROFILE_NAMES)) to override the defaults. If the domain has fewer layers
than a profile, the fractions above the domain top are added to the top layer.

The emissions are returned as mixing ratios in units of kg/kg/s by converting from the
native flux density (kg/m²/s) using:

    mixing_ratio = flux / (g0_100 * delp_dry)

where g0_100 ≈ 10.197 kg/m² and delp_dry is the dry pressure thickness of the model layer
(physically in hPa, but unitless here) that varies spatially across the domain.

`scale` is a scaling factor to apply to the emissions data. The default value is 1.0.

`stream` specifies whether the data should be streamed in as needed or loaded all at once.

`spatial_interp = :linear` (default) does full multilinear interpolation; `:nearest` does
spatial nearest-neighbour + time-only linear interpolation for ~8x speedup when queries
are always at grid points.

Conservative regridding (via ConservativeRegridding.jl) is used by default to map emissions
from the native NEI Lambert Conformal Conic grid to the simulation domain grid, preserving
total emissions mass.
"""
function NEI2016MonthlyEmis(
        sectors::AbstractVector{<:AbstractString},
        domaininfo::DomainInfo;
        scale = 1.0,
        name = :NEI2016MonthlyEmis,
        stream = true,
        spatial_interp::Symbol = :linear,
        vertical_profiles::AbstractDict = NEI2016_SECTOR_PROFILES
)
    spatial_interp in (:linear, :nearest) ||
        throw(ArgumentError("spatial_interp must be :linear or :nearest, got $spatial_interp"))
    for s in sectors
        p = get(vertical_profiles, s, "surface")
        p in NEI2016_PROFILE_NAMES ||
            error("Unknown vertical profile \"$p\" for sector $s; use one of $(NEI2016_PROFILE_NAMES).")
    end
    starttime, endtime = get_tspan_datetime(domaininfo)
    # Group the sectors by vertical profile; each group is summed at load time and gets
    # one interpolator per variable.
    groups = Tuple{Int, NEI2016MonthlyEmisMultiFileSet}[]
    for (pid, pname) in enumerate(NEI2016_PROFILE_NAMES)
        secs = [String(s) for s in sectors if get(vertical_profiles, s, "surface") == pname]
        isempty(secs) && continue
        push!(groups, (pid, NEI2016MonthlyEmisMultiFileSet(secs, starttime, endtime)))
    end
    isempty(groups) && error("At least one NEI2016 sector must be given.")
    _check_same_grid([sub for (_, fs) in groups for sub in fs.filesets])
    group_vars = [Set(varnames(fs)) for (_, fs) in groups]
    # The regridder is built from the first variable's grid metadata and
    # reused across every variable and sector; if any later variable's grid disagrees,
    # the regridder would silently mis-map its emissions.  Validate up-front
    # rather than letting the mismatch produce wrong numbers at solve time.
    ref_fs = groups[1][2]
    ref_var = first(varnames(ref_fs))
    ref_meta = loadmetadata(ref_fs, ref_var)
    for (g, (_, fs)) in enumerate(groups)
        for varname in group_vars[g]
            _validate_shared_grid(fs, varname, ref_var, ref_meta)
        end
    end
    shared_regridder = regridder(ref_fs, ref_meta, domaininfo)
    pvdict = Dict([Symbol(v) => v for v in EarthSciMLBase.pvars(domaininfo)]...)
    @assert :x in keys(pvdict)||:lon in keys(pvdict) "x or lon must be specified in the domaininfo"
    @assert :y in keys(pvdict)||:lat in keys(pvdict) "y or lat must be specified in the domaininfo"
    @assert :lev in keys(pvdict) "lev must be specified in the domaininfo"
    x = :x in keys(pvdict) ? pvdict[:x] : pvdict[:lon]
    y = :y in keys(pvdict) ? pvdict[:y] : pvdict[:lat]
    lev = pvdict[:lev]

    @parameters(Δz=1.0,
        [description = "Couldn't remove Δz without getting errors, so I set it to 1.0 without units"],)
    @parameters t_ref = get_tref(domaininfo) [unit = u"s", description = "Reference time"]
    # Conversion constant: g0_100 = 100 hPa / g0 where g0 = 9.80665 m/s²
    @parameters g0_100 = 100.0 / 9.80665 [unit = u"kg/m^2"]
    eqs = Equation[]
    params = Any[t_ref, g0_100]
    all_discretes = Any[]
    all_constants = Any[]
    interp_infos = []
    lhs_vars = Num[]

    dt = EarthSciMLBase.eltype(domaininfo)
    # Top model layer of the domain; profiles reaching above it are folded into it.
    levidx = findfirst(v -> Symbol(v) === Symbol(lev), EarthSciMLBase.pvars(domaininfo))
    ktop = round(Int, maximum(EarthSciMLBase.grid(domaininfo, (false, false, false))[levidx]))
    group_f = spatial_interp === :nearest ? nei_group_emis_nearest : nei_group_emis
    allvars = unique(vcat([varnames(fs) for (_, fs) in groups]...))
    for varname in allvars
        # One interpolator per vertical-profile group, each multiplied by the group's
        # fraction in layer `lev`. The interpolator of the surface group is named after
        # the variable, the others `<variable>_<profile>`.
        terms = []
        itp = nothing
        kemit = 0
        for (g, (pid, fs)) in enumerate(groups)
            varname in group_vars[g] || continue
            itp = DataSetInterpolator{dt}(fs, varname, starttime, endtime, domaininfo;
                stream = stream, regrid_f = shared_regridder)
            n = pid == 1 ? Symbol(varname) :
                Symbol(varname, "_", NEI2016_PROFILE_NAMES[pid])
            discretes, constants, info = create_interp_info(itp, n, [x, y];
                spatial_interp = spatial_interp)
            frac = nei_layer_fraction(pid, ktop, lev)
            push!(terms,
                group_f(interp_index_exprs(info, t_ref + t, [x, y])..., frac) *
                info.unit_const)
            kemit = max(kemit, min(ktop, length(NEI2016_LAYER_FRACTIONS[pid])))
            append!(all_discretes, discretes)
            append!(all_constants, constants)
            push!(interp_infos, info)
        end

        # Diurnal (× day-of-week) factor and mixing ratio conversion:
        # mixing_ratio = flux / (g0_100 * delp_dry(x, y, lev)), zero above layer `kemit`.
        gate = nei_layer_gate(lev, kemit)
        clock_f = get(_NEI_CLOCK_FN, varname, nothing)
        clock = clock_f === nothing ? 1 : clock_f(t + t_ref, x, gate)
        rhs = sum(terms) / Δz * scale * clock * nei_inv_delp(x, y, lev, gate) / g0_100

        n = Symbol(varname)
        lhs = only(
            @variables $n(t) [
            unit = ModelingToolkit.get_unit(rhs),
            description = description(itp),
            misc = Dict(:staggering => itp.metadata.staggering)
        ]
        )
        push!(eqs, lhs ~ rhs)
        push!(lhs_vars, lhs)
    end
    all_params = [x, y, lev, Δz, all_constants..., all_discretes..., params...]
    sys = System(
        eqs,
        t,
        lhs_vars,
        all_params;
        name = name,
        initial_conditions = _itp_defaults(all_params),
        discrete_events = [build_interp_event(interp_infos, starttime)],
        metadata = Dict(CoupleType => NEI2016MonthlyEmisCoupler,
            SysDomainInfo => domaininfo,
            InterpInfos => interp_infos,
            SysDiscreteEvent => make_prune_factory(interp_infos))
    )
    return sys
end

function NEI2016MonthlyEmis(sector::AbstractString, domaininfo::DomainInfo; kwargs...)
    NEI2016MonthlyEmis([sector], domaininfo; kwargs...)
end

"""
The six "inline" elevated point sectors of the 2016 NEI platform that GEOS-Chem reads in
addition to the surface sectors: power plants, other industrial points, oil and gas points
(the inline part only; the low-level part is in the merged surface file), Canada and Mexico
points, and class 1/2 and class 3 commercial marine vessels.
"""
const NEI2016_ELEVATED_SECTORS = ["emln_ptegu", "emln_ptnonipm", "emln_pt_oilgas",
    "emln_othpt", "emln_cmv_c3_12", "emln_cmv_c1c2_12"]

"""
$(SIGNATURES)

The NEI 2016 elevated point sectors ([`NEI2016_ELEVATED_SECTORS`](@ref)) as one emission
system, vertically allocated as in GEOS-Chem. Equivalent to
`NEI2016MonthlyEmis(NEI2016_ELEVATED_SECTORS, domaininfo; kwargs...)`; to combine them with
the merged surface file in a single system, pass both to [`NEI2016MonthlyEmis`](@ref) instead:

    NEI2016MonthlyEmis(["mrggrid_withbeis_withrwc"; NEI2016_ELEVATED_SECTORS], domaininfo)
"""
function NEI2016ElevatedEmis(domaininfo::DomainInfo; name = :NEI2016ElevatedEmis, kwargs...)
    NEI2016MonthlyEmis(NEI2016_ELEVATED_SECTORS, domaininfo; name = name, kwargs...)
end
