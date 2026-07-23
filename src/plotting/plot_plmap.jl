# PL map plotting: spatial heatmap and position-extracted spectra

"""
    plot_pl_map(m::PLMap; kwargs...) -> (Figure, Axis, Heatmap)

Plot the PL intensity as a spatial heatmap.

# Keyword Arguments
- `colormap`: Colormap (default `:hot`)
- `colorrange`: Tuple `(lo, hi)` for color limits (auto if `nothing`)
- `xlabel`, `ylabel`, `title`: Axis labels
- `kwargs...`: Additional arguments passed to `heatmap!`

# Returns
`(Figure, Axis, Heatmap)` for customization (e.g. adding Colorbar).

Respects the active Makie theme (`set_theme!` / `with_theme`). Lab-convention
inside ticks are passed as Axis kwargs; change them on the returned Axis.

# Example
```julia
m = load_pl_map("data.lvm"; nx=51, ny=51, step_size=2.16)
fig, ax, hm = plot_pl_map(normalize_intensity(m); title="PL Intensity Map")
save("pl_map.pdf", fig)
```
"""
function plot_pl_map(m::PLMap; colormap=:hot, colorrange=nothing,
                     xlabel=nothing, ylabel=nothing,
                     title="PL Intensity Map", kwargs...)
    fig = Figure()
    xl = something(xlabel, OpticalSpectroscopy.xlabel(m))
    yl = something(ylabel, OpticalSpectroscopy.ylabel(m))
    # Lab convention (inside ticks) as Axis kwargs rather than an internal
    # with_theme(qps_theme()), which would wipe any theme the caller has
    # active. Change tick direction on the returned Axis if needed.
    ax = Axis(fig[1, 1], xlabel=xl, ylabel=yl, title=title,
              aspect=DataAspect(), xtickalign=1.0, ytickalign=1.0)

    hm_kwargs = Dict{Symbol,Any}(:colormap => colormap)
    if !isnothing(colorrange)
        hm_kwargs[:colorrange] = colorrange
    end
    merge!(hm_kwargs, Dict(kwargs))

    hm = heatmap!(ax, m.x, m.y, m.intensity; hm_kwargs...)
    Colorbar(fig[1, 2], hm, label=OpticalSpectroscopy.zlabel(m))

    return fig, ax, hm
end

"""
    plot_pl_spectra(m::PLMap, positions; kwargs...) -> (Figure, Axis)

Plot CCD spectra extracted at one or more spatial positions.

`positions` is a vector of `(x, y)` tuples (spatial coordinates in μm).
Each spectrum is overlaid with its position shown in the legend.

# Keyword Arguments
- `xlabel`: X-axis label (default "Pixel")
- `ylabel`: Y-axis label (default "Counts")
- `title`: Plot title

# Returns
`(Figure, Axis)` for further customization.

# Example
```julia
m = load_pl_map("data.lvm"; nx=51, ny=51)
fig, ax = plot_pl_spectra(m, [(0, 0), (10, 10), (-10, -10)])
save("spectra.pdf", fig)
```
"""
function plot_pl_spectra(m::PLMap, positions::AbstractVector;
                         xlabel="Pixel", ylabel="Counts", title="", kwargs...)
    fig = Figure()
    # Inside ticks as kwargs, not an internal with_theme — see plot_pl_map.
    ax = Axis(fig[1, 1], xlabel=xlabel, ylabel=ylabel, title=title,
              xtickalign=1.0, ytickalign=1.0)
    colors = Makie.wong_colors()

    for (i, pos) in enumerate(positions)
        px, py = pos
        spec = extract_spectrum(m; x=px, y=py)
        c = colors[mod1(i, length(colors))]
        label = "($(round(spec.x, digits=1)), $(round(spec.y, digits=1))) μm"
        lines!(ax, spec.pixel, spec.signal; color=c, label=label, kwargs...)
    end

    if length(positions) > 1
        axislegend(ax, position=:rt)
    end

    return fig, ax
end

# Convenience: single position without wrapping in a vector
plot_pl_spectra(m::PLMap, pos::Tuple{Real,Real}; kwargs...) =
    plot_pl_spectra(m, [pos]; kwargs...)
