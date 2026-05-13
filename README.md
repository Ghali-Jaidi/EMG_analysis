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
├── core/                     (Signal preprocessing)
├── filters/                  (Filtering utilities)
├── utilities/                (Helper functions)
├── analysis/                 (High-level analysis workflows)
│   ├── spasm_detection/
│   ├── frequency_analysis/
│   └── feature_extraction/
├── plotting/                 (Visualization & figures)
├── tests/                    (Validation & synthetic data)
├── data/                     (Sample data)
└── config/                   (Configuration & GUI)
```

**See `ARCHITECTURE.md`** for a detailed dependency diagram and data flow explanation.

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
- **See:** `core/README.md`

### 2️⃣ Spasm Detection
**Find involuntary muscle contractions** using envelope-based analysis.

- **Input:** Preprocessed TT structure
- **Output:** Spasm event masks, statistics (rate, duration, amplitude)
- **What it does:**
  - Computes adaptive thresholds (percentile-based)
  - Detects high-amplitude bursts in muscle activity
  - Classifies spasms as stimulus-evoked or spontaneous
  - Generates statistical comparisons
- **See:** `analysis/spasm_detection/README.md`

### 3️⃣ Frequency Analysis
**Analyze spectral properties** of EMG signals.

- **Input:** Preprocessed TT structure
- **Output:** Band powers (100–500 Hz, 500–1000 Hz), PSD plots, statistics
- **What it does:**
  - Computes power spectral density using Welch's method
  - Integrates power within frequency bands
  - Validates offline analysis against real-time LabChart
  - Generates histograms and comparison plots
- **See:** `analysis/frequency_analysis/README.md`

### 4️⃣ Feature Extraction
**Create features** for classification and statistical analysis.

- **Input:** Preprocessed TT structure
- **Output:** Feature table (amplitude, RMS, frequency content, entropy, correlation)
- **What it does:**
  - Computes time-domain features (mean, std, kurtosis, RMS)
  - Computes frequency-domain features (band powers, spectral centroid)
  - Computes statistical features (entropy, ApEn, SampEn)
  - Cross-channel correlation analysis
- **See:** `analysis/feature_extraction/README.md`

---

## Key Signals & Parameters

### Two Muscle Channels
This pipeline analyzes:
- **TA (Tibialis Anterior):** Anterior shin muscle
- **MG (Medial Gastrocnemius):** Calf muscle

Both are recorded simultaneously at **10 kHz sampling rate**.

### Signal Basis Options
Choose which signal representation to use:

| Basis | Description | Best For |
|-------|-------------|----------|
| **raw** | Unfiltered 10 kHz signals | Spectral analysis, LabChart parity |
| **filtered** | Butterworth bandpass (5–500 Hz) | Envelope extraction, spasm detection |
| **rectified** | Absolute value of filtered signal | Legacy compatibility |

**Default:** `raw` (recommended for most applications)

### Key Parameters
All configurable in `core/default_emg_parameters.m`:

```matlab
opt.fs = 10000;                    % Sampling frequency (Hz)
opt.SignalBasis = 'raw';           % Signal representation
opt.BandpassFreq = [20, 450];      % Filter frequency range
opt.SpasmPrcTA = 75;               % Spasm detection threshold (percentile)
opt.MinSpasmDuration = 0.2;        % Minimum spasm length (seconds)
opt.AnalysisWindowLength = 0.1;    % FFT window (100 ms)
```

---

## How to Use

### For First-Time Users

**Start with the interactive menu:**
```matlab
cd Code/
main
```

You'll see 9 menu options:
1. Preprocess a single file
2. Detect spasms
3. Analyze frequency content
4. Extract features
5. Batch process multiple files
6. Tune parameters
7. Run validation tests
8. Launch GUI interface
9. View help documentation

### For Command-Line Users

Once you've explored via the menu, you can call functions directly:

```matlab
% Set up paths
cd Code/
main  % This auto-adds all folders to MATLAB path

% Preprocess a file
TT = preprocess_and_label('myfile.csv', 'SignalBasis', 'raw');

% Detect spasms
results = spasm_gait_stim_analysis(TT, snrValue, fs);

% Analyze frequency content
plot_spectral_comparison_advanced(TT, 'Gait');

% Extract features
features = Feature_Extraction(TT);
```

### For Batch Processing

Process multiple files automatically:

```matlab
cd Code/
main  % Sets up paths

files = {'file1.csv', 'file2.csv', 'file3.csv'};
for i = 1:length(files)
    TT = preprocess_and_label(files{i}, 'SignalBasis', 'raw');
    results = labchart_protocol_check_gait_vs_spasm(TT, [], TT.fs);
end
```

---

## Documentation & Learning Path

New to EMG analysis? Here's where to start:

### Quick References (5–10 min read)
- **QUICKSTART.md** – Get up and running in 30 seconds
- **REORGANIZATION_SUMMARY.md** – Overview of the new folder structure

### Understanding the Concepts
- **core/README.md** – Learn about signal preprocessing and signal basis options
- **filters/README.md** – Understand filtering approaches
- **utilities/README.md** – Explore helper functions

### Deep Dives by Analysis Type
- **analysis/spasm_detection/README.md** – Spasm event detection algorithms
- **analysis/frequency_analysis/README.md** – Band-power computation and LabChart parity
- **analysis/feature_extraction/README.md** –  feature preparation

### Implementation Details
- **plotting/README.md** – Publication-ready visualization techniques
- **tests/README.md** – Validation workflows and synthetic data generation
- **data/README.md** – Data formats and naming conventions
- **ARCHITECTURE.md** – System design and module dependencies

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

### Workflow 4: Extract Features
```matlab
main
→ Select option 4 (Feature extraction)
→ Get feature table ready for spasm identification
→ Export to CSV
```

### Workflow 5: Process Multiple Files
```matlab
main
→ Select option 5 (Batch processing)
→ Select multiple CSV files
→ Automatic processing and summary statistics
```

---

## Key Design Principles

This pipeline is built on best practices for reproducible EMG analysis:

✅ **Modular Design** – Separate preprocessing, analysis, and visualization for reusability  
✅ **Configurable** – All parameters in one central file (`core/default_emg_parameters.m`)  
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
| Spasm detection too sensitive | Use `main` → option 6 to tune percentile threshold |
| Spectral analysis looks noisy | Try 'filtered' signal basis instead of 'raw' |
| GUI doesn't launch | Ensure `interface.mlapp` exists in `config/` folder |
| Out of memory with large files | Use batch processing to split into smaller chunks |

For more help, see the **Help** section in the `main` menu (option 9).

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
- Analysis functions: `analysis/*/function_name.m`
- Plotting functions: `plotting/plot_description.m`
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
