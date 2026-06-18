# Detection Module

Spasm classification and stimulation (Ch3) ON/OFF analysis. All thresholds
default to the central config `config/default_emg_parameters.m` (the `P.spasm`
group) and can be overridden per call via name-value options.

## Functions

### `spasm_gait_stim_analysis.m`
Classifies every sample into four mutually exclusive states and compares
amplitudes across the Ch3 stimulation ON/OFF split.

**Usage:**
```matlab
out = spasm_gait_stim_analysis(TT_clean, snrValue, fs, ...
    'SpasmPrcTA', P.spasm.prc_TA, 'SpasmPrcMG', P.spasm.prc_MG, ...
    'PlotResult', true);
```

**States (priority Spasm → Rest → Active → Other):**
- **Spasm** — TA or MG envelope exceeds a high percentile of the active envelope
- **Rest** — taken from the rest masks produced by `preprocess_and_label` / `snr_emg`
- **Active** — active but neither spasm nor rest
- **Other** — everything else

**Name-value options (defaults from `default_emg_parameters().spasm`):**

| Option | Config field | Meaning |
|--------|--------------|---------|
| `SpasmPrcTA` / `SpasmPrcMG` | `spasm.prc_TA` / `spasm.prc_MG` | Percentile on the active envelope for the spasm threshold |
| `SpasmMinDurS` | `spasm.min_dur_s` | Minimum spasm event duration (s) |
| `FuseGapMs` | `spasm.fuse_gap_ms` | Gap (ms) below which adjacent spasm bursts are merged |
| `GaitMinOverlapS` | `spasm.gait_min_overlap_s` | Kept for compatibility, unused in the current active definition |
| `Ch3Threshold` | `spasm.ch3_threshold` | Manual Ch3 ON threshold; `[]` = auto (midpoint of min/max) |
| `Ch3MinOnMs` | `spasm.ch3_min_on_ms` | Minimum Ch3 ON pulse duration (ms) |
| `PlotDownsample` | `spasm.plot_downsample` | Downsampling factor for the annotated figure |
| `PlotResult` | — | Whether to draw the annotated figure (default `false`) |

**Algorithm:**
1. Threshold each channel: `thr_spasm = prctile(env(is_active), SpasmPrc)`.
2. Mark raw spasm samples where either envelope exceeds its threshold.
3. Drop short bursts (`keep_long_runs`, `SpasmMinDurS`) and fuse close ones (`fuse_masks`, `FuseGapMs`).
4. Build the four exclusive state masks.
5. Auto-compute (or accept) the Ch3 ON threshold, keep ON runs ≥ `Ch3MinOnMs`.
6. Per state × ON/OFF: amplitude means/medians and a per-event Wilcoxon signed-rank test.

**Outputs (`out` struct):** `is_spasm`, `is_active`, `is_rest`, `is_other`,
`is_ch3_on`, `thr_spasm_TA`, `thr_spasm_MG`, `thr_ch3`, `stats` (per-state ON/OFF
amplitudes and signed-rank p-values) and `t`.

### `compare_spasm_stim_vs_nostim.m`
Matched-window comparison of spasm amplitude between stimulated and
unstimulated spasms. Shares the same `SpasmPrcTA` / `SpasmPrcMG` defaults
(from `P.spasm`) and adds an `AmpPercentile` knob for the per-window summary.

**Usage:**
```matlab
out = compare_spasm_stim_vs_nostim(TT, snrValue, fs, ...
    'SpasmPrcTA', P.spasm.prc_TA, 'SpasmPrcMG', P.spasm.prc_MG, ...
    'AmpPercentile', 90, 'PlotResult', true);
```

### `compare_files_xcorr.m`
Cross-correlation between TA and MG envelopes (synchronization / lag).

**Usage:**
```matlab
out = compare_files_xcorr(TA_env, MG_env);
% out.correlation, out.lag_ms
```

## Related Modules

- **Config** (`config/default_emg_parameters.m`): defines the `P.spasm` defaults used here
- **Preprocessing** (`preprocessing/`): provides the cleaned `TT` and `snrValue` inputs
- **Visualization** (`visualization/`): annotated figures are produced inline by these functions
