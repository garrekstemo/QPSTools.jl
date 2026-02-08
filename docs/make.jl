using Documenter
using QPS

makedocs(
    sitename = "QPS.jl",
    modules = [QPS],
    remotes = nothing,
    checkdocs = :exports,
    warnonly = [:missing_docs],
    format = Documenter.HTML(prettyurls=false),
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "Raman Analysis" => "tutorials/raman.md",
            "FTIR Analysis" => "tutorials/ftir.md",
        ],
        "How-To Guides" => [
            "Tune Peak Detection Sensitivity" => "howto/peak_detection_sensitivity.md",
            "Fit Overlapping Peaks" => "howto/overlapping_peaks.md",
            "Choose a Peak Model" => "howto/choose_peak_model.md",
            "Fit with Baseline Correction" => "howto/fit_with_baseline.md",
            "Compare Fits Across Samples" => "howto/compare_fits.md",
            "Provide Manual Initial Guesses" => "howto/manual_initial_guesses.md",
        ],
        "Reference" => [
            "Peak Detection" => "reference/peak_detection.md",
            "Peak Fitting" => "reference/peak_fitting.md",
            "Baseline Correction" => "reference/baseline.md",
            "Preprocessing" => "reference/preprocessing.md",
        ],
        "Explanation" => [
            "Fitting Statistics" => "explanation/fitting_statistics.md",
            "Baseline Algorithms" => "explanation/baseline_algorithms.md",
            "eLabFTW Logging" => "explanation/elabftw_logging.md",
        ],
    ],
)
