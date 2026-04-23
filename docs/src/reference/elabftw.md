# eLabFTW Integration

Dispatches that extend [ElabFTW.jl](https://github.com/garrekstemo/ElabFTW.jl) with lab-specific behaviour for `AnnotatedSpectrum` values. See [`src/elabftw_glue.jl`](https://github.com/garrekstemo/QPSTools.jl/blob/main/src/elabftw_glue.jl).

`log_to_elab` and `tags_from_sample` are imported from ElabFTW.jl and extended here with new methods — load both packages to access them.

```julia
using QPSTools
using ElabFTW
```

## Dispatches

```@docs
QPSTools.log_to_elab
QPSTools.tags_from_sample
```
