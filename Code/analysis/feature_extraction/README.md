# Feature Extraction Module

Functions for computing higher-level features and parameters from preprocessed EMG signals.

## Functions

### `Feature_Extraction.m`
Comprehensive feature extraction pipeline computing time-domain, frequency-domain, and statistical features.

**Purpose:**
- Extracts multi-domain features from TA/MG envelopes and filtered signals
- Computes features separately for active vs. quiet periods
- Organizes features into a structured output table
- Enables machine-learning and statistical analysis workflows

**Usage:**
```matlab
features = Feature_Extraction(TT, varargin);
```

**Output:**
- `features` table with rows = time windows, columns = computed features
- Features include: RMS, mean power, peak amplitude, kurtosis, entropy, band powers, etc.

**Key Features Computed:**
1. **Time-domain (envelope):**
   - Mean, median, max, min
   - Standard deviation, variance
   - Peak-to-peak amplitude
   - Kurtosis (impulsiveness)

2. **Time-domain (filtered signal):**
   - Root-mean-square (RMS)
   - Mean absolute value (MAV)
   - Zero crossings (ZC)
   - Slope sign changes (SSC)

3. **Frequency-domain:**
   - Mean frequency (MNF)
   - Median frequency (MDF)
   - Band powers (100–500 Hz, 500–1000 Hz, etc.)
   - Power spectral centroid

4. **Statistical:**
   - Entropy (Shannon, approximate)
   - Approximate entropy (ApEn)
   - Sample entropy (SampEn)

**Example Output:**
```
    window    TA_mean    TA_std    TA_rms    TA_peak    MG_mean    MG_std    ...
       1      0.0234     0.0156    0.0267    0.1234     0.0145     0.0089    ...
       2      0.0267     0.0189    0.0312    0.1456     0.0176     0.0105    ...
       ...
```

### `emg_parameter_tuning.m`
Analyzes parameter sensitivity and optimizes thresholds for detection algorithms.

**Purpose:**
- Tunes spasm detection thresholds (envelope percentile, RMS multiplier, etc.)
- Tests multiple parameter combinations
- Computes ROC curves and optimal threshold via Youden index
- Generates sensitivity/specificity trade-off analysis

**Usage:**
```matlab
param_results = emg_parameter_tuning(TT, ground_truth, param_range, varargin);
```

**Outputs:**
- `param_results.optimal_threshold` – Best threshold for given metric
- `param_results.sensitivity` – True positive rate
- `param_results.specificity` – True negative rate
- `param_results.roc_curve` – ROC curve plot (false positive rate vs. TPR)
- `param_results.auc` – Area under ROC curve (>0.7 indicates good discriminability)

**Example:**
```matlab
% Test spasm detection percentile from 50th to 95th
param_range = 50:5:95;
results = emg_parameter_tuning(TT, is_true_spasm, param_range, ...
    'Method', 'percentile', 'Metric', 'f1');
% Returns: optimal_threshold = 75 (percentile) with F1 score = 0.82
```

## Workflow Integration

**Typical feature extraction pipeline:**

```matlab
% 1. Preprocess
TT = preprocess_and_label(filename);

% 2. Extract features
features = Feature_Extraction(TT, 'WindowLength', 0.1, 'Overlap', 0.5);

% 3. Tune thresholds (if ground truth available)
results = emg_parameter_tuning(TT, ground_truth, 50:5:95, 'Method', 'percentile');

% 4. Apply optimal threshold
is_spasm = TA_env > results.optimal_threshold;

% 5. Analyze
spasm_rate = sum(diff(is_spasm) & is_spasm) / (length(is_spasm) / fs) * 60;  % spasms/min
```

## Feature Selection for Classification

**Recommended features for spasm vs. non-spasm:**
- TA band power (100–500 Hz) – Good discriminability
- MG band power (100–500 Hz)
- TA RMS (high-frequency content)
- Envelope kurtosis (impulsiveness)

**Recommended features for gait phase classification:**
- TA/MG correlation lag – Phase relationship
- Envelope peaks (timing)
- Frequency content ratio (low vs. high bands)

## Related Modules

- **Core** (`core/`): Provides preprocessed signals with envelopes
- **Analysis/Spasm** (`analysis/spasm_detection/`): Uses features for detection
- **Plotting** (`plotting/`): Visualizes feature distributions
