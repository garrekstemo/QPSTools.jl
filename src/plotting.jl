# Standardized plotting themes, layers, layouts, and public API for lab-wide use

# ============================================================================
# QPS STANDARD THEME
# ============================================================================

"""
    qps_theme()

Minimal standard theme for QPS package. Used internally by API functions.

- Ticks inside (ytickalign = 1.0)
"""
function qps_theme()
    return Theme(
        Axis=(
            xtickalign=1.0,
            ytickalign=1.0,
        ),
    )
end

# ============================================================================
# PUBLICATION THEMES
# ============================================================================

"""
    print_theme()

Theme for publication figures designed at final print dimensions.

Use with figures sized in physical units (points = 1/72 inch):
```julia
fig = Figure(size=(7 * 72, 4 * 72))  # 7" × 4" figure
```

Font sizes are chosen for direct 1:1 output (no scaling needed):
- Axis labels: 10pt
- Tick labels: 9pt
- Legend: 9pt
- Panel labels: 12pt bold (set via Label())

Line widths appropriate for print:
- Data lines: 1.5pt
- Spines/ticks: 1pt
"""
function print_theme()
    return Theme(
        Axis=(
            xlabelsize=10,
            ylabelsize=10,
            xticklabelsize=9,
            yticklabelsize=9,
            spinewidth=1,
            xtickalign=1.0,
            ytickalign=1.0,
            xticksize=4,
            yticksize=4,
            xtickwidth=1,
            ytickwidth=1,
            xgridvisible=false,
            ygridvisible=false,
        ), Legend=(
            labelsize=9,
            framevisible=false,
            rowgap=0,
            padding=(2, 2, 2, 2),
            patchsize=(10, 10),
        ), Scatter=(
            markersize=6,
        ), Lines=(
            linewidth=1.5,
        ), Errorbars=(
            whiskerwidth=4,
        ), Label=(
            fontsize=12,
        ), Text=(
            fontsize=9,
        ),
    )
end

"""
    poster_theme()

Extra-large theme for poster presentations.

Maximizes readability for poster viewing distances with:
- Very large fonts (24-28pt)
- Thick lines and bold styling
- High contrast appearance

# Font Sizes
- Axis labels: 28pt
- Tick labels: 24pt
- Legend labels: 24pt

# Usage
```julia
set_theme!(poster_theme())
fig = Figure(size=(1200, 900))  # Large figure for posters
```
"""
function poster_theme()
    return Theme(
        Figure=(
            size=(1200, 900),
            backgroundcolor=:white,
        ), Axis=(
            xlabelsize=28,
            ylabelsize=28,
            xticklabelsize=24,
            yticklabelsize=24,
            spinewidth=5,
            xtickalign=1.0,
            ytickalign=1.0,
            xticksize=15,
            yticksize=15,
            xtickwidth=4,
            ytickwidth=4,
            xgridvisible=false,
            ygridvisible=false,
        ), Legend=(
            labelsize=24,
            framevisible=false,
        ), Lines=(
            linewidth=6,
        ), Scatter=(
            markersize=12,
        ), Errorbars=(
            whiskerwidth=15,
        ),
    )
end

# ============================================================================
# COLOR SCHEMES & STYLING
# ============================================================================

"""
    lab_colors()

Standardized color palette for consistent lab figures.

Returns a dictionary of semantic color names mapped to hex colors.
Use these for consistent styling across all lab publications.

# Available Colors
- `:primary` - Main data color (dark blue)
- `:secondary` - Comparison data (orange)
- `:accent` - Highlight color (red)
- `:fit` - Fit lines (red)
- `:bare` - Bare molecule data (blue)
- `:cavity` - Cavity data (orange)
- `:kinetics` - Time-resolved data (green)

# Usage
```julia
colors = lab_colors()
lines!(ax, x, y, color=colors[:primary])
lines!(ax, x_fit, y_fit, color=colors[:fit], linestyle=:dash)
```
"""
const _LAB_COLORS = Dict(
    :primary => "#1f77b4",    # Dark blue
    :secondary => "#ff7f0e",  # Orange
    :accent => "#d62728",     # Red
    :fit => "#d62728",        # Red for fits
    :bare => "#1f77b4",       # Blue for bare molecules
    :cavity => "#ff7f0e",     # Orange for cavity
    :kinetics => "#2ca02c",   # Green for kinetics
    :positive => "#2ca02c",   # Green for positive signals
    :negative => "#d62728",   # Red for negative signals
    :neutral => "#7f7f7f",    # Gray for neutral/reference
)

