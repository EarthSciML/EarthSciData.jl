module EarthSciData
using Dates, Downloads, Printf
using DocStringExtensions
using SciMLBase: DiscreteCallback
using Interpolations, DataInterpolations
using NCDatasets, ModelingToolkit, Symbolics, Proj
using ModelingToolkit: t
using EarthSciMLBase, DiffEqCallbacks
using DynamicQuantities, Latexify, ProgressMeter
using Scratch

# TODO: Hotfix to deal with issue https://github.com/SciML/DataInterpolations.jl/issues/331
# Remove this when the issue is fixed.
(itp::DataInterpolations.LinearInterpolation)(x::DynamicQuantities.Quantity) = itp(ustrip(x.value))

# General utilities
include("load.jl")
include("utils.jl")
include("update_callback.jl")

# Specific data sets
include("netcdf.jl")
include("geosfp.jl")
include("nei2016monthly.jl")
include("netcdf_output.jl")

# Coupling
include("coupling.jl")

end
