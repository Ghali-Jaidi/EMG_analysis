# Frequency Analysis Module

Spectral and frequency-domain analysis of EMG signals.

## Functions

### `labchart_protocol_check_gait_vs_spasm.m`
Reproduces LabChart's real-time frequency-domain analysis offline, validating spectral features for gait vs. spasm classification.

**Purpose:**
- Computes 100–500 Hz band power (LabChart spectrum-channel feature) using raw signals
- Validates that offline analysis matches real-time LabChart computation
- Assesses discriminability: does band power differ between gait and spasm?
- Outputs CSV with windows, threshold, and classification accuracy

**Usage:**
```matlab
results = labchart_protocol_check_gait_vs_spasm(varargin);
% Interactive: select file, condition, time intervals
```

**Key Features:**
- Default SignalBasis: `'raw'` (unfiltered 10 kHz signals)
- FFT size: N = 1000 (df = fs/N = 10 Hz @ 10 kHz fs)
- Window function: Hann (periodic, zero overlap)
- Band-power integration: `sum(Pxx[100–500 Hz]) × df` in V²
- Outputs: CSV file with per-window features

**Algorithm:**
```
1. Load & preprocess data (preprocess_and_label)
2. Extract active periods (SNR mask)
3. For each non-overlapping 100 ms window:
   a. Apply Hann window: w = hann(1000)
   b. Compute FFT: Pxx = abs(fft(signal .* w))^2 / (sum(w)^2 × fs)
   c. Extract 100–500 Hz band: idx = [11:51]  (f = 10:510 Hz)
   d. Integrate: Power = sum(Pxx[idx]) × df = V²
4. Compute threshold for gait vs. spasm classification
5. Report accuracy, sensitivity, specificity
```

**Outputs:**
```
LabChart_protocol_results/
├── labchart_features_<timestamp>.csv   (per-window band power)
├── labchart_summary_<timestamp>.txt    (statistics & threshold)
└── labchart_confusion_matrix_<timestamp>.fig
```

### `plot_spectral_comparison_advanced.m`
Advanced multi-band spectral visualization and cross-validation.

**Purpose:**
- Visualizes power spectral density (PSD) across epochs
- Analyzes 100–500 Hz band (LabChart primary) and 500–1000 Hz band (high-frequency content)
- Compares PSD-integrated band power vs. time-domain (causal bandpass) mean-square
- Generates histograms showing band-power distributions

**Usage:**
```matlab
plot_spectral_comparison_advanced(TT_data, condition_label, varargin);
```

**Key Features:**
- Signal basis: `'raw'` (TA_raw, MG_raw extracted from active periods)
- PSD method: Welch (pwelch) with Hann window, FFT size 1000, zero overlap
- Band-power features:
  - **100–500 Hz (PSD-integrated):** `sum(Pxx[band]) × df` (V²)
  - **100–500 Hz (time-domain):** Causal Butterworth bandpass (order 4) → mean-square
  - **500–1000 Hz (PSD-integrated):** Same as 100–500 Hz
  - **500–1000 Hz (time-domain):** Same as 100–500 Hz
- Output: Comparison statistics (mean, std) across epochs + histograms

**Visualizations:**
1. **4-panel PSD figure:** TA & MG, band highlighting, frequency axis 0–2 kHz
2. **100–500 Hz histogram (raw scale):** Distribution of window band powers
3. **100–500 Hz histogram (log10 scale):** Reveals skewness and outliers
4. **500–1000 Hz histograms:** Same as above for high-frequency band
5. **Comparison block:** Printed stats (mean PSD vs. mean time-domain per epoch)

**Algorithm:**
```
1. Extract active-period epochs (SNR-based)
2. For each epoch:
   a. Apply Hann window: w = hann(win_len)
   b. Compute PSD: [Pxx, f] = pwelch(signal, w, 0, 1000, fs)
   c. Integrate bands:
      - psd_100_500 = sum(Pxx(f_idx_100_500)) × df
      - psd_500_1000 = sum(Pxx(f_idx_500_1000)) × df
   d. Causal bandpass & mean-square:
      - bpass_filt = butter_filter(..., 'bandpass', [100, 500], 4)
      - td_100_500 = mean(bpass_filt.^2)
3. Plot histograms & comparison stats
```

### `batch_spectral_analysis.m`
Runs spectral analysis across multiple files/conditions in batch mode.

**Usage:**
```matlab
batch_results = batch_spectral_analysis(file_list, conditions, varargin);
```

**Outputs:**
- Summary table with band powers across all files
- Statistical comparison (ANOVA, t-tests across conditions)

### `compare_frequency_content.m`
Compares frequency content between two signals or conditions.

**Usage:**
```matlab
comparison = compare_frequency_content(signal1, signal2, fs, varargin);
```

## Band-Power Integration & Units

**Critical:** Band power must be integrated to yield V² (not V²/Hz):

```
Incorrect:  Power = mean(Pxx[band])          % ✗ Wrong units (V²/Hz)
Correct:    Power = sum(Pxx[band]) × df      % ✓ Correct units (V²)
```

**Why df multiplication matters:**
- Pxx from FFT: units are V²/Hz (spectral density)
- Band power = ∫ Pxx df (integrate over frequency)
- Numerical integration: Σ Pxx[i] × Δf (Riemann sum)
- Result: V² (absolute power in band)

**LabChart equivalence:**
- LabChart real-time: FFT size 1000, Hann window, zero overlap → df = 10 Hz
- Our implementation: identical parameters → reproduces LabChart output

## Time-Domain Cross-Validation

For robustness, compare PSD-integrated features with causal bandpass mean-square:

```matlab
% PSD-integrated (zero-phase, non-causal):
psd_power = sum(Pxx[band]) × df;

% Time-domain (causal Butterworth bandpass):
bpass_sig = butter_filter(signal, fs, 'bandpass', [f_low, f_high], 4);
td_power = mean(bpass_sig.^2);

% They should agree closely (within ~10% for typical EMG)
fprintf('PSD power: %.4f V^2, TD power: %.4f V^2\n', psd_power, td_power);
```

## Related Modules

- **Core** (`core/`): Provides preprocessed raw signals
- **Analysis/Spasm** (`analysis/spasm_detection/`): Detects events within bands
- **Plotting** (`plotting/`): Visualization of spectra
