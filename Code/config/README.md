# Config & Interface Module

Configuration files and user interfaces for the EMG analysis pipeline.

## Files

### `interface.mlapp`
MATLAB App Designer interactive GUI for data selection and parameter tuning.

**Features:**
- File browser for selecting LabChart CSV recordings
- Condition selector (Gait, Spasm, Baseline, etc.)
- Time interval picker (start/end time, duration)
- Signal basis selector (raw, filtered, rectified)
- Parameter preview (filter specs, spasm thresholds)
- One-click preprocessing and visualization
- Results export (CSV, MAT)

**Usage:**
```matlab
interface
% Launches GUI window in MATLAB
```

**Workflow via GUI:**
1. Click "Browse" → select CSV file
2. Choose condition from dropdown
3. Define time interval (optional: auto-detect from log)
4. Select signal basis
5. Click "Preprocess" → automatic pipeline execution
6. View live plots (filtered signals, envelopes, PSD)
7. Click "Analyze" → run spasm detection, frequency analysis, etc.
8. Export results → save CSV/MAT files

## Default Parameters

Default parameters are defined in `core/default_emg_parameters.m` and can be overridden via:

1. **GUI interface** – Interactive controls
2. **Function arguments** – `varargin` name-value pairs
3. **Config files** (future) – JSON/YAML for batch processing

### Core Parameters

```matlab
opt.fs = 10000;                          % Sampling frequency (Hz)
opt.SignalBasis = 'raw';                 % Signal basis: 'raw', 'filtered', 'rectified'
opt.BandpassFreq = [20, 450];            % Butterworth bandpass (Hz)
opt.ButterworthOrder = 4;                % Filter order
opt.EnvelopeWindow = ceil(0.05 * fs);    % Envelope smoothing window (50 ms)
opt.SpasmPrcTA = 75;                     % TA spasm threshold (percentile)
opt.SpasmPrcMG = 75;                     % MG spasm threshold (percentile)
opt.MinSpasmDuration = ceil(0.2 * fs);   % Min spasm burst duration (200 ms)
opt.AnalysisWindowLength = 0.1;          % FFT window length (100 ms)
opt.AnalysisWindowOverlap = 0;           % Window overlap (0 = no overlap, Welch)
```

### Condition-Specific Overrides

Different recording conditions may use different thresholds:

```matlab
% Gait condition: typically lower spasm rate
opt_gait.SpasmPrcTA = 85;  % Higher percentile = stricter threshold

% Spasm condition: more sensitive detection
opt_spasm.SpasmPrcTA = 70;  % Lower percentile = sensitive threshold

% Stimulus response: short analysis windows
opt_stim.AnalysisWindowLength = 0.05;  % 50 ms windows
```

## Signal Basis Selection Guide

| Scenario | Recommended Basis | Reason |
|----------|-------------------|--------|
| LabChart real-time analysis match | `'raw'` | Spectral content preserved, df integration works correctly |
| Envelope-based spasm detection | `'filtered'` | Bandpass removes high-frequency noise, improves SNR |
| Legacy code compatibility | `'rectified'` | Envelope already computed, direct use in detection |
| Frequency analysis & band power | `'raw'` | Full spectral resolution, 500–1000 Hz content available |
| Quick visual inspection | `'filtered'` or `'rectified'` | Cleaner visualization, less noisy |

## Workflow Configuration

### Interactive Mode (GUI)
```
interface.mlapp
  ↓
[User selects file & parameters]
  ↓
preprocess_and_label() runs
  ↓
[Live plot: signals, envelopes, activity masks]
  ↓
[User chooses analysis type]
  ↓
spasm_gait_stim_analysis() OR labchart_protocol_check_gait_vs_spasm() runs
  ↓
[Results & figures generated]
```

### Batch Mode (Command Line)
```matlab
% Define processing for multiple files
files = {'data/raw/S001_Gait.csv', 'data/raw/S001_Spasm.csv', ...};
conditions = {'Gait', 'Spasm', ...};

for i = 1:length(files)
    opt = default_emg_parameters();
    opt.SignalBasis = 'raw';  % Override default
    TT = preprocess_and_label(files{i}, 'Opt', opt);
    results = labchart_protocol_check_gait_vs_spasm(TT, [], opt);
end
```

### Script Mode (Pre-configured)
```matlab
% main.m (entry point) calls workflow functions
% Workflows read opt from default_emg_parameters() with optional overrides
main
  ↓
[Menu: Select analysis]
  ↓
run_single_file_analysis
  ↓
run_batch_analysis
  ↓
etc.
```

## Future Enhancements

- **JSON config files:** For reproducible batch analyses
- **Experiment templates:** Pre-configured workflows for common protocols
- **Parameter optimization:** Auto-tune thresholds based on pilot data
- **Real-time monitoring:** Live spectral updates during acquisition

## Related Modules

- **Core** (`core/default_emg_parameters.m`): Defines parameter structure
- **Plotting** (`plotting/`): GUI displays plots generated here
- **Main** (`main.m`): Entry point that orchestrates all modules
