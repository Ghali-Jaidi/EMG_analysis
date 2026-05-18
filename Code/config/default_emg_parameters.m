function P = default_emg_parameters()

P.envWindowMs = 3;
P.thresholds = [40 50];
P.min_quiet_dur_ms = 10;
P.fuse_gap_ms = 10;

P.snr_win_ms = 20;
P.act_prc = 70;
P.act_prc_MG = 50;

P.detect_acq_start = false;
P.use_envelope = true;

% acquisition start detection
P.acq.rms_win_ms = 20;
P.acq.baseline_mult = 5;
P.acq.window_s = 4;
P.acq.min_active_ms = 2000;
P.acq.plot_debug = false;
P.acq.noise_floor_mode = 'p5';
P.acq.noise_floor_value = 0.1;
P.acq.quiet_prctile = 20;
P.acq.quiet_min_s = 2;
P.acq.robust_k = 6;
%Alternatively, time index of when the acquisition starts
% manually defined from the gui 

P.acq.startingtime = 0;

end