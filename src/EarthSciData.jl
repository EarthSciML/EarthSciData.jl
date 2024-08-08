module EarthSciData
using Dates, Downloads, Printf
using DocStringExtensions
using GridInterpolations, DataInterpolations, StaticArrays
using NCDatasets, ModelingToolkit, Symbolics, Proj
using EarthSciMLBase, DiffEqCallbacks
using Unitful, Latexify, ProgressMeter
using Scratch

# General utilities
include("load.jl")
include("utils.jl")

# Specific data sets
include("netcdf.jl")
include("geosfp.jl")
include("nei2016monthly.jl")
include("netcdf_output.jl")

end
