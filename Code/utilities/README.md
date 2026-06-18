# Utilities Module

Low-level helpers used across the pipeline. The filtering and artifact-removal
utilities now resolve their default arguments from the central config
`config/default_emg_parameters.m`, so they behave consistently with the rest of
the pipeline even when called directly.

## Functions

### Filtering

#### `butter_filter.m`
Zero-phase band-pass Butterworth filter (`filtfilt`).

**Usage:**
```matlab
y = butter_filter(x);                 % defaults from config
y = butter_filter(x, [20 450], 1000, 4);
```
**Defaults (from `default_emg_parameters`):** `fc = P.filter.bp_fc` (`[5 500]` Hz),
`fs = P.fs` (10000), `order = P.filter.bp_order` (2; effective 4th order via `filtfilt`).

#### `notch_filter.m`
Power-line notch filter (`iirnotch`), fundamental only (no harmonics, to preserve EMG content).

**Usage:**
```matlab
y = notch_filter(x);                  % defaults from config
```
**Defaults (from `default_emg_parameters`):** `f0 = P.filter.notch_f0` (50 Hz),
`nyq = P.fs/2` (5000), `Q = P.filter.notch_Q` (30).

### Activity & mask helpers

#### `find_quiet_mask.m`
Marks low-amplitude (quiet/rest) samples using a percentile sequence.
```matlab
[is_quiet, thresh] = find_quiet_mask(signal, P.thresholds, 'TA');
```

#### `fuse_masks.m`
Merges runs in a single logical mask that are separated by a gap shorter than a
given duration (in ms).
```matlab
mask = fuse_masks(mask, fs, gap_ms);
```

#### `keep_long_runs.m`
Keeps only contiguous `true` runs at least `min_samples` long.
```matlab
mask = keep_long_runs(mask, min_samples);
```

### Signal processing

#### `remove_artifacts.m`
Flags rail/clipping artifacts relative to the typical active RMS and dilates the
flagged regions.

**Usage:**
```matlab
[TT_clean, TT_NaN, bad_seg] = remove_artifacts(TT, snrValue, fs, artifactP);
```
**Defaults (from `default_emg_parameters`):** `fs = P.fs`, `artifactP = P.artifact`,
i.e. the amplitude ceiling `rms_mult` (5000 × active RMS), the dilation window
`dilate_win_ms` (30 ms), the padding `pad_ms` (25 ms) and the flagged-fraction
threshold `frac_thresh` (0.2) are all sourced from the config instead of being
hard-coded.

#### `detect_valid_acquisition_start.m`
Finds the start of valid recording (rejects pre-acquisition zeros/artifacts).
Driven by the `P.acq.valid` knobs assembled in `preprocess_and_label`.

#### `compute_spasm_threshold.m`
Offline calibration of a spasm threshold from gait/spasm bursts.

## Common usage pattern

```matlab
P  = default_emg_parameters();
xf = notch_filter(butter_filter(x));            % both default from P
env = filtfilt(ones(round(P.envWindowMs/1000*P.fs),1), 1, abs(xf));
is_quiet = find_quiet_mask(env, P.thresholds, 'TA');
```

## Related Modules

- **Config** (`config/default_emg_parameters.m`): supplies every default used here
- **Preprocessing** (`preprocessing/`): orchestrates these helpers in `preprocess_and_label`
- **Detection** (`detection/`): reuses `fuse_masks` / `keep_long_runs` on spasm masks
