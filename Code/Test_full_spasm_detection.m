% ================================================================
%  TEST SCRIPT
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

% ------------------------------------------------
% Choose MG signal for amplitude analysis
% Recommended: envelope if available, otherwise filtered/raw MG
% ------------------------------------------------
if ismember('MG_env', TT.Properties.VariableNames)
    MG_for_amp = TT.MG_env;
elseif ismember('MG_filt', TT.Properties.VariableNames)
    MG_for_amp = abs(TT.MG_filt);
elseif ismember('MG', TT.Properties.VariableNames)
    MG_for_amp = abs(TT.MG);
else
    error('Could not find MG signal in TT.');
end

% ------------------------------------------------
% Choose TA signal for amplitude analysis
% Recommended: envelope if available, otherwise filtered/raw TA
% ------------------------------------------------
if ismember('TA_env', TT.Properties.VariableNames)
    TA_for_amp = TT.TA_env;
elseif ismember('TA_filt', TT.Properties.VariableNames)
    TA_for_amp = abs(TT.TA_filt);
elseif ismember('TA', TT.Properties.VariableNames)
    TA_for_amp = abs(TT.TA);
else
    error('Could not find TA signal in TT.');
end

if ismember('Ch3_raw', TT.Properties.VariableNames)
    Ch3_for_amp = TT.Ch3_raw;
else
    error('Could not find Ch3_raw in TT.');
end

% ------------------------------------------------
% Match the master-script logic:
%   - invalidate bad samples using meta.is_valid
%   - compare each ON epoch to a local pre-ON OFF window
% ------------------------------------------------
if isfield(meta, 'is_valid') && numel(meta.is_valid) == numel(Ch3_for_amp)
    MG_for_amp(~meta.is_valid)  = NaN;
    TA_for_amp(~meta.is_valid)  = NaN;
    Ch3_for_amp(~meta.is_valid) = NaN;
else
    warning('meta.is_valid not found or size mismatch. Proceeding without invalid-sample masking.');
end

count_runs = @(x) sum(diff([false; x(:); false]) == 1);

fprintf('Raw synthetic Ch3 ON runs: %d\n', count_runs(S.ground_truth.is_ch3_on));

ch3_raw_mask = TT.Ch3_raw > 0;
fprintf('TT.Ch3_raw ON runs: %d\n', count_runs(ch3_raw_mask));

ch3_valid = TT.Ch3_raw;
ch3_valid(~meta.is_valid) = NaN;
fprintf('Valid Ch3 ON runs after meta.is_valid masking: %d\n', ...
    count_runs(isfinite(ch3_valid) & ch3_valid > 0));

out_MG = amplitude_distribution(MG_for_amp, Ch3_for_amp, fs, ...
    'MGAlreadyAmplitude', true, ...
    'AmpPercentile', 90, ...
    'NormalizeToOn', false, ...
    'PreWindowS', [-2 -0.01], ...
    'PostWindowS', [0.5 2], ...
    'OnMinDurMs', 100, ...
    'SpasmMask', state_out.is_spasm, ...
    'RestMask', state_out.is_rest, ...
    'DominantFrac', 0.5, ...
    'RestFracThreshold', 0.6, ...
    'RequireOnInsideContext', false, ...
    'RequirePreInsideContext', false, ...
    'RequirePostInsideContext', false, ...
    'TitleStr', 'MG amplitude during Ch3 ON vs OFF');

% Style the MG figure
figHandles = get(0, 'Children');
style_figure_for_presentation(figHandles(1));

disp('--- MG summary ---');
disp(out_MG.summary);

out_TA = amplitude_distribution( ...
    TA_for_amp, Ch3_for_amp, fs, ...
    'MGAlreadyAmplitude', true, ...
    'AmpPercentile', 90, ...
    'NormalizeToOn', false, ...
    'PreWindowS', [-2 -0.01], ...
    'PostWindowS', [0.5 2], ...
    'OnMinDurMs', 100, ...
    'SpasmMask', state_out.is_spasm, ...
    'RestMask', state_out.is_rest, ...
    'DominantFrac', 0.5, ...
    'RestFracThreshold', 0.3, ...
    'RequireOnInsideContext', false, ...
    'RequirePreInsideContext', false, ...
    'RequirePostInsideContext', false, ...
    'TitleStr', 'TA amplitude during Ch3 ON vs OFF');

% Style the TA figure
figHandles = get(0, 'Children');
style_figure_for_presentation(figHandles(1));


disp('--- TA summary ---');
disp(out_TA.summary);