lab_colors() = _LAB_COLORS

"""
    lab_linewidths()

Standardized line widths for different plot elements.

Returns a dictionary of semantic line width names.

# Available Widths
- `:data` - Main data lines (3pt)
- `:fit` - Fit lines (2pt)
- `:reference` - Reference/guide lines (1pt)
- `:thick` - Emphasis lines (5pt)

# Usage
```julia
lw = lab_linewidths()
lines!(ax, x, y, linewidth=lw[:data])
lines!(ax, x_fit, y_fit, linewidth=lw[:fit], linestyle=:dash)
```
"""
const _LAB_LINEWIDTHS = Dict(
    :data => 3,
    :fit => 2,
    :reference => 1,
    :thick => 5,
)

lab_linewidths() = _LAB_LINEWIDTHS

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

"""
    setup_poster_plot()

Quick setup for poster presentation plots.

# Usage
```julia
setup_poster_plot()
fig = Figure()
# ... create plot
save("poster_figure.png", fig, px_per_unit=2)  # High DPI for posters
```
"""
function setup_poster_plot()
    set_theme!(poster_theme())
    return nothing
end

# ============================================================================
# LAYER FUNCTIONS (internal, draw on existing Axis)
# ============================================================================

"""
    _draw_data!(ax, x, y; scatter=false, label=nothing, kwargs...)

Draw raw data as lines (default) or scatter points on an existing axis.
"""
function _draw_data!(ax, x, y; scatter::Bool=false, label=nothing, kwargs...)
    if scatter
        scatter!(ax, x, y; label=label, kwargs...)
    else
        lines!(ax, x, y; label=label, kwargs...)
    end
end

"""
    _draw_fit!(ax, x, y_fit; kwargs...)

Draw a fit curve on an existing axis. Uses fit color by default.
"""
function _draw_fit!(ax, x, y_fit; label="Fit", kwargs...)
    lines!(ax, x, y_fit; color=lab_colors()[:fit], label=label, kwargs...)
end

"""
    _draw_peak_annotation!(ax, result::MultiPeakFitResult; units="")

Draw a text annotation with peak center and width for a single-peak fit result.

When `units` is non-empty, uses `"nu_0 = {val} {units}"` format.
Otherwise uses `"center = {val}"`.
"""
function _draw_peak_annotation!(ax, result::MultiPeakFitResult; units::String="")
    length(result.peaks) >= 1 || return

    pk = result[1]
    center_val = pk[:center].value
    width_param = haskey(pk, :fwhm) ? :fwhm : :sigma
    width_val = pk[width_param].value
    width_err = pk[width_param].err

    if !isempty(units)
        annotation = "ν₀ = $(round(center_val, digits=1)) $units\n$(width_param) = $(round(width_val, digits=1)) ± $(round(width_err, digits=1)) $units"
    else
        annotation = "center = $(round(center_val, digits=1))\n$(width_param) = $(round(width_val, digits=1)) ± $(round(width_err, digits=1))"
    end
    text!(ax, 0.95, 0.95, text=annotation, align=(:right, :top), space=:relative)
end

"""
    _draw_fit_stats!(ax, result::MultiPeakFitResult)

Draw R² and RSS text annotation on an existing axis.
"""
function _draw_fit_stats!(ax, result::MultiPeakFitResult)
    stats_text = "R² = $(round(result.r_squared, digits=4))\nRSS = $(round(result.rss, digits=4))"
    text!(ax, 0.95, 0.95, text=stats_text, align=(:right, :top), space=:relative)
end

"""
    _draw_residuals!(ax, x, res; scatter=true)

Draw residuals on an existing axis with a zero reference line.
"""
function _draw_residuals!(ax, x, res; scatter::Bool=true)
    if scatter
        scatter!(ax, x, res)
    else
        lines!(ax, x, res)
    end
    hlines!(ax, 0; color=:black, linestyle=:dash)
end

