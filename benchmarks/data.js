window.BENCHMARK_DATA = {
  "lastUpdate": 1723895578322,
  "repoUrl": "https://github.com/EarthSciML/EarthSciData.jl",
  "entries": {
    "Julia benchmark result": [
      {
        "commit": {
          "author": {
            "email": "ctessum@gmail.com",
            "name": "Christopher Tessum",
            "username": "ctessum"
          },
          "committer": {
            "email": "ctessum@gmail.com",
            "name": "Christopher Tessum",
            "username": "ctessum"
          },
          "distinct": true,
          "id": "a8f1d84afa6a1f217c7d3e9575f50d2112a58994",
          "message": "Add benchmarks",
          "timestamp": "2024-08-17T20:41:48+09:00",
          "tree_id": "325a2164e197ab4839075612dfc31b35c30de0c1",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/a8f1d84afa6a1f217c7d3e9575f50d2112a58994"
        },
        "date": 1723895577877,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 553996181,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47228408\nallocs=54633\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 504900646,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47124136\nallocs=53604\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      }
    ]
  }
}