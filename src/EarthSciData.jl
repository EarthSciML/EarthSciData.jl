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
using ZipFile
using JSON3

# General utilities
include("load.jl")
include("mtk_integration.jl")
include("utils.jl")
include("cds_api.jl")

# Specific data sets
include("netcdf.jl")
include("geosfp.jl")
include("wrf.jl")
include("regridding.jl")
include("nei2016monthly.jl")
include("ceds.jl")
include("edgar_v81_monthly.jl")
include("netcdf_output.jl")
include("NCEP-NCAR_Reanalysis.jl")
include("era5.jl")

# Coupling
include("coupling.jl")

end