"""
    _draw_region_indicator!(ax, region; center=nothing)

Draw a shaded region band and optional center line on a full spectrum context panel.
"""
function _draw_region_indicator!(ax, region::Tuple{Real,Real}; center=nothing)
    vspan!(ax, region..., color=(:gray, 0.2))
    if !isnothing(center)
        vlines!(ax, center, color=:red, linestyle=:dash, alpha=0.5)
    end
end

# ============================================================================
# LAYER FUNCTIONS (public, draw on existing Axis)
# ============================================================================

"""
    plot_peak_decomposition!(ax, result::MultiPeakFitResult; kwargs...)

Overlay individual peak curves, baseline, and composite fit on an existing axis.

# Keyword Arguments
- `show_peaks::Bool=true` — Show individual peak curves
- `show_baseline::Bool=true` — Show baseline
- `show_composite::Bool=true` — Show composite fit
- `peak_alpha::Real=0.3` — Transparency for individual peak fill
"""
function plot_peak_decomposition!(ax, result::MultiPeakFitResult;
    show_peaks::Bool=true,
    show_baseline::Bool=true,
    show_composite::Bool=true,
    peak_alpha::Real=0.3)
    x = result._x
    colors = lab_colors()

    # Composite fit
    if show_composite
        y_fit = predict(result)
        lines!(ax, x, y_fit, color=colors[:fit], label="Fit")
    end

    # Individual peaks
    if show_peaks && length(result.peaks) > 1
        peak_colors = Makie.wong_colors()
        for i in eachindex(result.peaks)
            y_peak = predict_peak(result, i)
            bl = predict_baseline(result)
            c = peak_colors[mod1(i, length(peak_colors))]
            lines!(ax, x, y_peak .+ bl, color=c, linestyle=:dash, label="Peak $i")
        end
    end

    # Baseline
    if show_baseline
        bl = predict_baseline(result)
        lines!(ax, x, bl, color=:gray, linestyle=:dot, label="Baseline")
    end
end

"""
    plot_peaks!(ax, peaks::Vector{PeakInfo}; kwargs...)

Add peak markers and labels to an existing axis.

Peaks are marked with short vertical ticks at the peak top and labeled
with their position in x-units. Labels are placed automatically to avoid overlaps.

# Keyword Arguments
- `marker::Symbol=:tick` — Marker style: `:tick` (short bar), `:vline`, `:point`, or `:region`
- `color` — Marker/connection color (default: `:red`)
- `textcolor` — Label text color (default: `:black`)
- `label::Bool=true` — Add position labels with automatic overlap avoidance
- `alpha::Real=0.5` — Marker transparency (for `:vline` and `:region`)

Note: Styling (fontsize, markersize, linewidth) follows Makie theme defaults.
"""
function plot_peaks!(ax, peaks::Vector{PeakInfo};
    marker::Symbol=:tick,
    color=:red,
    textcolor=:black,
    label::Bool=true,
    alpha::Real=0.5)

    isempty(peaks) && return

    # Compute layout dimensions from axis limits
    reset_limits!(ax)
    limits = ax.finallimits[]
    y_range = limits.widths[2]
    x_range = limits.widths[1]

    gap = y_range * 0.02        # space between peak top and bar bottom
    bar_height = y_range * 0.03 # bar length
    min_x_gap = x_range * 0.025 # x-distance threshold for staggering

    # Draw non-tick markers (tick is handled below with labels)
    if marker != :tick
        for p in peaks
            if marker == :vline
                vlines!(ax, p.position, color=color, linestyle=:dash, alpha=alpha)
            elseif marker == :point
                scatter!(ax, [p.position], [p.intensity], color=color)
            elseif marker == :region
                vspan!(ax, p.bounds..., color=(color, 0.2))
            end
        end
    end

    # Sort peaks by position for stagger computation
    sorted = sort(peaks, by=p -> p.position)

    # Compute label positions, staggering when peaks are close in x.
    text_slot = bar_height * 3
    label_ys = Float64[]
    for (i, p) in enumerate(sorted)
        base = p.intensity + gap + bar_height
        for j in (i-1):-1:1
            abs(p.position - sorted[j].position) < min_x_gap || break
            base = max(base, label_ys[j] + text_slot)
        end
        push!(label_ys, base)
    end

    # Draw bars and labels
    for (i, p) in enumerate(sorted)
        line_bottom = p.intensity + gap
        linesegments!(ax,
            [Point2f(p.position, line_bottom),
                Point2f(p.position, label_ys[i])],
            color=color, linewidth=0.75)

        if label
            text!(ax, p.position, label_ys[i],
                text=string(round(Int, p.position)),
                rotation=pi / 2,
                align=(:left, :center),
                color=textcolor)
        end
    end

    # Expand y-limits to make room for rotated labels above tallest bars
    if label
        max_label_y = maximum(label_ys)
        label_headroom = y_range * 0.15
        y_lo = limits.origin[2]
        ylims!(ax, y_lo, max(max_label_y + label_headroom, limits.origin[2] + y_range))
    end
