# PL Map Exploration
#
# Runnable version of starter/templates/explore_plmap.jl with real data.
# Step through in the REPL to interactively inspect CCD spectra and find
# the PL peak pixel range.
#
# Ref: starter/templates/explore_plmap.jl

using QPSTools, GLMakie

PROJECT_ROOT = dirname(@__DIR__)
set_theme!(qps_theme())

# Config
filepath = joinpath(PROJECT_ROOT, "data", "PLmap", "CCDtmp_260129_111138.lvm")
STEP_SIZE = 5.0
PIXEL_RANGE = (850, 1200)
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0), (-10.0, 10.0)]

# Load + process
# m_raw = load_pl_map(filepath; nx=51, ny=51, step_size=STEP_SIZE)
m = load_pl_map(filepath; nx=51, ny=51, step_size=STEP_SIZE, pixel_range=PIXEL_RANGE)
m = subtract_background(m)
centers = peak_centers(m)
m = normalize(m)

# Display
fig = Figure(size=(1400, 400))

# (a) Spectra with integration window
ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts", title="Spectra")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m_raw; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
vspan!(ax1, PIXEL_RANGE..., color=(:blue, 0.1))
axislegend(ax1, position=:rt)

# (b) PL map with spectrum positions marked
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="PL Map", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
colors = Makie.wong_colors()
for (i, pos) in enumerate(positions)
    scatter!(ax2, [pos[1]], [pos[2]], color=colors[i], markersize=10,
        strokecolor=:white, strokewidth=1)
end
Colorbar(fig[1, 3], hm, label="Normalized PL")
colsize!(fig.layout, 2, Aspect(1, 1.0))

# (c) PL peak center map
ax3 = Axis(fig[1, 4], xlabel="X (μm)", ylabel="Y (μm)",
    title="Peak Center", aspect=DataAspect())
hm2 = heatmap!(ax3, xdata(m), ydata(m), centers; colormap=:viridis,
    nan_color=:transparent)
Colorbar(fig[1, 5], hm2, label="Peak Center (pixel)")
colsize!(fig.layout, 4, Aspect(1, 1.0))

display(fig)
DataInspector()
