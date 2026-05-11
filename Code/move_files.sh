#!/bin/zsh

# Core preprocessing
mv preprocess_and_label.m core/
mv preprocess_and_label.asv core/
mv default_emg_parameters.m core/
mv snr_emg.m core/

# Filters
mv butter_filter.m filters/
mv notch_filter.m filters/

# Utilities
mv keep_long_runs.m utilities/
mv fuse_masks.m utilities/
mv find_quiet_mask.m utilities/
mv remove_artifacts.m utilities/
mv detect_valid_acquisition_start.m utilities/
mv ask_condition_and_intervals.m utilities/
mv compute_spasm_threshold.m utilities/
mv compute_logical_ticks.m utilities/
mv normalize_signal_for_display.m utilities/

# Spasm Detection Analysis
mv spasm_gait_stim_analysis.m analysis/spasm_detection/
mv compare_spasm_stim_vs_nostim.m analysis/spasm_detection/
mv compare_files_xcorr.m analysis/spasm_detection/

# Frequency Analysis
mv labchart_protocol_check_gait_vs_spasm.m analysis/frequency_analysis/
mv plot_spectral_comparison_advanced.m analysis/frequency_analysis/
mv batch_spectral_analysis.m analysis/frequency_analysis/
mv compare_frequency_content.m analysis/frequency_analysis/

# Feature Extraction
mv Feature_Extraction.m analysis/feature_extraction/
mv emg_parameter_tuning.m analysis/feature_extraction/

# Plotting
mv plot_PSD.m plotting/
mv plot_amplitudes.m plotting/
mv plot_filtered.m plotting/
mv plot_filtered_labeled.m plotting/
mv plot_frequency_spectrum.m plotting/
mv plot_rect_and_env.m plotting/
mv plot_TA_MG_correlation.m plotting/
mv Spasms_plot.m plotting/

# Tests
mv Test_full_spasm_detection.m tests/
mv amplitude_distribution.m tests/
mv generate_synthetic_emg.m tests/

# Data
mv synthetic_rec.mat data/

# Config
mv interface.mlapp config/

echo "✅ File reorganization complete!"
