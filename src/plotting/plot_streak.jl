# Streak-camera PL plotting: wavelength × time heatmap
#
# HamamatsuStreakFiles' Makie extension provides the `convert_arguments`
# heatmap conversion (ascending-wavelength flip included); it is always
# active here because QPSTools depends on both Makie and
# HamamatsuStreakFiles. This wrapper adds the lab-convention axis styling,
# axis labels, and colorbar.

_streak_axis_label(name, unit) = isempty(unit) ? name : string(name, " (", unit, ")")

"""
    plot_streak_pl(s; kwargs...) -> (Figure, Axis, Heatmap)

Plot a streak-camera PL image as a wavelength × time heatmap.

Accepts a [`StreakPL`](@ref) (from [`load_streak_pl`](@ref)) or a raw
`StreakImage`. Wavelength is plotted ascending regardless of on-disk order.

# Keyword Arguments
- `colormap`: Colormap (default `:hot`)
- `colorrange`: Tuple `(lo, hi)` for color limits (auto if `nothing`)
- `xlabel`, `ylabel`, `title`: Axis labels (units default from the file header)
- `kwargs...`: Additional arguments passed to `heatmap!`

# Returns
`(Figure, Axis, Heatmap)` for customization.

Respects the active Makie theme (`set_theme!` / `with_theme`). Lab-convention
inside ticks are passed as Axis kwargs; change them on the returned Axis.

# Example
```julia
pl = load_streak_pl("data/PL/15K.img"; temperature="15K")
fig, ax, hm = plot_streak_pl(pl; colorrange=(0, 500))
save("figures/streak_15K.png", fig)
```
"""
function plot_streak_pl(img::StreakImage; colormap=:hot, colorrange=nothing,
                        xlabel=nothing, ylabel=nothing, title="", kwargs...)
    fig = Figure()
    xl = something(xlabel, _streak_axis_label("Wavelength", img.xunits))
    yl = something(ylabel, _streak_axis_label("Time", img.yunits))
    # Inside ticks as Axis kwargs, not an internal with_theme(qps_theme()),
    # which would wipe any theme the caller has active.
    ax = Axis(fig[1, 1], xlabel=xl, ylabel=yl, title=title,
              xtickalign=1.0, ytickalign=1.0)

    hm_kwargs = Dict{Symbol,Any}(:colormap => colormap)
    if !isnothing(colorrange)
        hm_kwargs[:colorrange] = colorrange
    end
    merge!(hm_kwargs, Dict(kwargs))

    hm = heatmap!(ax, img; hm_kwargs...)
    Colorbar(fig[1, 2], hm, label=img.zunits)

    return fig, ax, hm
end

plot_streak_pl(s::StreakPL; kwargs...) = plot_streak_pl(s.data; kwargs...)
