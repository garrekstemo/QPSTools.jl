# Decay-Associated Spectra (DAS) plotting

# Unicode subscript digits for tau labels
const _SUBSCRIPT_DIGITS = ('₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉')

function _subscript(n::Int)
    return join(_SUBSCRIPT_DIGITS[d + 1] for d in reverse(digits(n)))
end

"""
    _auto_xlabel(wavelengths::Vector{Float64})

Auto-detect x-axis label from wavelength range.
Values in [1200, 5000] are assumed to be wavenumbers (cm⁻¹); otherwise nm.
"""
function _auto_xlabel(wavelengths::Vector{Float64})
    wl_min, wl_max = extrema(wavelengths)
    if wl_min > 1200 && wl_max < 5000
        return "Wavenumber (cm⁻¹)"
    else
        return "Wavelength (nm)"
    end
end

"""
    _format_tau(tau::Float64)

Format a time constant for display: use integer if ≥ 10, one decimal otherwise.
"""
function _format_tau(tau::Float64)
    if tau >= 10
        return string(round(Int, tau))
    else
        return string(round(tau, digits=1))
    end
end

"""
    plot_das(result::GlobalFitResult; kwargs...) -> (Figure, Axis)

Plot decay-associated spectra as overlaid line plots, one per exponential component.

Each line shows the amplitude spectrum for one time constant, revealing which
spectral regions are associated with each dynamic process.

Requires that `result` was produced by `fit_global(matrix::TAMatrix; ...)` so
that wavelength information is available. Errors otherwise.

# Keyword Arguments
- `xlabel::String`: X-axis label (auto-detected from wavelength range if not given)
- `ylabel::String="Amplitude"`: Y-axis label
- `title::String="Decay-Associated Spectra"`: Plot title

# Returns
`(Figure, Axis)` for further customization.

# Example
```julia
result = fit_global(matrix; n_exp=2)
fig, ax = plot_das(result)
save("das.pdf", fig)
```
"""
function plot_das(result::GlobalFitResult;
    xlabel::Union{String,Nothing}=nothing,
    ylabel::String="Amplitude",
    title::String="Decay-Associated Spectra",
    kwargs...)

    isnothing(result.wavelengths) &&
        error("plot_das requires wavelength axis (use fit_global with TAMatrix input)")

    with_theme(qps_theme()) do
        fig = Figure()
        ax = Axis(fig[1, 1],
            xlabel=something(xlabel, _auto_xlabel(result.wavelengths)),
            ylabel=ylabel,
            title=title)

        plot_das!(ax, result; kwargs...)

        axislegend(ax, position=:rt)

        return fig, ax
    end
end

"""
    plot_das!(ax, result::GlobalFitResult; kwargs...)

Draw decay-associated spectra on an existing axis.

One line per exponential component, colored via `Makie.wong_colors()`,
labeled with the corresponding time constant.

# Example
```julia
fig = Figure()
ax = Axis(fig[1, 1])
plot_das!(ax, result)
```
"""
function plot_das!(ax, result::GlobalFitResult; kwargs...)
    isnothing(result.wavelengths) &&
        error("plot_das! requires wavelength axis (use fit_global with TAMatrix input)")

    d = das(result)  # n_exp × n_wavelengths
    n = size(d, 1)
    colors = Makie.wong_colors()

    for i in 1:n
        c = colors[mod1(i, length(colors))]
        label = "τ$(_subscript(i)) = $(_format_tau(result.taus[i])) ps"
        lines!(ax, result.wavelengths, d[i, :]; color=c, label=label, kwargs...)
    end

    hlines!(ax, 0; color=:black, linestyle=:dash)

    return nothing
end
