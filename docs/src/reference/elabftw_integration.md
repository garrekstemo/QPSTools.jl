# eLabFTW Integration

QPSTools ties lab spectrum types into [ElabFTW.jl](https://garrekstemo.github.io/ElabFTW.jl/stable/) so `log_to_elab` and `tags_from_sample` accept any `AnnotatedSpectrum` (for example, `FTIRSpectrum`, `RamanSpectrum`, `UVVisSpectrum`, `CavitySpectrum`) and auto-extract sample metadata into the eLabFTW entry. Authentication setup, cache configuration, and the full `log_to_elab` keyword form live in the ElabFTW.jl docs — this page covers only the QPSTools dispatches.

## Where to find related content

| Topic | Location |
|-------|----------|
| Auth setup (`ELABFTW_HOST`, API token), base `log_to_elab(; title, body, ...)` keyword form | [ElabFTW.jl home](https://garrekstemo.github.io/ElabFTW.jl/stable/) |
| Idempotent experiment creation and update flows | [ElabFTW.jl how-to: Idempotent Logging](https://garrekstemo.github.io/ElabFTW.jl/stable/howto/idempotent_logging/) |
| Tag naming conventions shared across the lab | [ElabFTW.jl how-to: Tagging Conventions](https://garrekstemo.github.io/ElabFTW.jl/stable/howto/tagging_conventions/) |
| `format_results` for converting fit results to markdown | [SpectroscopyTools reporting reference](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/reference/) |
| `AnnotatedSpectrum` type and subtypes | See [Loaders](@ref) (each loader returns a subtype) |

## Dispatches

QPSTools adds two methods to the functions imported from ElabFTW.jl. Both dispatch on `AnnotatedSpectrum`, so they apply uniformly to every lab spectrum type.

```@docs
tags_from_sample(::QPSTools.AnnotatedSpectrum)
log_to_elab(::QPSTools.AnnotatedSpectrum, ::Any)
```

### What the dispatch adds

Compared with calling the ElabFTW.jl base functions directly, the QPSTools dispatch on `(spec, result)`:

- Auto-builds a `## Source` provenance block from the JASCO file header (file name, instrument, acquisition date, calling script) and prepends it to `body`.
- Auto-generates tags from the JASCO datatype (for example `"ftir"`, `"raman"`, `"uvvis"`) plus the kwargs passed to the loader (`solute`, `concentration`, `solvent`, `substrate`, and so on).
- Appends `format_results(result)` to the body as a markdown table.
- Delegates the upload to the keyword-only `log_to_elab(; ...)` form from ElabFTW.jl, inheriting its idempotency rules.

Note that `extra_tags` (not `tags`) is the keyword name on this dispatch: the auto-generated tag set is always included, and `extra_tags` adds to it.

## Putting it together

A typical call from an analysis script:

```julia
using QPSTools

spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv";
    solute = "NH4SCN",
    solvent = "DMF",
    concentration = "1.0M",
    substrate = "CaF2",
)

result = fit_peaks(spec, (1950, 2150))

log_to_elab(spec, result;
    title = "FTIR: CN stretch, 1.0 M NH4SCN in DMF",
    body = "Single Lorentzian on the asymmetric CN stretch.",
    attachments = ["figures/cn_stretch.pdf"],
    extra_tags = ["peak_fit"],
)
```

The experiment body eLabFTW receives looks like:

```markdown
## Source
- **File**: 1.0M_NH4SCN_DMF.csv
- **Instrument**: FT/IR-6600
- **Acquired**: 2026-04-15
- **Script**: fit_cn_stretch.jl

Single Lorentzian on the asymmetric CN stretch.

## Fit Results
| Parameter | Value | Std Error |
| ...       | ...   | ...       |
```

and the tags list is `["ftir", "NH4SCN", "DMF", "1.0M", "CaF2", "peak_fit"]`.

To call `tags_from_sample` on its own — for example, when logging a figure without a fit result via the base `log_to_elab(; ...)` form — pass the spectrum directly:

```julia
tags = tags_from_sample(spec)
```

## See Also

- [Lab Workflow](../tutorials/lab_workflow.md) — the end-to-end tutorial that uses these dispatches.
- [ElabFTW.jl tutorial: Iterative Experiment](https://garrekstemo.github.io/ElabFTW.jl/stable/tutorials/iterative_experiment/) — updating an entry across multiple analysis passes.
- [ElabFTW.jl tutorial: Items and Linking](https://garrekstemo.github.io/ElabFTW.jl/stable/tutorials/items_and_linking/) — attaching samples and referencing them from experiments.
- [ElabFTW.jl how-to: Idempotent Logging](https://garrekstemo.github.io/ElabFTW.jl/stable/howto/idempotent_logging/) — the provenance and idempotency model behind `log_to_elab`.
