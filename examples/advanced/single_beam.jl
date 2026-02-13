# Single-Beam Characterization Example
# MIR probe beam profile measurement (chopper off)
#
# This example manually loads single-beam spectral data and fits
# a Gaussian to characterize the probe beam bandwidth.
#
# Once load_lvm() is updated for single-beam mode, this will simplify.

using Revise
using QPSTools
using CairoMakie
using CurveFit
using CurveFitModels
using Statistics: mean

PROJECT_ROOT = dirname(dirname(@__DIR__))
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "single_beam")
mkpath(FIGDIR)

# ============================================================================
# Data path
# ============================================================================

DATA_FILE = joinpath(PROJECT_ROOT, "data", "MIRpumpprobe", "single_beam_spectrum.lvm")

# ============================================================================
# Manual loading (until load_lvm supports single-beam mode)
# ============================================================================

println("="^60)
println("Loading single-beam data...")
println("="^60)

lines = readlines(DATA_FILE)

# Find wavelength section
wl_start = findfirst(l -> startswith(l, "wavelength"), lines)
println("Wavelength section starts at line: $wl_start")

# Parse intensity data (lines 1 to wl_start-1)
# Format: header + data on same line, 8 channels
n_points = wl_start - 1
intensity = zeros(n_points, 8)

for i in 1:n_points
    line = lines[i]
    parts = split(replace(line, '\r' => '\t'), '\t')
    parts = filter(!isempty, parts)
    # Last 8 values are the data
    values = parts[end-7:end]
    intensity[i, :] = parse.(Float64, values)
end

# Parse wavenumber axis
n_wl = length(lines) - wl_start + 1
wavenumber = zeros(n_wl)

for (i, line_idx) in enumerate(wl_start:length(lines))
    line = lines[line_idx]
    parts = split(replace(line, '\r' => '\t'), '\t')
    parts = filter(!isempty, parts)
    # Second value is wavenumber (first is position)
    wavenumber[i] = parse(Float64, parts[end])
end

println("\nData dimensions:")
println("  Spectral points: $n_points")
println("  Channels: 8")
println("  Wavenumber range: $(round(minimum(wavenumber), digits=1)) - $(round(maximum(wavenumber), digits=1)) cm⁻¹")

# Use channel 0 (primary detector)
signal = intensity[:, 1]

# Align wavenumber axis with intensity (should be same length)
if length(wavenumber) != n_points
    println("  Note: Truncating wavenumber axis to match intensity ($(length(wavenumber)) → $n_points)")
    wavenumber = wavenumber[1:n_points]
end

# ============================================================================
# Plot raw single-beam spectrum
# ============================================================================

println("\n" * "="^60)
println("Creating single-beam spectrum plot...")
println("="^60)

fig1 = Figure(size=(800, 500))
ax1 = Axis(fig1[1, 1],
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Signal (V)",
    title="MIR Probe Beam Profile (Single-Beam)")

lines!(ax1, wavenumber, signal, color=:blue)

# Reverse x-axis (convention: higher wavenumber on left)
ax1.xreversed = true

figpath1 = joinpath(FIGDIR, "single_beam_raw.png")
save(figpath1, fig1)
println("Saved: $figpath1")

# ============================================================================
# Fit Gaussian to characterize beam
# ============================================================================

println("\n" * "="^60)
println("Fitting Gaussian to beam profile...")
println("="^60)

# Initial parameter estimates
# Gaussian: p = [amplitude, center, fwhm, offset]
signal_min = minimum(signal)
signal_max = maximum(signal)
amplitude_init = signal_min - signal_max  # Negative because it's absorption-like
center_init = wavenumber[argmin(signal)]
fwhm_init = 20.0  # Initial guess in cm⁻¹
offset_init = signal_max

p0 = [amplitude_init, center_init, fwhm_init, offset_init]

