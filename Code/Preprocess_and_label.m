function [TT_clean, snrValue, meta] = preprocess_and_label(fs, options)
% run_emg_analysis
% Runs your EMG pipeline. Can optionally suppress all plotting.
%
% Added option:
%   options.plot_figures (logical) : if false, no plots are created/saved.

arguments
    fs (1,1) double {mustBePositive} = 10000
    options.envWindowMs (1,1) double {mustBePositive} = 3
    options.thresholds (1,:) double {mustBeNonempty} = [40 50]
    options.min_quiet_dur_ms (1,1) double {mustBePositive} = 10
    options.fuse_gap_ms (1,1) double {mustBePositive} =  30
    options.snr_win_ms (1,1) double {mustBePositive} = 20
    options.act_prc (1,1) double {mustBePositive} = 80
    options.act_prc_MG (1,1) double {mustBePositive} = 50

    options.plot_figures (1,1) logical = true   % NEW
    options.save_figures (1,1) logical = false
    options.fig_folder (1,:) char = 'Figures'
    options.use_envelope (1, 1) logical = false

    % Optional: provide file + recording to skip UI
    options.fullFile (1,:) char = ''
    options.recID (1,1) double = NaN
end

%% ---- Select experiment file (unless provided) ----
if isempty(options.fullFile)
    [fileName, filePath] = uigetfile('*.mat', 'Select experiment MAT file');
    if isequal(fileName,0)
        error('No file selected. Script stopped.');
    end
    fullFile = fullfile(filePath, fileName);
else
    fullFile = options.fullFile;
    [~, fileName, ~] = fileparts(fullFile);
    fileName = [fileName '.mat'];
end
fprintf('Loading experiment: %s\n', fullFile);
S = load(fullFile);

%% ---- Detect available recordings ----
allVars = fieldnames(S);
recNums = [];
expr = '^data__chan_1_rec_(\d+)$';
for i = 1:numel(allVars)
    tok = regexp(allVars{i}, expr, 'tokens');
    if ~isempty(tok)
        recNums(end+1) = str2double(tok{1}{1}); %#ok<AGROW>
    end
end
recNums = unique(recNums);
if isempty(recNums)
    error('No recordings found (data__chan_1_rec_X).');
end

%% ---- Select recording (unless provided) ----
if ~isnan(options.recID)
    recID = options.recID;
    assert(ismember(recID, recNums), 'Provided recID not available in file.');
else
    recLabels = arrayfun(@(r) sprintf('Recording %d', r), recNums, 'UniformOutput', false);
    [idx, ok] = listdlg('PromptString','Select recording to analyze:', ...
                        'SelectionMode','single', ...
                        'ListString',recLabels);
    if ~ok, error('No recording selected.'); end
    recID = recNums(idx);
end
fprintf('Selected recording: %d\n', recID);

%% ---- Extract selected recording ----
v1 = sprintf('data__chan_1_rec_%d', recID);
v2 = sprintf('data__chan_2_rec_%d', recID);
v3 = sprintf('data__chan_3_rec_%d', recID);
assert(isfield(S,v1) && isfield(S,v2) && isfield(S,v3), ...
    'Selected recording is missing one or more channels.');

x1 = S.(v1)(:); x2 = S.(v2)(:); x3 = S.(v3)(:);
N = min([numel(x1) numel(x2) numel(x3)]);
y1 = x1(1:N); y2 = x2(1:N); y3 = x3(1:N);

