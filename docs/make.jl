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
        repolink = "https://github.com/EarthSciML/EarthSciData.jl",
        # The NEI and GEOS-FP pages have large equation tables; raise the
        # thresholds so Documenter's inline-HTML size checks pass.
        size_threshold = 300 * 2^10,
        size_threshold_warn = 200 * 2^10
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
        "LANDFIRE" => "landfire.md",
        "API" => "api.md",
        "🔗 Benchmarks" => "benchmarks.md"
    ]
)

deploydocs(; repo = "github.com/EarthSciML/EarthSciData.jl", devbranch = "main")
