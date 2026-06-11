# Tutorial scripts

Companion Julia scripts for the spectroscopy tutorial series at
`~/Documents/Teaching/Spectroscopy Tutorials`. Mirror the workshop exercises
and span the analysis archetypes used across the lectures.

Run from the QPSTools repo root:

```
julia --project=examples examples/tutorial/<name>.jl
```

All scripts generate synthetic data by default. Each script has a
`# Real data:` comment block showing the QPSTools loader call and expected
path under `sample_data/` for swapping in a student's own dataset.

| Script | Pairs with | Demonstrates |
|---|---|---|
| `ex1_peak_fit_basics.jl` | Workshop Ex 1; 01a-absorption.md | Lorentzian + linear baseline, residuals panel, area with propagated uncertainty |
| `ex3_lifetime_decay.jl` | Workshop Ex 3; 02-photoluminescence.md | IRF-convolved decay, single vs biexponential decision via χ²_red, error propagation to k_r |

More scripts (Ex 2 lineshape comparison, Ex 4 publication plot, TA matrix
basics, polariton dispersion) per
`~/.claude/plans/let-s-explore-adding-glmakie-silly-harbor.md`.
