# IRF Convolution Model

## Overview

Ultrafast pump-probe experiments measure dynamics convolved with the instrument response function (IRF). When the decay timescale is comparable to the pulse duration, fitting a simple exponential to the data gives the wrong time constant. IRF deconvolution recovers the true dynamics.

QPSTools uses `fit_exp_decay(trace; irf=true)` to fit with IRF deconvolution. This document explains the underlying model.

## The Model

The measured signal is the convolution of the molecular response with the IRF:

```
S(t) = IRF(t) * R(t)
```

We assume:
- **IRF**: Gaussian with standard deviation sigma (the cross-correlation of pump and probe pulses)
- **Response**: Step-function onset at t0 followed by exponential decay with time constant tau

The analytical result of this convolution is:

```
S(t) = (A/2) * exp(sigma^2 / (2*tau^2) - (t - t0) / tau)
              * erfc((sigma^2/tau - (t - t0)) / (sigma * sqrt(2)))
      + offset
```

where `erfc` is the complementary error function.

### Limiting behavior

- **sigma -> 0** (delta-function IRF): reduces to a simple exponential `A * exp(-(t - t0) / tau) + offset`
- **t << t0**: signal approaches offset (erfc -> 2)
- **t >> t0**: signal decays as `exp(-t/tau)` with the correct time constant

## Fitted Parameters

| Parameter | Symbol | Meaning |
|-----------|--------|---------|
| `amplitude` | A | Pre-exponential factor (sign indicates ESA vs GSB) |
| `tau` | tau | Exponential decay time constant (ps) |
| `t0` | t0 | Time zero (pump-probe overlap center) |
| `sigma` | sigma | IRF width, Gaussian standard deviation (ps) |
| `offset` | - | Long-time baseline |

## Converting sigma to Physical Quantities

The fitted `sigma` is the standard deviation of the Gaussian IRF (the pump-probe cross-correlation). Two helper functions convert this to more intuitive quantities:

### `irf_fwhm(sigma)`

Full width at half maximum of the IRF:

```
FWHM_IRF = 2 * sqrt(2 * ln(2)) * sigma = 2.355 * sigma
```

This is the temporal resolution of the experiment.

### `pulse_fwhm(sigma)`

Estimated FWHM of individual pump/probe pulses, assuming identical Gaussian pulses:

```
FWHM_pulse = 2.355 * sigma / sqrt(2)
```

The cross-correlation of two identical Gaussians with width `sigma_pulse` gives `sigma_IRF = sqrt(2) * sigma_pulse`, so `sigma_pulse = sigma_IRF / sqrt(2)`.

## Usage

```julia
trace = load_ta_trace("kinetics.lvm"; mode=:OD)

# Without IRF (default) -- use when tau >> pulse width
result = fit_exp_decay(trace)

# With IRF deconvolution -- use when tau is comparable to pulse width
result = fit_exp_decay(trace; irf=true)

# Access IRF parameters
result.sigma              # IRF sigma (ps)
irf_fwhm(result.sigma)    # IRF FWHM (ps)
pulse_fwhm(result.sigma)  # Estimated pulse FWHM (ps)
```

## When to Use IRF Deconvolution

| Regime | tau / FWHM_IRF | Recommendation |
|--------|---------------|----------------|
| tau >> IRF | > 10 | `irf=false` is fine |
| tau ~ IRF | 1-10 | `irf=true` improves accuracy |
| tau < IRF | < 1 | `irf=true` is essential |

For a typical Ti:Sapph system with ~150 fs pulses, the IRF FWHM is ~200 fs. Use `irf=true` for any dynamics faster than ~2 ps.

## Multi-Exponential Extension

The same convolution applies to each component independently:

```
S(t) = sum_i [ (A_i/2) * exp(sigma^2/(2*tau_i^2) - (t-t0)/tau_i)
               * erfc((sigma^2/tau_i - (t-t0)) / (sigma*sqrt(2))) ]
       + offset
```

All components share the same `t0` and `sigma` (they experience the same IRF).

Access via `fit_exp_decay(trace; n_exp=2, irf=true)`.
