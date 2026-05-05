% ================================================================
%  TEST SCRIPT - No Amplitude Distribution Plots
% ================================================================

clear; clc;

% Apply white background style for all figures
set_white_background_style();

fs = 10000;

% ------------------------------------------------
% Delete cached synthetic recording to force regeneration
% ------------------------------------------------
if isfile('synthetic_rec.mat')
    delete('synthetic_rec.mat');
    fprintf('Deleted cached synthetic_rec.mat to force regeneration.\n');
end

% ------------------------------------------------
% Generate and save synthetic recording
% ------------------------------------------------
S = generate_synthetic_emg( ...
    'SavePath', 'synthetic_rec.mat', ...
    'PlotResult', false);

% ------------------------------------------------
% Run preprocessing
% ------------------------------------------------
P = default_emg_parameters();

options = struct();
options.envWindowMs = P.envWindowMs;
options.thresholds = P.thresholds;
options.min_quiet_dur_ms = P.min_quiet_dur_ms;
options.fuse_gap_ms = P.fuse_gap_ms;
options.snr_win_ms = P.snr_win_ms;
options.act_prc = P.act_prc;
options.act_prc_MG = P.act_prc_MG;
options.plot_figures = false;
options.save_figures = false;
options.fig_folder = 'Figures';
options.use_envelope = P.use_envelope;
options.fullFile = 'synthetic_rec.mat';
options.recID = 1;

[TT, snr, meta] = preprocess_and_label(fs, options);

% ------------------------------------------------
% Run state analysis
% Kept here for inspection, but not used in the amplitude comparison below
% ------------------------------------------------
state_out = spasm_gait_stim_analysis(TT, snr, fs); %#ok<NASGU>
out_spasm_stim = compare_spasm_stim_vs_nostim(TT, snr, fs, ...
    'SpasmPrcTA',    65,   ...   % percentile on active TA to define spasm threshold
    'SpasmPrcMG',    65,   ...   % percentile on active MG to define spasm threshold
    'SpasmMinDurS',  0.1,  ...   % minimum spasm duration in seconds
    'FuseGapMs',     50,   ...   % fuse spasms separated by less than this
    'Ch3MinOnMs',    100,  ...   % minimum Ch3 ON duration to count as stimulation
    'AmpPercentile', 90,   ...   % percentile used to summarise amplitude in each window
    'MinWindowS',    0.05, ...   % ignore windows shorter than this
    'PlotResult',    true);

% Style all open figures
figHandles = get(0, 'Children');
for iFig = 1:numel(figHandles)
    style_figure_for_presentation(figHandles(iFig));
end

disp('--- Spasm stim comparison ---');
fprintf('TA: p = %.4g\n', out_spasm_stim.p_TA);
fprintf('MG: p = %.4g\n', out_spasm_stim.p_MG);
