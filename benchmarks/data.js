window.BENCHMARK_DATA = {
  "lastUpdate": 1749207467064,
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
          "id": "f5e7252bf806aad21df7451fb78021529b2717b6",
          "message": "Fix typo",
          "timestamp": "2024-08-24T11:40:19-05:00",
          "tree_id": "b7cdef18801ef3250ed75da9861a531744ac9f18",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/f5e7252bf806aad21df7451fb78021529b2717b6"
        },
        "date": 1724518482770,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 205566420,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 426872389,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15551920934,
            "unit": "ns",
            "extra": "gctime=83535316\nmemory=1012547456\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9546111469,
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
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "b54a471157ed38a13a3fbc9f2541ff65501a1a2d",
          "message": "Merge pull request #61 from EarthSciML/compathelper/new_version/2024-08-09-01-22-52-065-03995520334\n\nCompatHelper: bump compat for DiffEqCallbacks to 3, (keep existing compat)",
          "timestamp": "2024-08-30T09:58:13-05:00",
          "tree_id": "b837e46ce2a1de4c3200a9e89a9992c7b433d7a1",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b54a471157ed38a13a3fbc9f2541ff65501a1a2d"
        },
        "date": 1725030737841,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 210027059,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 430488656,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15340046330,
            "unit": "ns",
            "extra": "gctime=80821237\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9339562396,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "3f86559eb4628def7bbdf6f61a937e0a233b8c1b",
          "message": "Merge pull request #59 from EarthSciML/compathelper/new_version/2024-07-30-01-21-16-952-04096750012\n\nCompatHelper: bump compat for DataInterpolations to 6, (keep existing compat)",
          "timestamp": "2024-08-30T09:57:18-05:00",
          "tree_id": "8457e7d871b0f8e68ab426db80a829931662e74f",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/3f86559eb4628def7bbdf6f61a937e0a233b8c1b"
        },
        "date": 1725030751892,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 229748587,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 441338881,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15894917755,
            "unit": "ns",
            "extra": "gctime=93801502\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 10156009882,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "cef1e6a4c806ad7f9baa11b5a24de47d57ca3326",
          "message": "Merge pull request #64 from EarthSciML/compathelper/new_version/2024-08-12-01-24-01-165-01441916436\n\nCompatHelper: bump compat for Symbolics to 6, (keep existing compat)",
          "timestamp": "2024-08-30T10:00:16-05:00",
          "tree_id": "b837e46ce2a1de4c3200a9e89a9992c7b433d7a1",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/cef1e6a4c806ad7f9baa11b5a24de47d57ca3326"
        },
        "date": 1725030888235,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 224675085,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 427378039,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 17819690608,
            "unit": "ns",
            "extra": "gctime=86855163\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 10025783492,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "a770ef20ae9fea91161a07f7a54ee06f4059b6ab",
          "message": "Merge pull request #65 from EarthSciML/dependabot/github_actions/julia-actions/setup-julia-2\n\nBump julia-actions/setup-julia from 1 to 2",
          "timestamp": "2024-08-30T10:58:37-05:00",
          "tree_id": "539855cbf10a0c66c87e729bdf58017bfb5144e5",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/a770ef20ae9fea91161a07f7a54ee06f4059b6ab"
        },
        "date": 1725034369481,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 228348102,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 430578259,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 16044331341,
            "unit": "ns",
            "extra": "gctime=81421004\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 10091105317,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "ccb7b5ec7b8846b644b0c0a78a6b59b4b9b32d36",
          "message": "Merge pull request #66 from EarthSciML/dependabot/github_actions/cla-assistant/github-action-2.5.1\n\nBump cla-assistant/github-action from 2.4.0 to 2.5.1",
          "timestamp": "2024-08-30T10:58:51-05:00",
          "tree_id": "022516a91b267a92a182efd7ab835436e94bb659",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/ccb7b5ec7b8846b644b0c0a78a6b59b4b9b32d36"
        },
        "date": 1725034407441,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 227074195,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 436214957,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15873539085,
            "unit": "ns",
            "extra": "gctime=91090082\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 10116308725,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "b3bf49608dc1542ec9831715bb0c8d6d90ea85eb",
          "message": "Merge pull request #70 from EarthSciML/compathelper/new_version/2024-08-27-01-24-15-789-01555304735\n\nCompatHelper: bump compat for DynamicQuantities to 1, (keep existing compat)",
          "timestamp": "2024-08-30T10:59:13-05:00",
          "tree_id": "4237716a9ccfab6736bab98367d64522c4b38866",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b3bf49608dc1542ec9831715bb0c8d6d90ea85eb"
        },
        "date": 1725034430977,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 227669457,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47349760\nallocs=52304\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 445738177,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15926665709,
            "unit": "ns",
            "extra": "gctime=90653761\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 10163426288,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "b2f5ab79bff1ae34a91bf4c06044caa4928cc569",
          "message": "Merge pull request #71 from EarthSciML/compathelper/new_version/2024-08-27-01-24-49-592-00960336168\n\nCompatHelper: bump compat for DynamicQuantities to 1 for package docs, (keep existing compat)",
          "timestamp": "2024-08-30T10:59:27-05:00",
          "tree_id": "df49b7352c534944860b58f56a4dc9d0d12cf185",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b2f5ab79bff1ae34a91bf4c06044caa4928cc569"
        },
        "date": 1725034433287,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 211225328,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 433767572,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15404602201,
            "unit": "ns",
            "extra": "gctime=87561612\nmemory=1019196672\nallocs=21073140\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9418802098,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022882096\nallocs=21092288\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "cc6c7b502d4d2ece5596e2f1b11fc1b31e563643",
          "message": "Hotfix to deal with interpolation issue\n\nhere: https://github.com/SciML/DataInterpolations.jl/issues/331",
          "timestamp": "2024-08-31T13:01:44-05:00",
          "tree_id": "bc177fbc3b7ecf25f417d96510d780e102e232c4",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/cc6c7b502d4d2ece5596e2f1b11fc1b31e563643"
        },
        "date": 1725128162594,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 205709996,
            "unit": "ns",
            "extra": "gctime=0\nmemory=46394288\nallocs=52271\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 429378958,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15378081863,
            "unit": "ns",
            "extra": "gctime=87490242\nmemory=1019192648\nallocs=21073130\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9319188418,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022879016\nallocs=21092278\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "6ec7cd92a280e105057369d664613e44710c715e",
          "message": "Doc change",
          "timestamp": "2024-08-31T18:45:34-05:00",
          "tree_id": "03f27d4e329eb999af1479c2aea3e5eacb8b499a",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/6ec7cd92a280e105057369d664613e44710c715e"
        },
        "date": 1725148787773,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 206707989,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47371768\nallocs=52373\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 427187546,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47267496\nallocs=51344\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 15240090343,
            "unit": "ns",
            "extra": "gctime=91871823\nmemory=1019192648\nallocs=21073130\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 9393549024,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1022879016\nallocs=21092278\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "3a62dc6a35cf30dc48b183da8a25fde32777dcb7",
          "message": "Change from GridInterpolations.jl to Interpolations.jl",
          "timestamp": "2024-09-01T21:42:15-05:00",
          "tree_id": "87ffa28b746128af79b60363375d5274c6b503ee",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/3a62dc6a35cf30dc48b183da8a25fde32777dcb7"
        },
        "date": 1725245760170,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 134486966.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47307280\nallocs=52540\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 262954070,
            "unit": "ns",
            "extra": "gctime=0\nmemory=21171856\nallocs=34067\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11371378740,
            "unit": "ns",
            "extra": "gctime=98678218\nmemory=1015003912\nallocs=20533866\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6095125231,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1018690280\nallocs=20553014\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "45c94f3053b92c7c33f11d6a9c9d87edea1805d3",
          "message": "Fix test bugs",
          "timestamp": "2024-09-01T22:30:37-05:00",
          "tree_id": "9df01b6067c772ed42fb0724953ed1d6f3b7a8a1",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/45c94f3053b92c7c33f11d6a9c9d87edea1805d3"
        },
        "date": 1725248676760,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 134145601,
            "unit": "ns",
            "extra": "gctime=0\nmemory=47307280\nallocs=52540\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 267651848,
            "unit": "ns",
            "extra": "gctime=0\nmemory=21171856\nallocs=34067\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11461237017,
            "unit": "ns",
            "extra": "gctime=105960244\nmemory=1015003912\nallocs=20533866\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 5980577623,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1018690280\nallocs=20553014\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "0982a1f56a730362f0a9543c0c4a7bea737360f9",
          "message": "Fix time interpolation bug with scary, risky `deepcopy` hack.",
          "timestamp": "2024-09-02T22:43:27-05:00",
          "tree_id": "6ef7115ec80cfac341b71d35412dd9a869b1beb2",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/0982a1f56a730362f0a9543c0c4a7bea737360f9"
        },
        "date": 1725335871295,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 211274540,
            "unit": "ns",
            "extra": "gctime=0\nmemory=109042960\nallocs=65700\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 346101009,
            "unit": "ns",
            "extra": "gctime=0\nmemory=82907536\nallocs=47227\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11601209765,
            "unit": "ns",
            "extra": "gctime=130043628\nmemory=1022734464\nallocs=20534982\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6158370293,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1026420960\nallocs=20554130\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "0f5b5455cc6a24f8969fc8d5a825089e06140704",
          "message": "Add explanation",
          "timestamp": "2024-09-03T09:27:54-05:00",
          "tree_id": "0d313fa9b51c939193ee90c7b48d2f93efec82b4",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/0f5b5455cc6a24f8969fc8d5a825089e06140704"
        },
        "date": 1725374499316,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 211741276,
            "unit": "ns",
            "extra": "gctime=0\nmemory=109042960\nallocs=65700\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 344870593.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=82907536\nallocs=47227\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11732118179,
            "unit": "ns",
            "extra": "gctime=99802849\nmemory=1022734464\nallocs=20534982\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6056224046,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1026420960\nallocs=20554130\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "2b71ade0470d4a9abc77877eb7d11679e3dc2801",
          "message": "Handle larger caches",
          "timestamp": "2024-09-15T12:35:29-05:00",
          "tree_id": "36b450a98090c6b6c57cc84fa647013402c84650",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/2b71ade0470d4a9abc77877eb7d11679e3dc2801"
        },
        "date": 1726422459694,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 208999117,
            "unit": "ns",
            "extra": "gctime=0\nmemory=109042960\nallocs=65700\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 348352161,
            "unit": "ns",
            "extra": "gctime=0\nmemory=82907536\nallocs=47227\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11697976272,
            "unit": "ns",
            "extra": "gctime=101955800\nmemory=1024638296\nallocs=20555812\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6218447047,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1028324792\nallocs=20574960\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "ca4af5bfc8e75e1fb20139b2a831eb0da808e953",
          "message": "Add interpolation failure warning",
          "timestamp": "2024-09-15T14:37:12-05:00",
          "tree_id": "a735e6b642a7f4eb33d6c48791578ce01e85e747",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/ca4af5bfc8e75e1fb20139b2a831eb0da808e953"
        },
        "date": 1726429802230,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 209503667,
            "unit": "ns",
            "extra": "gctime=0\nmemory=109042960\nallocs=65700\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 346599274.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=82907536\nallocs=47227\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11774900072,
            "unit": "ns",
            "extra": "gctime=92081572\nmemory=1024638296\nallocs=20555812\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6374181780,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1028324792\nallocs=20574960\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "e9202e62cdeb600ebaddf3ff84b552afa7f1bf63",
          "message": "Remove hotfix",
          "timestamp": "2024-09-16T15:08:40-05:00",
          "tree_id": "f1ba577294043da38ce1f64c0411f4c31a2e4ead",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/e9202e62cdeb600ebaddf3ff84b552afa7f1bf63"
        },
        "date": 1726518125133,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 210695388,
            "unit": "ns",
            "extra": "gctime=0\nmemory=109042960\nallocs=65700\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 347811363,
            "unit": "ns",
            "extra": "gctime=0\nmemory=82907536\nallocs=47227\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11814840043,
            "unit": "ns",
            "extra": "gctime=96341164\nmemory=1024638296\nallocs=20555812\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6321128311,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1028324792\nallocs=20574960\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "49699333+dependabot[bot]@users.noreply.github.com",
            "name": "dependabot[bot]",
            "username": "dependabot[bot]"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "19e341237a1945594234e9345f00a8e8ed7dbc88",
          "message": "Bump cla-assistant/github-action from 2.5.1 to 2.6.0 (#75)\n\nBumps [cla-assistant/github-action](https://github.com/cla-assistant/github-action) from 2.5.1 to 2.6.0.\r\n- [Release notes](https://github.com/cla-assistant/github-action/releases)\r\n- [Commits](https://github.com/cla-assistant/github-action/compare/f41946747f85d28e9a738f4f38dbcc74b69c7e0e...b1522fa982419e79591a92e1267de463a281cdb7)\r\n\r\n---\r\nupdated-dependencies:\r\n- dependency-name: cla-assistant/github-action\r\n  dependency-type: direct:production\r\n  update-type: version-update:semver-minor\r\n...\r\n\r\nSigned-off-by: dependabot[bot] <support@github.com>\r\nCo-authored-by: dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>",
          "timestamp": "2024-09-23T09:47:49-05:00",
          "tree_id": "7a75b8887558cef6e9fed39a6690c68e100bbb0d",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/19e341237a1945594234e9345f00a8e8ed7dbc88"
        },
        "date": 1727103613914,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/Interpolation threaded",
            "value": 208079589,
            "unit": "ns",
            "extra": "gctime=0\nmemory=109042960\nallocs=65700\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/Interpolation serial",
            "value": 349282725.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=82907536\nallocs=47227\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11884516179,
            "unit": "ns",
            "extra": "gctime=88450875\nmemory=1024638296\nallocs=20555812\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 6216330181,
            "unit": "ns",
            "extra": "gctime=0\nmemory=1028324792\nallocs=20574960\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "5289878353c6f80693f670d921bc9e3f1a8639f9",
          "message": "Fix method conflict",
          "timestamp": "2024-10-28T15:29:57-05:00",
          "tree_id": "76deeadd76461e026356b8a1b933af01ca46e7b4",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/5289878353c6f80693f670d921bc9e3f1a8639f9"
        },
        "date": 1730148658081,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 493068984,
            "unit": "ns",
            "extra": "gctime=11202257.5\nmemory=109285656\nallocs=82943\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 452522716,
            "unit": "ns",
            "extra": "gctime=4324675\nmemory=83149448\nallocs=64323\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 190339853,
            "unit": "ns",
            "extra": "gctime=6475204\nmemory=59857232\nallocs=82000\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 385316429,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617008\nallocs=61932\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11606357755,
            "unit": "ns",
            "extra": "gctime=75531219\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11556755601,
            "unit": "ns",
            "extra": "gctime=51077560\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "b16ce47d5a98563573253e2a23891e1bb20776f9",
          "message": "Update compat",
          "timestamp": "2024-10-28T22:07:48-05:00",
          "tree_id": "0eaac72bc7946927209fb3c807fed2f7e367815d",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b16ce47d5a98563573253e2a23891e1bb20776f9"
        },
        "date": 1730172520190,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 467095504,
            "unit": "ns",
            "extra": "gctime=15034436\nmemory=109285656\nallocs=82943\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 473929939.5,
            "unit": "ns",
            "extra": "gctime=3059422\nmemory=83149448\nallocs=64323\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 189892167,
            "unit": "ns",
            "extra": "gctime=7346223\nmemory=59857232\nallocs=82000\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 383012925,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617008\nallocs=61932\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11872514041,
            "unit": "ns",
            "extra": "gctime=77614857\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11597931708,
            "unit": "ns",
            "extra": "gctime=42820615\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "d730cc925fa0eeca42576fcb9e4d4900a74bfaad",
          "message": "Change levelrange to levrange",
          "timestamp": "2024-10-29T08:22:04-05:00",
          "tree_id": "ad5783eb443c57611e011a43020e28bf41e5f8f8",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/d730cc925fa0eeca42576fcb9e4d4900a74bfaad"
        },
        "date": 1730209381998,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 462166713,
            "unit": "ns",
            "extra": "gctime=13209328\nmemory=109285656\nallocs=82943\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 448941833,
            "unit": "ns",
            "extra": "gctime=3292680\nmemory=83149448\nallocs=64323\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 189405756,
            "unit": "ns",
            "extra": "gctime=5933258\nmemory=59857232\nallocs=82000\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 381034583,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617008\nallocs=61932\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11692441281,
            "unit": "ns",
            "extra": "gctime=67386109\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11705764136,
            "unit": "ns",
            "extra": "gctime=44293270\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "bd1708f397f546b1b1bd8957b0a3ec8835475537",
          "message": "Update docs compat",
          "timestamp": "2024-10-29T09:59:51-05:00",
          "tree_id": "7a210ece74580a6e4c3f1c5573c557cf0815a863",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/bd1708f397f546b1b1bd8957b0a3ec8835475537"
        },
        "date": 1730215291532,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 478281110,
            "unit": "ns",
            "extra": "gctime=12283686.5\nmemory=109285656\nallocs=82943\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 459114505,
            "unit": "ns",
            "extra": "gctime=3464027\nmemory=83149448\nallocs=64323\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 189919945,
            "unit": "ns",
            "extra": "gctime=6737824\nmemory=59857232\nallocs=82000\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 387571766,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617008\nallocs=61932\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11745512171,
            "unit": "ns",
            "extra": "gctime=86119841\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11592902122,
            "unit": "ns",
            "extra": "gctime=49074471\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "7c6d0f69ccb08eda54c33e56b34620918c559275",
          "message": "Fix Pressure Bug",
          "timestamp": "2024-10-29T20:56:07-05:00",
          "tree_id": "bd32ff0b274f83795c5e6581fcb28a19a0cde725",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/7c6d0f69ccb08eda54c33e56b34620918c559275"
        },
        "date": 1730254702444,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 492408504.5,
            "unit": "ns",
            "extra": "gctime=12368509.5\nmemory=109285656\nallocs=82943\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 461626322.5,
            "unit": "ns",
            "extra": "gctime=3680286.5\nmemory=83149448\nallocs=64323\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 194195697,
            "unit": "ns",
            "extra": "gctime=8948435\nmemory=59857232\nallocs=82000\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 392624733.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617008\nallocs=61932\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11850652341,
            "unit": "ns",
            "extra": "gctime=80439669\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11708271897,
            "unit": "ns",
            "extra": "gctime=52601792\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "39a37c78bf879265444b1f68ef73ffa862fc08e1",
          "message": "Speed up data reindexing",
          "timestamp": "2024-10-30T21:37:02-05:00",
          "tree_id": "9956aa08e1c0ad60e251b126f3508339e292718c",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/39a37c78bf879265444b1f68ef73ffa862fc08e1"
        },
        "date": 1730343474695,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 436606365,
            "unit": "ns",
            "extra": "gctime=0\nmemory=48239224\nallocs=83030\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 432773946,
            "unit": "ns",
            "extra": "gctime=0\nmemory=22103016\nallocs=64410\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 190055630,
            "unit": "ns",
            "extra": "gctime=9058660\nmemory=59857952\nallocs=82029\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 379144366,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617728\nallocs=61961\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11662257654,
            "unit": "ns",
            "extra": "gctime=43299815\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11632211262,
            "unit": "ns",
            "extra": "gctime=44713574\nmemory=643466576\nallocs=18920778\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "3c4b717fd466848c5bef7b09f4753515ececed83",
          "message": "Change stream_data to stream, because it's obviously data",
          "timestamp": "2024-11-01T15:39:54-05:00",
          "tree_id": "1b53c68f1f779d53d8271ee4dc4cf3d3ad0051ff",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/3c4b717fd466848c5bef7b09f4753515ececed83"
        },
        "date": 1730494845109,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 433626465,
            "unit": "ns",
            "extra": "gctime=0\nmemory=48239224\nallocs=83030\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 416207216.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=22103016\nallocs=64410\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 191434014,
            "unit": "ns",
            "extra": "gctime=10410998\nmemory=59857952\nallocs=82029\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 383138655,
            "unit": "ns",
            "extra": "gctime=0\nmemory=33617728\nallocs=61961\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11810696755,
            "unit": "ns",
            "extra": "gctime=58275448\nmemory=744326480\nallocs=22072650\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11807120616,
            "unit": "ns",
            "extra": "gctime=61443992\nmemory=744326480\nallocs=22072650\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "862fa7b60e201091e98326d97f9efb96e538fb7b",
          "message": "Comment out profview",
          "timestamp": "2024-11-02T17:41:03-05:00",
          "tree_id": "eecba7630fdf19f10b18074caa18cc70985a3c73",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/862fa7b60e201091e98326d97f9efb96e538fb7b"
        },
        "date": 1730588480219,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 576200436.5,
            "unit": "ns",
            "extra": "gctime=53703137.5\nmemory=230156984\nallocs=8721038\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 499687104.5,
            "unit": "ns",
            "extra": "gctime=42911701.5\nmemory=208987480\nallocs=9011480\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 127078251,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 326223422,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11803699405,
            "unit": "ns",
            "extra": "gctime=62724735\nmemory=744326480\nallocs=22072650\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11805314939,
            "unit": "ns",
            "extra": "gctime=51662657\nmemory=744326480\nallocs=22072650\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "6d376900889458a107e356657faaebf2373c1d87",
          "message": "Fix docs",
          "timestamp": "2024-11-21T09:31:41-06:00",
          "tree_id": "ae846fa74aee85b208278fbca1dabe9ad57f8ab6",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/6d376900889458a107e356657faaebf2373c1d87"
        },
        "date": 1732204064134,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 569601532.5,
            "unit": "ns",
            "extra": "gctime=54645677.5\nmemory=232638760\nallocs=8788958\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 513149858,
            "unit": "ns",
            "extra": "gctime=48523099\nmemory=210418216\nallocs=9013710\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 125409052,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 328920496,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11303717903,
            "unit": "ns",
            "extra": "gctime=79747154\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11294291386,
            "unit": "ns",
            "extra": "gctime=86360288\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "df30c90d14f91ab26ca15675bee865144e8e4ce9",
          "message": "GEOS-FP: add coordinate transforms",
          "timestamp": "2024-11-22T00:06:01-06:00",
          "tree_id": "b8871f13f4e891029598c5e15ec11af5990aeb12",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/df30c90d14f91ab26ca15675bee865144e8e4ce9"
        },
        "date": 1732256517032,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 485273657,
            "unit": "ns",
            "extra": "gctime=23452939\nmemory=232858616\nallocs=8801342\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 480605119.5,
            "unit": "ns",
            "extra": "gctime=17127475.5\nmemory=209620792\nallocs=8963871\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 124977587,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 347721854,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11248674242,
            "unit": "ns",
            "extra": "gctime=75803707\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11257509557,
            "unit": "ns",
            "extra": "gctime=84418671\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "4252ad64dee80dd57c05880c9e28d336c1b81399",
          "message": "latexify interpolation",
          "timestamp": "2024-11-22T08:50:46-06:00",
          "tree_id": "4ed15ed4941f5fd530d0863d9bb5121d5462a0fe",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/4252ad64dee80dd57c05880c9e28d336c1b81399"
        },
        "date": 1732287991943,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 558472871,
            "unit": "ns",
            "extra": "gctime=52498080\nmemory=232076200\nallocs=8753277\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 513093927,
            "unit": "ns",
            "extra": "gctime=52567626\nmemory=209770376\nallocs=8973220\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 124958094,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 332770426,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11528971864,
            "unit": "ns",
            "extra": "gctime=78415565\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11599928362,
            "unit": "ns",
            "extra": "gctime=83894103\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "dfb461e8685ab18232c06e3395b69a08a35b6ed8",
          "message": "Add mutex for nc output",
          "timestamp": "2024-12-06T13:55:46-06:00",
          "tree_id": "3bbed165dd6996bdac3471d8388b69086b484688",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/dfb461e8685ab18232c06e3395b69a08a35b6ed8"
        },
        "date": 1733515868784,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 519051638,
            "unit": "ns",
            "extra": "gctime=20512851\nmemory=232671624\nallocs=8801332\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 481704465.5,
            "unit": "ns",
            "extra": "gctime=18042531\nmemory=210188728\nallocs=9009687\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 124064776,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 333051802.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11385342509,
            "unit": "ns",
            "extra": "gctime=74903615\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11334680209,
            "unit": "ns",
            "extra": "gctime=84471387\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "a369877973a9a5a4830bb40f6a605815b4531f5c",
          "message": "Make interp_unsafe more type-flexible",
          "timestamp": "2025-01-27T08:20:02-06:00",
          "tree_id": "2bc2375ae9ed88d4fbe74c0530c0299f42112830",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/a369877973a9a5a4830bb40f6a605815b4531f5c"
        },
        "date": 1737988558446,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 536426725.5,
            "unit": "ns",
            "extra": "gctime=53517192\nmemory=231816024\nallocs=8747873\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 545575191,
            "unit": "ns",
            "extra": "gctime=46732029.5\nmemory=211417048\nallocs=9086473\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 125875114,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 353735012,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11572144094,
            "unit": "ns",
            "extra": "gctime=155290453\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11495933448,
            "unit": "ns",
            "extra": "gctime=144858755\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "7f268962003f9039ada22b2b8af097cddc45e78a",
          "message": "Make type more flexible",
          "timestamp": "2025-01-28T19:49:15-06:00",
          "tree_id": "11abf39de8c2261e545e4ca80f17f3d18295740a",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/7f268962003f9039ada22b2b8af097cddc45e78a"
        },
        "date": 1738116460506,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 553115463,
            "unit": "ns",
            "extra": "gctime=58680068.5\nmemory=232274680\nallocs=8775195\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 514104609,
            "unit": "ns",
            "extra": "gctime=49235376.5\nmemory=211149064\nallocs=9069724\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 125841443,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 334026693,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11560797015,
            "unit": "ns",
            "extra": "gctime=138467365\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11547867653,
            "unit": "ns",
            "extra": "gctime=129267249\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "1e05c8e603879be3d8749b4c43b7424a94ba29b9",
          "message": "Fix type",
          "timestamp": "2025-01-28T20:14:40-06:00",
          "tree_id": "9abd873ded4b97223d08d0a082ef7ac9be3706fe",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/1e05c8e603879be3d8749b4c43b7424a94ba29b9"
        },
        "date": 1738117819895,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 541654897.5,
            "unit": "ns",
            "extra": "gctime=50715304\nmemory=232364840\nallocs=8782174\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 511000014,
            "unit": "ns",
            "extra": "gctime=45239697.5\nmemory=210955112\nallocs=9057615\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 126536393,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 329935277.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11510307121,
            "unit": "ns",
            "extra": "gctime=156660787\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11352199295,
            "unit": "ns",
            "extra": "gctime=123001378\nmemory=1223411024\nallocs=36256074\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "bc03c9afeb536254ab5cab1aebc509877c3533ad",
          "message": "Update to EarthSciMLBase v0.21",
          "timestamp": "2025-02-23T20:51:06-06:00",
          "tree_id": "9de32ecb86dc2e2f25bde0552997f0dc9bb8cc4b",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/bc03c9afeb536254ab5cab1aebc509877c3533ad"
        },
        "date": 1740405941673,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 566855444,
            "unit": "ns",
            "extra": "gctime=58060802\nmemory=231474584\nallocs=8726590\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 527089900,
            "unit": "ns",
            "extra": "gctime=53808806\nmemory=210912584\nallocs=9055001\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 126837186,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 332733828,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11735964144,
            "unit": "ns",
            "extra": "gctime=117971270\nmemory=1223427168\nallocs=36256113\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11682640259,
            "unit": "ns",
            "extra": "gctime=140546710\nmemory=1223427168\nallocs=36256113\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "20a2a22eb29b290b9890c8e10e100d07c08e4cd5",
          "message": "Update doc compat",
          "timestamp": "2025-02-24T08:25:57-06:00",
          "tree_id": "2e6ba88dbd42f26310c9504301fa922556c39766",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/20a2a22eb29b290b9890c8e10e100d07c08e4cd5"
        },
        "date": 1740408133139,
        "tool": "julia",
        "benches": [
          {
            "name": "GEOSFP/stream/Interpolation threaded",
            "value": 554653942.5,
            "unit": "ns",
            "extra": "gctime=56892476\nmemory=232369688\nallocs=8782534\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/stream/Interpolation serial",
            "value": 504960119,
            "unit": "ns",
            "extra": "gctime=43059727\nmemory=210214472\nallocs=9012726\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation threaded",
            "value": 127037637,
            "unit": "ns",
            "extra": "gctime=0\nmemory=26136656\nallocs=18621\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "GEOSFP/nostream/Interpolation serial",
            "value": 330967933.5,
            "unit": "ns",
            "extra": "gctime=0\nmemory=448\nallocs=1\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Serial",
            "value": 11602393218,
            "unit": "ns",
            "extra": "gctime=137270281\nmemory=1223427168\nallocs=36256113\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 11586968938,
            "unit": "ns",
            "extra": "gctime=149794310\nmemory=1223427168\nallocs=36256113\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "88a3f8784efdcf3551da253505cbd06464f52c3e",
          "message": "Clean up dependencies; fix benchmarks",
          "timestamp": "2025-05-28T09:15:45+08:00",
          "tree_id": "e997352f114e5110e052330e94e06ebd92846267",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/88a3f8784efdcf3551da253505cbd06464f52c3e"
        },
        "date": 1748396928210,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 170052290504,
            "unit": "ns",
            "extra": "gctime=29654301860\nmemory=198656695544\nallocs=1134683489\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 168602296823,
            "unit": "ns",
            "extra": "gctime=29368269639\nmemory=198656695544\nallocs=1134683489\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "9399f3044864af5491d4f073add5fb535536ae7c",
          "message": "Update dependencies",
          "timestamp": "2025-05-28T09:40:49+08:00",
          "tree_id": "953b3337fec11be5ba3c3d8a8a58f0f7a97a2504",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/9399f3044864af5491d4f073add5fb535536ae7c"
        },
        "date": 1748398406115,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 168287949763,
            "unit": "ns",
            "extra": "gctime=29228451422\nmemory=202262437112\nallocs=1218996065\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 168544289007,
            "unit": "ns",
            "extra": "gctime=29335936672\nmemory=202262437112\nallocs=1218996065\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "4f2a71f00440430a4c2812eb6e93f25b29ec224b",
          "message": "Update downgrade test",
          "timestamp": "2025-05-28T10:20:28+08:00",
          "tree_id": "b1f0137f513a8b35d7bfadad0760d147871e8cfb",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/4f2a71f00440430a4c2812eb6e93f25b29ec224b"
        },
        "date": 1748400822654,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 172781617819,
            "unit": "ns",
            "extra": "gctime=31010662551\nmemory=197446376696\nallocs=1229239649\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 171828220938,
            "unit": "ns",
            "extra": "gctime=30994361055\nmemory=197446376696\nallocs=1229239649\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "compathelper_noreply@julialang.org",
            "name": "CompatHelper Julia"
          },
          "committer": {
            "email": "ctessum@gmail.com",
            "name": "Christopher Tessum",
            "username": "ctessum"
          },
          "distinct": true,
          "id": "2d543a9800ca44d1b2efa3813855b858de9f680c",
          "message": "CompatHelper: add new compat entry for EarthSciData at version 0.12 for package docs, (keep existing compat)",
          "timestamp": "2025-05-28T10:27:58+08:00",
          "tree_id": "7e3a5f17c0272401cca721d568d54319013b09bb",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/2d543a9800ca44d1b2efa3813855b858de9f680c"
        },
        "date": 1748401134962,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 159115608177,
            "unit": "ns",
            "extra": "gctime=25477891747\nmemory=199034920184\nallocs=1134683489\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 158429592547,
            "unit": "ns",
            "extra": "gctime=25340310188\nmemory=199034920184\nallocs=1134683489\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "aeca5ec7904e3a8b2a2ec46e72eb6b8a057a82bc",
          "message": "Merge pull request #107 from EarthSciML/compat\n\nCompat",
          "timestamp": "2025-05-28T10:43:03+08:00",
          "tree_id": "00c2f9aa08da6d6764be66dcb3d936ccbb0f972b",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/aeca5ec7904e3a8b2a2ec46e72eb6b8a057a82bc"
        },
        "date": 1748402184671,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 174975340586,
            "unit": "ns",
            "extra": "gctime=31628821457\nmemory=199034920184\nallocs=1134683489\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 176042600026,
            "unit": "ns",
            "extra": "gctime=31687965913\nmemory=199034920184\nallocs=1134683489\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "352831268283a98ec34affb3d1bbcefe725e5bba",
          "message": "Remove methodoflines from docs",
          "timestamp": "2025-05-28T11:03:53+08:00",
          "tree_id": "662e772a444b06b92fa7d811b61dbd21363167ef",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/352831268283a98ec34affb3d1bbcefe725e5bba"
        },
        "date": 1748403690169,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 171044298865,
            "unit": "ns",
            "extra": "gctime=27141793216\nmemory=202262437112\nallocs=1218996065\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 171537878138,
            "unit": "ns",
            "extra": "gctime=27585134696\nmemory=202262437112\nallocs=1218996065\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "d12090dd2574955097b0ed5393e9c2ce52b53050",
          "message": "Add _typos.toml",
          "timestamp": "2025-05-28T11:33:38+08:00",
          "tree_id": "54dae5508ac4b4d0da0b537d150d0a8311fe778f",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/d12090dd2574955097b0ed5393e9c2ce52b53050"
        },
        "date": 1748405247753,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 179558287604,
            "unit": "ns",
            "extra": "gctime=30213203159\nmemory=200371313912\nallocs=1229239649\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 179267644056,
            "unit": "ns",
            "extra": "gctime=30332449379\nmemory=200371313912\nallocs=1229239649\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "b9886c3da270130112a66e99d98250b054c8d2c8",
          "message": "Fix ModelingToolkit at 9.79.1",
          "timestamp": "2025-05-28T12:24:02+08:00",
          "tree_id": "fa4e30314e0ae7329bb86b7abc89033ed6e7d6b0",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b9886c3da270130112a66e99d98250b054c8d2c8"
        },
        "date": 1748407336305,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 63510390031,
            "unit": "ns",
            "extra": "gctime=5618571265\nmemory=49787477240\nallocs=1629527393\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 63180802804,
            "unit": "ns",
            "extra": "gctime=5608762607\nmemory=49787477240\nallocs=1629527393\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "df68fb94729ec6a1695a3aaa90326836fa82826d",
          "message": "Update dependency",
          "timestamp": "2025-05-28T12:31:05+08:00",
          "tree_id": "8a99965c9b010fe6cb706be9222236b3bea03a03",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/df68fb94729ec6a1695a3aaa90326836fa82826d"
        },
        "date": 1748407738904,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 62279081836,
            "unit": "ns",
            "extra": "gctime=5237777836\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 62229199268,
            "unit": "ns",
            "extra": "gctime=5225417039\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "e163bdac7982a28f6281caa3ac34a2e359f9f115",
          "message": "Update scimlbase compat",
          "timestamp": "2025-05-28T12:47:24+08:00",
          "tree_id": "cfab98e90be9db7af17992938816d949b592c130",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/e163bdac7982a28f6281caa3ac34a2e359f9f115"
        },
        "date": 1748408740764,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 62611207132,
            "unit": "ns",
            "extra": "gctime=5087098167\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 62498711761,
            "unit": "ns",
            "extra": "gctime=5064750775\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "0a2b3d3a90f67ca05494c2cf42b59d2755103a43",
          "message": "Bump version number",
          "timestamp": "2025-05-28T13:14:44+08:00",
          "tree_id": "70455ad5ba71566d03bafe8013de6be0ba6a649d",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/0a2b3d3a90f67ca05494c2cf42b59d2755103a43"
        },
        "date": 1748410329065,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 60624518351,
            "unit": "ns",
            "extra": "gctime=4602424358\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 60695940162,
            "unit": "ns",
            "extra": "gctime=4653629382\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "d57b07877def9b89380f0a45b88fa59e35e70472",
          "message": "Fix system event bug",
          "timestamp": "2025-05-29T17:38:17+08:00",
          "tree_id": "198359406666d2a4d6a257453b566ea7b71b0cd5",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/d57b07877def9b89380f0a45b88fa59e35e70472"
        },
        "date": 1748512585440,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 65614161366,
            "unit": "ns",
            "extra": "gctime=4274760542\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 65635079569,
            "unit": "ns",
            "extra": "gctime=4264199295\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "9636c527d33ff7c1256d209042b07568b0f7772b",
          "message": "Format and Bump version number",
          "timestamp": "2025-05-29T18:31:01+08:00",
          "tree_id": "b50f7dd56adadb30ed5b9f372f4810e17a036428",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/9636c527d33ff7c1256d209042b07568b0f7772b"
        },
        "date": 1748515750486,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 61348523188,
            "unit": "ns",
            "extra": "gctime=4547423013\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 61394527499,
            "unit": "ns",
            "extra": "gctime=4591590771\nmemory=49737047288\nallocs=1626375521\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "b20610cfa93b440a144dc01d739aa64bed404643",
          "message": "Update version numbers",
          "timestamp": "2025-06-06T17:07:46+08:00",
          "tree_id": "ee83a8b0a23dc4066c4612d5e27c739de158f8be",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/b20610cfa93b440a144dc01d739aa64bed404643"
        },
        "date": 1749202057543,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 75046018977,
            "unit": "ns",
            "extra": "gctime=6736512136\nmemory=49963982072\nallocs=1637407073\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 75107034202,
            "unit": "ns",
            "extra": "gctime=6773289950\nmemory=49963982072\nallocs=1637407073\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "53cba53a348f0dfbd54112e6434b33d17d284b1e",
          "message": "Update docs compat",
          "timestamp": "2025-06-06T17:42:06+08:00",
          "tree_id": "101e95a5b28234e3f2dd73b0a450d7cf19171272",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/53cba53a348f0dfbd54112e6434b33d17d284b1e"
        },
        "date": 1749203997165,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 63758870087,
            "unit": "ns",
            "extra": "gctime=5901714666\nmemory=49913552120\nallocs=1634255201\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 63608384360,
            "unit": "ns",
            "extra": "gctime=5849455424\nmemory=49913552120\nallocs=1634255201\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "32e89c918506f2cbe2b69552d86ecc7b846a0299",
          "message": "Update dtype in documentation",
          "timestamp": "2025-06-06T18:34:45+08:00",
          "tree_id": "04b49208d40d0ba9baccf6e5bb1c5ccc60bd65d3",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/32e89c918506f2cbe2b69552d86ecc7b846a0299"
        },
        "date": 1749207181552,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 60401381046,
            "unit": "ns",
            "extra": "gctime=4585873534\nmemory=49913552120\nallocs=1634255201\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 60829087595,
            "unit": "ns",
            "extra": "gctime=4661249217\nmemory=49913552120\nallocs=1634255201\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
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
          "id": "8aeb0b0ad9ecee1427530ad4b886a84dfabff5fc",
          "message": "Ignore docs for benchmark",
          "timestamp": "2025-06-06T18:39:33+08:00",
          "tree_id": "fb4dc74a411778a10fa7f6743bacfe50866548e5",
          "url": "https://github.com/EarthSciML/EarthSciData.jl/commit/8aeb0b0ad9ecee1427530ad4b886a84dfabff5fc"
        },
        "date": 1749207466451,
        "tool": "julia",
        "benches": [
          {
            "name": "NEI Simulator/Serial",
            "value": 65620548655,
            "unit": "ns",
            "extra": "gctime=5507185243\nmemory=49963982072\nallocs=1637407073\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          },
          {
            "name": "NEI Simulator/Threads",
            "value": 65759418180,
            "unit": "ns",
            "extra": "gctime=5610944877\nmemory=49963982072\nallocs=1637407073\nparams={\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":false,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5,\"overhead\":0,\"memory_tolerance\":0.01}"
          }
        ]
      }
    ]
  }
}