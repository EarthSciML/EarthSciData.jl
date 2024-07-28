# Define the Dobson Unit: https://ozonewatch.gsfc.nasa.gov/facts/dobson_SH.html
module MyUnits; using Unitful; @unit dobson "Dobson" Dobson 2.69e16/6.022e23u"mol/cm^2" false; end
Unitful.register(MyUnits)

"""
Convert a string to a `Unitful` object.
"""
function to_unitful(u)
    d = Dict(
        "m s-1" => (1, u"m/s"),
        "Pa s-1" => (1, u"Pa/s"),
        "kg m-2 s-2" => (1, u"kg/m^2/s^2"),
        "kg kg-1" => (1, u"kg/kg"),
        "K" => (1, u"K"),
        "K m-2 kg-1 s-1" => (1, u"K/m^2/kg/s"),
        "hPa" => (1, u"hPa"),
        "kg m-2 s-1" => (1, u"kg/m^2/s"),
        "W m-2" => (1, u"W/m^2"),
        "m" => (1, u"m"),
        "Dobsons" => (1, u"dobson"),
        "m2 m-2" => (1, u"m^2/m^2"),
        "kg m-2" => (1, u"kg/m^2"),
        "kg kg-1 s-1" => (1, u"kg/kg/s"),
        "tons/day" => (907.185 / 86400, u"kg/s"),
        "1" => (1, Unitful.unit(1)), # unitless
        "<YYYYDD,HHMMSS>" => (1, Unitful.unit(1)),
    )
    if haskey(d, u)
        return d[u]
    end
    error(ArgumentError("unregistered unit `$(u)`"))
end