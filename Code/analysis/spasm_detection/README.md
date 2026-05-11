# Spasm Detection Analysis Module

Workflows for detecting and analyzing spastic muscle contractions (involuntary or hyperreflexive EMG bursts).

## Functions

### `spasm_gait_stim_analysis.m`
Comprehensive spasm analysis during gait and stimulation conditions.

**Purpose:**
- Detects spasm events using envelope percentile thresholds
- Quantifies spasm frequency, duration, and magnitude across conditions
- Compares stimulus-evoked vs. baseline spasm rates
- Generates statistical comparisons and visualizations

**Usage:**
```matlab
results = spasm_gait_stim_analysis(TT_clean, snrValue, fs, varargin);
```

**Outputs:**
- `results.spasm_rate` – Spasms per minute by condition
- `results.spasm_duration` – Mean spasm burst duration
- `results.statistics` – t-tests and effect sizes (stimulus effect)
- `results.figures` – Comparison plots (raster, histogram)

**Algorithm:**
1. Extract active periods (SNR-based mask)
2. Compute envelope (TA_env, MG_env)
3. Adaptive threshold: `thr_spasm_TA = prctile(TA_env(is_act_TA), opt.SpasmPrcTA)`
4. Mark spasm events: `is_spasm_TA = TA_env > thr_spasm_TA`
5. Filter short bursts: `keep_long_runs(is_spasm_TA, min_duration)`
6. Compare across conditions (gait vs. spasm vs. stim on/off)

### `compare_spasm_stim_vs_nostim.m`
Focused comparison of spasm rates between stimulus-on and stimulus-off periods.

**Purpose:**
- Tests hypothesis: does stimulation affect spasm occurrence?
- Computes statistical significance (paired t-test, Mann-Whitney U)
- Reports effect size (Cohen's d, Hedges' g)

**Usage:**
```matlab
results = compare_spasm_stim_vs_nostim(TT, snr, fs, varargin);
```

**Outputs:**
- `results.spasm_rate_stim_on` – Spasms/min during stimulation
- `results.spasm_rate_stim_off` – Spasms/min without stimulation
- `results.p_value` – Statistical significance
- `results.effect_size` – Magnitude of difference

### `compare_files_xcorr.m`
Cross-correlation analysis between TA and MG activity patterns.

**Purpose:**
- Quantifies synchronization between muscles
- Detects phase-locked activity (e.g., antagonistic vs. co-contraction)
- Compares correlation patterns across conditions

**Usage:**
```matlab
xcorr_results = compare_files_xcorr(TA_env, MG_env, varargin);
```

**Outputs:**
- `xcorr_results.correlation` – Peak cross-correlation coefficient
- `xcorr_results.lag_samples` – Time lag at peak correlation
- `xcorr_results.lag_ms` – Lag in milliseconds

## Signal Basis for Spasm Detection

**Current canonical approach:** Envelope-based (TA_env, MG_env)
- Rectified signal: `abs(TA_filt)`
- Smoothed envelope: `smoothdata(..., 'gaussian', ceil(0.05*fs))`
- Advantage: Robust to noise, simple percentile-based threshold

**Alternative (legacy):** RMS-based with adaptive baseline
- Causal Butterworth bandpass (80–400 Hz or custom)
- Compute RMS over sliding window
- Threshold: `is_spasm = RMS > baseline_multiplier × moving_baseline`
- Advantage: Accounts for baseline drift, captures high-frequency activity

## Threshold Selection

| Method | Threshold Formula | Pros | Cons |
|--------|-------------------|------|------|
| Percentile | `prctile(TA_env, 75)` | Simple, robust | May miss subtle events |
| Fixed | `thr = 0.05 V` | Fast, reproducible | Requires subject-specific tuning |
| Adaptive | `thr = mean + 3×std` | Auto-calibrates | Sensitive to baseline drift |

**Recommended:** Use percentile (75th) on active-period envelope for consistency.

## Related Modules

- **Core** (`core/`): Provides preprocessed TT structure with envelopes
- **Analysis/Frequency** (`analysis/frequency_analysis/`): Spectrum-based spasm properties
- **Plotting** (`plotting/`): Visualization functions for spasm rasters and statistics
