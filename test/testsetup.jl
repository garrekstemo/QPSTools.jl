using Test
using QPSTools
using OpticalSpectroscopy
using JASCOFiles
using ElabFTW
using QPSScanFormat

import OpticalSpectroscopy: format_results, n_exp, weights
# Disambiguate: both OpticalSpectroscopy and JASCOFiles export xlabel/ylabel.
# Tests in this suite operate on OpticalSpectroscopy types (TATrace, TASpectrum,
# TAMatrix), so resolve the bare names to OpticalSpectroscopy's methods.
import OpticalSpectroscopy: xlabel, ylabel

const PROJECT_ROOT = dirname(@__DIR__)

include("fixtures/plmap.jl")
const PLMAP_FIXTURE = make_plmap_fixture(joinpath(mktempdir(), "plmap_fixture.lvm"))
