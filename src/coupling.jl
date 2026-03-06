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
    eqs = [mw.v_lon ~ e.pl₊u]
    length(unknowns(mw)) > 1 ? push!(eqs, mw.v_lat ~ e.pl₊v) : nothing
    length(unknowns(mw)) > 2 ? push!(eqs, mw.v_lev ~ e.pl₊w) : nothing
    ConnectorSystem(eqs, mw, e)
end
