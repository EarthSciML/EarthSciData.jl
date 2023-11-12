module EarthSciData
using Dates, Downloads, Printf
using DocStringExtensions
using NetCDF, Interpolations, ModelingToolkit, Symbolics, Proj
using EarthSciMLBase
using Unitful, Latexify, ProgressMeter
using Scratch

# General utilities
include("load.jl")
include("utils.jl")

# Specific data sets
include("geosfp.jl")
include("nei2016monthly.jl")

end
