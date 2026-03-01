module EarthSciData
using Dates, Downloads
using DocStringExtensions
using SciMLBase: DiscreteCallback
using Interpolations, DataInterpolations
using NCDatasets, ModelingToolkit, Symbolics, Proj
using ModelingToolkit: t
using EarthSciMLBase, DiffEqCallbacks
using DynamicQuantities, Latexify, ProgressMeter
using Scratch
using JLD2
using ConservativeRegridding
using GeoInterface, GeometryOpsCore

# General utilities
include("load.jl")
include("mtk_integration.jl")
include("utils.jl")

# Specific data sets
include("netcdf.jl")
include("geosfp.jl")
include("wrf.jl")
include("regridding.jl")
include("nei2016monthly.jl")
include("netcdf_output.jl")
include("NCEP-NCAR_Reanalysis.jl")

# Coupling
include("coupling.jl")

function __init__()
    _fix_conservative_regridding_bugs()
end

end
