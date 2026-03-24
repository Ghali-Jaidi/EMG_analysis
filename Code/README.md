# EMG Analysis Pipeline

A comprehensive MATLAB pipeline for analyzing electromyography (EMG) signals from injured and uninjured subjects, with support for detecting spasms, gait, and stimulus-induced patterns in two muscle channels (TA: tibialis anterior, MG: medial gastrocnemius).

## Overview

This project processes raw EMG recordings to:
- **Preprocess & label** raw signals (filtering, artifact removal, activity detection)
- **Extract features** (amplitude, duration, correlation between channels)
- **Detect spasms** and classify them by stimulus state (stimulated vs. unstimulated)
- **Compare groups** (injured vs. uninjured) and conditions (stim ON vs. OFF)

---

## Core Pipeline

### 1. **Preprocessing & Labeling** (`preprocess_and_label.m`)
**Purpose**: Convert raw 3-channel EMG data into clean, labeled signals with activity masks.

**Input**: Raw MAT file with fields `data__chan_1_rec_X`, `data__chan_2_rec_X`, `data__chan_3_rec_X` (X = recording ID)

**Process**:
- Load & time-align three channels (TA, MG, Ch3/stimulus trigger)
- Robust scaling (median-based normalization)
- Apply bandpass (50–500 Hz) and notch filters (50 Hz)
- Compute rectified envelope
- Detect "quiet" (rest) periods using percentile thresholds
- Detect "active" periods using SNR-based methodology
- Merge nearby intervals and filter by duration

**Output**: 
- `TT_clean`: timetable with scaled signals, filtered signals, envelope, masks
- `snrValue`: struct with activity masks (`is_act`, `is_act_MG`, `is_rest`, `is_rest_TA`, `is_rest_MG`)
- `meta`: recording metadata (recID, file path)
- `preview`: diagnostic plot (optional)

**Key Parameters** (in `default_emg_parameters.m`):
- `envWindowMs`: envelope window duration (default 3 ms)
- `thresholds`: percentiles for quiet detection (default [40 50])
- `act_prc`: TA activity percentile threshold (default 70)
- `act_prc_MG`: MG activity percentile threshold (default 50)
- `snr_win_ms`: SNR computation window (default 20 ms)

---

### 2. **Feature Extraction** (`Feature_Extraction.m`)
**Purpose**: Master analysis script that orchestrates multi-file comparisons and generates summary statistics.

**Workflow**:
1. Prompts user to select between:
   - Injured vs. Uninjured comparison
   - Stimulus ON vs. OFF comparison
2. Loops over selected recordings, calling `preprocess_and_label` on each
3. Computes per-recording metrics:
   - **SNR-based**: Signal-to-noise ratio for each channel
   - **PNR**: Peak-to-noise ratio (peak activity vs. rest baseline)
   - **Duration**: Mean spasm duration and active/rest bout lengths
   - **Overlap**: Cross-channel correlation (TA–MG overlap during activity)
4. Groups results by condition (injured/uninjured) and generates comparison plots
5. Saves summary figures

**Output**: Structured results with per-file statistics and group comparisons.

---

### 3. **Spasm Detection** (`spasm_gait_stim_analysis.m`)
**Purpose**: Classify activity into four mutually exclusive states and analyze stimulus effects.

**States** (priority order):
1. **Spasm**: High-amplitude envelope (percentile-based threshold)
2. **Rest**: Low activity (from SNR masks)
3. **Active**: Intermediate activity
4. **Other**: Everything else (artifacts, noise)

**Process**:
- Define spasm threshold as percentile of active samples (default 65th)
- Filter spasms by minimum duration and fuse nearby events
- Detect Ch3 (stimulus) ON periods and classify each spasm as:
  - **Stimulated**: overlaps any Ch3 ON sample
  - **Unstimulated**: no overlap
- Compute amplitude (envelope percentile) for each spasm in stim/unstim groups
- Perform Wilcoxon rank-sum test (unpaired)

