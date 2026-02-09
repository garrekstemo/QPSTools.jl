# Kinetics plotting, TAMatrix visualization (heatmap, spectra extraction)

# ============================================================================
# KINETICS PLOTTING
# ============================================================================

"""
    plot_kinetics(time, signal; xlabel="Time (ps)", ylabel="ΔA", title="", kwargs...)

Create a standardized kinetics plot from raw vectors.

# Returns
Tuple of (figure, axis) for further customization.
"""
function plot_kinetics(time, signal; xlabel="Time (ps)", ylabel="ΔA", title="", kwargs...)
    with_theme(qps_theme()) do
        fig, ax = _layout_single(; xlabel=xlabel, ylabel=ylabel, title=title)
        _draw_data!(ax, time, signal; kwargs...)
        return fig, ax
    end
end

# Union type for all TA fit results
const TAFitResult = Union{ExpDecayFit,MultiexpDecayFit}

"""
    plot_kinetics(trace::TATrace; fit=nothing, residuals=true, kwargs...)

Plot a transient absorption kinetic trace, optionally with fit overlay and residuals.

When a fit is provided, automatically shows a two-panel layout with data+fit on top
and residuals below (can be disabled with `residuals=false`).

# Arguments
- `trace`: TATrace from `load_ta_trace`
- `fit`: Optional fit result (`ExpDecayFit`, `MultiexpDecayFit`, or `GlobalFitResult`)
- `residuals`: Show residuals panel when fit provided (default: true)
- `xlabel`, `ylabel`, `title`: Axis labels
- `kwargs...`: Additional arguments passed to data `scatter!`

# Returns
- `(Figure, Axis)` when no fit or `residuals=false`
- `(Figure, Axis, Axis)` when fit provided with `residuals=true`

# Example
```julia
trace = load_ta_trace("data.lvm"; mode=:OD)
result = fit_exp_decay(trace)

fig, ax, ax_res = plot_kinetics(trace; fit=result)
save("kinetics.pdf", fig)
```
"""
function plot_kinetics(trace::TATrace; fit::Union{TAFitResult,Nothing}=nothing,
    residuals::Bool=true,
    xlabel="Time (ps)", ylabel="ΔA", title="", kwargs...)

    with_theme(qps_theme()) do
        show_residuals = !isnothing(fit) && residuals

        if show_residuals
            fig, ax, ax_res = _layout_stacked(; xlabel=xlabel, ylabel=ylabel, title=title)

            # Determine fit region (IRF fits use all data, non-IRF only t >= t0)
            fit_mask = _kinetics_fit_mask(fit, trace)

            # Main panel
            _draw_data!(ax, trace.time, trace.signal; scatter=true, label="Data", kwargs...)
            y_fit = predict(fit, trace)
            _draw_fit!(ax, trace.time[fit_mask], y_fit[fit_mask])
            axislegend(ax, position=:rt)

            # Residuals panel
            resid = trace.signal .- y_fit
            _draw_residuals!(ax_res, trace.time[fit_mask], resid[fit_mask])

            return fig, ax, ax_res
        else
            fig, ax = _layout_single(; xlabel=xlabel, ylabel=ylabel, title=title)

            if isnothing(fit)
                _draw_data!(ax, trace.time, trace.signal; label="Data", kwargs...)
            else
                _draw_data!(ax, trace.time, trace.signal; scatter=true, label="Data", kwargs...)
                y_fit = predict(fit, trace)
                _draw_fit!(ax, trace.time, y_fit)
                axislegend(ax, position=:rt)
            end

            return fig, ax
        end
    end
end

"""Compute fit mask for kinetics: IRF fits use all data, non-IRF only t >= t0."""
function _kinetics_fit_mask(fit, trace)
    t0 = fit.t0
    has_irf = hasproperty(fit, :sigma) ? !isnan(fit.sigma) : true
    if has_irf
        return trues(length(trace.time))
    else
        return trace.time .>= t0
    end
end

# =============================================================================
# TAMatrix plotting
# =============================================================================

