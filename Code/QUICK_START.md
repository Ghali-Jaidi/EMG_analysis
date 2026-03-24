# Quick Start Guide

## Running the Pipeline

### Option 1: Full Comparative Analysis (Interactive)
```matlab
>> Feature_Extraction
% Prompts user to select:
% - Injured vs. Uninjured comparison
% - Stimulus ON/OFF comparison
% Automatically processes selected files and generates figures
```

### Option 2: Single-File Processing
```matlab
>> fs = 10000;
>> P = default_emg_parameters();
>> [TT_clean, snrValue, meta] = preprocess_and_label(P, fs);
% Preprocesses one recording; displays plots
```

### Option 3: Spasm & Stimulus Analysis
```matlab
>> [TT_clean, snrValue, meta] = preprocess_and_label(P, fs);
>> out = spasm_gait_stim_analysis(TT_clean, snrValue, fs, 'PlotResult', true);
% Detects spasms, classifies by stimulus state
>> out2 = compare_spasm_stim_vs_nostim(TT_clean, snrValue, fs, 'PlotResult', true);
% Compares amplitudes in matched time windows
```

### Option 4: Parameter Tuning (Single Recording)
```matlab
>> emg_parameter_tuning_gui()
% Interactive GUI to explore parameter sensitivity
% Save parameters to file for batch reuse
```

---

## Essential Parameters

Edit in `default_emg_parameters.m`:

| Parameter | Default | Use | 
|-----------|---------|-----|
| `envWindowMs` | 3 | Envelope smoothing window (ms) |
| `thresholds` | [40 50] | Percentiles for quiet detection |
| `act_prc` | 70 | TA activity detection percentile |
| `act_prc_MG` | 50 | MG activity detection percentile |
| `snr_win_ms` | 20 | SNR computation window (ms) |

Pass to `spasm_gait_stim_analysis.m`:

| Parameter | Default | Use |
|-----------|---------|-----|
| `SpasmPrcTA` | 65 | Spasm threshold: TA percentile |
| `SpasmPrcMG` | 65 | Spasm threshold: MG percentile |
| `SpasmMinDurS` | 0.1 | Minimum spasm duration (s) |
| `FuseGapMs` | 50 | Merge spasms within gap (ms) |

---

## Input File Format

### MAT Structure
```matlab
% For each recording, include three channels:
save('my_experiment.mat', ...
  'data__chan_1_rec_1', ta_signal,  ...  % TA channel, recording 1
  'data__chan_2_rec_1', mg_signal,  ...  % MG channel, recording 1
  'data__chan_3_rec_1', ch3_signal, ...  % Stimulus/trigger channel, recording 1
  'data__chan_1_rec_2', ta_signal,  ...  % Recording 2, etc.
  ...
);
```

### Optional: Parameter File
```matlab
P = default_emg_parameters();
P.act_prc = 75;  % Custom TA threshold
P.envWindowMs = 5;
save('my_experiment_param.mat', 'P');
% Auto-loaded by preprocess_and_label if found
```

---

## Output Files

### Figures Saved to `Figures/` subfolder:
- `OP81_F3_20-Nov-2025_rec1_figures.fig` — Preprocessing overview
- `emg_corr.fig` — Cross-correlation analysis
- `overall_stim_comparison.pdf` — Group-level comparison

### MATLAB Figures (Interactive):
- Signal overview with activity masks
- Spasm detection and classification
- Stimulus comparison (amplitude distributions)
- Cross-correlation lags

---

## Troubleshooting

**Q: "No recordings found" error**
- Check MAT file naming: must be `data__chan_1_rec_1`, not `data_chan1_rec1`

**Q: All samples classified as "quiet"**
- Lower `thresholds` in `default_emg_parameters.m`
- Check raw signal amplitude (may be noise-dominated)

**Q: Spasm detection missing obvious events**
- Increase `SpasmPrcTA` / `SpasmPrcMG` (lower percentile = lower threshold)
- Decrease `SpasmMinDurS` if spasms are brief

**Q: Too many false spasms detected**
- Decrease `SpasmPrcTA` / `SpasmPrcMG` (higher percentile = higher threshold)
- Increase `FuseGapMs` to merge fragmented detections

**Q: No stimulus effects detected**
- Verify `data__chan_3_rec_X` contains ON/OFF signal
- Check `Ch3MinOnMs` threshold (default 100 ms minimum)
- Plot `Ch3_raw` to verify signal range

---

## For Researchers

### Interpreting Key Outputs

**SNR (Signal-to-Noise Ratio)**
- Ratio of active-period RMS to quiet-period RMS
- Higher = cleaner recordings
- Compare across groups/conditions

**PNR (Peak-to-Noise Ratio)**
- Peak activity vs. quiet baseline
- Sensitive to burst amplitude

**Overlap (TA–MG correlation)**
- Percentage of active samples where both channels active simultaneously
- High = coordinated muscle activation
- Low = selective or independent patterns

**p-value (Wilcoxon rank-sum)**
- p < 0.05 typically denotes significant difference
- Tested: spasm amplitude, event count, correlation

---

## Recommended Workflow

1. **Validate preprocessing**: Run single file, examine plots
2. **Tune parameters**: Adjust thresholds if needed via GUI
3. **Batch process**: Run Feature_Extraction with validated params
4. **Interpret**: Check summary figures and statistical outputs
5. **Save results**: Export data for downstream analysis (stats package, etc.)

---

## File Organization

```
Code/
├── README.md                          (← Start here)
├── CLEANUP_LOG.md                     (code deduplication notes)
├── default_emg_parameters.m           (central config)
├── preprocess_and_label.m             (core pipeline)
├── Feature_Extraction.m               (multi-file analysis)
├── spasm_gait_stim_analysis.m         (spasm detection)
├── compare_spasm_stim_vs_nostim.m    (stim comparison)
├── compare_files_xcorr.m              (cross-correlation)
├── butter_filter.m                    (bandpass)
├── notch_filter.m                     (50 Hz notch)
├── keep_long_runs.m                   (utility)
├── fuse_masks.m                       (utility)
├── snr_emg.m                          (SNR computation)
├── [plotting functions]               (various .m files)
└── Figures/                           (output directory)
```

---

## Contact

For questions or issues, refer to README.md for design details and complete function reference.
