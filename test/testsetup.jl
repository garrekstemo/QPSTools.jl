using Test
using QPSTools
using SpectroscopyTools
using JASCOFiles
using ElabFTW

import SpectroscopyTools: format_results, n_exp, weights

const PROJECT_ROOT = dirname(@__DIR__)

include("fixtures/plmap.jl")
const PLMAP_FIXTURE = make_plmap_fixture(joinpath(mktempdir(), "plmap_fixture.lvm"))
