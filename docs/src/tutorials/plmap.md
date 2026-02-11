# Tutorial: PL / Raman Mapping Analysis

This tutorial walks through a complete PL mapping workflow for CCD raster scan data. You will load a spatial map, inspect individual spectra to identify the PL emission, compare three processing approaches, and produce a publication-quality normalized PL intensity map.

The data is a 51x51 spatial grid where each point has a full 2000-pixel CCD spectrum (e.g., MoSe2 flakes measured with a Raman/PL microscope and Suruga stage).

## Prerequisites

```julia
julia --project=.
using Revise
using QPSTools
using CairoMakie
using Statistics
```

You need a CCD raster scan `.lvm` file. The test data shipped with QPSTools is at `data/PLmap/CCDtmp_260129_111138.lvm`.

## 1. Load and Inspect the Raw Data

Load the CCD raster scan. Each of the 2601 spatial points (51x51 grid) has a full 2000-pixel CCD spectrum. `step_size` is the Suruga stage step in micrometers.

```julia
filepath = "data/PLmap/CCDtmp_260129_111138.lvm"
m = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)
println(m)
```

```
PLMap
  Grid:     51 x 51 spatial points
  Pixels:   2000 per spectrum
  X range:  -54.0 to 54.0 μm
  Y range:  -54.0 to 54.0 μm
  Source:   CCDtmp_260129_111138.lvm
```

The `PLMap` stores the full spectral cube (51 x 51 x 2000) and an integrated intensity map. By default, all 2000 pixels are summed to produce the intensity — but this is rarely what you want (see Step 3).

## 2. Inspect Spectra to Find the PL Emission

Before making a map, look at individual spectra to understand what the CCD is recording. This tells you which pixel range contains the PL emission.

A typical CCD spectrum from a Raman/PL measurement has:
- **Low pixels**: strong laser/Rayleigh scatter (dominates total counts)
- **Middle pixels**: Raman bands and/or PL emission
- **High pixels**: baseline noise

If you integrate over ALL pixels, the laser scatter dominates and the PL signal is buried. You need to identify the PL peak pixel range.

```julia
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig_spec, ax_spec = plot_pl_spectra(m, positions;
    title="Full CCD Spectra at Selected Positions")
save("figures/spectra_full.png", fig_spec)
```

Zoom into the PL region to identify the peak pixel range:

```julia
fig_zoom, ax_zoom = plot_pl_spectra(m, positions;
    title="PL Emission Region (zoomed)")
xlims!(ax_zoom, 900, 1150)
save("figures/spectra_pl_region.png", fig_zoom)
```

From the zoomed plot, the PL emission sits around pixels 950-1100. This is the range we integrate over.

You can also extract a single spectrum programmatically:

```julia
spec = extract_spectrum(m; x=0.0, y=0.0)
spec.pixel   # pixel indices
spec.signal  # CCD counts
spec.x, spec.y  # actual spatial position (nearest grid point)
```

## 3. Three Processing Approaches

We compare three increasingly refined ways to build a PL intensity map. Each one improves contrast by removing a different source of background.

### Approach 1: Raw (all pixels)

Sum all 2000 CCD pixels per spectrum. The laser/Rayleigh scatter at low pixel numbers dominates (~1200 counts/pixel vs ~50-100 for PL). Since the scatter is roughly uniform across the map, it acts as a large DC offset that compresses the PL contrast into a narrow range.

```julia
m_raw = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)
```

### Approach 2: PL pixel range only

Sum only the PL emission pixels (950-1100). This removes the laser scatter, dramatically improving contrast. However, the CCD still records a per-pixel baseline (dark current, readout noise, diffuse scatter) even at off-flake positions, so the background is not zero.

```julia
m_pr = load_pl_map(filepath; nx=51, ny=51, step_size=2.16, pixel_range=(950, 1100))
```

### Approach 3: Pixel range + background subtraction

First subtract a reference spectrum (averaged from off-flake positions) from every grid point, then integrate over the PL range. This zeros out the per-pixel baseline so off-flake regions have near-zero intensity.

```julia
m_bg = subtract_background(m_pr)
```

The auto mode averages the bottom corners of the map (away from flake and any top-row artifacts). You can also pass explicit positions:

