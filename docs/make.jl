using EarthSciMLData
using Documenter

DocMeta.setdocmeta!(EarthSciMLData, :DocTestSetup, :(using EarthSciMLData); recursive=true)

makedocs(;
    modules=[EarthSciMLData],
    authors="EarthSciML Authors",
    repo="https://github.com/EarthSciML/EarthSciMLData.jl/blob/{commit}{path}#{line}",
    sitename="EarthSciMLData.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://earthsciml.github.io/EarthSciMLData.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "GEOS-FP" => "geosfp.md",
    ],
)

deploydocs(;
    repo="github.com/EarthSciML/EarthSciMLData.jl",
    devbranch="main",
)
