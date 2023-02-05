var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = EarthSciData","category":"page"},{"location":"#EarthSciData","page":"Home","title":"EarthSciData","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for EarthSciData.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [EarthSciData]","category":"page"},{"location":"#EarthSciData.DataArray","page":"Home","title":"EarthSciData.DataArray","text":"An array of data.\n\ndata: The data.\nunits: Physical units of the data, e.g. m s⁻¹.\ndescription: Description of the data.\ndimnames: Dimensions of the data, e.g. (lat, lon, layer).\n\n\n\n\n\n","category":"type"},{"location":"#EarthSciData.DataFrequencyInfo","page":"Home","title":"EarthSciData.DataFrequencyInfo","text":"Information about the temporal frequency of archived data.\n\nstart: Beginning of time of the time series.\nfrequency: Interval between each record.\ncenterpoints: Time representing the temporal center of each record.\n\n\n\n\n\n","category":"type"},{"location":"#EarthSciData.DataSetInterpolator","page":"Home","title":"EarthSciData.DataSetInterpolator","text":"DataSetInterpolators are used to interpolate data from a FileSet to represent a given time and location. Data is loaded (and downloaded) lazily, so the first time you use it on a for a given  dataset and time period it may take a while to load. Each time step is downloaded and loaded as it is needed  during the simulation and cached on the hard drive at the path specified by the \\$EARTHSCIDATADIR environment variable. The interpolator will also cache data in memory representing the  data records for the times immediately before and after the current time step.\n\n\n\n\n\n","category":"type"},{"location":"#EarthSciData.FileSet","page":"Home","title":"EarthSciData.FileSet","text":"An interface for types describing a dataset, potentially comprised of multiple files.\n\nTo satisfy this interface, a type must implement the following methods:\n\nrelpath(fs::FileSet, t::DateTime)\nurl(fs::FileSet, t::DateTime)\nlocalpath(fs::GEOSFPFileSet, t::DateTime)\nDataFrequencyInfo(fs::GEOSFPFileSet, t::DateTime)::DataFrequencyInfo\nloadslice(fs::GEOSFPFileSet, t::DateTime, varname)::DataArray\nload_interpolator(fs::GEOSFPFileSet, t::DateTime, varname)\nvarnames(fs::GEOSFPFileSet, t::DateTime)\n\n\n\n\n\n","category":"type"},{"location":"#EarthSciData.GEOSFP","page":"Home","title":"EarthSciData.GEOSFP","text":"A data loader for GEOS-FP data as archived for use with GEOS-Chem classic.\n\nDomain options (as of 2022-01-30):\n\n4x5\n0.125x0.15625_AS\n0.125x0.15625_EU\n0.125x0.15625_NA\n0.25x0.3125\n0.25x0.3125_AF\n0.25x0.3125_AS\n0.25x0.3125_CH\n0.25x0.3125_EU\n0.25x0.3125_ME\n0.25x0.3125_NA\n0.25x0.3125_OC\n0.25x0.3125_RU\n0.25x0.3125_SA\n0.5x0.625\n0.5x0.625_AS\n0.5x0.625_CH\n0.5x0.625_EU\n0.5x0.15625_NA\n2x2.5\n4x5\nC180\nC720\nNATIVE\nc720\n\nSee http://geoschemdata.wustl.edu/ExtData/ for current options.\n\n\n\n\n\n","category":"type"},{"location":"#EarthSciData.GEOSFPFileSet","page":"Home","title":"EarthSciData.GEOSFPFileSet","text":"GEOS-FP data as archived for use with GEOS-Chem classic.\n\nDomain options (as of 2022-01-30):\n\n4x5\n0.125x0.15625_AS\n0.125x0.15625_EU\n0.125x0.15625_NA\n0.25x0.3125\n0.25x0.3125_AF\n0.25x0.3125_AS\n0.25x0.3125_CH\n0.25x0.3125_EU\n0.25x0.3125_ME\n0.25x0.3125_NA\n0.25x0.3125_OC\n0.25x0.3125_RU\n0.25x0.3125_SA\n0.5x0.625\n0.5x0.625_AS\n0.5x0.625_CH\n0.5x0.625_EU\n0.5x0.15625_NA\n2x2.5\n4x5\nC180\nC720\nNATIVE\nc720\n\nPossible filetypes are:\n\n:A1\n:A3cld\n:A3dyn\n:A3mstC\n:A3mstE\n:I3\n\nSee http://geoschemdata.wustl.edu/ExtData/ for current options.\n\n\n\n\n\n","category":"type"},{"location":"#EarthSciData.centerpoint_index-Tuple{EarthSciData.DataFrequencyInfo, Any}","page":"Home","title":"EarthSciData.centerpoint_index","text":"Return the index of the centerpoint closest to the given time.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.description-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"Home","title":"EarthSciData.description","text":"description(itp, t)\n\n\nReturn the description of the data associated with this interpolator.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.dimnames-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"Home","title":"EarthSciData.dimnames","text":"dimnames(itp, t)\n\n\nReturn the dimension names associated with this interpolator.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.endpoints-Tuple{EarthSciData.DataFrequencyInfo}","page":"Home","title":"EarthSciData.endpoints","text":"Return the time endpoints correcponding to each centerpoint\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.interp!-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime, Vararg{Any}}","page":"Home","title":"EarthSciData.interp!","text":"interp!(itp, t, locs)\n\n\nReturn the value of the given variable from the given dataset at the given time and location.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.load_interpolator-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime, Any}","page":"Home","title":"EarthSciData.load_interpolator","text":"load_interpolator(fs, t, varname)\n\n\nLoad the data for the given DateTime and variable name as an interpolator from Interpolations.jl.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.loadslice-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime, Any}","page":"Home","title":"EarthSciData.loadslice","text":"loadslice(fs, t, varname)\n\n\nLoad the data for the given variable name at the given time.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.localpath-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime}","page":"Home","title":"EarthSciData.localpath","text":"localpath(fs, t)\n\n\nReturn the local path for the GEOS-FP file for the given DateTime.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.maybedownload-Tuple{EarthSciData.FileSet, Dates.DateTime}","page":"Home","title":"EarthSciData.maybedownload","text":"maybedownload(fs, t)\n\n\nCheck if the specified file exists locally. If not, download it.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.prune!-Tuple{ModelingToolkit.PDESystem, AbstractString}","page":"Home","title":"EarthSciData.prune!","text":"prune!(pde_sys, prefix)\n\n\nRemove equations from a PDESystem where a variable in the LHS contains the given prefix but none of the equations have an RHS containing that variable. This can be used to  remove data loading equations that are not used in the final model.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.relpath-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime}","page":"Home","title":"EarthSciData.relpath","text":"relpath(fs, t)\n\n\nFile path on the server relative to the host root; also path on local disk relative to ENV[\"EARTHSCIDATADIR\"].\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.units-Tuple{EarthSciData.DataSetInterpolator, Dates.DateTime}","page":"Home","title":"EarthSciData.units","text":"units(itp, t)\n\n\nReturn the units of the data associated with this interpolator.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.url-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime}","page":"Home","title":"EarthSciData.url","text":"url(fs, t)\n\n\nReturn the URL for the GEOS-FP file for the given DateTime.\n\n\n\n\n\n","category":"method"},{"location":"#EarthSciData.varnames-Tuple{EarthSciData.GEOSFPFileSet, Dates.DateTime}","page":"Home","title":"EarthSciData.varnames","text":"varnames(fs, t)\n\n\nReturn the variable names associated with this FileSet.\n\n\n\n\n\n","category":"method"},{"location":"geosfp/#Using-data-from-GEOS-FP","page":"GEOS-FP","title":"Using data from GEOS-FP","text":"","category":"section"},{"location":"geosfp/","page":"GEOS-FP","title":"GEOS-FP","text":"using EarthSciData, EarthSciMLBase\nusing DomainSets, ModelingToolkit, MethodOfLines, DifferentialEquations\nusing Dates, Plots\n\n# Set up system\n@parameters t lev lon lat\ngeosfp = GEOSFP(\"4x5\", t)\n\nstruct Example <: EarthSciMLODESystem\n    sys\n    function Example(t; name)\n        @variables c(t) = 5.0\n        D = Differential(t)\n        new(ODESystem([D(c) ~ sin(lat * π / 180.0 * 6) + sin(lon * π / 180 * 6)], t, name=name))\n    end\nend\n@named examplesys = Example(t)\n\ndomain = DomainInfo(\n    partialderivatives_lonlat2xymeters,\n    constIC(0.0, t ∈ Interval(Dates.datetime2unix(DateTime(2022, 1, 1)), Dates.datetime2unix(DateTime(2022, 1, 3)))),\n    zerogradBC(lat ∈ Interval(-85.0f0, 85.0f0)),\n    periodicBC(lon ∈ Interval(-180.0f0, 175.0f0)),\n    zerogradBC(lev ∈ Interval(1.0f0, 10.0f0)),\n)\n\ncomposed_sys = examplesys + domain + Advection() + geosfp;\npde_sys = get_mtk(composed_sys)\n\n# Solve\ndiscretization = MOLFiniteDifference([lat => 6, lon => 6, lev => 6], t, approx_order=2)\n@time pdeprob = discretize(pde_sys, discretization)\n\n#@run pdesol = solve(pdeprob, Tsit5(), saveat=3600.0)\n@profview pdesol = solve(pdeprob, Tsit5(), saveat=36000.0)\n@time pdesol = solve(pdeprob, Tsit5(), saveat=3600.0)\n\n# Plot\ndiscrete_lon = pdesol[lon]\ndiscrete_lat = pdesol[lat]\ndiscrete_lev = pdesol[lev]\ndiscrete_t = pdesol[t]\n\n@variables meanwind₊u(..) meanwind₊v(..) examplesys₊c(..)\nsol_u = pdesol[meanwind₊u(t, lat, lon, lev)]\nsol_v = pdesol[meanwind₊v(t, lat, lon, lev)]\nsol_c = pdesol[examplesys₊c(t, lat, lon, lev)]\n\nanim = @animate for k in 1:length(discrete_t)\n    p1 = heatmap(discrete_lon, discrete_lat, sol_c[k, 1:end, 1:end, 2], clim=(minimum(sol_c[:, :, :, 2]), maximum(sol_c[:, :, :, 2])),\n            xlabel=\"Longitude\", ylabel=\"Latitude\", title=\"examplesys.c: $(Dates.unix2datetime(discrete_t[k]))\")\n    p2 = heatmap(discrete_lon, discrete_lat, sol_u[k, 1:end, 1:end, 2], clim=(minimum(sol_u[:, :, :, 2]), maximum(sol_u[:, :, :, 2])), \n            title=\"U\")\n    p3 = heatmap(discrete_lon, discrete_lat, sol_v[k, 1:end, 1:end, 2], clim=(minimum(sol_v[:, :, :, 2]), maximum(sol_v[:, :, :, 2])),\n            title=\"V\")\n    plot(p1, p2, p3, size=(1200, 700))\nend\ngif(anim, \"animation.gif\", fps = 8)","category":"page"}]
}
