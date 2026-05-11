# Plotting & Visualization Module

Functions for creating publication-quality figures and interactive visualizations.

## Functions

### Time-Domain Visualizations

#### `plot_filtered.m`
Plots preprocessed signals (raw, filtered, rectified) with activity masks.

**Usage:**
```matlab
plot_filtered(TT, muscle, varargin);
% muscle: 'TA' or 'MG'
```

**Output:**
- Time-domain signal (raw and filtered)
- Activity mask overlay
- Artifact markers (if detected)

#### `plot_filtered_labeled.m`
Enhanced version with condition labels and interval markers.

**Usage:**
```matlab
plot_filtered_labeled(TT, condition_intervals, varargin);
```

#### `plot_rect_and_env.m`
Plots rectified signal and smoothed envelope with spasm threshold.

**Usage:**
```matlab
plot_rect_and_env(TT, muscle, threshold, varargin);
```

**Output:**
- Rectified signal
- Smoothed envelope
- Horizontal spasm threshold line
- Marked spasm events

#### `Spasms_plot.m`
Specialized raster/timeline plot for spasm event visualization.

**Usage:**
```matlab
Spasms_plot(is_spasm_TA, is_spasm_MG, time_vector, varargin);
```

**Output:**
- TA spasm raster (top)
- MG spasm raster (bottom)
- Event count histogram (right)
- Shared time axis for synchronization

### Frequency-Domain Visualizations

#### `plot_PSD.m`
Plots power spectral density with band highlighting.

**Usage:**
```matlab
plot_PSD(signal, fs, varargin);
% Optional: plot_PSD(signal, fs, 'bands', [100, 500; 500, 1000])
```

**Output:**
- Linear and log-scale spectra (two subplots)
- Band-of-interest shading
- Frequency axis (0–2 kHz typical range)
- Statistics box (peak frequency, band power)

#### `plot_frequency_spectrum.m`
Alternative frequency visualization (FFT magnitude).

**Usage:**
```matlab
plot_frequency_spectrum(signal, fs, varargin);
```

#### `plot_amplitudes.m`
Bar plots comparing amplitude metrics across conditions.

**Usage:**
```matlab
plot_amplitudes(TA_env, MG_env, condition_labels, varargin);
```

**Output:**
- Mean ± std amplitude by condition (TA vs. MG)
- Statistical significance markers (*, **, ***)

### Correlation & Relationship Plots

#### `plot_TA_MG_correlation.m`
Scatter plots and correlation analysis between TA and MG signals.

**Usage:**
```matlab
plot_TA_MG_correlation(TA_env, MG_env, varargin);
```

**Output:**
- Scatter plot (TA vs. MG envelope)
- Regression line with R² value
- Pearson correlation coefficient
- Density contours (2D histogram)

## Visualization Best Practices

### Color Schemes
- TA (tibialis anterior): Blue (`[0 0.4 0.7]`)
- MG (medial gastrocnemius): Red (`[0.8 0 0]`)
- Active periods: Green overlay
- Spasms: Yellow/orange overlay
- Threshold lines: Black (dashed)

### Figure Organization
- **Time-domain plots:** Time on x-axis (seconds)
- **Frequency plots:** Frequency on x-axis (Hz), log scale for wide ranges
- **Legends:** Always include (upper right or separate legend box)
- **Labels:** Axis labels with units (e.g., "Amplitude (V)", "Frequency (Hz)")

### Publication-Ready Settings
```matlab
% Set figure properties for printing
set(gcf, 'PaperUnits', 'inches', 'PaperSize', [8, 6]);
set(gca, 'FontSize', 12, 'FontName', 'Arial');
set(gca, 'LineWidth', 1.5);
saveas(gcf, 'figure_name.pdf');  % Vector format for publications
```

### Interactive Features
- **Zoom/Pan:** Most figures support standard MATLAB zoom and pan tools
- **Data Cursor:** Hover over plot to see values
- **Linked axes:** Multiple subplots use shared x-axis for synchronization

## Common Workflows

**Visualization for data inspection:**
```matlab
TT = preprocess_and_label(filename);
figure('Position', [100, 100, 1200, 600]);
subplot(3, 2, 1); plot_filtered(TT, 'TA');
subplot(3, 2, 2); plot_filtered(TT, 'MG');
subplot(3, 2, 3); plot_rect_and_env(TT, 'TA', 0.05);
subplot(3, 2, 4); plot_rect_and_env(TT, 'MG', 0.05);
subplot(3, 2, 5); plot_PSD(TT.TA_raw, TT.fs, 'bands', [100, 500; 500, 1000]);
subplot(3, 2, 6); plot_TA_MG_correlation(TT.TA_env, TT.MG_env);
```

**Publication figure (spectral analysis):**
```matlab
plot_spectral_comparison_advanced(TT, 'Gait vs. Spasm');
```

**Statistics visualization (spasm comparison):**
```matlab
results = spasm_gait_stim_analysis(TT, snrValue, fs);
% Auto-generated figures in results.figures
```

## Figure Output Management

All figures are saved to `Figures/` directory (git-ignored):
- `.fig` – MATLAB native format (editable)
- `.pdf` – Vector format for publications
- `.png` – Raster format for presentations (300 dpi)

**Automatic file naming convention:**
```
Figures/
├── 2026-05-11_spasm_detection_Gait.fig
├── 2026-05-11_spectral_comparison_Spasm.pdf
└── 2026-05-11_correlation_TA_MG.png
```

## Related Modules

- **Analysis** (`analysis/`): Generates data for plotting
- **Config** (`config/`): UI (interface.mlapp) for interactive selections
