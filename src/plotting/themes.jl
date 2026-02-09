# Plotting themes, color palettes, and styling constants

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