end

# ============================================================================
# LAYOUT FUNCTIONS (internal, create Figure + Axes)
# ============================================================================

"""
    _layout_single(; xlabel, ylabel, title, xreversed) -> (Figure, Axis)

Single-panel layout wrapped in qps_theme().
"""
function _layout_single(; xlabel::String="X", ylabel::String="Y",
    title::String="", xreversed::Bool=false)
    fig = Figure()
    ax = Axis(fig[1, 1], xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)
    return fig, ax
end

"""
    _layout_stacked(; xlabel, ylabel, title, xreversed) -> (Figure, Axis, Axis)

Two-panel stacked layout: main panel on top, residuals below (25% height).
X-axes linked, zero row gap, x-decorations hidden on main axis.
"""
function _layout_stacked(; xlabel::String="X", ylabel::String="Y",
    title::String="", xreversed::Bool=false)
    fig = Figure(size=(600, 500))

    ax = Axis(fig[1, 1], ylabel=ylabel, title=title, xreversed=xreversed)
    hidexdecorations!(ax, grid=false)

    ax_res = Axis(fig[2, 1], xlabel=xlabel, ylabel="Residuals", xreversed=xreversed)

    linkxaxes!(ax, ax_res)
    rowgap!(fig.layout, 1, 0)
    rowsize!(fig.layout, 2, Relative(0.25))

    return fig, ax, ax_res
end

"""
    _layout_three_panel(; xlabel, ylabel, title, xreversed) -> (Figure, Axis, Axis, Axis)

Three-panel layout: context at top, fit in middle, residuals at bottom.
Fit and residuals panels have linked x-axes with zero gap.

Returns (fig, ax_context, ax_fit, ax_residuals).
"""
function _layout_three_panel(; xlabel::String="X", ylabel::String="Y",
    title::String="", xreversed::Bool=false)
    fig = Figure(size=(600, 750))

    # Panel (a): Context (full spectrum)
    ax_ctx = Axis(fig[1, 1],
        xlabel=xlabel,
        ylabel=ylabel,
        title=isempty(title) ? "(a) Full spectrum" : title,
        xreversed=xreversed
    )

    # Panel (b): Fit region
    ax_fit = Axis(fig[2, 1],
        ylabel=ylabel,
        title="(b) Peak fit",
        xreversed=xreversed,
        xticklabelsvisible=false,
        xlabelvisible=false,
    )

    # Panel (c): Residuals
    ax_res = Axis(fig[3, 1],
        xlabel=xlabel,
        ylabel="Residuals",
        xreversed=xreversed,
    )

    linkxaxes!(ax_fit, ax_res)
    rowgap!(fig.layout, 2, 0)

    return fig, ax_ctx, ax_fit, ax_res
end

# ============================================================================
# SPECTRUM PLOTTING: implementation + dispatch
# ============================================================================

# Title dispatch for AnnotatedSpectrum subtypes
_annotated_title(spec::FTIRSpectrum) = _ftir_title(spec)
_annotated_title(spec::RamanSpectrum) = _raman_title(spec)
_annotated_title(::AnnotatedSpectrum) = nothing

# Units dispatch for annotations
_annotated_units(::FTIRSpectrum) = "cm⁻¹"
_annotated_units(::RamanSpectrum) = "cm⁻¹"
_annotated_units(::AnnotatedSpectrum) = ""

