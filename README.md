# EMG Analysis Pipeline

Welcome to the **EMG Analysis Pipeline**—a comprehensive MATLAB framework for processing and analyzing electromyography (EMG) signals. This project is designed to help researchers study muscle activity patterns, detect spastic events, and compare responses across different conditions and subject groups.

## What Can You Do With This?

This pipeline enables you to:

- 🔬 **Preprocess raw EMG data** – Load recordings, remove noise, and extract clean muscle signals
- 📊 **Detect muscle activity** – Automatically identify active vs. quiet periods using intelligent activity masks
- 🎯 **Detect spasms** – Find involuntary muscle contractions using adaptive thresholds
- ⚡ **Analyze stimulus effects** – Compare muscle responses with and without stimulation
- 📈 **Extract features** – Compute amplitude, duration, frequency content, and cross-channel correlation
- 👥 **Compare groups** – Statistically compare injured vs. uninjured subjects or different conditions
- 📉 **Visualize results** – Generate publication-ready plots and interactive visualizations

## Quick Start

New to this project? Start here:

1. **Open MATLAB** and navigate to the `Code/` folder
2. **Type:** `main`
3. **Follow the interactive menu** to select your analysis

That's it! The menu guides you through file selection, preprocessing, and analysis. For more details, see `QUICKSTART.md`.

## Project Organization

The code is organized into logical modules for easy navigation:

```
Code/
├── main.m                    ← START HERE! (Interactive menu)
├── config/                   (default_emg_parameters.m — central config + GUI)
├── preprocessing/            (preprocess_and_label, snr_emg)
├── utilities/                (filters, masks, artifact removal)
├── detection/                (spasm classification & stim ON/OFF analysis)
├── analysis/                 (frequency / spectral workflows)
├── visualization/            (plotting & figures)
├── tests/                    (validation & synthetic data)
└── data/                     (sample data)
```

Every tunable value lives in **`config/default_emg_parameters.m`** — see
`config/README.md` for the full, grouped parameter reference.

---

## Core Analysis Workflows

### 1️⃣ Preprocessing
**Start here:** Convert your raw EMG recordings into clean, labeled signals ready for analysis.

- **Input:** CSV files from LabChart or MAT files with raw EMG data
- **Output:** `TT` structure with multiple signal representations (raw, filtered, rectified, envelope)
- **What it does:**
  - Loads and aligns multi-channel recordings
  - Applies filtering (bandpass, notch) and removes artifacts
  - Detects activity periods using SNR-based masks
  - Computes smoothed envelopes for event detection
- **See:** `preprocessing/README.md`

### 2️⃣ Spasm Detection
**Find involuntary muscle contractions** using envelope-based analysis.

- **Input:** Preprocessed TT structure
- **Output:** Spasm/Active/Rest/Other state masks, per-state ON/OFF amplitude statistics
- **What it does:**
  - Computes adaptive thresholds (percentile-based, defaults from `P.spasm`)
  - Detects high-amplitude bursts in muscle activity
  - Splits each state by Ch3 stimulation ON/OFF and runs a Wilcoxon signed-rank test
  - Generates an annotated comparison figure
- **See:** `detection/README.md`

### 3️⃣ Frequency Analysis
**Analyze spectral properties** of EMG signals.

- **Input:** Preprocessed TT structure
- **Output:** Band powers (100–500 Hz, 500–1000 Hz), PSD plots, statistics
- **What it does:**
  - Computes power spectral density using Welch's method
  - Integrates power within frequency bands
  - Validates offline analysis against real-time LabChart
  - Generates histograms and comparison plots
- **See:** `analysis/README.md`

### 4️⃣ Group Comparison
**Compare across recordings** (injured vs uninjured, stim ON vs OFF).

- **Input:** Multiple preprocessed recordings (selected interactively)
- **Output:** Group comparison figures and summary statistics
- **What it does:**
  - Aggregates amplitude/SNR metrics across recordings
  - Compares groups and stimulation conditions
  - Exports comparison figures (`group_comparison.pdf`, `overall_stim_comparison.pdf`)
