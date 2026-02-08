# MIR Pump-Probe Workflow Example
# Complete analysis workflow for MIR transient absorption spectroscopy:
# - Transient spectra with ESA/GSB peak fitting
# - Kinetic traces with single/multi-exponential fitting
# - Global fitting with shared parameters
# - Publication-quality composite figure

using QPSTools
using CairoMakie

# ============================================================================
# PART 1: TRANSIENT SPECTRA
# ============================================================================

# Load spectra at different time delays
spec_1ps = load_ta_spectrum("data/MIRpumpprobe/spectra/bare_1M_1ps.lvm";
                            mode=:OD, calibration=-19.0, time_delay=1.0)
spec_5ps = load_ta_spectrum("data/MIRpumpprobe/spectra/bare_1M_5ps.lvm";
                            mode=:OD, calibration=-19.0, time_delay=5.0)
spec_10ps = load_ta_spectrum("data/MIRpumpprobe/spectra/bare_1M_10ps.lvm";
                             mode=:OD, calibration=-19.0, time_delay=10.0)

# Load different concentration for comparison
spec_3p5M = load_ta_spectrum("data/MIRpumpprobe/spectra/bare_3p5M_1ps.lvm";
                             mode=:OD, calibration=-19.0, time_delay=1.0)

println("=== Transient Spectra ===")
println(spec_1ps)

# Fit ESA + GSB peaks
fit_1M = fit_ta_spectrum(spec_1ps; region=(2000, 2100))
fit_3p5M = fit_ta_spectrum(spec_3p5M; region=(2000, 2100))

println("\n=== 1M Spectrum Fit ===")
report(fit_1M)

println("=== 3.5M Spectrum Fit ===")
report(fit_3p5M)

# Plot spectrum with fit and residuals
fig_spec, ax_spec, ax_res_spec = plot_spectrum(spec_1ps; fit=fit_1M, residuals=true,
                                                title="1M NH₄SCN at 1 ps")
save("figures/EXAMPLES/mir_workflow/spectrum_fit.pdf", fig_spec)

# ============================================================================
# PART 2: KINETIC TRACES
# ============================================================================

# Load kinetic traces (single wavelength, time-resolved)
trace_esa = load_ta_trace("data/MIRpumpprobe/pp_kinetics_esa.lvm"; mode=:OD)
trace_gsb = load_ta_trace("data/MIRpumpprobe/pp_kinetics_gsb.lvm"; mode=:OD)

println("\n=== Kinetic Traces ===")
println(trace_esa)
println(trace_gsb)

# ============================================================================
# PART 3: EXPONENTIAL FITTING
# ============================================================================

# Single exponential with IRF deconvolution (default)
result_esa = fit_exp_decay(trace_esa, irf=false)
result_gsb = fit_exp_decay(trace_gsb)

println("\n=== ESA Kinetics Fit ===")
report(result_esa)

println("=== GSB Kinetics Fit ===")
report(result_gsb)

# Report IRF width (only meaningful when irf=true)
if !isnan(result_gsb.sigma)
    println("\n=== IRF Analysis ===")
    println("  σ_IRF       = $(round(result_gsb.sigma, digits=3)) ps")
    println("  FWHM_IRF    = $(round(irf_fwhm(result_gsb.sigma), digits=3)) ps")
    println("  FWHM_pulse  = $(round(pulse_fwhm(result_gsb.sigma), digits=3)) ps  (estimated, assuming equal pump/probe)")
end

# Plot kinetics with fit and residuals
fig_esa, ax_esa, ax_res_esa = plot_kinetics(trace_esa; fit=result_esa, residuals=true,
                                             title="ESA (τ = $(round(result_esa.tau, digits=1)) ps)")
save("figures/EXAMPLES/mir_workflow/esa_kinetics_fit.pdf", fig_esa)

fig_gsb, ax_gsb, ax_res_gsb = plot_kinetics(trace_gsb; fit=result_gsb, residuals=true,
                                             title="GSB (τ = $(round(result_gsb.tau, digits=1)) ps)")
save("figures/EXAMPLES/mir_workflow/gsb_kinetics_fit.pdf", fig_gsb)

# Multi-exponential fitting
result_biexp = fit_exp_decay(trace_esa; n_exp=2)

println("\n=== Biexponential Fit ===")
report(result_biexp)

# ============================================================================
# PART 4: GLOBAL FITTING
# ============================================================================

