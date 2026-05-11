# Testing & Validation Module

Scripts for validating the preprocessing pipeline and analysis algorithms.

## Functions

### `Test_full_spasm_detection.m`
Integration test validating the entire spasm detection workflow.

**Purpose:**
- Tests preprocessing → spasm detection → statistics pipeline
- Validates against synthetic data with known ground truth
- Checks output data types and dimensions
- Ensures all dependencies are available

**Usage:**
```matlab
test_results = Test_full_spasm_detection();
% Displays: PASS/FAIL for each validation step
```

**Test Checks:**
- ✓ Preprocessing loads and cleans data
- ✓ SNR-based activity mask is correct dimensionality
- ✓ Spasm threshold is adaptive and robust
- ✓ Spasm events are properly detected
- ✓ Statistics (rate, duration) are computed correctly
- ✓ Output table has expected structure

### `generate_synthetic_emg.m`
Generates realistic synthetic EMG signals for algorithm development and validation.

**Purpose:**
- Creates synthetic EMG with known properties (amplitude, frequency, noise)
- Embeds artificial spasm events at known times
- Enables reproducible testing without requiring real data files
- Supports parameter sweeps (SNR levels, spasm amplitudes, etc.)

**Usage:**
```matlab
% Generate synthetic signal with 2 spasm events
[signal, ground_truth, params] = generate_synthetic_emg(...
    'fs', 10000, ...
    'duration', 30, ...
    'num_spasms', 2, ...
    'snr_db', 20);

% signal: 10 kHz sampled signal (3×10^5 samples for 30 sec)
% ground_truth: logical array marking spasm onset/offset
% params: structure with generation parameters
```

**Synthetic Signal Components:**
1. **Base EMG (motor unit recruitment):**
   - Sum of sinusoids (10–400 Hz) with random amplitudes
   - Modulates in amplitude over time (simulates contraction)

2. **Spasm events (artificial bursts):**
   - High-amplitude sinusoids (50–200 Hz) at known times
   - Duration: 0.5–2 seconds
   - Amplitude: 0.1–0.5 V (tunable)

3. **Noise (Gaussian white noise):**
   - SNR-controlled (e.g., 20 dB means noise power = signal power / 100)
   - Simulates electrode noise, motion artifact, etc.

**Example:**
```matlab
% Generate 3 datasets with different SNR levels
snr_levels = [10, 20, 30];  % dB
for i = 1:length(snr_levels)
    [sig, gt, p] = generate_synthetic_emg(...
        'duration', 60, 'num_spasms', 5, 'snr_db', snr_levels(i));
    
    % Test detection algorithm
    TT.TA_raw = sig;
    [is_spasm] = detect_spasms(TT, 'method', 'envelope_percentile');
    
    % Compute accuracy
    accuracy = sum(is_spasm == gt) / length(gt);
    fprintf('SNR %d dB: Accuracy %.2f%%\n', snr_levels(i), accuracy*100);
end
```

### `amplitude_distribution.m`
Analyzes statistical distribution of EMG amplitudes across conditions.

**Purpose:**
- Computes descriptive statistics (mean, median, quantiles, skewness, kurtosis)
- Tests normality (Shapiro-Wilk, Anderson-Darling tests)
- Compares amplitude distributions between conditions (Kolmogorov-Smirnov test)
- Generates Q-Q plots and histogram visualizations

**Usage:**
```matlab
dist_results = amplitude_distribution(TA_env, MG_env, condition_labels);
```

**Output:**
- `dist_results.mean`, `.median`, `.std`, `.iqr`
- `dist_results.skewness`, `.kurtosis`
- `dist_results.normality_pvalue` (reject normality if p < 0.05)
- `dist_results.ks_pvalue` (difference between conditions if p < 0.05)

## Validation Workflows

### 1. Preprocessing Validation
```matlab
% Load raw data
TT = preprocess_and_label('test_file.csv');

% Checks:
assert(length(TT.TA_raw) == length(TT.TA_filt), 'Signal length mismatch');
assert(all(isfinite(TT.TA_env)), 'Envelope contains NaN');
assert(mean(TT.is_act_TA) > 0.1 && mean(TT.is_act_TA) < 0.9, ...
    'Activity mask suspiciously sparse or dense');
```

### 2. Algorithm Validation (Synthetic Data)
```matlab
% Generate synthetic data with ground truth
[signal, ground_truth] = generate_synthetic_emg('num_spasms', 5, 'snr_db', 20);

% Create minimal TT structure
TT.TA_raw = signal;
TT.fs = 10000;
TT.TA_rect = abs(TT.TA_raw);  % Placeholder

% Run algorithm and validate
is_spasm = spasm_detection_function(TT);

% Compute metrics
TP = sum(is_spasm & ground_truth);
FP = sum(is_spasm & ~ground_truth);
FN = sum(~is_spasm & ground_truth);
TN = sum(~is_spasm & ~ground_truth);

sensitivity = TP / (TP + FN);
specificity = TN / (TN + FP);
fprintf('Sensitivity: %.2f%%, Specificity: %.2f%%\n', sensitivity*100, specificity*100);
```

### 3. Cross-Condition Reproducibility
```matlab
% Test that multiple analyses of same condition agree
for i = 1:3
    results{i} = spasm_gait_stim_analysis(TT, snrValue, fs);
end

% Check consistency
assert(all(abs(results{1}.spasm_rate - results{2}.spasm_rate) < 0.1), ...
    'Results not reproducible');
```

## Testing Best Practices

1. **Always use synthetic data for initial development** – Enables ground truth validation
2. **Test with edge cases** – Very low SNR, very short signals, no activity
3. **Check dimensions** – Ensure functions respect MATLAB conventions (row vs. column vectors)
4. **Validate against known values** – Compare band powers to hand calculations when possible
5. **Profile performance** – Run `profile` on slow workflows to identify bottlenecks

## Related Modules

- **Core** (`core/`): Tests preprocessing functions
- **Analysis** (`analysis/`): Tests detection/classification workflows
- **Data** (`data/`): Contains synthetic_rec.mat for quick testing
