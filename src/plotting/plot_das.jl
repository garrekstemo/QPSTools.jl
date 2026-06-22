# Decay-Associated Spectra (DAS) plotting

# Unicode subscript digits for tau labels
const _SUBSCRIPT_DIGITS = ('₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉')

function _subscript(n::Int)
    return join(_SUBSCRIPT_DIGITS[d + 1] for d in reverse(digits(n)))
end

"""
    _das_xlabel(result::GlobalFitResult)

Derive the DAS x-axis label from the spectral-axis tokens the fit carried from
its source matrix (`spectral_quantity`/`spectral_unit`), never from the data
magnitude. Falls back to the broadband-TA convention "Wavelength (nm)" when the
fit carried no tokens (e.g. fit from bare traces); callers can override with the
`xlabel` keyword.
"""
function _das_xlabel(result::GlobalFitResult)
    q = result.spectral_quantity
    isnothing(q) && return "Wavelength (nm)"
    return OpticalSpectroscopy.axis_label(q, something(result.spectral_unit, :dimensionless))
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

Requires that `result` was produced by `fit_global(matrix::TimeResolvedMatrix; ...)` so
that wavelength information is available. Errors otherwise.

# Keyword Arguments
- `xlabel::String`: X-axis label (derived from the fit's spectral-axis tokens if not given)
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
        error("plot_das requires wavelength axis (use fit_global with TimeResolvedMatrix input)")

    with_theme(qps_theme()) do
        fig = Figure()
        ax = Axis(fig[1, 1],
            xlabel=something(xlabel, _das_xlabel(result)),
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
        error("plot_das! requires wavelength axis (use fit_global with TimeResolvedMatrix input)")

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
