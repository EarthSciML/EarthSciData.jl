function EarthSciMLBase.couple2(e::NEI2016MonthlyEmisCoupler, g::GEOSFPCoupler)
    e, g = e.sys, g.sys

    e = param_to_var(e, :lat, :lon, :lev)
    ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon, e.lev ~ g.lev], e, g)
end

function EarthSciMLBase.couple2(c::CEDSCoupler, g::GEOSFPCoupler)
    c, g = c.sys, g.sys
    c = param_to_var(c, :lat, :lon)
    ConnectorSystem([c.lat ~ g.lat, c.lon ~ g.lon], c, g)
end

function EarthSciMLBase.couple2(e::EDGARv81MonthlyEmisCoupler, g::GEOSFPCoupler)
    e, g = e.sys, g.sys

    e = param_to_var(e, :lat, :lon, :lev)
    ConnectorSystem([e.lat ~ g.lat, e.lon ~ g.lon, e.lev ~ g.lev], e, g)
end
