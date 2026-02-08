# Broadband Transient Absorption Example
# Demonstrates the TAMatrix API for 2D TA data (time × wavelength)
#
# Run from project root: julia --project=. examples/broadband_ta_example.jl

using Revise
using QPSTools
using CairoMakie

# ============================================================================
# PART 1: LOAD 2D TA DATA
# ============================================================================

println("=" ^ 60)
println("Loading broadband TA data...")
println("=" ^ 60)

DATA_ROOT = "/Users/garrek/Documents/projects/QPS.jl/data/broadband-TA"

# Load with automatic file detection
matrix = load_ta_matrix(DATA_ROOT;
    time_file="time_axis_240528.txt",
    wavelength_file="wavelength_axis.txt",
    data_file="ta_matrix_240528.lvm",
    time_unit=:fs)

println("\n", matrix)

# ============================================================================
# PART 2: TA HEATMAP
# ============================================================================

println("\n" * "=" ^ 60)
println("Creating TA heatmap...")
println("=" ^ 60)

fig1, ax1, hm = plot_ta_heatmap(matrix; colorrange=(-0.02, 0.02))

figpath1 = joinpath(@__DIR__, "..", "figures", "EXAMPLES", "broadband_ta", "broadband_ta_heatmap.pdf")
mkpath(dirname(figpath1))
save(figpath1, fig1)
println("Saved: $figpath1")

# ============================================================================
# PART 3: EXTRACT AND FIT KINETICS
# ============================================================================

println("\n" * "=" ^ 60)
println("Extracting kinetics at specific wavelengths...")
println("=" ^ 60)

# Extract kinetics at 800 nm using indexing syntax
trace_800nm = matrix[λ=800]
println("\nExtracted trace:")
println("  ", trace_800nm)
println("  Actual wavelength: $(round(trace_800nm.wavelength, digits=1)) nm")

# Fit exponential decay with IRF
result = fit_exp_decay(trace_800nm; irf_width=0.15)

println("\n=== Fit at $(round(trace_800nm.wavelength, digits=1)) nm ===")
report(result)

# ============================================================================
# PART 4: MULTI-WAVELENGTH KINETICS PLOT
# ============================================================================

println("\n\n" * "=" ^ 60)
println("Creating multi-wavelength kinetics plot...")
println("=" ^ 60)

target_wavelengths = [700.0, 750.0, 800.0, 850.0]
fig2, ax2 = plot_kinetics(matrix; λ=target_wavelengths)
ax2.title = "Kinetics at selected wavelengths"

figpath2 = joinpath(@__DIR__, "..", "figures", "EXAMPLES", "broadband_ta", "broadband_ta_kinetics.pdf")
save(figpath2, fig2)
println("Saved: $figpath2")

# ============================================================================
# PART 5: SINGLE WAVELENGTH FIT PLOT
# ============================================================================

println("\n" * "=" ^ 60)
println("Creating single-wavelength fit plot...")
println("=" ^ 60)

fig3, ax3, ax3_res = plot_kinetics(trace_800nm; fit=result, residuals=true,
                                    title="Fit at $(round(Int, trace_800nm.wavelength)) nm (τ = $(round(result.tau, digits=1)) ps)")

figpath3 = joinpath(@__DIR__, "..", "figures", "EXAMPLES", "broadband_ta", "broadband_ta_fit.pdf")
save(figpath3, fig3)
println("Saved: $figpath3")

# ============================================================================
# PART 6: TRANSIENT SPECTRA
# ============================================================================

println("\n" * "=" ^ 60)
println("Creating transient spectra plot...")
println("=" ^ 60)

target_times = [-0.5, 0.1, 0.5, 1.0, 3.0]
fig4, ax4 = plot_spectra(matrix; t=target_times)
ax4.title = "Transient spectra at selected times"

figpath4 = joinpath(@__DIR__, "..", "figures", "EXAMPLES", "broadband_ta", "broadband_ta_spectra.pdf")
save(figpath4, fig4)
println("Saved: $figpath4")

# ============================================================================
# PART 7: SPECTRUM EXTRACTION DEMO
# ============================================================================

println("\n" * "=" ^ 60)
println("Spectrum extraction demo...")
println("=" ^ 60)

# Extract spectrum at t = 1.0 ps
spec_1ps = matrix[t=1.0]
println("\nExtracted spectrum:")
println("  Time delay: $(round(spec_1ps.time_delay, digits=2)) ps")
println("  Wavelength range: $(round(minimum(spec_1ps.wavenumber), digits=1)) - $(round(maximum(spec_1ps.wavenumber), digits=1)) nm")

# ============================================================================
# SUMMARY
# ============================================================================

println("\n" * "=" ^ 60)
println("Summary: TAMatrix Workflow")
println("=" ^ 60)
println("""
  # Load 2D TA data
  matrix = load_ta_matrix("data/broadband-TA/")

  # Extract kinetics at specific wavelength
  trace = matrix[λ=800]  # TATrace at λ ≈ 800 nm

  # Extract spectrum at specific time
  spec = matrix[t=1.0]   # TASpectrum at t ≈ 1.0 ps

  # Fit kinetics
  result = fit_exp_decay(trace)

  # Plot options
  plot_ta_heatmap(matrix)            # 2D heatmap
  plot_kinetics(matrix; λ=[700, 800]) # Multi-wavelength kinetics
  plot_spectra(matrix; t=[0.1, 1.0])  # Multi-time spectra
  plot_kinetics(trace; fit=result)    # Single trace with fit
""")

println("\nDone! Generated 4 figures in figures/EXAMPLES/broadband_ta/")

# ============================================================================
# LOG TO ELABFTW (optional)
# ============================================================================

# Uncomment to log results to your lab notebook:
#
# log_to_elab(
#     title = "Broadband TA: $(basename(DATA_ROOT))",
#     body = """
# ## Dataset
# - Time points: $(size(matrix.data, 1))
# - Wavelengths: $(size(matrix.data, 2))
# - Time range: $(round(minimum(matrix.time), digits=2)) – $(round(maximum(matrix.time), digits=2)) ps
# - Wavelength range: $(round(minimum(matrix.wavelength), digits=1)) – $(round(maximum(matrix.wavelength), digits=1)) nm
#
# ## Kinetics at $(round(Int, trace_800nm.wavelength)) nm
# $(format_results(result))
# """,
#     attachments = [figpath1, figpath3],
#     tags = ["broadband-ta", "kinetics"]
# )
