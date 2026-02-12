# Spectrum plotting: plot_spectrum dispatches, multi-spectrum views, generic plot_data

# ============================================================================
# SPECTRUM PLOTTING: implementation + dispatch
# ============================================================================

# Title dispatch for AnnotatedSpectrum subtypes
_annotated_title(spec::FTIRSpectrum) = _ftir_title(spec)
_annotated_title(spec::RamanSpectrum) = _raman_title(spec)
_annotated_title(spec::CavitySpectrum) = _cavity_title(spec)
_annotated_title(::AnnotatedSpectrum) = nothing

# Units dispatch for annotations
_annotated_units(::FTIRSpectrum) = "cm⁻¹"
_annotated_units(::RamanSpectrum) = "cm⁻¹"
_annotated_units(::CavitySpectrum) = "cm⁻¹"
_annotated_units(::AnnotatedSpectrum) = ""

"""
    _plot_spectrum_impl(x, y; xlabel, ylabel, title, xreversed,
                        fit, peaks, residuals, context,
                        annotation_units, scatter_data, kwargs...)

Central routing function for all `plot_spectrum` dispatch methods.
Selects layout and fills with layer functions based on keyword arguments.

# Layout selection priority
1. `fit + context`  → three-panel (full spectrum, fit region, residuals)
2. `fit + residuals` → stacked (fit region + residuals)
3. `fit + peaks`     → full spectrum with fit overlaid in its region
4. `fit` only        → zoomed to fit region (scatter + fit)
5. no `fit`          → survey with optional peak markers
"""
function _plot_spectrum_impl(x, y;
    xlabel::String="X", ylabel::String="Y", title::String="",
    xreversed::Bool=false,
    fit::Union{MultiPeakFitResult,TASpectrumFit,CavityFitResult,Nothing}=nothing,
    peaks::Union{Vector{PeakInfo},Nothing}=nothing,
    residuals::Bool=false,
    context::Union{Tuple,Nothing}=nothing,
    annotation_units::String="",
    scatter_data::Bool=false,
    kwargs...)

    # Warn about ignored keyword combinations
    if residuals && isnothing(fit)
        @warn "`residuals=true` requires a `fit` result — ignoring. Pass `fit=result` to show residuals."
    end

    with_theme(qps_theme()) do
        if !isnothing(fit) && !isnothing(context)
            # Three-panel: context + fit + residuals
            return _spectrum_three_panel(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, context=context, annotation_units=annotation_units,
                scatter_data=scatter_data, peaks=peaks, kwargs...)
        elseif !isnothing(fit) && residuals
            # Stacked: fit + residuals (peaks filtered to fit region)
            return _spectrum_stacked(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, annotation_units=annotation_units,
                scatter_data=scatter_data, peaks=peaks, kwargs...)
        elseif !isnothing(fit) && !isnothing(peaks)
            # Full spectrum with fit overlaid + all peaks
            return _spectrum_with_fit_overview(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, annotation_units=annotation_units,
                peaks=peaks, kwargs...)
        elseif !isnothing(fit)
            # Zoomed to fit region
            return _spectrum_with_fit(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, annotation_units=annotation_units,
                scatter_data=scatter_data, kwargs...)
        else
            # Single panel: survey with optional peak markers
            fig, ax = _layout_single(; xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)
            _draw_data!(ax, x, y; scatter=scatter_data, kwargs...)

            if !isnothing(peaks)
                plot_peaks!(ax, peaks)
            end

            return fig, ax
        end
    end
end

# -- Three-panel layout helper --

function _spectrum_three_panel(x, y;
    xlabel, ylabel, title, xreversed,
    fit, context, annotation_units, scatter_data, peaks=nothing, kwargs...)

    # context = (full_x, full_y) or (full_x, full_y, region)
    full_x, full_y = context[1], context[2]
    region = length(context) >= 3 ? context[3] : nothing

    fig, ax_ctx, ax_fit, ax_res = _layout_three_panel(;
        xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)

    # Panel (a): Full spectrum with region indicator and peaks
    _draw_data!(ax_ctx, full_x, full_y)
    if !isnothing(region)
        center = _fit_center(fit)
        _draw_region_indicator!(ax_ctx, region; center=center)
    end
    if !isnothing(peaks)
        plot_peaks!(ax_ctx, peaks)
    end

    # Panel (b): Fit region
    _draw_data!(ax_fit, x, y; scatter=true, label="Data")
    y_fit = _predict_fit(fit, x)
    _draw_fit!(ax_fit, x, y_fit)

    if fit isa MultiPeakFitResult
        plot_peak_decomposition!(ax_fit, fit; show_composite=false)
        _draw_peak_annotation!(ax_fit, fit; units=annotation_units)
    end

    # Panel (c): Residuals
    res = y .- y_fit
    _draw_residuals!(ax_res, x, res)
    if fit isa MultiPeakFitResult
        _draw_fit_stats!(ax_res, fit)
    end

    return fig, ax_ctx, ax_fit, ax_res
