# Drawing layers (internal + public) and layout scaffolding

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
