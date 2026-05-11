# Data Module

Sample data files and data management guidelines.

## Files

### `synthetic_rec.mat`
Synthetic EMG recording for testing and demonstration purposes.

**Contents:**
- `TA_raw` – Raw tibialis anterior signal (10 kHz, 30+ seconds)
- `MG_raw` – Raw medial gastrocnemius signal
- `fs` – Sampling frequency (10000 Hz)
- Metadata (condition, subject ID, date)

**Usage:**
```matlab
data = load('data/synthetic_rec.mat');
TT.TA_raw = data.TA_raw;
TT.MG_raw = data.MG_raw;
TT.fs = data.fs;
```

## Data Organization Best Practices

### Directory Structure
```
data/
├── synthetic_rec.mat          (test data, included in repo)
├── raw/                       (git-ignored, local raw recordings)
│   ├── subject_001_gait.csv
│   ├── subject_001_spasm.csv
│   └── ...
└── processed/                 (git-ignored, preprocessed outputs)
    ├── TT_subject_001_gait.mat
    ├── results_subject_001.csv
    └── ...
```

### File Naming Convention
**Raw recordings:**
```
<subject_id>_<condition>_<date>.csv
Example: S001_Gait_2026-05-11.csv
```

**Preprocessed data:**
```
TT_<subject_id>_<condition>.mat
Example: TT_S001_Gait.mat
```

**Analysis results:**
```
results_<analysis_type>_<subject_id>_<date>.csv
Example: results_spasm_detection_S001_2026-05-11.csv
```

### Data Formats

#### CSV (Raw Recordings from LabChart)
- **Columns:** Time, TA_Channel, MG_Channel, Stim_Trigger, Notes
- **Delimiter:** Comma or tab
- **Header:** Yes (column names on first line)
- **Sampling:** 10 kHz (100 µs time intervals)

**Example:**
```
Time(s),TA(V),MG(V),Stim(V),Notes
0.0000,0.0012,-0.0008,0,Gait_Start
0.0001,0.0015,-0.0009,0
...
```

#### MAT (MATLAB Preprocessed)
- **Format:** Binary MATLAB v7.3 (HDF5) for large files
- **Variables:**
  - `TT` (struct) – Preprocessed signals (TA_raw, MG_raw, TA_filt, TA_env, etc.)
  - `opt` (struct) – Processing parameters used
  - `metadata` (struct) – Experiment information

**Saving:**
```matlab
save('data/TT_S001_Gait.mat', 'TT', 'opt', 'metadata', '-v7.3');
```

#### CSV (Analysis Results)
- **Columns:** Window, Time_Start(s), TA_Power_100_500Hz, MG_Power_100_500Hz, is_Spasm_TA, is_Spasm_MG
- **Rows:** One per analysis window (e.g., 100 ms windows)

## Data Privacy & Compliance

- **Real subject data:** Store locally, do NOT commit to repository
- **Synthetic data:** Safe to include (synthetic_rec.mat included)
- **Aggregate statistics:** Safe to commit (summary tables, group comparisons)
- **.gitignore rules** prevent accidental data leakage:
  ```
  data/raw/
  data/processed/
  *.mat        # Except synthetic_rec.mat (explicitly tracked)
  *.csv        # Except test files
  ```

## Data Loading Examples

### Load Synthetic Data (for testing)
```matlab
load('data/synthetic_rec.mat');  % Loads TA_raw, MG_raw, fs
```

### Load Real Subject Data
```matlab
% From CSV file
opts = detectImportOptions('data/raw/S001_Gait_2026-05-11.csv');
data_table = readtable('data/raw/S001_Gait_2026-05-11.csv', opts);
TA_raw = data_table.TA_V;
MG_raw = data_table.MG_V;
fs = 10000;
```

### Load Preprocessed Data
```matlab
load('data/TT_S001_Gait.mat', 'TT', 'opt');
% Now use: TT.TA_raw, TT.TA_env, TT.is_act_TA, etc.
```

## Related Modules

- **Core** (`core/preprocess_and_label.m`): Reads data, generates TT structure
- **Analysis** (`analysis/`): Reads TT structure, generates results