**Output**: 
- Masks for each state and stimulus condition
- Amplitude distributions
- Statistical test results (p-value, median, n)
- Annotated figure with shaded regions

**Key Parameters**:
- `SpasmPrcTA`, `SpasmPrcMG`: Percentile thresholds (default 65)
- `SpasmMinDurS`: Minimum spasm duration in seconds (default 0.1 s)
- `FuseGapMs`: Gap to fuse nearby spasms (default 50 ms)
- `Ch3MinOnMs`: Minimum stimulus ON duration (default 100 ms)

---

### 4. **Stimulus vs. No-Stimulus Comparison** (`compare_spasm_stim_vs_nostim.m`)
**Purpose**: Compare amplitude in stimulated vs. unstimulated spasms using matched relative time windows.

**Key Design**:
- For each **stimulated spasm**, extract the exact window where it overlaps Ch3 ON
- Apply that **relative window** (offset & duration from spasm start) to **all unstimulated spasms**
- Compare amplitude percentiles (unpaired Wilcoxon test) — different events, not paired samples

**Output**:
- Per-spasm amplitude in stim and unstimulated windows
- Summary statistics and rank-sum p-values
- Multi-panel visualization:
  - Signal overview with shaded spasm types and stimulus windows
  - Individual points with mean ± SD per group
  - Amplitude distributions with KDE overlay

---

### 5. **Cross-Correlation Analysis** (`compare_files_xcorr.m`)
**Purpose**: Quantify TA–MG temporal coordination via sliding cross-correlation.

**Process**:
- Compute maximum cross-correlation between TA and MG envelopes within specified lag window
- Optional: restrict to activity intervals or user-defined time windows
- Average correlation across recording segments
- Compare groups (injured vs. uninjured)

**Output**: Cross-correlation curves and group statistics.

---

## Utility Functions

### Filtering
- **`butter_filter.m`**: Bandpass Butterworth (default 50–500 Hz, 2nd order, zero-phase)
- **`notch_filter.m`**: Notch filter at 50 Hz to remove power line noise

### Mask Operations
- **`keep_long_runs.m`**: Keep only mask regions ≥ minimum length (used for denoising brief artifacts)
- **`fuse_masks.m`**: Merge nearby ON regions separated by < max_gap_ms
- **`find_quiet_mask.m`**: Identify quiet samples using percentile-based thresholds

### Signal Processing
- **`remove_artifacts.m`**: Replace NaN-heavy segments with NaN, segment data
- **`detect_valid_acquisition_start.m`**: Auto-detect recording start time based on activity rise
- **`snr_emg.m`**: Compute SNR and identify active samples

### Plotting
- **`plot_filtered.m`**: Stack-plot three channels with vertical spacing
- **`plot_amplitudes.m`**: Visualize amplitude distribution
- **`plot_frequency_spectrum.m`**: FFT-based spectral analysis
- **`plot_PSD.m`**: Power spectral density
- **`plot_rect_and_env.m`**: Rectified signal and envelope overlay
- **`plot_TA_MG_correlation.m`**: Cross-correlation time-lag plot

### Synthetic Data
- **`generate_synthetic_emg.m`**: Create test EMG with controlled spasms, gait, and noise for validation

### Parameter Tuning
- **`default_emg_parameters.m`**: Central configuration file defining all processing parameters
- **`emg_parameter_tuning.m`**: Interactive GUI to test parameter sensitivity on a single recording

---

## Data Format

### Input
- **MAT files** with structure:
  ```
  data__chan_1_rec_1  : TA channel, recording 1
  data__chan_2_rec_1  : MG channel, recording 1
  data__chan_3_rec_1  : Stimulus/trigger channel, recording 1
  (repeat for rec_2, rec_3, ...)
  ```
- Optional: `filename_param.mat` containing saved parameters `P` for that file

