using EarthSciData
using Documenter

DocMeta.setdocmeta!(EarthSciData, :DocTestSetup, :(using EarthSciData); recursive = true)

makedocs(;
    modules = [EarthSciData],
    authors = "EarthSciML Authors",
    repo = "https://github.com/EarthSciML/EarthSciData.jl/blob/{commit}{path}#{line}",
    sitename = "EarthSciData.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://earthsciml.github.io/EarthSciData.jl",
        assets = String[],
        repolink = "https://github.com/EarthSciML/EarthSciData.jl"
    ),
    pages = [
        "Home" => "index.md",
        "GEOS-FP" => "geosfp.md",
        "2016 NEI" => "nei2016.md",
        "OpenAQ" => "openaq.md",
        "CEDS" => "ceds.md",
        "ERA5" => "era5.md",
        "EDGAR v8.1" => "edgar_v81.md",
        "USGS 3DEP" => "usgs3dep.md",
        "API" => "api.md",
        "🔗 Benchmarks" => "benchmarks.md"
    ]
)

deploydocs(; repo = "github.com/EarthSciML/EarthSciData.jl", devbranch = "main")
