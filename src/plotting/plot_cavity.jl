# Cavity-specific plotting: dispersion, Hopfield coefficients, polariton peaks

"""
    plot_dispersion(result::DispersionFitResult; title="")

Plot polariton dispersion: LP/UP data points, coupled oscillator fit curves,
bare cavity and molecular mode lines.

# Returns
`(Figure, Axis)`
"""
function plot_dispersion(result::DispersionFitResult; title::String="")
    with_theme(qps_theme()) do
        fig = Figure()
        ax = Axis(fig[1, 1],
            xlabel="Angle (deg)",
            ylabel="Energy (cm⁻¹)",
            title=isempty(title) ? "Polariton Dispersion" : title)

        plot_dispersion!(ax, result)

        return fig, ax
    end
end

"""
    plot_dispersion!(ax, result::DispersionFitResult)

Draw polariton dispersion on an existing axis.
"""
function plot_dispersion!(ax, result::DispersionFitResult)
    colors = lab_colors()

    # Data points (LP and UP may be at different angles)
    scatter!(ax, rad2deg.(result.lp_angles), result.lp_positions, label="LP", color=colors[:primary])
    scatter!(ax, rad2deg.(result.up_angles), result.up_positions, label="UP", color=colors[:secondary])

    # Fit curves (dense angle grid spanning all data)
    all_angles = [result.lp_angles; result.up_angles]
    theta_fine = range(minimum(all_angles), maximum(all_angles), length=200)
    theta_deg_fine = rad2deg.(theta_fine)

    E_cav_fine = cavity_mode_energy([result.E0, result.n_eff], theta_fine)

    if length(result.molecular_modes) == 1
        lp_fine, up_fine = polariton_branches(E_cav_fine, result.molecular_modes[1],
                                              result.rabi_splitting)
        lines!(ax, theta_deg_fine, lp_fine, color=colors[:primary])
        lines!(ax, theta_deg_fine, up_fine, color=colors[:secondary])
    else
        lp_fine = similar(theta_fine)
        up_fine = similar(theta_fine)
        for i in eachindex(theta_fine)
            Omegas = fill(result.rabi_splitting, length(result.molecular_modes))
            eigs = polariton_eigenvalues(E_cav_fine[i], result.molecular_modes, Omegas)
            lp_fine[i] = eigs[1]
            up_fine[i] = eigs[end]
        end
        lines!(ax, theta_deg_fine, lp_fine, color=colors[:primary])
        lines!(ax, theta_deg_fine, up_fine, color=colors[:secondary])
    end

    # Bare cavity mode (dashed)
    lines!(ax, theta_deg_fine, E_cav_fine,
        color=colors[:neutral], linestyle=:dash, label="Cavity")

    # Molecular modes (horizontal dashed)
    for m in result.molecular_modes
        hlines!(ax, m, color=colors[:accent], linestyle=:dot, label="Mol. mode")
    end

    # Rabi splitting annotation at zero detuning
    mol_center = mean(result.molecular_modes)
    E_LP_0, E_UP_0 = polariton_branches(mol_center, mol_center, result.rabi_splitting)
    mid_angle = mean(rad2deg.(all_angles))
    text!(ax, mid_angle, (E_LP_0 + E_UP_0) / 2,
        text="Ω = $(round(result.rabi_splitting, digits=1)) cm⁻¹",
        align=(:center, :center),
        space=:data)

    axislegend(ax, position=:lt, unique=true)
end

"""
    plot_hopfield(result::DispersionFitResult; title="")

Plot Hopfield coefficients (photon/matter fractions) vs cavity detuning.

# Returns
`(Figure, Axis)`
"""
function plot_hopfield(result::DispersionFitResult; title::String="")
    with_theme(qps_theme()) do
        fig = Figure()
        ax = Axis(fig[1, 1],
            xlabel="Detuning (cm⁻¹)",
            ylabel="|C|², |X|²",
            title=isempty(title) ? "Hopfield Coefficients" : title)

        plot_hopfield!(ax, result)

        return fig, ax
    end
end

"""
    plot_hopfield!(ax, result::DispersionFitResult)

Draw Hopfield coefficients on an existing axis.
"""
function plot_hopfield!(ax, result::DispersionFitResult)
    mol_center = mean(result.molecular_modes)

    # Compute over a detuning range
    detuning_range = 3 * result.rabi_splitting
    E_cav = range(mol_center - detuning_range, mol_center + detuning_range, length=200)
    detuning = E_cav .- mol_center

    h = hopfield_coefficients(E_cav, mol_center, result.rabi_splitting)

    colors = lab_colors()

    # LP branch
    lines!(ax, detuning, h.photon_LP, color=colors[:primary], label="LP photon")
    lines!(ax, detuning, h.matter_LP, color=colors[:primary], linestyle=:dash, label="LP matter")

    # UP branch
    lines!(ax, detuning, h.photon_UP, color=colors[:secondary], label="UP photon")
    lines!(ax, detuning, h.matter_UP, color=colors[:secondary], linestyle=:dash, label="UP matter")

    # Zero detuning marker
    vlines!(ax, 0, color=colors[:neutral], linestyle=:dot)

    axislegend(ax, position=:rt)
end

"""
    _draw_polariton_peaks!(ax, result::CavityFitResult)

Draw vertical dashed lines at polariton peak positions with labels.
"""
function _draw_polariton_peaks!(ax, result::CavityFitResult)
    colors = lab_colors()
    labels = ["LP", "UP", "MP"]  # LP, UP, middle polariton for multi-mode

    sorted_peaks = sort(result.polariton_peaks)
    for (i, pk) in enumerate(sorted_peaks)
        lbl = i <= length(labels) ? labels[i] : "P$i"
        vlines!(ax, pk, color=colors[:accent], linestyle=:dash, alpha=0.5)
        text!(ax, pk, 1.0,
            text=lbl,
            align=(:center, :bottom),
            space=:relative)
    end
end
