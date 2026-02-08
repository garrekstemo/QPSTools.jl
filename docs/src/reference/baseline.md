# Baseline Correction

Three baseline correction algorithms with a unified `correct_baseline` dispatcher.

For guidance on choosing between algorithms, see [Baseline Algorithms](@ref).

## Unified API

```@docs
correct_baseline(y::AbstractVector{<:Real}; method::Symbol, kwargs...)
correct_baseline(x::AbstractVector, y::AbstractVector{<:Real}; kwargs...)
```

## Individual Algorithms

```@docs
als_baseline
arpls_baseline
snip_baseline
```
