# eLabFTW Integration

QPSTools extends [ElabFTW.jl](https://github.com/garrekstemo/ElabFTW.jl) with
lab-specific provenance for token-stamped `Spectrum` and `StreakPL` values. These
dispatches live in the `QPSToolsElabFTWExt` package extension
([`ext/QPSToolsElabFTWExt.jl`](https://github.com/garrekstemo/QPSTools.jl/blob/main/ext/QPSToolsElabFTWExt.jl)),
so they activate only when ElabFTW is in scope — `ElabFTW` is a weak dependency
of QPSTools, not a hard one.

```julia
using QPSTools
using ElabFTW   # activates the extension
```

## Dispatches

`log_to_elab` and `tags_from_sample` are owned by ElabFTW.jl; the extension adds
methods for QPSTools' own types:

- `tags_from_sample(s::Spectrum)` and `tags_from_sample(pl::StreakPL)` — derive
  eLabFTW tags (technique, sample) from the value's metadata tokens.
- `log_to_elab(s::Spectrum, result; ...)` and `log_to_elab(pl::StreakPL, result; ...)`
  — post a provenance entry (acquisition parameters, fit summary, auto-tags) to
  an eLabFTW experiment.

See the [ElabFTW.jl](https://github.com/garrekstemo/ElabFTW.jl) documentation for
the base API these extend.