### Output Timetable (`TT_clean`)
| Variable | Description |
|----------|-------------|
| `tDur` | Time vector (duration type) |
| `TA_raw`, `MG_raw`, `Ch3_raw` | Scaled raw signals |
| `TA`, `MG`, `Ch3` | Normalized signals |
| `TA_f`, `MG_f` | Filtered signals (butter + notch) |
| `TA_rect`, `MG_rect` | Rectified envelopes |
| `TA_env`, `MG_env` | Smoothed envelopes |

---

## Key Design Choices

### 1. **Robust Scaling over Z-Score**
Raw EMG has variable baseline drift and outliers. Median-based scaling `(x - median) / MAD` is less sensitive to artifacts than standard z-score normalization.

### 2. **Percentile-Based Thresholds**
Activity detection uses adaptive percentile thresholds (e.g., 70th) of the signal distribution rather than fixed amplitude cutoffs. This accommodates variable signal quality and recording conditions.

### 3. **Unpaired Statistical Tests**
When comparing stimulated vs. unstimulated spasms, Wilcoxon rank-sum is used (unpaired) because stimulated and unstimulated events are distinct spasms, not repeated measurements of the same event.

### 4. **Matched Time Windows**
The stimulus comparison uses relative (offset + duration) windows extracted from stimulated spasms, then applied to all unstimulated spasms. This ensures fair amplitude comparison by accounting for different spasm morphologies.

### 5. **Mask Priority Hierarchy**
In `spasm_gait_stim_analysis.m`, mutually exclusive states are assigned with priority: Spasm → Rest → Active → Other. This prevents ambiguous classifications.

### 6. **Zero-Phase Filtering**
All frequency-domain filters use `filtfilt` to eliminate phase distortion, critical for accurate temporal alignment and envelope detection.

---

## Workflow Example

```matlab
% 1. Basic single-file pipeline
P = default_emg_parameters();
fs = 10000;
[TT_clean, snrValue, meta, preview] = preprocess_and_label(P, fs);

% 2. Run spasm detection and stim comparison
out_spasm = spasm_gait_stim_analysis(TT_clean, snrValue, fs, ...
    'SpasmPrcTA', 65, 'PlotResult', true);

out_stim_comp = compare_spasm_stim_vs_nostim(TT_clean, snrValue, fs, ...
    'SpasmPrcTA', 65, 'PlotResult', true);

% 3. Multi-file group comparison
Feature_Extraction;  % Interactive UI guides the process
```

---

## Tips & Troubleshooting

- **No quiet samples found**: Lower percentile thresholds in `default_emg_parameters.m` or check data quality
- **Spasm threshold too high/low**: Adjust `SpasmPrcTA` / `SpasmPrcMG` in spasm detection functions
- **Missing param file**: Script auto-defaults to `default_emg_parameters.m` — no error expected
- **Artifact contamination**: Use `remove_artifacts.m` to replace high-noise segments with NaN
- **Channel misalignment**: Verify MAT file naming convention (`data__chan_X_rec_Y`)

---

## Code Cleanup

**Consolidated duplicate functions** (March 2026):
- `keep_long_runs.m` now single source; removed local copies from `amplitude_distribution.m` and `compare_spasm_stim_vs_nostim.m`
- `fuse_masks.m` is the definitive implementation
- `shade_mask.m` helper used in `spasm_gait_stim_analysis.m`; similar `shade_ax.m` in `compare_spasm_stim_vs_nostim.m`

---

## References

- **Envelope detection**: Standard rectify + low-pass filter approach (Tkach et al., J. Biomech. 2010)
- **SNR computation**: Energy-ratio method comparing active vs. quiet windows
- **Statistical testing**: Wilcoxon rank-sum for non-parametric unpaired comparisons (paired when appropriate)
- **Cross-correlation**: Lag-sweep over ±2 s window (configurable)

---

## Contact & Maintenance

Project structure designed for reproducibility and extensibility. All parameters centralized in `default_emg_parameters.m`. Add new metrics or plots in dedicated analysis scripts following the established naming convention.