end

# -- Stacked layout helper --

function _spectrum_stacked(x, y;
    xlabel, ylabel, title, xreversed,
    fit, annotation_units, scatter_data, peaks=nothing, kwargs...)

    fig, ax, ax_res = _layout_stacked(;
        xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)

    # Main panel
    _draw_data!(ax, x, y; scatter=scatter_data, label="Data", kwargs...)
    y_fit = _predict_fit(fit, x)
    _draw_fit!(ax, x, y_fit)

    if fit isa MultiPeakFitResult
        plot_peak_decomposition!(ax, fit; show_composite=false)
        _draw_peak_annotation!(ax, fit; units=annotation_units)
    end
    filtered = _filter_peaks(peaks, x)
    if !isnothing(filtered) && !isempty(filtered)
        plot_peaks!(ax, filtered)
    end
    axislegend(ax, position=:rt)

    # Residuals panel
    res = y .- y_fit
    _draw_residuals!(ax_res, x, res; scatter=scatter_data)
    if fit isa MultiPeakFitResult
        _draw_fit_stats!(ax_res, fit)
    end

    return fig, ax, ax_res
end

# -- Full spectrum overview with fit overlaid --

function _spectrum_with_fit_overview(x, y;
    xlabel, ylabel, title, xreversed,
    fit, annotation_units, peaks, kwargs...)

    fig, ax = _layout_single(; xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)

    # Full spectrum as lines
    _draw_data!(ax, x, y; label="Data", kwargs...)

    # Fit curve in its region
    if fit isa MultiPeakFitResult
        _draw_fit!(ax, fit._x, predict(fit))
        plot_peak_decomposition!(ax, fit; show_composite=false)
        _draw_peak_annotation!(ax, fit; units=annotation_units)
    else
        y_fit = _predict_fit(fit, x)
        _draw_fit!(ax, x, y_fit)
    end

    # All peak markers (full range, no filtering)
    plot_peaks!(ax, peaks)
    axislegend(ax, position=:rt)

    return fig, ax
end

# -- Single panel with fit helper --

function _spectrum_with_fit(x, y;
    xlabel, ylabel, title, xreversed,
    fit, annotation_units, scatter_data, kwargs...)

    fig, ax = _layout_single(; xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)

    _draw_data!(ax, x, y; scatter=scatter_data, label="Data", kwargs...)
    y_fit = _predict_fit(fit, x)
    _draw_fit!(ax, x, y_fit)

    if fit isa MultiPeakFitResult
        plot_peak_decomposition!(ax, fit; show_composite=false)
        _draw_peak_annotation!(ax, fit; units=annotation_units)
    end
    axislegend(ax, position=:rt)

    return fig, ax
end

# -- Fit prediction helpers --

"""Filter peaks to those within the x-data range (avoids axis distortion)."""
function _filter_peaks(peaks::Vector{PeakInfo}, x)
    lo, hi = extrema(x)
    return filter(p -> lo <= p.position <= hi, peaks)
end
_filter_peaks(::Nothing, x) = nothing

_predict_fit(fit::MultiPeakFitResult, x) = predict(fit)
_predict_fit(fit::TASpectrumFit, x) = predict(fit, x)
_predict_fit(fit::CavityFitResult, x) = predict(fit, x)

_fit_center(fit::MultiPeakFitResult) = fit[1][:center].value
_fit_center(::TASpectrumFit) = nothing
_fit_center(::CavityFitResult) = nothing

# ============================================================================
# plot_spectrum dispatch methods
# ============================================================================

