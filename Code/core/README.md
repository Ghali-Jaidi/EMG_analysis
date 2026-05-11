# Core Preprocessing Module

This folder contains the fundamental EMG signal preprocessing and analysis functions that form the backbone of the entire pipeline.

## Functions

### `preprocess_and_label.m`
Main preprocessing function that handles:
- Data import from LabChart recordings
- Signal filtering (zero-phase Butterworth filters)
- Artifact detection and removal
- Activity mask generation (based on SNR)
- Envelope computation (rectification + smoothing)
- Signal basis selection (raw, filtered, rectified)

**Usage:**
```matlab
TT = preprocess_and_label(filePath, varargin);
```

### `default_emg_parameters.m`
Returns default parameter structure for EMG analysis:
- Sampling frequency (fs = 10 kHz)
- Filter specifications (notch, bandpass, butterworth orders)
- Spasm detection thresholds (percentile-based)
- Signal processing options

**Usage:**
```matlab
opt = default_emg_parameters();
```

### `snr_emg.m`
Computes Signal-to-Noise Ratio (SNR) for activity detection:
- Separates background noise from active EMG
- Generates activity masks (`is_act_TA`, `is_act_MG`)
- Robust to artifacts and baseline drift

**Usage:**
```matlab
[is_act_TA, is_act_MG] = snr_emg(TA_rect, MG_rect, fs, varargin);
```

## Signal Basis Options

The `preprocess_and_label` function supports three signal bases:

| Basis | Description | Use Case |
|-------|-------------|----------|
| `'raw'` | Unfiltered 10 kHz signals (TA_raw, MG_raw) | LabChart real-time parity, spectral analysis |
| `'filtered'` | Butterworth bandpass (20–450 Hz) | Spasm/gait envelope extraction |
| `'rectified'` | Rectified + smoothed envelope | Legacy compatibility, baseline estimation |

Default: `'raw'` (for LabChart frequency-domain analysis compatibility)

## Dependencies

- MATLAB Signal Processing Toolbox (filtfilt, butter, fir1)
- Requires `filters/butter_filter.m` for bandpass filtering

## Output Structure (TT)

```matlab
TT struct contains:
  .TA_raw          % Raw TA signal (10 kHz)
  .MG_raw          % Raw MG signal (10 kHz)
  .TA_filt         % Filtered TA (5–500 Hz)
  .MG_filt         % Filtered MG (5–500 Hz)
  .TA_rect         % Rectified TA
  .MG_rect         % Rectified MG
  .TA_env          % Rectified + smoothed envelope
  .MG_env          % Rectified + smoothed envelope
  .is_act_TA       % Activity mask (TA SNR-based)
  .is_act_MG       % Activity mask (MG SNR-based)
  .t               % Time vector (seconds)
  .fs              % Sampling frequency (10000 Hz)
  .condition       % Recording condition (e.g., 'Gait', 'Spasm')
  .metadata        % Experiment metadata (subject, date, etc.)
```

## Related Modules

- **Filters** (`filters/`): Low-level filtering implementations
- **Utilities** (`utilities/`): Helper functions for activity detection and artifact removal
- **Analysis** (`analysis/`): High-level analysis workflows using preprocessed data