"""
    _plot_spectrum_impl(x, y; xlabel, ylabel, title, xreversed,
                        fit, peaks, labels, residuals, context,
                        annotation_units, scatter_data, kwargs...)

Central routing function for all `plot_spectrum` dispatch methods.
Selects layout and fills with layer functions based on keyword arguments.
"""
function _plot_spectrum_impl(x, y;
    xlabel::String="X", ylabel::String="Y", title::String="",
    xreversed::Bool=false,
    fit::Union{MultiPeakFitResult,TASpectrumFit,Nothing}=nothing,
    peaks::Union{Vector{PeakInfo},Nothing}=nothing,
    labels::Bool=false,
    residuals::Bool=false,
    context::Union{Tuple,Nothing}=nothing,
    annotation_units::String="",
    scatter_data::Bool=false,
    kwargs...)

    with_theme(qps_theme()) do
        if !isnothing(fit) && !isnothing(context)
            # Three-panel: context + fit + residuals
            return _spectrum_three_panel(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, context=context, annotation_units=annotation_units,
                scatter_data=scatter_data, kwargs...)
        elseif !isnothing(fit) && residuals
            # Stacked: fit + residuals
            return _spectrum_stacked(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, annotation_units=annotation_units,
                scatter_data=scatter_data, kwargs...)
        elseif !isnothing(fit)
            # Single panel with fit overlay
            return _spectrum_with_fit(x, y;
                xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
                fit=fit, annotation_units=annotation_units,
                scatter_data=scatter_data, kwargs...)
        else
            # Single panel: survey or labeled
            fig, ax = _layout_single(; xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)
            _draw_data!(ax, x, y; scatter=scatter_data, kwargs...)

            if labels && isnothing(peaks)
                detected = find_peaks(x, y)
                plot_peaks!(ax, detected)
            elseif !isnothing(peaks)
                plot_peaks!(ax, peaks)
            end

            return fig, ax
        end
    end
end

# -- Three-panel layout helper --

function _spectrum_three_panel(x, y;
    xlabel, ylabel, title, xreversed,
    fit, context, annotation_units, scatter_data, kwargs...)

    # context = (full_x, full_y) or (full_x, full_y, region)
    full_x, full_y = context[1], context[2]
    region = length(context) >= 3 ? context[3] : nothing

    fig, ax_ctx, ax_fit, ax_res = _layout_three_panel(;
        xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed)

    # Panel (a): Full spectrum with region indicator
    _draw_data!(ax_ctx, full_x, full_y)
    if !isnothing(region)
        center = _fit_center(fit)
        _draw_region_indicator!(ax_ctx, region; center=center)
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
    fit, annotation_units, scatter_data, kwargs...)

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
    axislegend(ax, position=:rt)

    # Residuals panel
    res = y .- y_fit
    _draw_residuals!(ax_res, x, res; scatter=scatter_data)
    if fit isa MultiPeakFitResult
        _draw_fit_stats!(ax_res, fit)
    end

    return fig, ax, ax_res
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

_predict_fit(fit::MultiPeakFitResult, x) = predict(fit)
_predict_fit(fit::TASpectrumFit, x) = predict(fit, x)

_fit_center(fit::MultiPeakFitResult) = fit[1][:center].value
_fit_center(::TASpectrumFit) = nothing

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
- `labels::Bool=false`: Auto-detect and label peaks
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
    fit=nothing, peaks=nothing, labels::Bool=false,
    residuals::Bool=false, context=nothing, kwargs...)
    return _plot_spectrum_impl(x, y;
        xlabel=xlabel, ylabel=ylabel, title=title, xreversed=xreversed,
        fit=fit, peaks=peaks, labels=labels, residuals=residuals,
        context=context, kwargs...)
end