"""
    plot_spectrum(x::AbstractVector, y::AbstractVector; xlabel="Wavenumber (cm⁻¹)", ylabel="Absorbance", kwargs...)

Plot a spectrum from raw x/y vectors.

# Keyword Arguments
- `xlabel`, `ylabel`, `title`: Axis labels
- `xreversed::Bool=false`: Reverse x-axis
- `fit`: Optional fit result (MultiPeakFitResult or TASpectrumFit)
- `peaks`: Pre-computed peaks from `find_peaks` to display
- `residuals::Bool=false`: Show residuals panel (requires `fit`)
- `context`: Tuple `(full_x, full_y)` or `(full_x, full_y, region)` for three-panel view
- `kwargs...`: Passed to data drawing function

# Returns
- `(Figure, Axis)` for single-panel views
- `(Figure, Axis, Axis)` for fit + residuals
- `(Figure, Axis, Axis, Axis)` for three-panel context view
"""
function plot_spectrum(x::AbstractVector, y::AbstractVector;
    xlabel::String="Wavenumber (cm⁻¹)", ylabel::String="Absorbance",
    title::String="", xreversed::Bool=false,
    fit=nothing, peaks=nothing,
    residuals::Bool=false, context=nothing, kwargs...)
    return _plot_spectrum_impl(x, y;
        xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
        fit=fit, peaks=peaks, residuals=residuals,
        context=context, kwargs...)
end

"""
    plot_spectrum(spec::AnnotatedSpectrum; kwargs...)

Plot an annotated spectrum (FTIR, Raman, etc.) with automatic axis labels and orientation.

# Keyword Arguments
- `fit`: Optional `MultiPeakFitResult` from `fit_peaks`
- `peaks`: Pre-computed peaks from `find_peaks`
- `residuals::Bool=false`: Show residuals panel (requires `fit`)
- `context::Bool=false`: Three-panel view with full spectrum context
- `title`: Override auto-generated title
- `kwargs...`: Passed to data drawing function

# Layout selection
- `peaks` only → full spectrum + peak markers
- `fit` only → zoomed to fit region (scatter + fit + decomposition)
- `fit + peaks` → full spectrum with fit overlaid + all peaks
- `fit + residuals` → fit region with residuals panel below
- `fit + context` → three-panel (full spectrum, fit, residuals)

# Examples
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Survey view
fig, ax = plot_spectrum(spec)

# With pre-computed peaks
peaks = find_peaks(spec)
fig, ax = plot_spectrum(spec; peaks=peaks)

# With fit overlay (zoomed to fit region)
result = fit_peaks(spec, (1950, 2150))
fig, ax = plot_spectrum(spec; fit=result)

# Fit + peaks (full spectrum with fit overlaid)
fig, ax = plot_spectrum(spec; fit=result, peaks=peaks)

# With fit and residuals
fig, ax, ax_res = plot_spectrum(spec; fit=result, residuals=true)

# Three-panel publication view
fig, ax_ctx, ax_fit, ax_res = plot_spectrum(spec; fit=result, context=true)
```
"""
function plot_spectrum(spec::AnnotatedSpectrum;
    fit::Union{MultiPeakFitResult,CavityFitResult,Nothing}=nothing,
    peaks::Union{Vector{PeakInfo},Nothing}=nothing,
    residuals::Bool=false,
    context::Bool=false,
    title::String="",
    kwargs...)

    x = xdata(spec)
    y = ydata(spec)
    xl = QPSTools.xlabel(spec)
    yl = QPSTools.ylabel(spec)
    rev = xreversed(spec)
    units = _annotated_units(spec)

    if context && isnothing(fit)
        @warn "`context=true` requires a `fit` result — ignoring. Pass `fit=result` to use three-panel view."
    end

    # Auto-title from metadata if not provided
    t = isempty(title) ? something(_annotated_title(spec), "") : title

    # Build context tuple for three-panel view
    ctx = nothing
    if context && !isnothing(fit) && fit isa MultiPeakFitResult
        region = (minimum(fit._x), maximum(fit._x))
        ctx = (x, y, region)
        return _plot_spectrum_impl(fit._x, fit._y;
            xlabel=xl, ylabel=yl, title=t, xreversed=rev,
            fit=fit, peaks=peaks, residuals=true,
            context=ctx, annotation_units=units,
            scatter_data=true, kwargs...)
    end

    # fit + peaks (no residuals): full spectrum with fit overlaid
    if !isnothing(fit) && fit isa MultiPeakFitResult && !isnothing(peaks) && !residuals
        return _plot_spectrum_impl(x, y;
            xlabel=xl, ylabel=yl, title=t, xreversed=rev,
            fit=fit, peaks=peaks,
            annotation_units=units, kwargs...)
    end

    # fit region views: fit-only, fit+residuals, fit+peaks+residuals
    if !isnothing(fit) && fit isa MultiPeakFitResult
        return _plot_spectrum_impl(fit._x, fit._y;
            xlabel=xl, ylabel=yl, title=t, xreversed=rev,
            fit=fit, peaks=peaks, residuals=residuals,
            annotation_units=units, scatter_data=true, kwargs...)
    end

    return _plot_spectrum_impl(x, y;
        xlabel=xl, ylabel=yl, title=t, xreversed=rev,
        fit=fit, peaks=peaks, residuals=residuals,
        annotation_units=units, kwargs...)
