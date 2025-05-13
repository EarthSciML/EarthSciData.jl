function EarthSciMLBase.couple2(e::NEI2016MonthlyEmisCoupler, g::GEOSFPCoupler)
    e, g = e.sys, g.sys

    e = param_to_var(e, :lat, :lon, :lev)
    ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon, e.lev ~ g.lev], e, g)
end