println("\nInitial guesses:")
println("  Amplitude: $(round(amplitude_init, sigdigits=4))")
println("  Center:    $(round(center_init, digits=1)) cm⁻¹")
println("  FWHM:      $(round(fwhm_init, digits=1)) cm⁻¹")
println("  Offset:    $(round(offset_init, sigdigits=4))")

# Fit using CurveFit.jl
prob = NonlinearCurveFitProblem(gaussian, p0, wavenumber, signal)
sol = solve(prob)

amp, center, fwhm, offset = coef(sol)
amp_err, center_err, fwhm_err, offset_err = stderror(sol)

println("\nFit results:")
println("  Center:    $(round(center, digits=2)) ± $(round(center_err, digits=2)) cm⁻¹")
println("  FWHM:      $(round(abs(fwhm), digits=2)) ± $(round(fwhm_err, digits=2)) cm⁻¹")
println("  Amplitude: $(round(amp, sigdigits=4)) ± $(round(amp_err, sigdigits=2))")
println("  Offset:    $(round(offset, sigdigits=4)) ± $(round(offset_err, sigdigits=2))")

# Compute R²
y_fit = gaussian(coef(sol), wavenumber)
ss_res = sum((signal .- y_fit) .^ 2)
ss_tot = sum((signal .- mean(signal)) .^ 2)
rsquared = 1 - ss_res / ss_tot
println("  R²:        $(round(rsquared, digits=5))")

# ============================================================================
# Plot with Gaussian fit
# ============================================================================

println("\n" * "="^60)
println("Creating fit comparison plot...")
println("="^60)

fig2 = Figure(size=(900, 400))

# Panel A: Data + fit
ax2a = Axis(fig2[1, 1],
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Signal (V)",
    title="Single-Beam with Gaussian Fit")

lines!(ax2a, wavenumber, signal, color=:blue, label="Data")
lines!(ax2a, wavenumber, y_fit, color=:red, linestyle=:dash, label="Gaussian fit")
ax2a.xreversed = true

# Add annotation with fit parameters
text!(ax2a, 0.95, 0.95,
    text="ν₀ = $(round(center, digits=1)) cm⁻¹\nFWHM = $(round(abs(fwhm), digits=1)) cm⁻¹",
    align=(:right, :top),
    space=:relative)

axislegend(ax2a, position=:lb)

# Panel B: Residuals
ax2b = Axis(fig2[1, 2],
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Residual (V)",
    title="Fit Residuals")

resid = signal .- y_fit
lines!(ax2b, wavenumber, resid, color=:gray)
hlines!(ax2b, [0], color=:black, linestyle=:dash, linewidth=0.5)
ax2b.xreversed = true

figpath2 = joinpath(FIGDIR, "single_beam_fit.png")
save(figpath2, fig2)
println("Saved: $figpath2")

# ============================================================================
# Multi-channel comparison
# ============================================================================

println("\n" * "="^60)
println("Creating multi-channel comparison...")
println("="^60)

fig3 = Figure(size=(800, 500))
ax3 = Axis(fig3[1, 1],
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Signal (V)",
    title="All Detector Channels")

colors = Makie.wong_colors()
for ch in 1:min(4, size(intensity, 2))  # Plot first 4 channels
    lines!(ax3, wavenumber, intensity[:, ch], color=colors[ch], label="CH$(ch-1)")
end
ax3.xreversed = true
axislegend(ax3, position=:lb)

figpath3 = joinpath(FIGDIR, "single_beam_channels.png")
save(figpath3, fig3)
println("Saved: $figpath3")

# ============================================================================
# Summary
# ============================================================================

println("\n" * "="^60)
println("Summary: Probe Beam Characteristics")
println("="^60)
println("""
  Center frequency:  $(round(center, digits=1)) cm⁻¹
  Bandwidth (FWHM):  $(round(abs(fwhm), digits=1)) cm⁻¹
  Fit quality (R²):  $(round(rsquared, digits=4))

This characterizes the MIR probe beam spectral profile.
The FWHM gives the effective bandwidth for pump-probe experiments.
""")