end

"""
    plot_spectrum(spec::TASpectrum; fit=nothing, residuals=true, kwargs...)

Plot a transient absorption spectrum, optionally with fit and residuals.

# Arguments
- `spec`: TASpectrum from `load_ta_spectrum`
- `fit`: Optional `TASpectrumFit` from `fit_ta_spectrum`
- `residuals`: Show residuals panel when fit provided (default: true)
- `xlabel`, `ylabel`, `title`: Axis labels
- `kwargs...`: Additional arguments passed to data drawing

# Returns
Tuple of (figure, axis) or (figure, axis, residuals_axis) when residuals shown.

# Example
```julia
spec = load_ta_spectrum("data.lvm"; mode=:OD)
result = fit_ta_spectrum(spec)

fig, ax, ax_res = plot_spectrum(spec; fit=result)
save("spectrum.pdf", fig)
```
"""
function plot_spectrum(spec::TASpectrum;
    fit::Union{TASpectrumFit,Nothing}=nothing,
    residuals::Bool=true,
    xlabel::String="Wavenumber (cm⁻¹)", ylabel::String="ΔA",
    title::String="", kwargs...)
    return _plot_spectrum_impl(spec.wavenumber, spec.signal;
        xlabel=xlabel, ylabel=ylabel, title=title,
        fit=fit, residuals=(!isnothing(fit) && residuals),
        kwargs...)
end

# =============================================================================
# Generic plotting via AbstractSpectroscopyData interface
# =============================================================================

"""
    plot_data(data::AbstractSpectroscopyData; kwargs...)

Generic plotting function that works with any spectroscopy data type.

Uses the `AbstractSpectroscopyData` interface to automatically determine:
- X/Y data via `xdata()`, `ydata()`, `zdata()`
- Axis labels via `xlabel()`, `ylabel()`, `zlabel()`
- 1D vs 2D layout via `is_matrix()`

# Returns
For 1D data: `(figure, axis)`
For 2D data: `(figure, axis, heatmap)`

# Example
```julia
data = load_spectroscopy("measurement.lvm")
fig, ax = plot_data(data)
save("plot.pdf", fig)
```
"""
function plot_data(data::AbstractSpectroscopyData; colormap=:RdBu, colorrange=nothing, kwargs...)
    with_theme(qps_theme()) do
        if is_matrix(data)
            # 2D heatmap
            fig = Figure(size=(800, 500))
            ax = Axis(fig[1, 1], xlabel=QPSTools.xlabel(data), ylabel=QPSTools.ylabel(data))

            z = zdata(data)
            if isnothing(colorrange)
                max_abs = maximum(abs, z)
                colorrange = (-max_abs, max_abs)
            end

            # Transpose for heatmap (expects x x y, we have y x x)
            hm = heatmap!(ax, xdata(data), ydata(data), z';
                colormap=colormap, colorrange=colorrange, kwargs...)
            Colorbar(fig[1, 2], hm, label=zlabel(data))

            return fig, ax, hm
        else
            # 1D line plot
            fig = Figure()
            ax = Axis(fig[1, 1], xlabel=QPSTools.xlabel(data), ylabel=QPSTools.ylabel(data))
            lines!(ax, xdata(data), ydata(data); kwargs...)

            return fig, ax
        end
    end
end

# =============================================================================
# MULTI-SPECTRUM VIEWS
# =============================================================================

# Helper to extract x, y from various spectrum types
_spec_xy(spec::AnnotatedSpectrum) = (xdata(spec), ydata(spec))
_spec_xy(spec::TASpectrum) = (spec.wavenumber, spec.signal)
_spec_xy((x, y)::Tuple{AbstractVector,AbstractVector}) = (x, y)

