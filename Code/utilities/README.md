# Utilities Module

Helper functions used across multiple analysis workflows.

## Functions

### Activity & Mask Functions

#### `find_quiet_mask.m`
Identifies periods of minimal EMG activity (muscle at rest).

**Usage:**
```matlab
is_quiet = find_quiet_mask(signal, fs, threshold, min_duration);
```

#### `fuse_masks.m`
Combines multiple activity masks (e.g., TA and MG) using logical operations.

**Usage:**
```matlab
is_act_combined = fuse_masks(is_act_TA, is_act_MG, 'and');  % Both muscles active
is_act_combined = fuse_masks(is_act_TA, is_act_MG, 'or');   % Either muscle active
```

#### `keep_long_runs.m`
Filters activity mask to keep only long contiguous active periods.

**Usage:**
```matlab
is_act_filtered = keep_long_runs(is_act, min_samples);
```

### Signal Processing Utilities

#### `remove_artifacts.m`
Detects and removes or interpolates spike artifacts (e.g., electrode motion, electrical noise).

**Usage:**
```matlab
signal_clean = remove_artifacts(signal, fs, threshold, method);
% method: 'remove' (zero out) or 'interpolate' (smooth over)
```

#### `detect_valid_acquisition_start.m`
Identifies the start of valid EMG recording (after instrument stabilization).

**Usage:**
```matlab
t_start = detect_valid_acquisition_start(signal, fs, varargin);
```

### Signal Labeling & Analysis

#### `ask_condition_and_intervals.m`
Interactive UI for labeling recording conditions and time intervals.

**Usage:**
```matlab
intervals = ask_condition_and_intervals(time_vector, signal);
```

#### `compute_spasm_threshold.m`
Computes adaptive spasm detection threshold based on activity characteristics.

**Usage:**
```matlab
threshold = compute_spasm_threshold(signal, is_active, method);
% method: 'percentile', 'adaptive', 'statistical'
```

#### `compute_logical_ticks.m`
Converts continuous time/sample indices into discrete logical arrays.

**Usage:**
```matlab
is_event = compute_logical_ticks(sample_indices, total_samples);
```

### Display & Visualization Helpers

#### `normalize_signal_for_display.m`
Normalizes signals to [0, 1] or [-1, 1] range for consistent visualization.

**Usage:**
```matlab
signal_norm = normalize_signal_for_display(signal, 'range', [0, 1]);
```

## Design Principles

1. **Modularity**: Each function has a single, well-defined purpose
2. **Reusability**: Functions accept flexible input formats (vectors, tables, structures)
3. **Robustness**: Built-in checks for edge cases (empty arrays, NaNs, etc.)
4. **Documentation**: Clear help sections and example usage

## Common Usage Patterns

**Activity detection workflow:**
```matlab
% 1. Compute SNR-based activity masks
[is_act_TA, is_act_MG] = snr_emg(TA_rect, MG_rect, fs);

% 2. Filter out brief artifacts
is_act_TA = keep_long_runs(is_act_TA, ceil(0.2*fs));  % Keep only >200ms runs

% 3. Combine masks
is_act = fuse_masks(is_act_TA, is_act_MG, 'or');

% 4. Remove spike artifacts from active regions
TA_clean = remove_artifacts(TA_raw, fs, 5, 'interpolate');
```

## Related Modules

- **Core** (`core/`): Calls utilities during preprocessing
- **Analysis** (`analysis/`): Uses masks and thresholds for feature extraction
- **Plotting** (`plotting/`): Uses normalization for display
