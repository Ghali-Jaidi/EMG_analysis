function [TT_clean, snrValue, meta, preview] = preprocess_and_label( P, fs, options)
% run_emg_analysis
% Runs your EMG pipeline. Can optionally suppress all plotting.
%
% Added option:
%   options.plot_figures (logical) : if false, no plots are created/saved.

arguments
    P = default_emg_parameters()
    fs (1,1) double {mustBePositive} = 10000
    options.plot_figures (1,1) logical = true   
    options.save_figures (1,1) logical = false
    options.fig_folder (1,:) char = 'Figures'

    % Optional: provide file + recording to skip UI
    options.fullFile (1,:) char = ''
    options.recID (1,1) double = NaN
    
end

if isempty(P) 
   
end

min_quiet_samples = round(P.min_quiet_dur_ms/1000 * fs);


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

envWindowSamples = max(1, round((P.envWindowMs/1000) * fs));
b = ones(envWindowSamples,1) / envWindowSamples;
TT.TA_env = filtfilt(b, 1, TT.TA_rect);
TT.MG_env = filtfilt(b, 1, TT.MG_rect);

%% ---- Detect valid acquisition start (reject pre-acquisition zeros/artifacts) ----
valid_opts = struct();
valid_opts.min_valid_ms      = 100;
valid_opts.base_dur_s        = 3;
valid_opts.start_k_mad       = 3;
valid_opts.fuse_gap_ms       = 50;
valid_opts.min_channels_req  = 2;
valid_opts.quiet_before_s    = 0.5;
valid_opts.env_mult          = 3;
valid_opts.fallback_full_valid = true;
valid_opts.plot_debug          = true; 

if P.detect_acq_start
    [is_valid_acq, ~] = detect_valid_acquisition_start( ...
        TT.TA_f, TT.MG_f, TT.TA_env, TT.MG_env, fs, valid_opts);
    
    if ~any(is_valid_acq)
        warning('Acquisition start not detected for this recording. Using full signal.');
        is_valid_acq = true(size(TT.TA_f));
    end
else
    % Skip detection and keep full recording valid
    is_valid_acq = true(size(TT.TA_f));
end

%% ---- Choose amplitude signal for rest/SNR ----
if P.use_envelope
    TA = TT.TA_env;
    MG = TT.MG_env;
else
    TA = TT.TA_rect;
    MG = TT.MG_rect;
end

% Only use valid acquisition period for threshold estimation
TA_valid = TA(is_valid_acq);
MG_valid = MG(is_valid_acq);

%% ---- Rest masks (unclean) ----

[is_quiet_TA_valid, thresh_quiet_TA] = find_quiet_mask(TA_valid, P.thresholds, 'TA');
[is_quiet_MG_valid, thresh_quiet_MG] = find_quiet_mask(MG_valid, P.thresholds, 'MG');

% Map back to full timeline
is_quiet_TA = false(size(TA));
is_quiet_MG = false(size(MG));
is_quiet_TA(is_valid_acq) = is_quiet_TA_valid;
is_quiet_MG(is_valid_acq) = is_quiet_MG_valid;

is_rest_TA_unclean = fuse_masks(keep_long_runs(is_quiet_TA, min_quiet_samples), fs, P.fuse_gap_ms);
is_rest_MG_unclean = fuse_masks(keep_long_runs(is_quiet_MG, min_quiet_samples), fs, P.fuse_gap_ms);

is_rest_TA_unclean(~is_valid_acq) = false;
is_rest_MG_unclean(~is_valid_acq) = false;

noise_rms_TA = rms(TA(is_rest_TA_unclean), 'omitnan');
noise_rms_MG = rms(MG(is_rest_MG_unclean), 'omitnan');
if ~any(is_rest_TA_unclean), noise_rms_TA = NaN; end
if ~any(is_rest_MG_unclean), noise_rms_MG = NaN; end
%% ---- Preliminary SNR (uses chosen TA/MG) ----
fprintf("TA_valid length: %d\n", length(TA_valid));
fprintf("Quiet TA samples: %d\n", sum(is_quiet_TA_valid));
fprintf("TA percentiles: %.3f %.3f %.3f\n", prctile(TA_valid,[10 40 80]));
snr_pre = snr_emg(TA, is_rest_TA_unclean, fs, P.snr_win_ms, P.act_prc, ...
    'xMG', MG, ...
    'is_rest_MG', is_rest_MG_unclean, ...
    'act_prc_MG', P.act_prc_MG, ...
    'valid_mask', is_valid_acq);
snr_pre.is_act    = fuse_masks(snr_pre.is_act,    fs, P.fuse_gap_ms);
snr_pre.is_act_MG = fuse_masks(snr_pre.is_act_MG, fs, P.fuse_gap_ms);
snr_pre.thr_rest    = thresh_quiet_TA;
snr_pre.thr_rest_MG = thresh_quiet_MG;
snr_pre.is_act(~is_valid_acq) = false;
snr_pre.is_act_MG(~is_valid_acq) = false;

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
disp(any(isnan(TT_clean.TA_rect(:))))
disp(any(isinf(TT_clean.TA_rect(:))))

% Recompute env on cleaned rect (always possible)
TT_clean.TA_env = filtfilt(b, 1, TT_clean.TA_rect);
TT_clean.MG_env = filtfilt(b, 1, TT_clean.MG_rect);