%% ---- Build timetable ----
tDur = seconds((0:N-1)'/fs);
TT = timetable(tDur, y1, y2, y3, 'VariableNames', {'TA_raw','MG_raw','Ch3_raw'});

%% ---- Robust scaling ----
scale = @(v) (v - median(v)) / (mad(v,1) + eps);
TT.TA  = scale(TT.TA_raw);
TT.MG  = scale(TT.MG_raw);
TT.Ch3 = TT.Ch3_raw;

%% ---- Filters ----
TT.TA_f = notch_filter(butter_filter(TT.TA));
TT.MG_f = notch_filter(butter_filter(TT.MG));

t = seconds(TT.tDur);

if options.plot_figures
    plot_filtered(TT.TA_f, TT.MG_f, TT.Ch3, t);
    plot_PSD(TT.TA, TT.TA_f, TT.MG, TT.MG_f);
end

%% ---- Rectification + envelope ----
TT.TA_rect = abs(TT.TA_f);
TT.MG_rect = abs(TT.MG_f);

envWindowSamples = max(1, round((options.envWindowMs/1000) * fs));
b = ones(envWindowSamples,1) / envWindowSamples;
TT.TA_env = filtfilt(b, 1, TT.TA_rect);
TT.MG_env = filtfilt(b, 1, TT.MG_rect);

%% ---- Choose amplitude signal for rest/SNR ----
if options.use_envelope
    TA = TT.TA_env;
    MG = TT.MG_env;
else
    TA = TT.TA_rect;
    MG = TT.MG_rect;
end

%% ---- Rest masks (unclean) ----
[is_quiet_TA, thresh_quiet_TA] = find_quiet_mask(TA, options.thresholds, 'TA');
[is_quiet_MG, thresh_quiet_MG] = find_quiet_mask(MG, options.thresholds, 'MG'); % FIX

min_quiet_dur = round((options.min_quiet_dur_ms/1000) * fs);
gap_ms        = options.fuse_gap_ms;

is_rest_TA_unclean = fuse_masks(keep_long_runs(is_quiet_TA, min_quiet_dur), fs, gap_ms);
is_rest_MG_unclean = fuse_masks(keep_long_runs(is_quiet_MG, min_quiet_dur), fs, gap_ms);

noise_rms_TA = rms(TA(is_rest_TA_unclean));
noise_rms_MG = rms(MG(is_rest_MG_unclean)); % FIX

%% ---- Preliminary SNR (uses chosen TA/MG) ----
snr_pre = snr_emg(TA, is_rest_TA_unclean, fs, options.snr_win_ms, options.act_prc, ...
    'xMG', MG, ...
    'is_rest_MG', is_rest_MG_unclean, ...
    'act_prc_MG', options.act_prc_MG);
snr_pre.is_act    = fuse_masks(snr_pre.is_act,    fs, gap_ms);
snr_pre.is_act_MG = fuse_masks(snr_pre.is_act_MG, fs, gap_ms);
snr_pre.thr_rest    = thresh_quiet_TA;
snr_pre.thr_rest_MG = thresh_quiet_MG;

%% ---- Artifact removal ----
[~, TT_NaN, bad_seg] = remove_artifacts(TT, snr_pre, fs);
TT_clean = TT_NaN;  % keep name for compatibility downstream, but it is NOT compressed now% Ensure filtered signals exist in TT_clean (depends on remove_artifacts implementation)
if ~ismember('TA_f', TT_clean.Properties.VariableNames)
    TT_clean.TA_f = notch_filter(butter_filter(TT_clean.TA));
end
if ~ismember('MG_f', TT_clean.Properties.VariableNames)
    TT_clean.MG_f = notch_filter(butter_filter(TT_clean.MG));
end

% Ensure rect exists too (if remove_artifacts dropped it)
if ~ismember('TA_rect', TT_clean.Properties.VariableNames)
    TT_clean.TA_rect = abs(TT_clean.TA_f);
end
if ~ismember('MG_rect', TT_clean.Properties.VariableNames)
    TT_clean.MG_rect = abs(TT_clean.MG_f);
end

% Recompute env on cleaned rect (always possible)
TT_clean.TA_env = filtfilt(b, 1, TT_clean.TA_rect);
TT_clean.MG_env = filtfilt(b, 1, TT_clean.MG_rect);

%% ---- Choose cleaned amplitude signal consistently ----
if options.use_envelope
    TA_clean = TT_clean.TA_env;
    MG_clean = TT_clean.MG_env;
else
    TA_clean = TT_clean.TA_rect;
    MG_clean = TT_clean.MG_rect;
end

%% ---- Final rest masks (mapped to cleaned timeline) ----
is_rest_TA_clean = is_rest_TA_unclean;
is_rest_MG_clean = is_rest_MG_unclean;

% mark bad segments as not-rest (and later also not-active)
is_rest_TA_clean(bad_seg) = false;
is_rest_MG_clean(bad_seg) = false;

is_rest_TA_clean = fuse_masks(is_rest_TA_clean, fs, gap_ms);
is_rest_MG_clean = fuse_masks(is_rest_MG_clean, fs, gap_ms);

assert(numel(is_rest_TA_clean) == height(TT_clean), "Rest mask length mismatch with TT_clean.");
%% ---- Final SNR (uses chosen TA_clean/MG_clean) ----
snrValue = snr_emg(TA_clean, is_rest_TA_clean, fs, options.snr_win_ms, options.act_prc, ...
    'xMG', MG_clean, ...
    'is_rest_MG', is_rest_MG_clean, ...
    'act_prc_MG', options.act_prc_MG);
% ---- Fuse active and rest masks (merge close bursts; no keep_long_runs for active parts) ----
snrValue.is_act    = fuse_masks(snrValue.is_act,    fs, gap_ms);
snrValue.is_act_MG = fuse_masks(snrValue.is_act_MG, fs, gap_ms);
snrValue.is_rest     = is_rest_TA_clean;
snrValue.is_rest_MG  = is_rest_MG_clean;
snrValue.thr_rest    = thresh_quiet_TA;
snrValue.thr_rest_MG = thresh_quiet_MG;  

if options.plot_figures
    fprintf('SNR -> TA: %.2f (%.2f dB)   MG: %.2f (%.2f dB)\n', ...
        snrValue.SNR_TA, snrValue.SNR_dB, snrValue.SNR_MG, snrValue.SNR_MG_dB);

    figure;
    subplot(2,1,1);
    plot_amplitudes(TT.TA_f, 'NumBins', 100, 'Axes', gca, ...
        'ThrAct', snrValue.thr_act, 'NoiseRMS', noise_rms_TA);
    title('Left TA - Amplitude Distribution (unrectified)');

    subplot(2,1,2);
    plot_amplitudes(TT.MG_f, 'NumBins', 100, 'Axes', gca, ...
        'ThrAct', snrValue.thr_act_MG, 'NoiseRMS', noise_rms_MG);
    title('Left MG - Amplitude Distribution (unrectified)');

    if options.use_envelope
        TA_plot = TT_clean.TA_env .* sign(TT_clean.TA_f);
        MG_plot = TT_clean.MG_env .* sign(TT_clean.MG_f);
    else
        TA_plot = TT_clean.TA_f;
        MG_plot = TT_clean.MG_f;
    end
    
    plot_filtered_labeled(TA_plot, MG_plot, TT_clean.Ch3, ...
        seconds(TT_clean.tDur), snrValue);
end

%% ---- Save figures (optional) ----
if options.plot_figures && options.save_figures
    [~, baseName, ~] = fileparts(fileName);
    if ~exist(options.fig_folder, 'dir'), mkdir(options.fig_folder); end
    figFile = fullfile(options.fig_folder, sprintf('%s_rec%d_figures.fig', baseName, recID));
    savefig(findall(0,'Type','figure'), figFile);
    fprintf('Figures saved to: %s\n', figFile);
end

%% ---- Meta ----
meta = struct();
meta.fileName = fileName;
meta.fullFile = fullFile;
meta.recID    = recID;
meta.varNames = {v1,v2,v3};
meta.noise_rms_TA = noise_rms_TA;
meta.noise_rms_MG = noise_rms_MG;
meta.thresh_quiet_TA = thresh_quiet_TA;
meta.thresh_quiet_MG = thresh_quiet_MG;
meta.is_rest_TA_unclean = is_rest_TA_unclean;
meta.is_rest_MG_unclean = is_rest_MG_unclean;
meta.bad_seg = bad_seg;

end