# Preprocessing Module

Core EMG signal preprocessing functions that turn a raw LabChart recording into
clean, labeled signals ready for analysis. All tunable values are read from the
central config `config/default_emg_parameters.m` (`P`).

## Functions

### `preprocess_and_label.m`
Main preprocessing pipeline.

**Usage:**
```matlab
P = default_emg_parameters();
[TT_clean, snrValue, meta, preview] = preprocess_and_label(P, P.fs, ...
    'plot_figures', true, 'fullFile', 'recording.mat', 'recID', 1);
```

**Signature:**
```matlab
[TT_clean, snrValue, meta, preview] = preprocess_and_label(P, fs, options)
```
- `P`  — parameter struct (defaults to `default_emg_parameters()`)
- `fs` — sampling frequency (defaults to `default_emg_parameters().fs`)
- name-value `options`: `plot_figures`, `save_figures`, `fig_folder`, `fullFile`, `recID`

**What it does (in order):**
1. Loads a recording from a `.mat` file (`data__chan_{1,2,3}_rec_{N}`); prompts via UI if no file/recording is given.
2. Filters TA and MG: `notch_filter(butter_filter(...))` — both pull their cutoffs/order from `P.filter` and `P.fs`.
3. Rectifies (`abs`) and computes the linear envelope as a moving average of width `P.envWindowMs`.
4. Optionally detects a valid acquisition start (`P.detect_acq_start`, knobs in `P.acq` / `P.acq.valid`).
5. Builds quiet/rest masks via `find_quiet_mask` using `P.thresholds`.
6. Estimates SNR and activity masks via `snr_emg` (`P.snr_win_ms`, `P.act_prc`, `P.act_prc_MG`).
7. Removes artifacts via `remove_artifacts` (ceiling/dilation from `P.artifact`).
8. Recomputes the envelope on the cleaned signal and produces final rest/activity masks, fusing gaps with `P.fuse_gap_ms`.

**Signal selection:** `P.use_envelope` chooses whether rest/SNR/activity work on
the smoothed envelope (`true`) or the raw rectified signal (`false`).

### `snr_emg.m`
Windowed-RMS SNR estimate and activity-mask generation, per channel (TA + optional MG).

**Usage:**
```matlab
out = snr_emg(x, is_rest, fs, win_ms, act_prc, ...
    'xMG', xMG, 'is_rest_MG', is_rest_MG, 'act_prc_MG', P.act_prc_MG, ...
    'valid_mask', is_valid_acq);
```

**Defaults from config:** `fs`, `win_ms` (`P.snr_win_ms`), `act_prc` (`P.act_prc`),
plus the activity post-processing knobs `min_active_dur_ms` (`P.min_active_dur_ms`)
and `act_fuse_gap_ms` (`P.act_fuse_gap_ms`) — the previously hard-coded
`round(0.05*fs)` minimum run and 50 ms fuse gap are now both parameters.

**Outputs (`out` struct):** `SNR`/`SNR_dB`, `Ract_TA`/`Rrest_TA`, `thr_act`,
`is_act`, `rmsw`, and the matching `*_MG` fields when an MG channel is supplied.

### `default_emg_parameters.m`
Lives in `config/` (see `config/README.md`). Returns the categorized parameter
struct consumed throughout this module.

## Output structure (`TT_clean` timetable)

| Variable | Description |
|----------|-------------|
| `TA_raw`, `MG_raw`, `Ch3_raw` | Raw channels as loaded |
| `TA_f`, `MG_f` | Notch + band-pass filtered (`P.filter`) |
| `TA_rect`, `MG_rect` | Rectified filtered signals |
| `TA_env`, `MG_env` | Linear envelope (moving average of width `P.envWindowMs`) |

`snrValue` additionally carries the activity (`is_act`, `is_act_MG`) and rest
(`is_rest`, `is_rest_MG`) masks and the rest/activity thresholds.

## Dependencies

- MATLAB Signal Processing Toolbox (`butter`, `filtfilt`, `iirnotch`)
- `utilities/butter_filter.m`, `utilities/notch_filter.m`, `utilities/remove_artifacts.m`
- `utilities/find_quiet_mask.m`, `utilities/fuse_masks.m`, `utilities/keep_long_runs.m`

## Related Modules

- **Config** (`config/default_emg_parameters.m`): defines every parameter used here
- **Utilities** (`utilities/`): filtering, masking and artifact-removal helpers
- **Detection** (`detection/`): consumes the cleaned `TT` and `snrValue`
