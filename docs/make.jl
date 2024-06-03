using EarthSciData
using Documenter

DocMeta.setdocmeta!(EarthSciData, :DocTestSetup, :(using EarthSciData); recursive=true)

makedocs(;
    modules=[EarthSciData],
    authors="EarthSciML Authors",
    repo="https://github.com/EarthSciML/EarthSciData.jl/blob/{commit}{path}#{line}",
    sitename="EarthSciData.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://earthsciml.github.io/EarthSciData.jl",
        assets=String[],
        repolink="https://github.com/EarthSciML/EarthSciData.jl"
    ),
    pages=[
        "Home" => "index.md",
        "GEOS-FP" => "geosfp.md",
    ],
)

deploydocs(;
    repo="github.com/EarthSciML/EarthSciData.jl",
    devbranch="main",
)