- **Run via:** `main` → option 4 (`Feature_Extraction`)

---

## Key Signals & Parameters

### Two Muscle Channels
This pipeline analyzes:
- **TA (Tibialis Anterior):** Anterior shin muscle
- **MG (Medial Gastrocnemius):** Calf muscle

Both are recorded simultaneously at **10 kHz sampling rate**.

### Centralized Parameters
**All tunable values live in one place: `config/default_emg_parameters.m`.**
It returns a struct `P` whose fields are grouped by pipeline stage. Every
function that used to hard-code these numbers now reads them from here (directly
or through its default arguments), so the whole pipeline can be reconfigured
from this single file.

```matlab
P = default_emg_parameters();

P.fs                 % 10000   sampling frequency (Hz)
P.filter.bp_fc       % [5 500] band-pass cutoffs (Hz)
P.filter.notch_f0    % 50      power-line notch frequency (Hz)
P.envWindowMs        % 3       envelope moving-average window (ms)
P.act_prc            % 70      TA activity-detection percentile
P.artifact.rms_mult  % 5000    artifact ceiling (× active RMS)
P.spasm.prc_TA       % 65      spasm threshold percentile (TA)
P.spasm.min_dur_s    % 0.1     minimum spasm duration (s)
```

To customise a run, override fields on the returned struct and pass it along:
```matlab
P = default_emg_parameters();
P.spasm.prc_TA = 70;
[TT, snr] = preprocess_and_label(P, P.fs);
```

See **`config/README.md`** for the complete grouped reference.

---

## How to Use

### For First-Time Users

**Start with the interactive menu:**
```matlab
cd Code/
main
```

You'll see the menu options:
1. Preprocess single recording file
2. Spasm detection & analysis
3. Frequency analysis (spectral features)
4. Cross-recording group analyses
5. Run validation tests
6. Launch GUI interface
7. Display help & documentation
0. Exit

### For Command-Line Users

Once you've explored via the menu, you can call functions directly:

```matlab
% Set up paths
cd Code/
main  % This auto-adds all folders to MATLAB path

% Build the parameter struct (single source of truth)
P = default_emg_parameters();

% Preprocess a recording
[TT, snrValue] = preprocess_and_label(P, P.fs, 'fullFile', 'myfile.mat', 'recID', 1);

% Detect spasms (thresholds default to P.spasm.*)
results = spasm_gait_stim_analysis(TT, snrValue, P.fs, 'PlotResult', true);

% Group comparisons
out = Feature_Extraction();
```

### For Batch Processing

Process multiple files automatically:

```matlab
cd Code/
main  % Sets up paths

P = default_emg_parameters();
files = {'file1.mat', 'file2.mat', 'file3.mat'};
for i = 1:length(files)
    [TT, snrValue] = preprocess_and_label(P, P.fs, 'fullFile', files{i}, 'recID', 1);
    results = labchart_protocol_check_gait_vs_spasm(TT, [], P.fs);
end
```

---

## Documentation & Learning Path

New to EMG analysis? Here's where to start:

### Quick References (5–10 min read)
- **QUICKSTART.md** – Get up and running in 30 seconds
- **REORGANIZATION_SUMMARY.md** – Overview of the new folder structure

### Understanding the Concepts
- **config/README.md** – The central parameter reference (`default_emg_parameters`)
- **preprocessing/README.md** – Signal preprocessing, envelope and SNR/activity masks
- **utilities/README.md** – Filtering, masking and artifact-removal helpers

### Deep Dives by Analysis Type
- **detection/README.md** – Spasm classification and stim ON/OFF analysis
- **analysis/README.md** – Band-power computation and LabChart parity

### Implementation Details
- **visualization/README.md** – Plotting and figure conventions
- **tests/README.md** – Validation workflows and synthetic data generation
- **data/README.md** – Data formats and naming conventions

---

## Common Workflows

