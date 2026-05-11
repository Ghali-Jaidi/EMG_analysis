# Filtering Module

Low-level signal filtering utilities used throughout the pipeline.

## Functions

### `butter_filter.m`
Applies zero-phase Butterworth filters using `filtfilt` for zero distortion.

**Supported Filter Types:**
- `'lowpass'` – Attenuates high-frequency noise
- `'highpass'` – Removes DC offset and low-frequency drift
- `'bandpass'` – Extracts frequency band of interest
- `'notch'` – Removes narrowband interference (e.g., 60 Hz power line)

**Usage:**
```matlab
filtered_sig = butter_filter(signal, fs, ftype, fspec, order);
% Example (bandpass 20–450 Hz):
TA_filt = butter_filter(TA_raw, 10000, 'bandpass', [20, 450], 4);
```

**Key Features:**
- Zero-phase filtering via `filtfilt` (no phase distortion)
- Robust stability checks
- Handles edge artifacts gracefully

### `notch_filter.m`
Specialized filter for removing narrowband interference.

**Usage:**
```matlab
filtered_sig = notch_filter(signal, fs, freq, Q);
% Example (remove 60 Hz):
TA_clean = notch_filter(TA_raw, 10000, 60, 35);
```

**Parameters:**
- `freq` – Center frequency to attenuate (Hz)
- `Q` – Quality factor (higher Q = narrower notch)

## Filter Design Philosophy

1. **Zero-phase distortion**: All filters use `filtfilt` (forward-backward IIR)
2. **Causal alternatives**: For real-time analysis, use forward filtering only
3. **Order selection**: Default order 4 balances rolloff steepness vs. stability
4. **Nyquist compliance**: All frequencies normalized to fs/2

## Common Filter Chains in EMG Analysis

**For envelope-based spasm detection:**
```matlab
TA_filt = butter_filter(TA_raw, fs, 'bandpass', [20, 450], 4);
TA_env = smoothdata(abs(TA_filt), 'gaussian', ceil(0.05*fs));
```

**For spectral analysis (raw):**
```matlab
% No filtering applied; use raw signal directly
TA_raw = preprocess_and_label(..., 'SignalBasis', 'raw');
```

**For narrowband interference removal:**
```matlab
TA_clean = notch_filter(TA_raw, 10000, 60, 35);  % Remove 60 Hz
```

## Related Modules

- **Core** (`core/`): Uses filters in preprocessing pipeline
- **Analysis** (`analysis/`): Band-specific filtering for feature extraction