"""
    plot_ta_heatmap(matrix::TAMatrix; colormap=:RdBu, colorrange=nothing, kwargs...)

Create a 2D heatmap of transient absorption data (time x wavelength).

# Arguments
- `matrix`: TAMatrix from `load_ta_matrix`
- `colormap`: Colormap for heatmap (default: `:RdBu`, diverging red-blue)
- `colorrange`: Symmetric color range tuple, e.g., `(-0.02, 0.02)`. Auto-detected if not specified.
- `xlabel`: X-axis label (default: auto-detected based on wavelength units)
- `ylabel`: Y-axis label (default: "Time (ps)")
- `title`: Plot title
- `kwargs...`: Additional arguments passed to `heatmap!`

# Returns
Tuple of (figure, axis, heatmap_object) for further customization.

# Example
```julia
matrix = load_ta_matrix("data/CCD/")
fig, ax, hm = plot_ta_heatmap(matrix; colorrange=(-0.02, 0.02))
save("ta_heatmap.pdf", fig)
```
"""
function plot_ta_heatmap(matrix::TAMatrix; colormap=:RdBu, colorrange=nothing,
    xlabel=nothing, ylabel=nothing, title="ΔA(t, λ)", kwargs...)
    with_theme(qps_theme()) do
        fig = Figure(size=(800, 500))

        # Convention: time on x-axis, wavelength on y-axis
        xl = something(xlabel, QPSTools.ylabel(matrix))  # "Time (ps)"
        yl = something(ylabel, QPSTools.xlabel(matrix))  # "Wavelength (nm)"

        ax = Axis(fig[1, 1], xlabel=xl, ylabel=yl, title=title)

        # Auto colorrange if not specified (symmetric around 0)
        if isnothing(colorrange)
            max_abs = maximum(abs, matrix.data)
            colorrange = (-max_abs, max_abs)
        end

        # Heatmap expects z with shape (length(x), length(y))
        # Our data is (n_time, n_wavelength) = (length(x), length(y)), no transpose needed
        hm = heatmap!(ax, matrix.time, matrix.wavelength, matrix.data;
            colormap=colormap, colorrange=colorrange, kwargs...)

        Colorbar(fig[1, 2], hm, label="ΔA")

        return fig, ax, hm
    end
end

"""
    plot_kinetics(matrix::TAMatrix; λ, kwargs...)

Plot kinetic traces extracted from a TAMatrix at one or more wavelengths.

# Arguments
- `matrix`: TAMatrix from `load_ta_matrix`
- `λ`: Single wavelength or vector of wavelengths to extract
- `xlabel`, `ylabel`, `title`: Axis labels
- `kwargs...`: Additional arguments passed to `lines!`

# Returns
Tuple of (figure, axis) for further customization.

# Example
```julia
matrix = load_ta_matrix("data/CCD/")
fig, ax = plot_kinetics(matrix; λ=[700, 750, 800, 850])
save("kinetics.pdf", fig)
```
"""
function plot_kinetics(matrix::TAMatrix; λ::Union{Real,AbstractVector},
    xlabel="Time (ps)", ylabel="ΔA", title="", kwargs...)
    with_theme(qps_theme()) do
        fig = Figure()
        ax = Axis(fig[1, 1], xlabel=xlabel, ylabel=ylabel, title=title)

        wavelengths = λ isa Real ? [λ] : collect(λ)
        colors = Makie.wong_colors()

        for (i, wl) in enumerate(wavelengths)
            trace = matrix[λ=wl]
            actual_wl = trace.wavelength
            color = colors[mod1(i, length(colors))]
            lines!(ax, trace.time, trace.signal; color=color,
                label="$(round(Int, actual_wl)) nm", kwargs...)
        end

        if length(wavelengths) > 1
            axislegend(ax, position=:rt)
        end

        return fig, ax
    end
end

"""
    plot_spectra(matrix::TAMatrix; t, kwargs...)

Plot transient spectra extracted from a TAMatrix at one or more time delays.

# Arguments
- `matrix`: TAMatrix from `load_ta_matrix`
- `t`: Single time delay or vector of time delays to extract (ps)
- `xlabel`, `ylabel`, `title`: Axis labels
- `kwargs...`: Additional arguments passed to `lines!`

# Returns
Tuple of (figure, axis) for further customization.

# Example
```julia
matrix = load_ta_matrix("data/CCD/")
fig, ax = plot_spectra(matrix; t=[-0.5, 0.1, 0.5, 1.0, 3.0])
save("spectra.pdf", fig)
```
"""
function plot_spectra(matrix::TAMatrix; t::Union{Real,AbstractVector},
    xlabel=nothing, ylabel="ΔA", title="", kwargs...)
    with_theme(qps_theme()) do
        fig = Figure()

        # Use interface function for default x-label
        xl = something(xlabel, QPSTools.xlabel(matrix))

        ax = Axis(fig[1, 1], xlabel=xl, ylabel=ylabel, title=title)

        times = t isa Real ? [t] : collect(t)
        colors = Makie.wong_colors()

        for (i, time_val) in enumerate(times)
            spec = matrix[t=time_val]
            actual_t = spec.time_delay
            color = colors[mod1(i, length(colors))]
            lines!(ax, spec.wavenumber, spec.signal; color=color,
                label="$(round(actual_t, digits=2)) ps", kwargs...)
        end

        hlines!(ax, 0; color=:black, linestyle=:dash, linewidth=0.5)

        if length(times) > 1
            axislegend(ax, position=:rt)
        end

        return fig, ax
    end
end