%% ---- Choose cleaned amplitude signal consistently ----
if P.use_envelope
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

is_rest_TA_clean = fuse_masks(is_rest_TA_clean, fs, P.fuse_gap_ms);
is_rest_MG_clean = fuse_masks(is_rest_MG_clean, fs, P.fuse_gap_ms);
is_rest_TA_clean(~is_valid_acq) = false;
is_rest_MG_clean(~is_valid_acq) = false;

assert(numel(is_rest_TA_clean) == height(TT_clean), "Rest mask length mismatch with TT_clean.");
%% ---- Final SNR (uses chosen TA_clean/MG_clean) ----
snrValue = snr_emg(TA_clean, is_rest_TA_clean, fs, P.snr_win_ms, P.act_prc, ...
    'xMG', MG_clean, ...
    'is_rest_MG', is_rest_MG_clean, ...
    'act_prc_MG', P.act_prc_MG, ...
    'valid_mask', is_valid_acq);
    
% ---- Fuse active and rest masks (merge close bursts; no keep_long_runs for active parts) ----
snrValue.is_act    = fuse_masks(snrValue.is_act,    fs, P.fuse_gap_ms);
snrValue.is_act_MG = fuse_masks(snrValue.is_act_MG, fs, P.fuse_gap_ms);
snrValue.is_rest     = is_rest_TA_clean;
snrValue.is_rest_MG  = is_rest_MG_clean;
snrValue.thr_rest    = thresh_quiet_TA;
snrValue.thr_rest_MG = thresh_quiet_MG;  

snrValue.is_act(~is_valid_acq) = false;
snrValue.is_act_MG(~is_valid_acq) = false;
snrValue.is_rest(~is_valid_acq) = false;
snrValue.is_rest_MG(~is_valid_acq) = false;

%% ---- Enforce mutually exclusive states (fix overlap color issue) ----
overlap_TA = snrValue.is_act & snrValue.is_rest;
overlap_MG = snrValue.is_act_MG & snrValue.is_rest_MG;


snrValue.is_rest(overlap_TA) = false; 
snrValue.is_rest_MG(overlap_MG) = false;

if P.use_envelope
    TA_plot = TT_clean.TA_env .* sign(TT_clean.TA_f);
    MG_plot = TT_clean.MG_env .* sign(TT_clean.MG_f);
else
    TA_plot = TT_clean.TA_f;
    MG_plot = TT_clean.MG_f;
end

if options.plot_figures
    fprintf('SNR -> TA: %.2f (%.2f dB)   MG: %.2f (%.2f dB)\n', ...
        snrValue.SNR_TA, snrValue.SNR_dB, snrValue.SNR_MG, snrValue.SNR_MG_dB);

    figure;
    subplot(2,1,1);
    plot_amplitudes(TT.TA_f(is_valid_acq), 'NumBins', 100, 'Axes', gca, ...
        'ThrAct', snrValue.thr_act, 'NoiseRMS', noise_rms_TA);
    title('Left TA - Amplitude Distribution (unrectified)');

    subplot(2,1,2);
    plot_amplitudes(TT.MG_f(is_valid_acq), 'NumBins', 100, 'Axes', gca, ...
        'ThrAct', snrValue.thr_act_MG, 'NoiseRMS', noise_rms_MG);
    title('Left MG - Amplitude Distribution (unrectified)');

    
    plot_filtered_labeled(TA_plot, MG_plot, TT_clean.Ch3, ...
        seconds(TT_clean.tDur), snrValue);
    % ---- Highlight TA∩MG overlap (both active) ----
    ov = snrValue.is_act(:) & snrValue.is_act_MG(:);
    
    tsec = seconds(TT_clean.tDur);
    
    figure('Name','TA/MG activity overlap');
    ax = axes; hold(ax,'on'); grid(ax,'on');
    
    % plot signals (same ones you used above)
    plot(ax, tsec, TA_plot, 'DisplayName','TA');
    plot(ax, tsec, MG_plot, 'DisplayName','MG');
    
    % shade overlap regions
    yl = ylim(ax);
    d = diff([false; ov; false]);
    i0 = find(d==1);
    i1 = find(d==-1)-1;
    
    for k = 1:numel(i0)
        x0 = tsec(i0(k));
        x1 = tsec(i1(k));
        patch(ax, [x0 x1 x1 x0], [yl(1) yl(1) yl(2) yl(2)], ...
            [1 0 0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
            'DisplayName', ternary(k==1,'Overlap (TA & MG active)',''));
    end
    
    % redraw on top (patch can affect limits)
    uistack(findobj(ax,'Type','line'),'top');
    
    xlabel(ax,'Time (s)');
    ylabel(ax,'Amplitude');
    title(ax,'Overlap highlighted (TA & MG active)');

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
meta.is_valid = is_valid_acq;

preview.t = seconds(TT_clean.tDur);
preview.TA_plot = TA_plot;
preview.MG_plot = MG_plot;
preview.Ch3 = TT_clean.Ch3;
preview.is_act_TA = snrValue.is_act;
preview.is_act_MG = snrValue.is_act_MG;
preview.is_rest_TA = snrValue.is_rest;
preview.is_rest_MG = snrValue.is_rest_MG;
preview.is_valid = meta.is_valid;

end

function s = ternary(cond, a, b)
if cond, s = a; else, s = b; end
end

