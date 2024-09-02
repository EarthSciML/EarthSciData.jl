window.BENCHMARK_DATA = {
  "lastUpdate": 1725245760569,
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
      }
    ]
  }
}