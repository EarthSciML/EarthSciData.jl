# Shared helper: couple MeanWind variables to meteorological wind components.
# Dynamically maps v_lon/v_x → u_wind, v_lat/v_y → v_wind, v_lev → w_wind.
function _couple_meanwind(mw_sys, met_sys, u_wind, v_wind, w_wind)
    mw_unkn = unknowns(mw_sys)
    mw_syms = Symbol.([split(string(Symbolics.tosymbol(v, escape=false)), "₊")[end]
                        for v in mw_unkn])
    wind_targets = Dict(
        :v_lon => u_wind, :v_x => u_wind,
        :v_lat => v_wind, :v_y => v_wind,
        :v_lev => w_wind,
    )
    eqs = Equation[]
    for (i, sym) in enumerate(mw_syms)
        if haskey(wind_targets, sym)
            push!(eqs, mw_unkn[i] ~ wind_targets[sym])
        end
    end
    ConnectorSystem(eqs, mw_sys, met_sys)
end

# Shared helper for coupling emissions loaders to meteorological data providers.
function _couple_emis_to_met(emis_coupler, met_coupler)
    e, g = emis_coupler.sys, met_coupler.sys
    e = param_to_var(e, :lat, :lon, :lev)
    ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon, e.lev ~ g.lev], e, g)
end

# CEDS + GEOSFP (CEDS has only lat/lon, no lev)
function EarthSciMLBase.couple2(c::CEDSCoupler, g::GEOSFPCoupler)
    c, g = c.sys, g.sys
    c = param_to_var(c, :lat, :lon)
    ConnectorSystem([c.lat ~ g.lat, c.lon ~ g.lon], c, g)
end

# NEI + GEOSFP
EarthSciMLBase.couple2(e::NEI2016MonthlyEmisCoupler, g::GEOSFPCoupler) = _couple_emis_to_met(e, g)

# EDGAR + GEOSFP
EarthSciMLBase.couple2(e::EDGARv81MonthlyEmisCoupler, g::GEOSFPCoupler) = _couple_emis_to_met(e, g)

# NEI + ERA5
EarthSciMLBase.couple2(e::NEI2016MonthlyEmisCoupler, g::ERA5Coupler) = _couple_emis_to_met(e, g)

# EDGAR + ERA5
EarthSciMLBase.couple2(e::EDGARv81MonthlyEmisCoupler, g::ERA5Coupler) = _couple_emis_to_met(e, g)

# MeanWind + ERA5
function EarthSciMLBase.couple2(mw::EarthSciMLBase.MeanWindCoupler, e::ERA5Coupler)
    mw, e = mw.sys, e.sys
    _couple_meanwind(mw, e, e.pl₊u, e.pl₊v, e.pl₊w)
end