_spec_xlabel(spec::AnnotatedSpectrum) = QPSTools.xlabel(spec)
_spec_xlabel(::TASpectrum) = "Wavenumber (cm⁻¹)"
_spec_xlabel(::Tuple) = "X"

_spec_ylabel(spec::AnnotatedSpectrum) = QPSTools.ylabel(spec)
_spec_ylabel(::TASpectrum) = "ΔA"
_spec_ylabel(::Tuple) = "Y"

_spec_xreversed(spec::AnnotatedSpectrum) = xreversed(spec)
_spec_xreversed(::Any) = false

"""
    plot_comparison(specs; labels=nothing, xlabel=nothing, ylabel=nothing, title="", kwargs...)

Plot multiple spectra overlaid on a single axis for comparison.

Accepts a vector of `AnnotatedSpectrum`, `TASpectrum`, or `(x, y)` tuples.
Uses Makie's wong color cycle for automatic coloring.

# Arguments
- `specs`: Vector of spectra to compare
- `labels`: Optional vector of label strings (one per spectrum)
- `xlabel`, `ylabel`: Axis labels (auto-detected from first spectrum if not provided)
- `title`: Plot title

# Returns
`(Figure, Axis)`

# Example
```julia
specs = search_ftir(solute="NH4SCN")
plot_comparison(specs; labels=["0.5M", "1.0M", "2.0M"])
```
"""
function plot_comparison(specs::AbstractVector;
    labels=nothing,
    xlabel=nothing,
    ylabel=nothing,
    title::String="",
    xreversed=nothing,
    kwargs...)

    with_theme(qps_theme()) do
        xl = something(xlabel, _spec_xlabel(first(specs)))
        yl = something(ylabel, _spec_ylabel(first(specs)))
        rev = something(xreversed, _spec_xreversed(first(specs)))

        fig, ax = _layout_single(; xlabel=xl, ylabel=yl, title=title, xreversed=rev)

        colors = Makie.wong_colors()
        for (i, spec) in enumerate(specs)
            x, y = _spec_xy(spec)
            color = colors[mod1(i, length(colors))]
            lbl = !isnothing(labels) && i <= length(labels) ? labels[i] : nothing
            _draw_data!(ax, x, y; color=color, label=lbl, kwargs...)
        end

        if !isnothing(labels)
            axislegend(ax, position=:rt)
        end

        return fig, ax
    end
end

"""
    plot_waterfall(specs; offset=0.1, labels=nothing, xlabel=nothing, ylabel=nothing, title="", kwargs...)

Plot multiple spectra stacked vertically with an offset between each.

Each spectrum is shifted by `i * offset` along the y-axis for visual separation.

# Arguments
- `specs`: Vector of spectra to display
- `offset`: Vertical offset between spectra (default: 0.1)
- `labels`: Optional vector of label strings
- `xlabel`, `ylabel`: Axis labels
- `title`: Plot title

# Returns
`(Figure, Axis)`

# Example
```julia
specs = search_ftir(solute="NH4SCN")
fig, ax = plot_waterfall(specs; offset=0.3, labels=["0.5M", "1.0M", "2.0M"])
```
"""
function plot_waterfall(specs::AbstractVector;
    offset::Real=0.1,
    labels=nothing,
    xlabel=nothing,
    ylabel=nothing,
    title::String="",
    xreversed=nothing,
    kwargs...)

    with_theme(qps_theme()) do
        xl = something(xlabel, _spec_xlabel(first(specs)))
        yl = something(ylabel, _spec_ylabel(first(specs)))
        rev = something(xreversed, _spec_xreversed(first(specs)))

        fig, ax = _layout_single(; xlabel=xl, ylabel=yl, title=title, xreversed=rev)

        colors = Makie.wong_colors()
        for (i, spec) in enumerate(specs)
            x, y = _spec_xy(spec)
            color = colors[mod1(i, length(colors))]
            y_shifted = y .+ (i - 1) * offset
            lbl = !isnothing(labels) && i <= length(labels) ? labels[i] : nothing
            _draw_data!(ax, x, y_shifted; color=color, label=lbl, kwargs...)
        end

        if !isnothing(labels)
            axislegend(ax, position=:rt)
        end

        return fig, ax
    end
end
