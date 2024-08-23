window.BENCHMARK_DATA = {
  "lastUpdate": 1724441473667,
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
      },
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
          "id": "42325971e05f49191dcc99421a7c1a09b576dae2",
          "message": "Fix test and typo",
          "timestamp": "2024-08-17T20:53:34+09:00",
          "tree_id": "dd7ade94c6ea592d967d8bad61de94986fa8dece",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/42325971e05f49191dcc99421a7c1a09b576dae2"
        },
        "date": 1723896310575,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 554053583,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47228408\nallocs=54633\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 505999961,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47124136\nallocs=53604\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
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
          "id": "f5fb95ba171bb6779b774f1f01ca2999eb3fd728",
          "message": "Add env variable",
          "timestamp": "2024-08-22T10:54:53+09:00",
          "tree_id": "4bd4c983a2bb955aeef72adaad5815974494f0d8",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/f5fb95ba171bb6779b774f1f01ca2999eb3fd728"
        },
        "date": 1724292532639,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 515655850,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 509854052,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 16382500912,
            "unit": "ns",
            "extra": "gctime=95430386\nmemory=1012462008\nallocs=21071901\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11516269468,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1016147432\nallocs=21091049\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ctessum@gmail.com",
            "name": "Christopher Tessum",
            "username": "ctessum"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "88ec7c0bb4b23108a695da5612172846cf2ac9a0",
          "message": "CI: remove Julia 1.9",
          "timestamp": "2024-08-22T11:41:41+09:00",
          "tree_id": "31d859895451ccc721fbe3b27ff89ee937bcc6ac",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/88ec7c0bb4b23108a695da5612172846cf2ac9a0"
        },
        "date": 1724295321011,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 481719560,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 507753519,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 16373671808,
            "unit": "ns",
            "extra": "gctime=81135380\nmemory=1012462008\nallocs=21071901\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11587828724,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1016147432\nallocs=21091049\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
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
          "id": "b8a26e2f4e297ef4208f2af169cc15ef0d96dd48",
          "message": "Merge branch 'main' of github.com:EarthSciML/EarthSciData.jl",
          "timestamp": "2024-08-22T15:29:11+09:00",
          "tree_id": "354a9b5c4664a936d38b3b344630002166edd7f3",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b8a26e2f4e297ef4208f2af169cc15ef0d96dd48"
        },
        "date": 1724308970645,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 188958504,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 406404583,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15042379778,
            "unit": "ns",
            "extra": "gctime=94179212\nmemory=1012547456\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9213373693,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1016232880\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
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
          "id": "77d9ba6afc6af892e282cfdbfeef64ac7673bc25",
          "message": "Change from degrees to radians everywhere",
          "timestamp": "2024-08-23T10:20:17+09:00",
          "tree_id": "385abfb6bb6644cc2c56825c0424515b4bb8f756",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/77d9ba6afc6af892e282cfdbfeef64ac7673bc25"
        },
        "date": 1724376934917,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 199658684.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 424258770,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 31815859808,
            "unit": "ns",
            "extra": "gctime=993368789\nmemory=6828589216\nallocs=275524972\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 19023005834,
            "unit": "ns",
            "extra": "gctime=1129871883\nmemory=6832276560\nallocs=275544204\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
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
          "id": "307526a4f2f12ded6a368698dbdd73f4254259aa",
          "message": "Fix performance regression",
          "timestamp": "2024-08-23T14:09:10+09:00",
          "tree_id": "9ab6ebce0bde89c1d46b6da7c9111c58d913bd98",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/307526a4f2f12ded6a368698dbdd73f4254259aa"
        },
        "date": 1724441473220,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 205906716,
            "unit": "ns",
            "extra": "gctime=0\nmemory=46351864\nallocs=51412\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 428185890,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15380779496,
            "unit": "ns",
            "extra": "gctime=79161632\nmemory=1012547456\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9507499929,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1016232880\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      }
    ]
  }
}