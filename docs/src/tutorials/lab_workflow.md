# Lab Workflow: FTIR to eLabFTW

This tutorial walks through the path a QPS lab member takes for a typical analysis: load a JASCO FTIR spectrum with sample metadata attached, fit a peak, produce a publication figure with the lab theme, and log the result to eLabFTW. At the end you have a single script that reproduces the figure on disk and a published eLabFTW entry with provenance, tags, and the figure attached.

The deep content — the math behind the fit, every `log_to_elab` keyword, the tag naming conventions — lives in the sibling package docs. This tutorial is about composing the stack.

## Goal

A working script that:

1. Loads an FTIR spectrum of 1.0 M NH4SCN in DMF with sample kwargs.
2. Fits the asymmetric CN stretch near 2050 cm⁻¹ with a Lorentzian.
3. Saves a three-panel figure (survey, fit, residuals) to `figures/`.
4. Creates an eLabFTW experiment with the figure attached and the source file, instrument, fit parameters, and lab-wide tags recorded.

## Prerequisites

```julia
using QPSTools
using CairoMakie
```

`QPSTools` re-exports everything from SpectroscopyTools that you need here (`fit_peaks`, `format_results`, `print_theme`, `plot_ftir`, `log_to_elab`, `tags_from_sample`).

If you have not configured eLabFTW on this machine yet, set the `ELABFTW_HOST` and `ELABFTW_API_KEY` environment variables as described in the [ElabFTW.jl setup guide](https://garrekstemo.github.io/ElabFTW.jl/stable/). You can run steps 1 through 3 below without any eLabFTW configuration — only the final `log_to_elab` call needs the server.

## 1. Load via the registry

`load_ftir` takes a path to a JASCO CSV file and a set of sample kwargs. The path loads into an `FTIRSpectrum` and the kwargs are stored in `spec.sample` for display, plotting titles, and eLabFTW tag auto-generation.

```julia
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv";
    solute = "NH4SCN",
    solvent = "DMF",
    concentration = "1.0M",
    substrate = "CaF2",
)
```

Every kwarg becomes a string entry in `spec.sample`. Two things to know:

- The JASCO file header is carried inside `spec.data` (instrument name, acquisition date, y-units). You do not pass these manually — the loader reads them from the file.
- `spec.sample` is where the QPS lab convention of `solute` / `solvent` / `concentration` / `substrate` lives. Those keys drive the auto-generated tag list in step 4.

A quick `show(spec)` in the REPL prints the metadata the loader captured.

## 2. Fit peaks

`fit_peaks(spec, region)` dispatches through SpectroscopyTools to the Lorentzian-by-default peak fitter. Pass the wavenumber window as a tuple:

```julia
result = fit_peaks(spec, (1950, 2150))
report(result)
```

`report(result)` prints the centers, widths, amplitudes, and standard errors. For choice of model (Gaussian, Pseudo-Voigt), handling overlapping peaks, fixing initial guesses, and the full result type, see the SpectroscopyTools references:

- [Peak Fitting reference](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/reference/peak_fitting/) — `fit_peaks` signatures, `PeakFitResult` / `MultiPeakFitResult` fields.
- [How-to: Fit Overlapping Peaks](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/howto/overlapping_peaks/) — when one Lorentzian is not enough.
- [How-to: Choose a Peak Model](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/howto/choose_peak_model/) — Gaussian vs Lorentzian vs Voigt.

## 3. Plot with the lab theme

Apply the lab-wide print theme once, then call `plot_ftir`. The three-panel layout (survey with fit region shaded, zoomed fit, residuals) is selected by passing `context=true`:

```julia
set_theme!(print_theme())

fig, ax_ctx, ax_fit, ax_res = plot_ftir(spec;
    fit = result,
    context = true,
)

save("figures/cn_stretch.pdf", fig)
```

The output goes under `figures/` by convention — never in the project root or next to the script. PDF is the right choice here because the figure is headed for the eLabFTW entry and, potentially, a manuscript.

For the other supported layouts (survey, fit + residuals, peaks overlay) see the [Spectrum Plotting Views](@ref "Spectrum Plotting") tutorial.

## 4. Log to eLabFTW

`log_to_elab(spec, result; ...)` is the QPSTools dispatch that does the packaging work — it reads the JASCO header for the provenance section, converts `result` to a markdown table via `format_results`, and builds the tag list from the sample kwargs you passed in step 1.

```julia
log_to_elab(spec, result;
    title = "FTIR: CN stretch fit, 1.0 M NH4SCN in DMF",
    body = "Single Lorentzian on the asymmetric CN stretch.",
    attachments = ["figures/cn_stretch.pdf"],
    extra_tags = ["peak_fit"],
)
```

What eLabFTW receives:

- **Title**: as given.
- **Body**: provenance block (file, instrument, acquisition date, calling script), then your `body` string, then `format_results(result)` as a markdown table.
- **Tags**: `["ftir", "NH4SCN", "DMF", "1.0M", "CaF2", "peak_fit"]` — the JASCO technique tag, everything from `tags_from_sample(spec)`, and whatever you added via `extra_tags`.
- **Attachments**: the PDF from step 3.

The call is idempotent in the same sense as the base ElabFTW.jl `log_to_elab`. If you re-run the script with the same title, the existing experiment is updated in place rather than duplicated — see the [ElabFTW.jl how-to on idempotent logging](https://garrekstemo.github.io/ElabFTW.jl/stable/howto/idempotent_logging/) for the rules and how to opt out.

## The full script

Combining the sections above:

```julia
using QPSTools
using CairoMakie

spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv";
    solute = "NH4SCN",
    solvent = "DMF",
    concentration = "1.0M",
    substrate = "CaF2",
)

result = fit_peaks(spec, (1950, 2150))
report(result)

set_theme!(print_theme())
fig, ax_ctx, ax_fit, ax_res = plot_ftir(spec; fit=result, context=true)
save("figures/cn_stretch.pdf", fig)

log_to_elab(spec, result;
    title = "FTIR: CN stretch fit, 1.0 M NH4SCN in DMF",
    body = "Single Lorentzian on the asymmetric CN stretch.",
    attachments = ["figures/cn_stretch.pdf"],
    extra_tags = ["peak_fit"],
)
```

Twenty lines, one published experiment, and a figure on disk you can drop straight into a manuscript.

## Next steps

- Fitting technique: [SpectroscopyTools how-tos](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/) cover overlapping peaks, model choice, manual initial guesses, and baseline correction inside the fit.
- Data organization in eLabFTW: the [ElabFTW.jl items and linking tutorial](https://garrekstemo.github.io/ElabFTW.jl/stable/tutorials/items_and_linking/) shows how to register samples as items and link every analysis experiment to the sample it came from. The [iterative experiment tutorial](https://garrekstemo.github.io/ElabFTW.jl/stable/tutorials/iterative_experiment/) covers updating a single experiment as an analysis evolves.
- Alternative figure layouts: [Spectrum Plotting Views](@ref "Spectrum Plotting") shows every supported combination of survey, fit, residuals, and context panels.
- The QPSTools integration surface: [eLabFTW Integration](@ref "eLabFTW Integration") reference page documents the `log_to_elab` and `tags_from_sample` dispatches in detail.
