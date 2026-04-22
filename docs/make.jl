using Documenter
using QPSTools

makedocs(
    sitename = "QPSTools.jl",
    modules = [QPSTools],
    checkdocs = :exports,
    warnonly = [:missing_docs, :cross_references],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "Lab Workflow" => "tutorials/lab_workflow.md",
            "Spectrum Plotting Views" => "tutorials/plot_spectrum_views.md",
        ],
        "Reference" => [
            "Loaders" => "reference/loaders.md",
            "Plotting" => "reference/plotting.md",
            "eLabFTW Integration" => "reference/elabftw_integration.md",
        ],
    ],
)

deploydocs(
    repo = "github.com/garrekstemo/QPSTools.jl.git",
    push_preview = true,
)
