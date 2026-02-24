function [TT_clean, snrValue, meta] = preprocess_and_label(fs, options)
% run_emg_analysis
% Runs your EMG pipeline. Can optionally suppress all plotting.
%
% Added option:
%   options.plot_figures (logical) : if false, no plots are created/saved.

arguments
    fs (1,1) double {mustBePositive} = 10000
    options.envWindowMs (1,1) double {mustBePositive} = 10
    options.thresholds (1,:) double {mustBeNonempty} = [40 50]
    options.min_quiet_dur_ms (1,1) double {mustBePositive} = 5
    options.fuse_gap_ms (1,1) double {mustBePositive} = 50
    options.snr_win_ms (1,1) double {mustBePositive} = 20
    options.act_prc (1,1) double {mustBePositive} = 80

    options.plot_figures (1,1) logical = true   % NEW
    options.save_figures (1,1) logical = true
    options.fig_folder (1,:) char = 'Figures'

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

%% ---- Rest masks ----
[is_quiet_TA, thresh_quiet_TA] = find_quiet_mask(TT.TA_rect, options.thresholds, 'TA');
[is_quiet_MG, thresh_quiet_MG] = find_quiet_mask(TT.MG_rect, options.thresholds, 'MG');

min_quiet_dur = round((options.min_quiet_dur_ms/1000) * fs);
gap_ms = options.fuse_gap_ms;

is_rest_TA_unclean = fuse_masks(keep_long_runs(is_quiet_TA, min_quiet_dur), fs, gap_ms);
is_rest_MG_unclean = fuse_masks(keep_long_runs(is_quiet_MG, min_quiet_dur), fs, gap_ms);

noise_rms_TA = rms(TT.TA_rect(is_rest_TA_unclean));
noise_rms_MG = rms(TT.MG_rect(is_rest_MG_unclean));

if options.plot_figures
    spacing = max([range(TT.TA_f), range(TT.MG_f), range(TT.Ch3)]) * 1.5;
    plot_rect_and_env(t, TT.TA_rect, TT.MG_rect, TT.TA_env, TT.MG_env, TT.Ch3, spacing, options.envWindowMs);
end

%% ---- Preliminary SNR ----
snr_pre = snr_emg(TT.TA_rect, is_rest_TA_unclean, fs, options.snr_win_ms, options.act_prc, ...
    'xMG', TT.MG_rect, 'is_rest_MG', is_rest_MG_unclean);
snr_pre.thr_rest    = thresh_quiet_TA;
snr_pre.thr_rest_MG = thresh_quiet_MG;

%% ---- Artifact removal ----
[TT_clean, ~, bad_seg] = remove_artifacts(TT, snr_pre, fs);

TT_clean.TA_env = filtfilt(b, 1, TT_clean.TA_rect);
TT_clean.MG_env = filtfilt(b, 1, TT_clean.MG_rect);

%% ---- Final rest masks ----
is_rest_TA_clean = fuse_masks(is_rest_TA_unclean(~bad_seg), fs, gap_ms);
is_rest_MG_clean = fuse_masks(is_rest_MG_unclean(~bad_seg), fs, gap_ms);

assert(numel(is_rest_TA_clean) == height(TT_clean), "Rest mask length mismatch with TT_clean.");

%% ---- Final SNR ----
snrValue = snr_emg(TT_clean.TA_rect, is_rest_TA_clean, fs, options.snr_win_ms, options.act_prc, ...
    'xMG', TT_clean.MG_rect, 'is_rest_MG', is_rest_MG_clean);

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

    plot_filtered_labeled(TT_clean.TA_env, TT_clean.MG_env, TT_clean.Ch3, ...
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