```julia
m_bg = subtract_background(m_pr; positions=[(-40, -40), (40, -40)])
```

### Normalize and compare

After normalization to [0, 1], approaches 2 and 3 look visually identical because `normalize()` already removes the DC offset via min-max scaling. The background subtraction matters when you need absolute PL intensities (e.g., comparing samples or correlating with excitation power).

```julia
m_raw_norm = normalize(m_raw)
m_pr_norm = normalize(m_pr)
m_bg_norm = normalize(m_bg)
```

## 4. SNR Analysis

Quantify the improvement from each processing step. SNR = (mean\_flake - mean\_background) / std\_background.

```julia
on_x, on_y = 21:31, 21:31   # center of map (on flake)
off_x, off_y = 1:10, 1:10   # bottom-left corner (off flake)

for (name, map) in [("Raw (all pixels)", m_raw),
                     ("PL pixel range", m_pr),
                     ("Pixel range + bg sub", m_bg)]
    sig = mean(map.intensity[on_x, on_y])
    bg = mean(map.intensity[off_x, off_y])
    bg_std = std(map.intensity[off_x, off_y])
    snr = (sig - bg) / bg_std
    println(rpad(name, 28), "SNR = ", round(snr, digits=1))
end
```

Typical results:

| Processing | SNR |
|-----------|-----|
| Raw (all pixels) | ~7.5 |
| PL pixel range | ~70 |
| Pixel range + bg sub | ~70 |

The pixel range gives ~10x improvement over raw. Background subtraction gives identical SNR because it only shifts the mean (subtracting a constant from every point doesn't change the contrast or variance). Its value is in producing physically meaningful absolute intensities, not in SNR.

## 5. Publication-Quality PL Map

Use the pixel-range approach with normalization for the cleanest result:

```julia
fig, ax, hm = plot_pl_map(m_pr_norm; title="PL Intensity Map")
save("figures/pl_map.pdf", fig)
```

`plot_pl_map` returns `(Figure, Axis, Heatmap)`. You can customize the colormap and range:

```julia
fig, ax, hm = plot_pl_map(m_pr_norm;
    colormap=:inferno,
    colorrange=(0.2, 1.0),
    title="MoSe2 PL Map"
)
```

### Multi-panel comparison

```julia
fig = Figure(size=(1400, 450))
ax1 = Axis(fig[1, 1], xlabel="X (μm)", ylabel="Y (μm)",
           title="Raw (all pixels)", aspect=DataAspect())
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
           title="PL pixel range only", aspect=DataAspect())
ax3 = Axis(fig[1, 3], xlabel="X (μm)", ylabel="Y (μm)",
           title="Pixel range + background sub", aspect=DataAspect())

hm1 = heatmap!(ax1, m_raw_norm.x, m_raw_norm.y, m_raw_norm.intensity; colormap=:hot)
hm2 = heatmap!(ax2, m_pr_norm.x, m_pr_norm.y, m_pr_norm.intensity; colormap=:hot)
hm3 = heatmap!(ax3, m_bg_norm.x, m_bg_norm.y, m_bg_norm.intensity; colormap=:hot)
Colorbar(fig[1, 4], hm3, label="Normalized PL")

save("figures/pl_comparison.pdf", fig)
```

## Summary

| Step | Function | What it does |
|------|----------|-------------|
| Load | `load_pl_map(path; nx, ny, step_size)` | Load CCD raster scan into `PLMap` |
| Inspect | `plot_pl_spectra(m, positions)` | View CCD spectra at spatial positions |
| Extract | `extract_spectrum(m; x, y)` | Pull spectrum at a position |
| Pixel range | `load_pl_map(...; pixel_range=(lo, hi))` | Integrate only PL emission pixels |
| Background | `subtract_background(m)` | Remove per-pixel CCD baseline |
| Normalize | `normalize(m)` | Scale intensity to [0, 1] |
| Plot | `plot_pl_map(m)` | Spatial heatmap with colorbar |

## Next Steps

- Experiment with different `pixel_range` values to isolate Raman bands vs PL emission
- Use `extract_spectrum` to compare spectra at high-intensity and low-intensity positions
- Try different colormaps (`:hot`, `:inferno`, `:viridis`) for different visual emphasis
