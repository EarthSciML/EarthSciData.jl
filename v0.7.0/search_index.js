var documenterSearchIndex = {"docs":
[{"location":"api/","page":"API","title":"API","text":"","category":"page"},{"location":"api/","page":"API","title":"API","text":"Modules = [EarthSciData]","category":"page"},{"location":"api/#EarthSciData.DataFrequencyInfo","page":"API","title":"EarthSciData.DataFrequencyInfo","text":"Information about the temporal frequency of archived data.\n\nstart: Beginning of time of the time series.\nfrequency: Interval between each record.\ncenterpoints: Time representing the temporal center of each record.\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.DataSetInterpolator","page":"API","title":"EarthSciData.DataSetInterpolator","text":"DataSetInterpolators are used to interpolate data from a FileSet to represent a given time and location. Data is loaded (and downloaded) lazily, so the first time you use it on a for a given  dataset and time period it may take a while to load. Each time step is downloaded and loaded as it is needed  during the simulation and cached on the hard drive at the path specified by the \\$EARTHSCIDATADIR environment variable, or in a scratch directory if that environment variable has not been specified.  The interpolator will also cache data in memory representing the  data records for the times immediately before and after the current time step.\n\nvarname is the name of the variable to interpolate. default_time is the time to use when initializing the interpolator. spatial_ref is the spatial reference system that the simulation will be using. cache_size is the number of time steps that should be held in the cache at any given time (default=3). (For gridded simulations where all grid cells are computed synchronously, a cache_size of 2 is best, but if the grid cells are not all time stepping together, a cache_size of 3 or more is best.)\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.FileSet","page":"API","title":"EarthSciData.FileSet","text":"An interface for types describing a dataset, potentially comprised of multiple files.\n\nTo satisfy this interface, a type must implement the following methods:\n\nrelpath(fs::FileSet, t::DateTime)\nurl(fs::FileSet, t::DateTime)\nlocalpath(fs::FileSet, t::DateTime)\nDataFrequencyInfo(fs::FileSet, t::DateTime)::DataFrequencyInfo\nloadmetadata(fs::FileSet, t::DateTime, varname)::MetaData\nloadslice!(cache::AbstractArray, fs::FileSet, t::DateTime, varname)\nvarnames(fs::FileSet, t::DateTime)\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.GEOSFPFileSet","page":"API","title":"EarthSciData.GEOSFPFileSet","text":"GEOS-FP data as archived for use with GEOS-Chem classic.\n\nDomain options (as of 2022-01-30):\n\n4x5\n0.125x0.15625_AS\n0.125x0.15625_EU\n0.125x0.15625_NA\n0.25x0.3125\n0.25x0.3125_AF\n0.25x0.3125_AS\n0.25x0.3125_CH\n0.25x0.3125_EU\n0.25x0.3125_ME\n0.25x0.3125_NA\n0.25x0.3125_OC\n0.25x0.3125_RU\n0.25x0.3125_SA\n0.5x0.625\n0.5x0.625_AS\n0.5x0.625_CH\n0.5x0.625_EU\n0.5x0.15625_NA\n2x2.5\n4x5\nC180\nC720\nNATIVE\nc720\n\nPossible filetypes are:\n\n:A1\n:A3cld\n:A3dyn\n:A3mstC\n:A3mstE\n:I3\n\nSee http://geoschemdata.wustl.edu/ExtData/ for current options.\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.MetaData","page":"API","title":"EarthSciData.MetaData","text":"Information about a data array.\n\ncoords: The locations associated with each data point in the array.\nunits: Physical units of the data, e.g. m s⁻¹.\ndescription: Description of the data.\ndimnames: Dimensions of the data, e.g. (lat, lon, layer).\nvarsize: Dimension sizes of the data, e.g. (180, 360, 30).\nnative_sr: The spatial reference system of the data, e.g. \"EPSG:4326\" for lat-lon data.\nxdim: The index number of the x-dimension (e.g. longitude)\nydim: The index number of the y-dimension (e.g. latitude)\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.NEI2016MonthlyEmisFileSet","page":"API","title":"EarthSciData.NEI2016MonthlyEmisFileSet","text":"Archived CMAQ emissions data.\n\nCurrently, only data for year 2016 is available.\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.NetCDFOutputter","page":"API","title":"EarthSciData.NetCDFOutputter","text":"Create an EarthSciMLBase.Operator to write simulation output to a NetCDF file.\n\nfilepath::String: The path of the NetCDF file to write to\nfile::Any: The netcdf dataset\nvars::Any: The netcdf variables corresponding to the state variables\ntvar::Any: The netcdf variable for time\ntime_interval::AbstractFloat: Times interval (in seconds) at which to write to disk\nextra_vars::AbstractVector: Extra observed variables to write to disk\ndtype::Any: Data type of the output\n\n\n\n\n\n","category":"type"},{"location":"api/#EarthSciData.GEOSFP-Tuple{Any, Any}","page":"API","title":"EarthSciData.GEOSFP","text":"GEOSFP(\n    domain,\n    t;\n    coord_defaults,\n    spatial_ref,\n    dtype,\n    kwargs...\n)\n\n\nA data loader for GEOS-FP data as archived for use with GEOS-Chem classic.\n\nDomain options (as of 2022-01-30):\n\n4x5\n0.125x0.15625_AS\n0.125x0.15625_EU\n0.125x0.15625_NA\n0.25x0.3125\n0.25x0.3125_AF\n0.25x0.3125_AS\n0.25x0.3125_CH\n0.25x0.3125_EU\n0.25x0.3125_ME\n0.25x0.3125_NA\n0.25x0.3125_OC\n0.25x0.3125_RU\n0.25x0.3125_SA\n0.5x0.625\n0.5x0.625_AS\n0.5x0.625_CH\n0.5x0.625_EU\n0.5x0.15625_NA\n2x2.5\n4x5\nC180\nC720\nNATIVE\nc720\n\ncoord_defaults can be used to provide default values for the coordinates of the domain. For example if we want to perform a 2D simulation with a vertical dimension, we can set coord_defaults = Dict(:lev => 1).\n\ndtype represents the desired data type of the interpolated values. The native data type for this dataset is Float32.\n\nSee http://geoschemdata.wustl.edu/ExtData/ for current options.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.NEI2016MonthlyEmis-NTuple{6, Any}","page":"API","title":"EarthSciData.NEI2016MonthlyEmis","text":"NEI2016MonthlyEmis(\n    sector,\n    t,\n    x,\n    y,\n    lev,\n    Δz;\n    spatial_ref,\n    dtype,\n    kwargs...\n)\n\n\nA data loader for CMAQ-formatted monthly US National Emissions Inventory data for year 2016,  available from: https://gaftp.epa.gov/Air/emismod/2016/v1/gridded/monthly_netCDF/. The emissions here are monthly averages, so there is no information about diurnal variation etc.\n\nspatial_ref should be the spatial reference system that  the simulation will be using. x and y, and should be the coordinate variables and grid  spacing values for the simulation that is going to be run, corresponding to the given x and y  values of the given spatial_ref, and the lev represents the variable for the vertical grid level. x and y must be in the same units as spatial_ref.\n\ndtype represents the desired data type of the interpolated values. The native data type for this dataset is Float32.\n\nNOTE: This is an interpolator that returns an emissions value by interpolating between the centers of the nearest grid cells in the underlying emissions grid, so it may not exactly conserve the total  emissions mass, especially if the simulation grid is coarser than the emissions grid.\n\nExample\n\nusing EarthSciData, ModelingToolkit, Unitful\n@parameters t lat lon lev\n@parameters Δz = 60 [unit=u\"m\"]\nemis = NEI2016MonthlyEmis(\"mrggrid_withbeis_withrwc\", t, lon, lat, lev, Δz)\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.async_loader-Tuple{EarthSciData.DataSetInterpolator}","page":"API","title":"EarthSciData.async_loader","text":"Asynchronously load data, anticipating which time will be requested next. \n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.centerpoint_index-Tuple{EarthSciData.DataFrequencyInfo, Any}","page":"API","title":"EarthSciData.centerpoint_index","text":"Return the index of the centerpoint closest to the given time.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.create_interp_equation-Tuple{EarthSciData.DataSetInterpolator, Vararg{Any, 4}}","page":"API","title":"EarthSciData.create_interp_equation","text":"create_interp_equation(\n    itp,\n    filename,\n    t,\n    sample_time,\n    coords;\n    wrapper_f\n)\n\n\nCreate an equation that interpolates the given dataset at the given time and location. filename is an identifier for the dataset, and t is the time variable.  wrapper_f can specify a function to wrap the interpolated value, for example eq -> eq / 2 to divide the interpolated value by 2.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.currenttimepoint-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.currenttimepoint","text":"Return the current interpolation time point for this interpolator. \n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.description-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.description","text":"description(itp, t)\n\n\nReturn the description of the data associated with this interpolator.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.dimnames-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.dimnames","text":"dimnames(itp, t)\n\n\nReturn the dimension names associated with this interpolator.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.endpoints-Tuple{EarthSciData.DataFrequencyInfo}","page":"API","title":"EarthSciData.endpoints","text":"Return the time endpoints correcponding to each centerpoint\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.getnc-Tuple{String}","page":"API","title":"EarthSciData.getnc","text":"Get the NCDataset for the given file path, caching the last 20 files. \n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.interp!-Union{Tuple{FT}, Tuple{N2}, Tuple{N}, Tuple{T}, Tuple{EarthSciData.DataSetInterpolator{T, N, N2, FT}, Dates.DateTime, Vararg{T, N2}}} where {T, N, N2, FT}","page":"API","title":"EarthSciData.interp!","text":"interp!(itp, t, locs)\n\n\nReturn the value of the given variable from the given dataset at the given time and location.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.interp!-Union{Tuple{N}, Tuple{T}, Tuple{EarthSciData.DataSetInterpolator, Real, Vararg{T, N}}} where {T, N}","page":"API","title":"EarthSciData.interp!","text":"Interpolation with a unix timestamp.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.interp_cache_times!-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.interp_cache_times!","text":"Load the time points that should be cached in this interpolator. \n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.interp_unsafe-Union{Tuple{FT}, Tuple{N2}, Tuple{N}, Tuple{T}, Tuple{EarthSciData.DataSetInterpolator{T, N, N2, FT}, Dates.DateTime, Vararg{T, N2}}} where {T, N, N2, FT}","page":"API","title":"EarthSciData.interp_unsafe","text":"Interpolate without checking if the data has been correctly loaded for the given time.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.loadmetadata-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime, Any}","page":"API","title":"EarthSciData.loadmetadata","text":"loadmetadata(fs, t, varname)\n\n\nLoad the data for the given variable name at the given time.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.loadmetadata-Tuple{EarthSciData.NEI2016MonthlyEmisFileSet, Dates.DateTime, Any}","page":"API","title":"EarthSciData.loadmetadata","text":"loadmetadata(fs, t, varname)\n\n\nLoad the data for the given variable name at the given time.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.loadslice!-Tuple{AbstractArray, EarthSciData.GEOSFPFileSet, Dates.DateTime, Any}","page":"API","title":"EarthSciData.loadslice!","text":"loadslice!(data, fs, t, varname)\n\n\nLoad the data in place for the given variable name at the given time.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.loadslice!-Tuple{AbstractArray, EarthSciData.NEI2016MonthlyEmisFileSet, Dates.DateTime, Any}","page":"API","title":"EarthSciData.loadslice!","text":"loadslice!(data, fs, t, varname)\n\n\nLoad the data in place for the given variable name at the given time.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.localpath-Tuple{EarthSciData.FileSet, Dates.DateTime}","page":"API","title":"EarthSciData.localpath","text":"localpath(fs, t)\n\n\nReturn the local path for the file for the given DateTime.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.maybedownload-Tuple{EarthSciData.FileSet, Dates.DateTime}","page":"API","title":"EarthSciData.maybedownload","text":"maybedownload(fs, t)\n\n\nCheck if the specified file exists locally. If not, download it.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.nexttimepoint-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.nexttimepoint","text":"Return the next interpolation time point for this interpolator. \n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.partialderivatives_δPδlev_geosfp-Tuple{Any}","page":"API","title":"EarthSciData.partialderivatives_δPδlev_geosfp","text":"partialderivatives_δPδlev_geosfp(geosfp; default_lev)\n\n\nReturn a function to calculate coefficients to multiply the  δ(u)/δ(lev) partial derivative operator by to convert a variable named u from δ(u)/δ(lev)toδ(u)/δ(P), i.e. from vertical level number to pressure in hPa. The return format iscoordinateindex => conversionfactor`.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.prevtimepoint-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.prevtimepoint","text":"Return the previous interpolation time point for this interpolator. \n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.prune!-Tuple{ModelingToolkit.PDESystem, AbstractString}","page":"API","title":"EarthSciData.prune!","text":"prune!(pde_sys, prefix)\n\n\nRemove equations from a PDESystem where a variable in the LHS contains the given prefix but none of the equations have an RHS containing that variable. This can be used to  remove data loading equations that are not used in the final model.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.relpath-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime}","page":"API","title":"EarthSciData.relpath","text":"relpath(fs, t)\n\n\nFile path on the server relative to the host root; also path on local disk relative to ENV[\"EARTHSCIDATADIR\"]  (or a scratch directory if that environment variable is not set).\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.relpath-Tuple{EarthSciData.NEI2016MonthlyEmisFileSet, Dates.DateTime}","page":"API","title":"EarthSciData.relpath","text":"relpath(fs, t)\n\n\nFile path on the server relative to the host root; also path on local disk relative to ENV[\"EARTHSCIDATADIR\"].\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.to_unitful-Tuple{Any}","page":"API","title":"EarthSciData.to_unitful","text":"Convert a string to a Unitful object.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.units-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"API","title":"EarthSciData.units","text":"units(itp, t)\n\n\nReturn the units of the data associated with this interpolator.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.url-Tuple{EarthSciData.FileSet, Dates.DateTime}","page":"API","title":"EarthSciData.url","text":"url(fs, t)\n\n\nReturn the URL for the file for the given DateTime.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.varnames-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime}","page":"API","title":"EarthSciData.varnames","text":"varnames(fs, t)\n\n\nReturn the variable names associated with this FileSet.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciData.varnames-Tuple{EarthSciData.NEI2016MonthlyEmisFileSet, Dates.DateTime}","page":"API","title":"EarthSciData.varnames","text":"varnames(fs, t)\n\n\nReturn the variable names associated with this FileSet.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciMLBase.finalize!-Tuple{NetCDFOutputter, EarthSciMLBase.Simulator}","page":"API","title":"EarthSciMLBase.finalize!","text":"Close the NetCDF file\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciMLBase.initialize!-Tuple{NetCDFOutputter, EarthSciMLBase.Simulator}","page":"API","title":"EarthSciMLBase.initialize!","text":"Set up the output file.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciMLBase.run!-Tuple{NetCDFOutputter, EarthSciMLBase.Simulator, Any}","page":"API","title":"EarthSciMLBase.run!","text":"Write the current state of the Simulator to the NetCDF file.\n\n\n\n\n\n","category":"method"},{"location":"api/#EarthSciMLBase.timestep-Tuple{NetCDFOutputter}","page":"API","title":"EarthSciMLBase.timestep","text":"Return the interval at which to write the simulation state to disk.\n\n\n\n\n\n","category":"method"},{"location":"api/#ModelingToolkit.get_unit-Tuple{EarthSciData.DataSetInterpolator}","page":"API","title":"ModelingToolkit.get_unit","text":"Return the units of the data. \n\n\n\n\n\n","category":"method"},{"location":"nei2016/#2016-US-EPA-National-Emissions-Inventory-(NEI)-data","page":"2016 NEI","title":"2016 US EPA National Emissions Inventory (NEI) data","text":"","category":"section"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"We have a data loader for CMAQ-formatted monthly US National Emissions Inventory data for year 2016,NEI2016MonthlyEmis.","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"Because there is an issue with the EPA's FTP server that we download the data from you may need to set the following environment variable before using it:","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"In Julia:","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"ENV[\"JULIA_NO_VERIFY_HOSTS\"] = \"gaftp.epa.gov\"","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"or in a bash shell:","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"export JULIA_NO_VERIFY_HOSTS=gaftp.epa.gov","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"This is what its equation system looks like:","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"using EarthSciData, ModelingToolkit, Unitful, DataFrames\n@parameters t lat lon lev\n@parameters Δz = 60 [unit=u\"m\"]\nemis = NEI2016MonthlyEmis(\"mrggrid_withbeis_withrwc\", t, lon, lat, lev, Δz)","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"And here are the variables in tabular format:","category":"page"},{"location":"nei2016/","page":"2016 NEI","title":"2016 NEI","text":"vars = states(emis)\nDataFrame(\n        :Name => [string(Symbolics.tosymbol(v, escape=false)) for v ∈ vars],\n        :Units => [ModelingToolkit.get_unit(v) for v ∈ vars],\n        :Description => [ModelingToolkit.getdescription(v) for v in vars],\n)","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = EarthSciData","category":"page"},{"location":"#EarthSciData:-Earth-Science-Data-Loaders-and-Interpolators","page":"Home","title":"EarthSciData: Earth Science Data Loaders and Interpolators","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for EarthSciData.","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"using Pkg\nPkg.add(\"EarthSciMLData\")","category":"page"},{"location":"#Feature-Summary","page":"Home","title":"Feature Summary","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package contains data loaders for use with the EarthSciML ecosystem.","category":"page"},{"location":"#Feature-List","page":"Home","title":"Feature List","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Loader for GEOS-FP data.\nLoader for 2016 NEI emissions data.\nData outputters:\nNetCDFOutputter","category":"page"},{"location":"#Contributing","page":"Home","title":"Contributing","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Please refer to the SciML ColPrac: Contributor's Guide on Collaborative Practices for Community Packages for guidance on PRs, issues, and other matters relating to contributing.","category":"page"},{"location":"#Reproducibility","page":"Home","title":"Reproducibility","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"<details><summary>The documentation of this EarthSciML package was built using these direct dependencies,</summary>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Pkg # hide\nPkg.status() # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"</details>","category":"page"},{"location":"","page":"Home","title":"Home","text":"<details><summary>and using this machine and Julia version.</summary>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using InteractiveUtils # hide\nversioninfo() # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"</details>","category":"page"},{"location":"","page":"Home","title":"Home","text":"<details><summary>A more complete overview of all dependencies and their versions is also provided.</summary>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Pkg # hide\nPkg.status(;mode = PKGMODE_MANIFEST) # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"</details>","category":"page"},{"location":"","page":"Home","title":"Home","text":"You can also download the \n<a href=\"","category":"page"},{"location":"","page":"Home","title":"Home","text":"using TOML\nusing Markdown\nversion = TOML.parse(read(\"../../Project.toml\",String))[\"version\"]\nname = TOML.parse(read(\"../../Project.toml\",String))[\"name\"]\nlink = Markdown.MD(\"https://github.com/EarthSciML/\"*name*\".jl/tree/gh-pages/v\"*version*\"/assets/Manifest.toml\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"\">manifest</a> file and the\n<a href=\"","category":"page"},{"location":"","page":"Home","title":"Home","text":"using TOML\nusing Markdown\nversion = TOML.parse(read(\"../../Project.toml\",String))[\"version\"]\nname = TOML.parse(read(\"../../Project.toml\",String))[\"name\"]\nlink = Markdown.MD(\"https://github.com/EarthSciML/\"*name*\".jl/tree/gh-pages/v\"*version*\"/assets/Project.toml\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"\">project</a> file.","category":"page"},{"location":"geosfp/#Using-data-from-GEOS-FP","page":"GEOS-FP","title":"Using data from GEOS-FP","text":"","category":"section"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"This example demonstrates how to use the GEOS-FP data loader in the EarthSciML ecosystem. The GEOS-FP data loader is used to load data from the GEOS-FP dataset.","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"First, let's initialize some packages and set up the GEOS-FP equation system.","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"using EarthSciData, EarthSciMLBase\nusing DomainSets, ModelingToolkit, MethodOfLines, DifferentialEquations\nusing Dates, Plots, DataFrames\n\n# Set up system\n@parameters t lev lon lat\ngeosfp = GEOSFP(\"4x5\", t)","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"We can see above the different variables that are available in the GEOS-FP dataset. But also, here they are in table form:","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"vars = states(geosfp)\nDataFrame(\n        :Name => [string(Symbolics.tosymbol(v, escape=false)) for v ∈ vars],\n        :Units => [ModelingToolkit.get_unit(v) for v ∈ vars],\n        :Description => [ModelingToolkit.getdescription(v) for v ∈ vars],\n)","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"The GEOS-FP equation system isn't an ordinary differential equation (ODE) system, so we can't run it by itself. To fix this, we create another equation system that is an ODE.  (We don't actually end up using this system for anything, it's just necessary to get the system to compile.)","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"function Example(t)\n    @variables c(t) = 5.0\n    D = Differential(t)\n    ODESystem([D(c) ~ sin(lat * π / 180.0 * 6) + sin(lon * π / 180 * 6)], t, name=:Docs₊Example)\nend\nexamplesys = Example(t)","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"Now, let's couple these two systems together, and also add in advection and some information about the domain:","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"domain = DomainInfo(\n    partialderivatives_δxyδlonlat,\n    constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),\n    zerogradBC(lat ∈ Interval(-80.0f0, 80.0f0)),\n    periodicBC(lon ∈ Interval(-180.0f0, 180.0f0)),\n    zerogradBC(lev ∈ Interval(1.0f0, 11.0f0)),\n)\n\ncomposed_sys = couple(examplesys, domain, geosfp)\npde_sys = get_mtk(composed_sys)","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"Now, finally, we can run the simulation and plot the GEOS-FP wind fields in the result:","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"(The code below is commented out because it is very slow right now. A faster solution is coming soon!)","category":"page"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"# discretization = MOLFiniteDifference([lat => 10, lon => 10, lev => 10], t, approx_order=2)\n# @time pdeprob = discretize(pde_sys, discretization)\n\n# pdesol = solve(pdeprob, Tsit5(), saveat=3600.0)\n\n# discrete_lon = pdesol[lon]\n# discrete_lat = pdesol[lat]\n# discrete_lev = pdesol[lev]\n# discrete_t = pdesol[t]\n\n# @variables meanwind₊u(..) meanwind₊v(..) examplesys₊c(..)\n# sol_u = pdesol[meanwind₊u(t, lat, lon, lev)]\n# sol_v = pdesol[meanwind₊v(t, lat, lon, lev)]\n# sol_c = pdesol[examplesys₊c(t, lat, lon, lev)]\n\n# anim = @animate for k in 1:length(discrete_t)\n#     p1 = heatmap(discrete_lon, discrete_lat, sol_c[k, 1:end, 1:end, 2], clim=(minimum(sol_c[:, :, :, 2]), maximum(sol_c[:, :, :, 2])),\n#             xlabel=\"Longitude\", ylabel=\"Latitude\", title=\"examplesys.c: $(Dates.unix2datetime(discrete_t[k]))\")\n#     p2 = heatmap(discrete_lon, discrete_lat, sol_u[k, 1:end, 1:end, 2], clim=(minimum(sol_u[:, :, :, 2]), maximum(sol_u[:, :, :, 2])), \n#             title=\"U\")\n#     p3 = heatmap(discrete_lon, discrete_lat, sol_v[k, 1:end, 1:end, 2], clim=(minimum(sol_v[:, :, :, 2]), maximum(sol_v[:, :, :, 2])),\n#             title=\"V\")\n#     plot(p1, p2, p3, size=(800, 500))\n# end\n# gif(anim, \"animation.gif\", fps = 8)","category":"page"}]
}
