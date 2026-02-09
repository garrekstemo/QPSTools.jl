# Chirp diagnostic plotting

# =============================================================================
# plot_chirp: heatmap with chirp curve overlay
# =============================================================================

"""
    plot_chirp(matrix::TAMatrix, cal::ChirpCalibration; kwargs...) -> (Figure, Axis)

Create a diagnostic plot: TA heatmap with the detected chirp curve overlaid.

Shows the polynomial fit as a line and the detected points as scatter markers,
allowing visual assessment of chirp detection quality.

# Keyword Arguments
- `colormap`: Heatmap colormap (default: `:RdBu`)
- `colorrange`: Symmetric color range tuple. Auto-detected if not specified.
- `title`: Plot title (default: `"Chirp Detection"`)

# Returns
`(Figure, Axis)` for further customization.

# Example
```julia
cal = detect_chirp(matrix_bg)
fig, ax = plot_chirp(matrix_bg, cal)
save("chirp_diagnostic.png", fig)
```
"""
function plot_chirp(matrix::TAMatrix, cal::ChirpCalibration;
    colormap=:RdBu, colorrange=nothing, title="Chirp Detection")

    with_theme(qps_theme()) do
        fig = Figure(size=(800, 500))
        ax = Axis(fig[1, 1],
            xlabel=QPSTools.ylabel(matrix),  # "Time (ps)"
            ylabel=QPSTools.xlabel(matrix),  # "Wavelength (nm)"
            title=title)

        # Auto colorrange
        if isnothing(colorrange)
            max_abs = maximum(abs, matrix.data)
            colorrange = (-max_abs, max_abs)
        end

        # Heatmap (same orientation as plot_ta_heatmap: time on x, wavelength on y)
        hm = heatmap!(ax, matrix.time, matrix.wavelength, matrix.data;
            colormap=colormap, colorrange=colorrange)
        Colorbar(fig[1, 2], hm, label="ΔA")

        # Overlay chirp curve and points
        plot_chirp!(ax, cal)

        return fig, ax
    end
end

"""
    plot_chirp!(ax, cal::ChirpCalibration)

Overlay chirp curve and detected points on an existing axis.

Adds the polynomial chirp curve and detected scatter points. The axis should
have time on the x-axis and wavelength on the y-axis (matching `plot_ta_heatmap`).

# Example
```julia
fig, ax, hm = plot_ta_heatmap(matrix)
plot_chirp!(ax, cal)
```
"""
function plot_chirp!(ax, cal::ChirpCalibration)
    poly = polynomial(cal)

    # Dense wavelength grid for smooth curve
    λ_min = minimum(cal.wavelength)
    λ_max = maximum(cal.wavelength)
    λ_dense = range(λ_min, λ_max, length=200)
    t_curve = [poly(λ) for λ in λ_dense]

    # Polynomial curve (time on x-axis, wavelength on y-axis)
    lines!(ax, t_curve, collect(λ_dense); color=:black, linestyle=:dash)

    # Detected points
    scatter!(ax, cal.time_offset, cal.wavelength; color=:yellow, markersize=4)

    return nothing
end
