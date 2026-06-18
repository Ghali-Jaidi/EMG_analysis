# Config & Interface Module

Central configuration and the interactive GUI for the EMG analysis pipeline.

## Files

### `default_emg_parameters.m`
**The single source of truth for every tunable value in the pipeline.**

This function returns a struct `P` whose fields are grouped by the pipeline
stage that consumes them. Every other function that used to hard-code these
numbers now reads them from here — either directly, or through its default
arguments (e.g. `butter_filter`, `notch_filter`, `snr_emg`, `remove_artifacts`
and `spasm_gait_stim_analysis` all resolve their defaults from this file). As a
result, the behaviour of the whole pipeline can be changed from this one place.

**Usage:**
```matlab
P = default_emg_parameters();          % get the defaults
P.spasm.prc_TA = 70;                   % override a single value
[TT, snr] = preprocess_and_label(P, P.fs);
```

#### Parameter groups

| Group | Field | Meaning |
|-------|-------|---------|
| **Acquisition / sampling** | `fs` | Sampling frequency (Hz) of the LabChart export (10000) |
| **Filtering** | `filter.bp_fc` | Band-pass cutoffs `[low high]` in Hz for the Butterworth filter (`[5 500]`) |
| | `filter.bp_order` | Butterworth order; `filtfilt` doubles it → effective 4th order (2) |
| | `filter.notch_f0` | Power-line frequency notched out (50 Hz = Europe) |
| | `filter.notch_Q` | Notch quality factor; higher = narrower (30, ≈1.7 Hz BW). Only the fundamental is notched, no harmonics |
| **Envelope** | `envWindowMs` | Moving-average window for the linear envelope (3 ms) |
| | `use_envelope` | `true`: threshold on envelope; `false`: on raw rectified signal |
| **Rest / quiet detection** | `thresholds` | Percentile sequence passed to `find_quiet_mask` for the quiet/rest cut (`[40 50]`) |
| | `min_quiet_dur_ms` | Minimum quiet-segment duration (10 ms) |
| | `fuse_gap_ms` | Gap below which adjacent rest/activity bursts are merged (10 ms) |
| **SNR / activity detection** | `snr_win_ms` | Sliding RMS window for SNR / activity (20 ms) |
| | `act_prc` | TA activity-detection percentile of windowed RMS (70) |
| | `act_prc_MG` | MG activity-detection percentile of windowed RMS (50) |
| | `min_active_dur_ms` | Minimum sustained active run to keep (50 ms) |
| | `act_fuse_gap_ms` | Gap below which adjacent active bursts are merged (50 ms) |
| **Artifact rejection** | `artifact.rms_mult` | Amplitude ceiling = `rms_mult × active RMS` — very permissive, catches rail/clipping only (5000) |
| | `artifact.dilate_win_ms` | Moving-average window to dilate flagged regions (30 ms) |
| | `artifact.pad_ms` | Padding added around flagged regions (25 ms) |
| | `artifact.frac_thresh` | Fraction of the dilation window that must be flagged (0.2) |
| **Spasm / stim analysis** | `spasm.prc_TA` / `spasm.prc_MG` | Percentile on the active envelope for the spasm threshold (65 / 65) |
| | `spasm.min_dur_s` | Minimum spasm event duration (0.1 s) |
| | `spasm.fuse_gap_ms` | Gap below which adjacent spasm bursts are merged (50 ms) |
| | `spasm.gait_min_overlap_s` | Kept for compatibility, unused in current active definition (0.05) |
| | `spasm.ch3_threshold` | Manual Ch3 ON threshold; `[]` = auto (midpoint of min/max) |
| | `spasm.ch3_min_on_ms` | Minimum Ch3 ON pulse duration (100 ms) |
| | `spasm.plot_downsample` | Downsampling factor for the annotated figure (10) |
| **Acq-start detection** | `detect_acq_start` | Master switch for auto-detecting the acquisition start (`false`) |
| | `acq.*` | RMS window, baseline multiplier, search window, noise-floor mode, etc. |
| | `acq.valid.*` | Per-channel "valid acquisition" detector knobs used by `detect_valid_acquisition_start` |

> The numbers in parentheses are the shipped defaults. Edit `default_emg_parameters.m`
> to change them globally, or override individual fields on the returned struct
> for a one-off run.

### `interface.mlapp`
MATLAB App Designer GUI for data selection, parameter tuning and visualization.

**Usage:**
```matlab
Interface_GUI    % launched from main.m, menu option 6
```

The GUI reads its starting values from `default_emg_parameters()` and lets the
user adjust them before running `preprocess_and_label` / the analysis routines.

## How overrides flow through the pipeline

```
default_emg_parameters()         <- defaults defined here
        │
        ├─ preprocess_and_label(P, P.fs)
        │        ├─ butter_filter / notch_filter   (defaults from P.filter, P.fs)
        │        ├─ snr_emg(...)                    (defaults from P.snr_*, P.act_*, P.min_active_dur_ms)
        │        └─ remove_artifacts(...)           (defaults from P.artifact)
        │
        └─ spasm_gait_stim_analysis(...)            (defaults from P.spasm)
```

Any value not explicitly overridden falls back to `default_emg_parameters()`,
so the config file alone fully determines the pipeline's behaviour.

## Related Modules

- **Preprocessing** (`preprocessing/`): consumes `P` in `preprocess_and_label` and `snr_emg`
- **Utilities** (`utilities/`): `butter_filter`, `notch_filter`, `remove_artifacts` default from `P`
- **Detection** (`detection/`): `spasm_gait_stim_analysis` defaults from `P.spasm`
- **Main** (`main.m`): entry point that builds `P` and passes it to the workflows
