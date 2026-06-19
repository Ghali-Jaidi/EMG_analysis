function P = default_emg_parameters()
% DEFAULT_EMG_PARAMETERS  Central configuration for the EMG pipeline.
%
% This struct is the single source of truth for every tunable value used
% across preprocessing, SNR/activity detection, artifact rejection and
% spasm/stim analysis. Functions that used to hard-code these numbers now
% read them from here (directly, or via their default arguments), so the
% behaviour of the whole pipeline can be changed from this one file.
%
% Parameters are grouped by the stage of the pipeline that consumes them.

%% =====================================================================
%  ACQUISITION / SAMPLING
%  Basic properties of the recorded signal.
%% =====================================================================
P.fs = 10000;                 % sampling frequency (Hz) of the LabChart export

%% =====================================================================
%  FILTERING  (used by butter_filter.m and notch_filter.m)
%  Applied to the raw TA/MG channels before rectification.
%% =====================================================================
P.filter.bp_fc    = [5 500];  % band-pass cutoffs [low high] in Hz (Butterworth)
P.filter.bp_order = 2;        % Butterworth order; filtfilt doubles it (effective 4th order)
P.filter.notch_f0 = 50;       % power-line frequency to notch out (Hz, 50 = Europe)
P.filter.notch_Q  = 30;       % notch quality factor (higher = narrower notch, ~1.7 Hz BW)
%  Only the 50 Hz fundamental is notched (no harmonics) to preserve EMG content.

%% =====================================================================
%  ENVELOPE  (used by preprocess_and_label.m)
%  Linear envelope = moving average of the rectified, filtered signal.
%% =====================================================================
P.envWindowMs = 3;            % moving-average window for the envelope (ms)
P.use_envelope = true;        % true: threshold on envelope; false: on raw rectified signal

%% =====================================================================
%  REST / QUIET DETECTION  (used by preprocess_and_label.m)
%  Identifies low-amplitude "quiet" baseline used as the noise reference.
%% =====================================================================
P.thresholds       = [40 50]; % percentile sequence passed to find_quiet_mask (quiet/rest cut)
P.min_quiet_dur_ms = 10;      % minimum quiet-segment duration (ms)
P.fuse_gap_ms      = 10;      % gap (ms) below which adjacent rest/activity bursts are merged

%% =====================================================================
%  SNR / ACTIVITY DETECTION  (used by snr_emg.m)
%  Windowed-RMS activity mask and SNR estimate, per channel.
%% =====================================================================
P.snr_win_ms          = 20;   % sliding RMS window for SNR / activity (ms)
P.act_prc             = 70;   % TA activity-detection percentile of windowed RMS
P.act_prc_MG          = 50;   % MG activity-detection percentile of windowed RMS
P.min_active_dur_ms   = 50;   % minimum sustained active run to keep (ms)
P.act_fuse_gap_ms     = 50;   % gap (ms) below which adjacent active bursts are merged

%% =====================================================================
%  ARTIFACT REJECTION  (used by remove_artifacts.m)
%  Flags rail/clipping events relative to the typical active RMS.
%% =====================================================================
P.artifact.rms_mult      = 5000; % amplitude ceiling = rms_mult * active RMS (very permissive)
P.artifact.dilate_win_ms = 30;   % moving-average window to dilate flagged regions (ms)
P.artifact.pad_ms        = 25;    % padding added around flagged regions (ms)
P.artifact.frac_thresh   = 0.2;   % fraction of dilation window that must be flagged (0-1)

%% =====================================================================
%  SPASM / STIM ANALYSIS  (used by spasm_gait_stim_analysis.m)
%  Thresholds for spasm classification and Ch3 stimulation ON/OFF split.
%% =====================================================================
P.spasm.prc_TA            = 70;   % percentile on active TA envelope for spasm threshold
P.spasm.prc_MG            = 70;   % percentile on active MG envelope for spasm threshold
P.spasm.min_dur_s         = 0.1;  % minimum spasm event duration (s)
P.spasm.fuse_gap_ms       = 50;   % gap (ms) below which adjacent spasm bursts are merged
P.spasm.gait_min_overlap_s = 0.05;% kept for compatibility, unused in current active definition
P.spasm.ch3_threshold     = [];   % manual Ch3 ON threshold; [] = auto (midpoint of min/max)
P.spasm.ch3_min_on_ms     = 100;  % minimum Ch3 ON pulse duration (ms)
P.spasm.plot_downsample   = 10;   % downsampling factor for the annotated figure

%% =====================================================================
%  ACQUISITION-START DETECTION  (used by detect_valid_acquisition_start)
%  Rejects pre-acquisition zeros/artifacts before threshold estimation.
%% =====================================================================
P.detect_acq_start = false;   % master switch: auto-detect the acquisition start

P.acq.rms_win_ms        = 20;     % RMS window for acq-start detection (ms)
P.acq.baseline_mult     = 5;      % multiplier on baseline RMS to declare a channel "live"
P.acq.window_s          = 4;      % sliding search window for acq start (s)
P.acq.min_active_ms     = 2000;   % minimum sustained activity to confirm acq start (ms)
P.acq.plot_debug        = false;  % plot debug figures for acq-start detection
P.acq.noise_floor_mode  = 'p5';   % noise-floor estimation strategy
P.acq.noise_floor_value = 0.1;    % fallback fixed noise floor
P.acq.quiet_prctile     = 20;     % quiet-region percentile for acq detection
P.acq.quiet_min_s       = 2;      % minimum quiet duration before acq start (s)
P.acq.robust_k          = 6;      % MAD multiplier for outlier detection
P.acq.startingtime      = 0;      % manual acq-start override (s), e.g. set from the GUI

% Per-channel "valid acquisition" detector knobs (detect_valid_acquisition_start).
P.acq.valid.min_valid_ms        = 100;  % minimum valid-run length (ms)
P.acq.valid.base_dur_s          = 3;    % baseline duration used for the start estimate (s)
P.acq.valid.start_k_mad         = 3;    % MAD multiplier for the start threshold
P.acq.valid.fuse_gap_ms         = 50;   % gap (ms) to fuse nearby valid runs
P.acq.valid.min_channels_req    = 2;    % channels that must agree for a valid start
P.acq.valid.quiet_before_s      = 0.5;  % required quiet duration before the start (s)
P.acq.valid.env_mult            = 3;    % envelope multiplier over baseline to call "active"
P.acq.valid.fallback_full_valid = true; % if detection fails, treat the whole signal as valid
P.acq.valid.plot_debug          = true; % plot debug figures for the valid-acq detector

end
