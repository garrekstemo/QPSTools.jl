using Test
using QPSTools
using OpticalSpectroscopy
using JASCOFiles
using HamamatsuStreakFiles
using ElabFTW
# Qualified access only (QPSScanFormat.save_*_scan in fixtures). NOT
# blanket-`using`: both QPSTools and QPSScanFormat export a `load_scan`
# (QPSTools' is the typed wrapper) and the bindings would clash.
import QPSScanFormat

import OpticalSpectroscopy: format_results, n_exp, weights
# Disambiguate: both OpticalSpectroscopy and JASCOFiles export xlabel/ylabel.
# Tests in this suite operate on OpticalSpectroscopy types (KineticTrace, Spectrum,
# TimeResolvedMatrix), so resolve the bare names to OpticalSpectroscopy's methods.
import OpticalSpectroscopy: xlabel, ylabel

const PROJECT_ROOT = dirname(@__DIR__)

include("fixtures/plmap.jl")
const PLMAP_FIXTURE = make_plmap_fixture(joinpath(mktempdir(), "plmap_fixture.lvm"))

include("fixtures/streak.jl")
const STREAK_FIXTURE = make_streak_fixture(joinpath(mktempdir(), "streak_fixture.img"))