"""
    plot_spectrum(spec::AnnotatedSpectrum; kwargs...)

Plot an annotated spectrum (FTIR, Raman, etc.) with automatic axis labels and orientation.

# Keyword Arguments
- `fit`: Optional `MultiPeakFitResult` from `fit_peaks`
- `peaks`: Pre-computed peaks from `find_peaks`
- `labels::Bool=false`: Auto-detect and label peaks
- `residuals::Bool=false`: Show residuals panel (requires `fit`)
- `context::Bool=false`: Three-panel view with full spectrum context
- `title`: Override auto-generated title
- `kwargs...`: Passed to data drawing function

# Examples
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Survey view
fig, ax = plot_spectrum(spec)

# With auto-detected peak labels
fig, ax = plot_spectrum(spec; labels=true)

# With pre-computed peaks
peaks = find_peaks(spec)
fig, ax = plot_spectrum(spec; peaks=peaks)

# With fit overlay
result = fit_peaks(spec, (1950, 2150))
fig, ax = plot_spectrum(spec; fit=result)

# With fit and residuals
fig, ax, ax_res = plot_spectrum(spec; fit=result, residuals=true)

# Three-panel publication view
fig, ax_ctx, ax_fit, ax_res = plot_spectrum(spec; fit=result, residuals=true, context=true)
```
"""
function plot_spectrum(spec::AnnotatedSpectrum;
    fit::Union{MultiPeakFitResult,Nothing}=nothing,
    peaks::Union{Vector{PeakInfo},Nothing}=nothing,
    labels::Bool=false,
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

    # Auto-title from metadata if not provided
    t = isempty(title) ? something(_annotated_title(spec), "") : title

    # Build context tuple for three-panel view
    ctx = nothing
    if context && !isnothing(fit) && fit isa MultiPeakFitResult
        # Use fit region data for the zoomed panels, full data for context
        region = (minimum(fit._x), maximum(fit._x))
        ctx = (x, y, region)
        # For the fit panels, use the fit's own x/y data
        return _plot_spectrum_impl(fit._x, fit._y;
            xlabel=xl, ylabel=yl, title=t, xreversed=rev,
            fit=fit, peaks=peaks, labels=labels, residuals=true,
            context=ctx, annotation_units=units,
            scatter_data=true, kwargs...)
    end

    # For fit with scatter data (peak fit results have their own x/y)
    if !isnothing(fit) && fit isa MultiPeakFitResult
        return _plot_spectrum_impl(fit._x, fit._y;
            xlabel=xl, ylabel=yl, title=t, xreversed=rev,
            fit=fit, peaks=peaks, labels=labels, residuals=residuals,
            annotation_units=units, scatter_data=true, kwargs...)
    end

    return _plot_spectrum_impl(x, y;
        xlabel=xl, ylabel=yl, title=t, xreversed=rev,
        fit=fit, peaks=peaks, labels=labels, residuals=residuals,
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
const TAFitResult = Union{ExpDecayIRFFit,BiexpDecayFit,MultiexpDecayFit}

"""
    plot_kinetics(trace::TATrace; fit=nothing, residuals=true, kwargs...)

Plot a transient absorption kinetic trace, optionally with fit overlay and residuals.

When a fit is provided, automatically shows a two-panel layout with data+fit on top
and residuals below (can be disabled with `residuals=false`).

# Arguments
- `trace`: TATrace from `load_ta_trace`
- `fit`: Optional fit result (`ExpDecayIRFFit`, `BiexpDecayFit`, or `MultiexpDecayFit`)
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
matrix = load_ta_matrix("data/broadband-TA/")
fig, ax, hm = plot_ta_heatmap(matrix; colorrange=(-0.02, 0.02))
save("ta_heatmap.pdf", fig)
```
"""
function plot_ta_heatmap(matrix::TAMatrix; colormap=:RdBu, colorrange=nothing,
    xlabel=nothing, ylabel=nothing, title="ΔA(t, λ)", kwargs...)
    with_theme(qps_theme()) do
        fig = Figure(size=(800, 500))

        # Use interface functions for default labels
        xl = something(xlabel, QPSTools.xlabel(matrix))
        yl = something(ylabel, QPSTools.ylabel(matrix))

        ax = Axis(fig[1, 1], xlabel=xl, ylabel=yl, title=title)

        # Auto colorrange if not specified (symmetric around 0)
        if isnothing(colorrange)
            max_abs = maximum(abs, matrix.data)
            colorrange = (-max_abs, max_abs)
        end

        # Heatmap expects z with shape (length(x), length(y))
        # Our data is (n_time, n_wavelength), so we transpose
        hm = heatmap!(ax, matrix.wavelength, matrix.time, matrix.data';
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
matrix = load_ta_matrix("data/broadband-TA/")
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
matrix = load_ta_matrix("data/broadband-TA/")
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