# Fit ESA and GSB simultaneously with shared τ
result_global = fit_global([trace_esa, trace_gsb]; labels=["ESA", "GSB"])

println("\n=== Global Fit ===")
report(result_global)

# ============================================================================
# PART 5: PUBLICATION FIGURE
# ============================================================================

set_theme!(publication_theme())

fig = Figure(size=(900, 700))

# Panel (a): Transient spectra at different time delays
ax_a = Axis(fig[1, 1], xlabel="Wavenumber (cm⁻¹)", ylabel="ΔA", title="(a) Transient Spectra")
lines!(ax_a, spec_1ps.wavenumber, spec_1ps.signal, label="1 ps")
lines!(ax_a, spec_5ps.wavenumber, spec_5ps.signal, label="5 ps")
lines!(ax_a, spec_10ps.wavenumber, spec_10ps.signal, label="10 ps")
hlines!(ax_a, 0; color=:black, linestyle=:dash, linewidth=0.5)
axislegend(ax_a, position=:rt)

# Panel (b): Spectrum fit (1M at 1ps)
ax_b = Axis(fig[1, 2], xlabel="Wavenumber (cm⁻¹)", ylabel="ΔA", title="(b) ESA/GSB Fit")
lines!(ax_b, spec_1ps.wavenumber, spec_1ps.signal, label="Data")
lines!(ax_b, spec_1ps.wavenumber, predict(fit_1M, spec_1ps), color=:red, label="Fit")
hlines!(ax_b, 0; color=:black, linestyle=:dash, linewidth=0.5)
axislegend(ax_b, position=:rt)
xlims!(ax_b, 1950, 2150)

# Panel (c): Kinetics with single exponential fit
ax_c = Axis(fig[2, 1], xlabel="Time (ps)", ylabel="ΔA",
            title="(c) ESA Kinetics (τ = $(round(result_esa.tau, digits=1)) ps)")
scatter!(ax_c, trace_esa.time, trace_esa.signal, markersize=4, label="Data")
lines!(ax_c, trace_esa.time, predict(result_esa, trace_esa), color=:red, label="Fit")
axislegend(ax_c, position=:rt)

# Panel (d): Global fit comparison (ESA and GSB)
ax_d = Axis(fig[2, 2], xlabel="Time (ps)", ylabel="ΔA",
            title="(d) Global Fit (τ = $(round(result_global.tau, digits=1)) ps)")
global_curves = predict(result_global, [trace_esa, trace_gsb])
scatter!(ax_d, trace_esa.time, trace_esa.signal, markersize=4, label="ESA")
lines!(ax_d, trace_esa.time, global_curves[1], color=Makie.wong_colors()[1])
scatter!(ax_d, trace_gsb.time, trace_gsb.signal, markersize=4, label="GSB")
lines!(ax_d, trace_gsb.time, global_curves[2], color=Makie.wong_colors()[2])
axislegend(ax_d, position=:rt)

fig

save("figures/EXAMPLES/mir_workflow/mir_publication_figure.pdf", fig)

println("\nFigures saved to figures/EXAMPLES/mir_workflow/")
println("  - spectrum_fit.pdf          (spectrum + fit + residuals)")
println("  - esa_kinetics_fit.pdf      (ESA kinetics + fit + residuals)")
println("  - gsb_kinetics_fit.pdf      (GSB kinetics + fit + residuals)")
println("  - mir_publication_figure.pdf (4-panel composite)")

# ============================================================================
# PART 6: LOG TO ELABFTW (optional)
# ============================================================================

# Uncomment to log results to your lab notebook:
#
# log_to_elab(
#     title = "MIR pump-probe: NH4SCN vibrational dynamics",
#     body = """
# ## Sample
# NH₄SCN in DMF, CN stretch region (2000-2100 cm⁻¹)
#
# ## Spectrum Fit (1 ps)
# $(format_results(fit_1M))
#
# ## Kinetics
# $(format_results(result_biexp))
#
# ## Global Fit (ESA + GSB)
# $(format_results(result_global))
# """,
#     attachments = [
#         "figures/EXAMPLES/mir_workflow/mir_publication_figure.pdf",
#         "figures/EXAMPLES/mir_workflow/spectrum_fit.pdf"
#     ],
#     tags = ["pump-probe", "mir", "nh4scn", "kinetics"]
# )
