"""
Convert a string to a `DynamicQuantities.Quantity` object.
"""
function to_unit(u)
    u = strip(u)
    d = Dict(
        "m s-1" => (1, u"m/s"),
        "Pa s-1" => (1, u"Pa/s"),
        "kg m-2 s-2" => (1, u"kg/m^2/s^2"),
        "kg kg-1" => (1, u"kg/kg"),
        "K" => (1, u"K"),
        "K m-2 kg-1 s-1" => (1, u"K/m^2/kg/s"),
        "hPa" => (100, u"Pa"),
        "kg m-2 s-1" => (1, u"kg/m^2/s"),
        "W m-2" => (1, u"W/m^2"),
        "m" => (1, u"m"),
        "Pa" => (1, u"Pa"),
        "min{-1}" => (1 / 60, u"s^-1"),
        "Dobsons" => (2.69e16/6.022e23 * 10000, u"mol/m^2"), # Dobson Unit: https://ozonewatch.gsfc.nasa.gov/facts/dobson_SH.html
        "m2 m-2" => (1, u"m^2/m^2"),
        "m2 s-2" => (1, u"m^2/s^2"),
        "kg m-2" => (1, u"kg/m^2"),
        "kg kg-1 s-1" => (1, u"kg/kg/s"),
        "tons/day" => (907.185 / 86400, u"kg/s"),
        "mol km^-2 hr^-1" => (1 / (1e6 * 3600), u"mol/m^2/s"),
        "1" => (1, Quantity(1.0)), # unitless
        "1.0" => (1, Quantity(1.0)),
        "ppmv" => (1e-6, Quantity(1.0)),
        "ug/m3" => (1e-6, u"kg/m^3"),
        "ug m^-3" => (1e-6, u"kg/m^3"),
        "1/km" => (0.001, u"m^-1"),
        "km^-1" => (0.001, u"m^-1"),
        "<YYYYDD,HHMMSS>" => (1, Quantity(1.0)),
        "none" => (1, Quantity(1.0)),
        "?" => (1, Quantity(1.0)),
        "" => (1, Quantity(1.0)),
        "-" => (1, Quantity(1.0)),
    )
    if haskey(d, u)
        return d[u]
    end
    error(ArgumentError("unregistered unit `$(u)`"))
end