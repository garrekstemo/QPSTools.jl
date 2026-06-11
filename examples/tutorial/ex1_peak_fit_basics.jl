# ex1_peak_fit_basics.jl
#
# Workshop Exercise 1 in Julia. Fit one absorption peak with a Lorentzian
# line shape and a linear baseline. Extract center, FWHM, amplitude, and the
# integrated peak area with propagated uncertainty.
#
# Pairs with: 06-workshop-data-analysis.md §Exercise 1, 01a-absorption.md.

using QPSTools, OpticalSpectroscopy, GLMakie
using Random

set_theme!(qps_theme())
Random.seed!(42)

# --- Synthetic spectrum -----------------------------------------------------
# Real data: replace this block with
#   spec = load_spectroscopy("sample_data/uvvis_dye.csv")  # or load_ftir(...)
# The fit below works on any AbstractSpectroscopyData.

x  = 1500.0:1.0:2500.0            # wavenumber, cm⁻¹
A_true, x0_true, Γ_true = 1.0, 2050.0, 18.0
peak     = lorentzian([A_true, x0_true, Γ_true], x)
baseline = 0.05 .+ 8e-5 .* (x .- 2000.0)   # gentle slope across the window
noise    = 0.01 .* randn(length(x))
spec = peak .+ baseline .+ noise

# --- Fit --------------------------------------------------------------------
fit = fit_peaks(spec; model=lorentzian, n_peaks=1, baseline_order=1)
report(fit)

# --- Derived quantity: area with propagated uncertainty ---------------------
# Lorentzian area = π · A · Γ / 2.  Relative uncertainties add in quadrature
# (workshop §Block 2 walkthrough on covariance):
#   σ(area)/area = √[ (σ(A)/A)² + (σ(Γ)/Γ)² ]
peak1 = fit[1]
A   = peak1[:amplitude].value
σA  = peak1[:amplitude].err
Γ   = peak1[:fwhm].value
σΓ  = peak1[:fwhm].err

area  = π * A * Γ / 2
σarea = area * sqrt((σA / A)^2 + (σΓ / Γ)^2)

println()
println("Integrated area")
println("  area = $(round(area, digits=2)) ± $(round(σarea, digits=2)) (cm⁻¹ × OD)")

# --- Plot: data + fit + residuals + baseline overlay ------------------------
fig = plot_fit(fit;
    xlabel = "Wavenumber (cm⁻¹)",
    ylabel = "Absorbance (OD)",
    baseline = true,
)

fig
