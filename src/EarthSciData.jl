module EarthSciData
using Dates, Downloads, Printf
using DocStringExtensions
using NetCDF, Interpolations, ModelingToolkit, Symbolics
using EarthSciMLBase
using Unitful, Latexify

# General utilities
include("load.jl")
include("utils.jl")

# Specific data sets
include("geosfp.jl")

end