### Workflow 1: Quick Data Inspection
```matlab
main
→ Select option 1 (Preprocess)
→ Choose your CSV file
→ View live plots and activity masks
```

### Workflow 2: Find Spasms in a Recording
```matlab
main
→ Select option 2 (Spasm detection)
→ Choose "Spasm vs. Gait comparison"
→ View spasm events and statistics
```

### Workflow 3: Analyze Spectral Features (LabChart Parity)
```matlab
main
→ Select option 3 (Frequency analysis)
→ Choose "LabChart protocol validation"
→ View 100–500 Hz band power and generate CSV
```

### Workflow 4: Cross-Recording Group Comparison
```matlab
main
→ Select option 4 (Cross-recording group analyses)
→ Select multiple recordings
→ Group comparison (injured vs uninjured, stim ON vs OFF) and figures
```

---

## Key Design Principles

This pipeline is built on best practices for reproducible EMG analysis:

✅ **Modular Design** – Separate preprocessing, analysis, and visualization for reusability  
✅ **Configurable** – All parameters in one central file (`config/default_emg_parameters.m`)  
✅ **Robust** – Handles artifacts, baseline drift, and variable signal quality  
✅ **Transparent** – Clear documentation of all algorithms and design choices  
✅ **Validated** – Synthetic data generation and parameter tuning tools included  
✅ **Publication-Ready** – High-quality figures with proper scaling and labeling  

### Signal Processing Highlights

- **Zero-phase filtering:** Eliminates phase distortion using `filtfilt`
- **Adaptive thresholds:** Percentile-based detection adapts to recording conditions
- **Robust scaling:** Median-based normalization resists artifacts better than z-score
- **Proper band-power integration:** Spectral features include frequency resolution (df) for correct units
- **Activity-aware analysis:** All computations respect SNR-based activity masks

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Undefined function" error | Make sure you ran `main` first (it adds all paths) |
| CSV file won't load | Check format: must have Time, TA, MG columns |
| Spasm detection too sensitive | Raise `P.spasm.prc_TA` / `P.spasm.prc_MG` in `config/default_emg_parameters.m` (or enter a higher percentile at the prompt) |
| Too many / too few active samples | Adjust `P.act_prc` / `P.act_prc_MG` in the config |
| GUI doesn't launch | Ensure `interface.mlapp` exists in `config/` folder |
| Out of memory with large files | Use batch processing to split into smaller chunks |

For more help, see the **Help** section in the `main` menu (option 7).

---

## Input/Output Data Formats

### Input: CSV Files from LabChart
```
Time(s),TA(V),MG(V),Stim(V),Notes
0.0000,0.0012,-0.0008,0,Gait_Start
0.0001,0.0015,-0.0009,0
...
```

### Output: Results Directory
All results automatically saved to:
- **Figures/** – PNG/PDF plots (git-ignored)
- **LabChart_protocol_results/** – CSV tables with band powers
- **Your chosen folder** – Feature tables, statistics

---

## Requirements

- **MATLAB R2019b or newer** (R2020a or later recommended)
- **Signal Processing Toolbox**
- No other special toolboxes required!

---

## Citation

If you use this pipeline in your research, please cite:

```bibtex
@software{emg_analysis_2026,
  author = {Your Lab Name},
  title = {EMG Analysis Pipeline},
  year = {2026},
  url = {https://github.com/your-repo/emg-analysis}
}
```

---

## Contributing

Found a bug? Have a suggestion? Contributions are welcome!

Please follow the established naming conventions:
- Analysis functions: `analysis/function_name.m`
- Plotting functions: `visualization/plot_description.m`
- Utility functions: `utilities/utility_name.m`
- Tests: `tests/test_feature.m`

All new functions should include:
- Clear function header with purpose, inputs, outputs
- Usage examples
- Links to related functions

---

## Contact

For questions or support:
- Check the **Help** menu in `main`
- Review module-specific README files
- See ARCHITECTURE.md for system design details

---

**Last Updated:** May 2026  
**Version:** 1.0 (Reorganized and documented)
