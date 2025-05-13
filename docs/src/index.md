```@meta
CurrentModule = EarthSciData
```

# EarthSciData: Earth Science Data Loaders and Interpolators

Documentation for [EarthSciData](https://github.com/EarthSciML/EarthSciData.jl).

## Installation

```julia
using Pkg
Pkg.add("EarthSciMLData")
```

## Feature Summary

This package contains data loaders for use with the [EarthSciML](https://earthsci.dev/) ecosystem.

## Feature List

  - Loader for [GEOS-FP](https://gmao.gsfc.nasa.gov/GMAO_products/NRT_products.php) data.
  - Loader for [2016 NEI](https://gaftp.epa.gov/Air/) emissions data.
  - Data outputters:
    
      + [`NetCDFOutputter`](@ref)

## Contributing

  - Please refer to the
    [SciML ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://github.com/SciML/ColPrac/blob/master/README.md)
    for guidance on PRs, issues, and other matters relating to contributing.

## Reproducibility

```@raw html
<details><summary>The documentation of this EarthSciML package was built using these direct dependencies,</summary>
```

```@example
using Pkg # hide
Pkg.status() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>and using this machine and Julia version.</summary>
```

```@example
using InteractiveUtils # hide
versioninfo() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>A more complete overview of all dependencies and their versions is also provided.</summary>
```

```@example
using Pkg # hide
Pkg.status(; mode = PKGMODE_MANIFEST) # hide
```

```@raw html
</details>
```

```@raw html
You can also download the 
<a href="
```

```@eval
using TOML
using Markdown
version = TOML.parse(read("../../Project.toml", String))["version"]
name = TOML.parse(read("../../Project.toml", String))["name"]
link = Markdown.MD("https://github.com/EarthSciML/"*name*".jl/tree/gh-pages/v"*version*"/assets/Manifest.toml")
```

```@raw html
">manifest</a> file and the
<a href="
```

```@eval
using TOML
using Markdown
version = TOML.parse(read("../../Project.toml", String))["version"]
name = TOML.parse(read("../../Project.toml", String))["name"]
link = Markdown.MD("https://github.com/EarthSciML/"*name*".jl/tree/gh-pages/v"*version*"/assets/Project.toml")
```

```@raw html
">project</a> file.
```
