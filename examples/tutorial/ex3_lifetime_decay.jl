# ex3_lifetime_decay.jl
#
# Workshop Exercise 3 in Julia. Fit a fluorescence lifetime decay with
# IRF convolution. Decide single vs biexponential from residuals + χ²_red.
# Propagate uncertainty to the radiative rate k_r = Φ / τ.
#
# Pairs with: 06-workshop-data-analysis.md §Exercise 3, 02-photoluminescence.md.

using QPSTools, OpticalSpectroscopy, GLMakie
using Random
using Statistics: mean
using OpticalSpectroscopy: _exp_decay_irf_conv  # the IRF-convolved model the fitter uses

set_theme!(qps_theme())
Random.seed!(42)

# --- Synthetic biexponential decay with Gaussian IRF ------------------------
# Real data: replace this block with
#   trace = load_ta_trace("sample_data/dye_lifetime.lvm")
# A TATrace just needs time + signal — units are not enforced by the type.

t       = collect(-1.0:0.05:80.0)        # ns
A1, τ1  = 0.30, 2.0                      # fast component
A2, τ2  = 0.70, 15.0                     # slow component (factor 7.5 — clearly resolvable)
t0      = 0.0
σ_irf   = 0.15                           # IRF width, ns
σ_noise = 0.005                          # known noise level (TCSPC dark counts etc.)

clean = [_exp_decay_irf_conv(ti, A1, τ1, t0, σ_irf) +
         _exp_decay_irf_conv(ti, A2, τ2, t0, σ_irf) for ti in t]
noisy = clean .+ σ_noise .* randn(length(t))
trace = TATrace(t, noisy; metadata=Dict{Symbol,Any}(:filename => "synthetic_biexp"))

# Reduced χ²: residuals scaled by the known noise σ, divided by degrees of
# freedom (n_data - n_params).  A good fit gives χ²_red ≈ 1.
chi2_red(res, n_par) = sum((res ./ σ_noise) .^ 2) / (length(res) - n_par)

# --- Fit single exponential -------------------------------------------------
fit1 = fit_exp_decay(trace; n_exp=1, irf=true, irf_width=0.15)
report(fit1)
println("\nSingle-exponential χ²_red ≈ ", round(chi2_red(fit1.residuals, 5), digits=3))

# --- Fit biexponential ------------------------------------------------------
fit2 = fit_exp_decay(trace; n_exp=2, irf=true, irf_width=0.15)
report(fit2)
println("\nBiexponential χ²_red ≈ ", round(chi2_red(fit2.residuals, 7), digits=3))

# Workshop check: τ₁/τ₂ should differ by ≥ 3× and both amplitudes should be
# significant. If not, the second component is fitting noise.
ratio = maximum(fit2.taus) / minimum(fit2.taus)
println("τ ratio = ", round(ratio, digits=2),
        ratio > 3 ? "  (≥ 3, biexponential justified)" : "  (< 3, suspect overfit)")

# --- Error propagation: k_r = Φ / τ -----------------------------------------
# Use the dominant (slow) component's τ. Quantum yield Φ assumed measured
# elsewhere with 5% relative uncertainty (typical literature value).
τ      = maximum(fit2.taus)              # ns
στ_rel = 0.04                            # 4% — placeholder; real fits return σ(τ) via covariance
Φ      = 0.65
σΦ_rel = 0.05

k_r       = Φ / τ                        # ns⁻¹
σkr_rel   = sqrt(σΦ_rel^2 + στ_rel^2)
σk_r      = k_r * σkr_rel

println()
println("Radiative rate")
println("  τ (slow)  = $(round(τ, digits=2)) ns")
println("  k_r       = $(round(k_r, digits=3)) ± $(round(σk_r, digits=3)) ns⁻¹  ",
        "($(round(100σkr_rel, digits=1))% relative)")

# --- Plot: log-y data + biexp fit + residuals subpanel ----------------------
fit_curve = [_exp_decay_irf_conv(ti, fit2.amplitudes[1], fit2.taus[1], fit2.t0, fit2.sigma) +
             _exp_decay_irf_conv(ti, fit2.amplitudes[2], fit2.taus[2], fit2.t0, fit2.sigma) +
             fit2.offset for ti in t]

# Mask non-positive values for log axis
posmask = noisy .> 0

fig = Figure(size=(720, 520))
ax_main = Axis(fig[1, 1];
    ylabel="Counts (a.u.)",
    yscale=log10,
    yminorticksvisible=true)
scatter!(ax_main, t[posmask], noisy[posmask]; color=:black, markersize=4, label="data")
lines!(ax_main, t, fit_curve; color=:crimson, linewidth=2, label="biexponential fit")
axislegend(ax_main; position=:rt)

ax_res = Axis(fig[2, 1]; xlabel="Time (ns)", ylabel="residuals")
scatter!(ax_res, t, fit2.residuals; color=:black, markersize=3)
hlines!(ax_res, [0.0]; color=:gray, linestyle=:dash)

linkxaxes!(ax_main, ax_res)
hidexdecorations!(ax_main; grid=false)
rowsize!(fig.layout, 2, Relative(0.25))

wait(display(fig))
