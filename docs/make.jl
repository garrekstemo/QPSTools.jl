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
            "Loading FTIR Spectra" => "tutorials/loading_ftir.md",
        ],
        "How-To Guides" => [
            "Log a Spectrum to eLabFTW" => "howto/log_to_elabftw.md",
        ],
        "Reference" => [
            "File Loaders" => "reference/io.md",
            "Plotting" => "reference/plotting.md",
            "Cavity Spectroscopy" => "reference/cavity.md",
            "PL / Raman Mapping" => "reference/plmap.md",
            "eLabFTW Integration" => "reference/elabftw.md",
        ],
        "Explanation" => [
            "Ecosystem Architecture" => "explanation/ecosystem_architecture.md",
        ],
    ],
)

deploydocs(
    repo = "github.com/garrekstemo/QPSTools.jl.git",
    push_preview = true,
)
