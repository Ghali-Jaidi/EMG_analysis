function results = labchart_protocol_check_gait_vs_spasm(varargin)
% labchart_protocol_check_gait_vs_spasm
% -------------------------------------------------------------------------
% MATLAB check of a LabChart-compatible spasm detector.
%
% Protocol mimicked:
%   Spectrum window length = 1000 samples by default
%   Fs                     = 10000 Hz by default
%   Feature                = Total Power between 100 and 500 Hz
%
% Workflow:
%   1. Select one or multiple gait files.
%   2. For each gait file, choose the recording ID inside the MAT file.
%   3. Preprocess with preprocess_and_label(..., 'fullFile', file, 'recID', recID).
%   4. Extract gait windows only inside detected active periods.
%   5. Select one spasm file.
%   6. Choose the recording ID inside the spasm file.
%   7. Enter spasm intervals.
%   8. Compute the same LabChart-style spectrum feature for gait and spasm.
%
% This version fixes the table concatenation issue by forcing gait and spasm
% rows to have exactly the same variables before vertical concatenation.
% -------------------------------------------------------------------------

clearvars -except varargin; clc;

%% -------------------- Options --------------------
p = inputParser;
p.addParameter('Fs', 10000, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('WindowSamples', 1000, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('StepSamples', 1000, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('BandHz', [100 500], @(x)isnumeric(x) && numel(x)==2 && x(1)<x(2));
p.addParameter('ReferenceBandHz', [20 500], @(x)isnumeric(x) && numel(x)==2 && x(1)<x(2));
p.addParameter('WindowType', 'hann', @(x)ischar(x) || isstring(x));
p.addParameter('SignalBasis', 'raw', @(x)ischar(x) || isstring(x)); % 'raw', 'filtered' or 'rectified'
p.addParameter('UseBothMuscles', true, @(x)islogical(x) && isscalar(x));
p.addParameter('OutputFolder', fullfile(pwd, 'LabChart_protocol_results'), @(x)ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

fs = opt.Fs;
winN = round(opt.WindowSamples);
stepN = round(opt.StepSamples);
bandHz = opt.BandHz;
refBandHz = opt.ReferenceBandHz;
outputFolder = char(opt.OutputFolder);
if ~exist(outputFolder, 'dir'); mkdir(outputFolder); end

fprintf('========================================\n');
fprintf('LABCHART PROTOCOL CHECK: GAIT VS SPASM\n');
fprintf('========================================\n');
fprintf('Fs: %.0f Hz\n', fs);
fprintf('Window length: %d samples = %.1f ms\n', winN, 1000*winN/fs);
fprintf('Step length: %d samples = %.1f ms\n', stepN, 1000*stepN/fs);
fprintf('Frequency resolution: %.2f Hz\n', fs/winN);
fprintf('Feature: total power %.0f-%.0f Hz\n', bandHz(1), bandHz(2));
fprintf('Reference band for %% power: %.0f-%.0f Hz\n', refBandHz(1), refBandHz(2));
fprintf('Signal basis: %s\n\n', char(opt.SignalBasis));

%% -------------------- Load Gait Recording(s) --------------------
fprintf('========================================\n');
fprintf('GAIT RECORDING SELECTION\n');
fprintf('========================================\n\n');

choice = questdlg('Load multiple gait recordings for better estimates?', ...
    'Multiple Gait Files', 'Yes', 'No', 'Yes');

if strcmp(choice, 'Yes')
    [files, gaitPath] = uigetfile('*.mat', 'Select gait MAT files (can select multiple)', ...
        'MultiSelect', 'on');
    if isequal(files, 0); error('Gait file selection cancelled.'); end
    if ischar(files); files = {files}; end
    gaitFiles = files;
else
    msgbox('Select a GAIT recording (normal/uninjured movement)', 'Load Gait', 'modal');
    [f, gaitPath] = uigetfile('*.mat', 'Select gait MAT file');
    if isequal(f, 0); error('Gait file selection cancelled.'); end
    gaitFiles = {f};
end

%% -------------------- Process Gait Windows --------------------
gait_rows = empty_feature_table();
gait_data = struct([]);

fprintf('\nLoading %d gait recording(s)...\n\n', numel(gaitFiles));

for file_idx = 1:numel(gaitFiles)
    f_gait = gaitFiles{file_idx};
    fullFile_gait = fullfile(gaitPath, f_gait);

    fprintf('[%d/%d] Loading GAIT file: %s\n', file_idx, numel(gaitFiles), f_gait);

    recID_gait = choose_recording_id(fullFile_gait, sprintf('Choose GAIT recording for %s', f_gait));
    fprintf('  Selected gait recording ID: %d\n', recID_gait);

    P = load_or_default_params(gaitPath, f_gait);

    [TT_gait, snr_gait, ~] = preprocess_and_label(P, fs, ...
        'fullFile', fullFile_gait, ...
        'recID', recID_gait, ...
        'plot_figures', false, ...
        'save_figures', false);

    [TA_sig, MG_sig, basis_used] = get_TA_MG_signals(TT_gait, opt.SignalBasis);
    fprintf('  Signal used: %s\n', basis_used);

    TA_active_mask = get_mask_field(snr_gait, {'is_act','is_act_TA'});
    MG_active_mask = get_mask_field(snr_gait, {'is_act_MG','is_act'});

    [TA_sig, TA_active_mask] = align_signal_and_mask(TA_sig, TA_active_mask);
    [MG_sig, MG_active_mask] = align_signal_and_mask(MG_sig, MG_active_mask);

    fprintf('  TA active: %.1f%% (%.2f sec)\n', 100*mean(TA_active_mask), sum(TA_active_mask)/fs);
    fprintf('  MG active: %.1f%% (%.2f sec)\n', 100*mean(MG_active_mask), sum(MG_active_mask)/fs);

    rowsTA = compute_windows_from_active_runs(TA_sig, TA_active_mask, fs, winN, stepN, bandHz, refBandHz, opt.WindowType);
    rowsTA = add_metadata(rowsTA, "Gait", "TA", string(f_gait), recID_gait);

    rowsMG = compute_windows_from_active_runs(MG_sig, MG_active_mask, fs, winN, stepN, bandHz, refBandHz, opt.WindowType);
    rowsMG = add_metadata(rowsMG, "Gait", "MG", string(f_gait), recID_gait);

    gait_rows = [gait_rows; rowsTA; rowsMG]; %#ok<AGROW>

    gait_data(file_idx).filename = f_gait; %#ok<AGROW>
    gait_data(file_idx).recID = recID_gait;
    gait_data(file_idx).TA_windows = height(rowsTA);
    gait_data(file_idx).MG_windows = height(rowsMG);

    fprintf('  ✓ TA windows: %d\n', height(rowsTA));
    fprintf('  ✓ MG windows: %d\n\n', height(rowsMG));
end

fprintf('========================================\n');
fprintf('GAIT SUMMARY\n');
fprintf('========================================\n');
fprintf('Total gait windows: %d\n', height(gait_rows));
fprintf('  TA windows: %d\n', sum(gait_rows.muscle == "TA"));
fprintf('  MG windows: %d\n\n', sum(gait_rows.muscle == "MG"));

%% -------------------- Load Spasm Recording --------------------
msgbox('Select a SPASM recording with spasm events', 'Load Spasm', 'modal');
[f_spasm, p_spasm] = uigetfile('*.mat', 'Select spasm MAT file');
if isequal(f_spasm, 0); error('Spasm file selection cancelled.'); end

fullFile_spasm = fullfile(p_spasm, f_spasm);
fprintf('\n========================================\n');
fprintf('Loading SPASM file: %s\n', f_spasm);
fprintf('========================================\n');

recID_spasm = choose_recording_id(fullFile_spasm, sprintf('Choose SPASM recording for %s', f_spasm));
fprintf('Selected spasm recording ID: %d\n', recID_spasm);

P = load_or_default_params(p_spasm, f_spasm);

[TT_spasm, ~, ~] = preprocess_and_label(P, fs, ...
    'fullFile', fullFile_spasm, ...
    'recID', recID_spasm, ...
    'plot_figures', false, ...
    'save_figures', false);

N_spasm = height(TT_spasm);
duration_spasm = N_spasm / fs;
fprintf('Spasm recording duration: %.2f seconds\n', duration_spasm);
fprintf('Select one or more time intervals from spasm for analysis.\n');

spasm_intervals = select_signal_intervals(duration_spasm, 'Spasm');

[TA_spasm, MG_spasm, basis_used] = get_TA_MG_signals(TT_spasm, opt.SignalBasis);
fprintf('Signal used for spasm: %s\n', basis_used);

%% -------------------- Process Spasm Windows --------------------
fprintf('\n========================================\n');
fprintf('PROCESSING SPASM WINDOWS\n');
fprintf('========================================\n\n');

rowsTA_spasm = compute_windows_from_intervals(TA_spasm, fs, spasm_intervals, winN, stepN, bandHz, refBandHz, opt.WindowType);
rowsTA_spasm = add_metadata(rowsTA_spasm, "Spasm", "TA", string(f_spasm), recID_spasm);

rowsMG_spasm = compute_windows_from_intervals(MG_spasm, fs, spasm_intervals, winN, stepN, bandHz, refBandHz, opt.WindowType);
rowsMG_spasm = add_metadata(rowsMG_spasm, "Spasm", "MG", string(f_spasm), recID_spasm);

spasm_rows = [rowsTA_spasm; rowsMG_spasm];

fprintf('Spasm windows: %d\n', height(spasm_rows));
fprintf('  TA windows: %d\n', height(rowsTA_spasm));
fprintf('  MG windows: %d\n\n', height(rowsMG_spasm));

%% -------------------- Combine and Analyze --------------------
% This is the line that previously failed. It is safe now because both
% tables are forced to the same schema by empty_feature_table() and add_metadata().
all_rows = [gait_rows; spasm_rows];

if ~opt.UseBothMuscles
    all_rows = all_rows(all_rows.muscle == "MG", :);
end

if height(gait_rows) == 0 || height(spasm_rows) == 0
    error('Not enough windows extracted. Check active masks, intervals, and window length.');
end

% Put columns in convenient order.
all_rows = movevars(all_rows, {'class','muscle','file','recID','interval_id','t_start_s','t_end_s'}, 'Before', 1);

features = {'band_power', 'log10_band_power', 'percent_power'};
summary_rows = table();

fprintf('========================================\n');
fprintf('THRESHOLD SUMMARY\n');
fprintf('========================================\n\n');

for i = 1:numel(features)
    feat = features{i};
    S = find_best_threshold(all_rows.(feat), all_rows.class == "Spasm");
    newrow = table(string(feat), S.threshold, S.direction, S.accuracy, S.balanced_accuracy, ...
        S.sensitivity, S.specificity, S.precision, S.f1, ...
        'VariableNames', {'feature','threshold','direction','accuracy','balanced_accuracy', ...
        'sensitivity','specificity','precision','f1'});
    summary_rows = [summary_rows; newrow]; %#ok<AGROW>

    fprintf('%s\n', feat);
    fprintf('  Best rule: Spasm if %s %s %.6g\n', feat, S.direction, S.threshold);
    fprintf('  Accuracy: %.3f | Balanced accuracy: %.3f\n', S.accuracy, S.balanced_accuracy);
    fprintf('  Sensitivity: %.3f | Specificity: %.3f\n\n', S.sensitivity, S.specificity);
end

features_csv = fullfile(outputFolder, 'labchart_window_features.csv');
summary_csv = fullfile(outputFolder, 'labchart_threshold_summary.csv');
writetable(all_rows, features_csv);
writetable(summary_rows, summary_csv);

fprintf('Saved window features:\n  %s\n', features_csv);
fprintf('Saved threshold summary:\n  %s\n\n', summary_csv);

plot_feature_histograms(all_rows, outputFolder, bandHz);
plot_feature_by_muscle(all_rows, outputFolder, bandHz);

results = struct();
results.options = opt;
results.spasm_file = f_spasm;
results.spasm_recID = recID_spasm;
results.spasm_intervals = spasm_intervals;
results.window_features = all_rows;
results.threshold_summary = summary_rows;
results.gait_data = gait_data;
results.output_folder = outputFolder;

fprintf('========================================\n');
fprintf('LABCHART IMPLEMENTATION SUGGESTION\n');
fprintf('========================================\n');
fprintf('In LabChart, create a Spectrum channel calculation:\n');
fprintf('  Parameter: Total Power\n');
fprintf('  Frequency range: %.0f-%.0f Hz\n', bandHz(1), bandHz(2));
fprintf('  Window length: %d samples\n', winN);
fprintf('Then threshold that channel using the band_power threshold above.\n');
fprintf('Start with the raw band_power threshold, not the log threshold.\n');

end

%% ========================================================================
%% Helper functions
%% ========================================================================

function T = empty_feature_table()
T = table( ...
    strings(0,1), strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'class','muscle','file','recID','interval_id', ...
    't_start_s','t_end_s','band_power','log10_band_power', ...
    'total_power_denominator','percent_power','max_power_frequency'});
end

function T = add_metadata(T, className, muscleName, fileName, recID)
% Ensure metadata exists and tables can be vertically concatenated.
if isempty(T)
    T = empty_feature_table();
    return;
end
T.class = repmat(string(className), height(T), 1);
T.muscle = repmat(string(muscleName), height(T), 1);
T.file = repmat(string(fileName), height(T), 1);
T.recID = repmat(double(recID), height(T), 1);

% Force exact schema and order.
base = empty_feature_table();
missingVars = setdiff(base.Properties.VariableNames, T.Properties.VariableNames);
for i = 1:numel(missingVars)
    v = missingVars{i};
    if ismember(v, {'class','muscle','file'})
        T.(v) = strings(height(T),1);
    else
        T.(v) = NaN(height(T),1);
    end
end
T = T(:, base.Properties.VariableNames);
end

function P = load_or_default_params(folderPath, matFileName)
[~, srcName, ~] = fileparts(matFileName);
paramFile = fullfile(folderPath, [srcName, '_param.mat']);
if isfile(paramFile)
    tmp = load(paramFile, 'P');
    P = tmp.P;
else
    P = default_emg_parameters();
end
end

function recID = choose_recording_id(fullFile, dialogTitle)
info = whos('-file', fullFile);
varNames = string({info.name});

recIDs = [];
patterns = ["data__chan_1_rec_(\d+)", "data__chan_2_rec_(\d+)", "data__chan_3_rec_(\d+)"];
for p = 1:numel(patterns)
    tokens = regexp(varNames, patterns(p), 'tokens');
    for i = 1:numel(tokens)
        if ~isempty(tokens{i})
            recIDs(end+1) = str2double(tokens{i}{1}{1}); %#ok<AGROW>
        end
    end
end
recIDs = unique(recIDs);

if isempty(recIDs)
    warning('No data__chan_X_rec_Y variables found. Falling back to recID = 1.');
    recID = 1;
    return;
end

if numel(recIDs) == 1
    recID = recIDs(1);
    return;
end

labels = arrayfun(@(x)sprintf('Recording %d', x), recIDs, 'UniformOutput', false);
[idx, ok] = listdlg('PromptString', 'Select recording ID:', ...
    'SelectionMode', 'single', ...
    'ListString', labels, ...
    'Name', dialogTitle, ...
    'ListSize', [300 200]);
if ~ok
    error('Recording selection cancelled.');
end
recID = recIDs(idx);
end

function mask = get_mask_field(S, possibleNames)
mask = [];
for i = 1:numel(possibleNames)
    if isfield(S, possibleNames{i})
        mask = S.(possibleNames{i});
        break;
    end
end
if isempty(mask)
    error('Could not find active mask in snr output. Tried: %s', strjoin(possibleNames, ', '));
end
mask = logical(mask(:));
end

function [sig, mask] = align_signal_and_mask(sig, mask)
sig = double(sig(:));
mask = logical(mask(:));
n = min(numel(sig), numel(mask));
sig = sig(1:n);
mask = mask(1:n);
end

function [TA_sig, MG_sig, basis_used] = get_TA_MG_signals(TT, signalBasis)
signalBasis = lower(string(signalBasis));
names = string(TT.Properties.VariableNames);

switch signalBasis

    case "raw"
        if all(ismember(["TA_raw","MG_raw"], names))
            TA_sig = TT.TA_raw;
            MG_sig = TT.MG_raw;
            basis_used = 'raw (unfiltered): TA_raw/MG_raw';
        else
            error('Could not find TA_raw/MG_raw in TT.');
        end

    case "filtered"
        if all(ismember(["TA_f","MG_f"], names))
            TA_sig = TT.TA_f;
            MG_sig = TT.MG_f;
            basis_used = 'filtered unrectified: TA_f/MG_f';
        elseif all(ismember(["TA_raw","MG_raw"], names))
            warning('TA_f/MG_f not found. Falling back to TA_raw/MG_raw.');
            TA_sig = TT.TA_raw;
            MG_sig = TT.MG_raw;
            basis_used = 'raw fallback: TA_raw/MG_raw';
        else
            error('Could not find TA_f/MG_f or TA_raw/MG_raw in TT.');
        end

    case "rectified"
        if all(ismember(["TA_rect","MG_rect"], names))
            TA_sig = TT.TA_rect;
            MG_sig = TT.MG_rect;
            basis_used = 'rectified: TA_rect/MG_rect';
        else
            error('Could not find TA_rect/MG_rect in TT.');
        end

    otherwise
        error('Unknown SignalBasis: %s. Use filtered or rectified.', signalBasis);
end

TA_sig = double(TA_sig(:));
MG_sig = double(MG_sig(:));
end

function intervals = select_signal_intervals(duration, label)
intervals = [];
interval_count = 0;
while true
    interval_count = interval_count + 1;
    prompt = sprintf(['Interval %d of %s recording (duration: %.2f s):\n' ...
        'Enter [start_sec end_sec]\nOr press Cancel to finish.'], ...
        interval_count, label, duration);
    answer = inputdlg(prompt, 'Select Time Interval', [1 50], ...
        {sprintf('0 %.1f', min(5, duration))});
    if isempty(answer)
        if interval_count == 1
            error('At least one interval must be selected.');
        else
            break;
        end
    end
    vals = str2num(answer{1}); %#ok<ST2NM>
    if numel(vals) ~= 2
        msgbox('Invalid input. Please enter two numbers separated by space or comma.', 'Input Error', 'modal');
        interval_count = interval_count - 1;
        continue;
    end
    t_start = vals(1);
    t_end = vals(2);
    if t_start < 0 || t_end > duration || t_start >= t_end
        msgbox(sprintf('Invalid interval. Must satisfy: 0 <= start < end <= %.2f', duration), 'Range Error', 'modal');
        interval_count = interval_count - 1;
        continue;
    end
    intervals = [intervals; t_start, t_end]; %#ok<AGROW>
    fprintf('  ✓ Interval %d: %.2f - %.2f s (duration: %.2f s)\n', interval_count, t_start, t_end, t_end - t_start);
end
end

function rows = compute_windows_from_active_runs(signal, activeMask, fs, winN, stepN, bandHz, refBandHz, windowType)
signal = signal(:);
activeMask = logical(activeMask(:));

n = min(numel(signal), numel(activeMask));
signal = signal(1:n);
activeMask = activeMask(1:n);

runs = mask_to_runs(activeMask);
rows = empty_feature_table();

for r = 1:size(runs,1)
    idx1 = runs(r,1);
    idx2 = runs(r,2);
    if idx2 - idx1 + 1 < winN
        continue;
    end
    for startIdx = idx1:stepN:(idx2 - winN + 1)
        stopIdx = startIdx + winN - 1;
        segment = signal(startIdx:stopIdx);
        feat = compute_labchart_power_feature(segment, fs, bandHz, refBandHz, windowType);
        T = feature_to_table(feat, startIdx, stopIdx, fs, NaN);
        rows = [rows; T]; %#ok<AGROW>
    end
end
end

function rows = compute_windows_from_intervals(signal, fs, intervals, winN, stepN, bandHz, refBandHz, windowType)
signal = signal(:);
rows = empty_feature_table();

for k = 1:size(intervals,1)
    startIdx = max(1, round(intervals(k,1)*fs) + 1);
    stopIdx  = min(numel(signal), round(intervals(k,2)*fs));
    if stopIdx - startIdx + 1 < winN
        warning('Interval %.2f-%.2f s is shorter than one window. Skipping.', intervals(k,1), intervals(k,2));
        continue;
    end
    for s = startIdx:stepN:(stopIdx - winN + 1)
        e = s + winN - 1;
        segment = signal(s:e);
        feat = compute_labchart_power_feature(segment, fs, bandHz, refBandHz, windowType);
        T = feature_to_table(feat, s, e, fs, k);
        rows = [rows; T]; %#ok<AGROW>
    end
end
end

function runs = mask_to_runs(mask)
mask = logical(mask(:));
d = diff([false; mask; false]);
starts = find(d == 1);
ends = find(d == -1) - 1;
runs = [starts, ends];
end

function feat = compute_labchart_power_feature(x, fs, bandHz, refBandHz, windowType)
x = double(x(:));
x = x - mean(x, 'omitnan');
x(~isfinite(x)) = 0;
N = numel(x);

switch lower(string(windowType))
    case {"hann", "hanning"}
        w = hann(N, 'periodic');
    case {"rect", "rectangular", "none"}
        w = ones(N,1);
    otherwise
        error('Unknown WindowType: %s', string(windowType));
end

% Periodogram with 'power' returns a one-sided power spectrum.
[Pxx, f] = periodogram(x, w, N, fs, 'power');

bandMask = f >= bandHz(1) & f <= bandHz(2);
refMask = f >= refBandHz(1) & f <= refBandHz(2);

% Integrate PSD over frequency by multiplying summed PSD bins by df
if numel(f) >= 2
    df = f(2) - f(1);
else
    df = fs / N;
end

bandPower = sum(Pxx(bandMask), 'omitnan') * df;
refPower = sum(Pxx(refMask), 'omitnan') * df;
percentPower = 100 * bandPower / max(refPower, eps);

pRef = Pxx(refMask);
fRef = f(refMask);
if isempty(pRef) || all(pRef <= 0)
    maxPowerFrequency = NaN;
else
    [~, imax] = max(pRef);
    maxPowerFrequency = fRef(imax);
end

feat = struct();
feat.band_power = bandPower;
feat.log10_band_power = log10(max(bandPower, realmin));
feat.total_power_denominator = refPower;
feat.percent_power = percentPower;
feat.max_power_frequency = maxPowerFrequency;
end

function T = feature_to_table(feat, startIdx, stopIdx, fs, intervalID)
T = empty_feature_table();
T(1,:) = {"", "", "", 0, intervalID, ...
    (startIdx-1)/fs, (stopIdx-1)/fs, ...
    feat.band_power, feat.log10_band_power, feat.total_power_denominator, ...
    feat.percent_power, feat.max_power_frequency};
end

function S = find_best_threshold(x, ySpasm)
x = double(x(:));
y = logical(ySpasm(:));
valid = isfinite(x) & ~isnan(x);
x = x(valid);
y = y(valid);

ux = unique(sort(x));
if numel(ux) < 2
    thresholds = ux;
else
    thresholds = [-inf; (ux(1:end-1)+ux(2:end))/2; inf];
end

directions = [">", "<"];
bestBA = -inf;
best = struct();

for d = 1:numel(directions)
    for i = 1:numel(thresholds)
        thr = thresholds(i);
        if directions(d) == ">"
            pred = x > thr;
        else
            pred = x < thr;
        end
        TP = sum(pred & y);
        TN = sum(~pred & ~y);
        FP = sum(pred & ~y);
        FN = sum(~pred & y);
        sens = TP / max(TP + FN, eps);
        spec = TN / max(TN + FP, eps);
        acc = (TP + TN) / numel(y);
        ba = 0.5 * (sens + spec);
        prec = TP / max(TP + FP, eps);
        f1 = 2 * prec * sens / max(prec + sens, eps);
        if ba > bestBA
            bestBA = ba;
            best.threshold = thr;
            best.direction = directions(d);
            best.accuracy = acc;
            best.balanced_accuracy = ba;
            best.sensitivity = sens;
            best.specificity = spec;
            best.precision = prec;
            best.f1 = f1;
        end
    end
end
S = best;
end

function plot_feature_histograms(T, outputFolder, bandHz)
features = {'band_power', 'log10_band_power', 'percent_power'};
labels = {sprintf('Total power %.0f-%.0f Hz', bandHz(1), bandHz(2)), ...
          sprintf('log10 total power %.0f-%.0f Hz', bandHz(1), bandHz(2)), ...
          sprintf('%% power %.0f-%.0f Hz', bandHz(1), bandHz(2))};
for i = 1:numel(features)
    feat = features{i};
    fig = figure('Name', ['Histogram - ', feat], 'NumberTitle', 'off');
    hold on;
    histogram(T.(feat)(T.class == "Gait"), 30, 'Normalization', 'probability', 'DisplayName', 'Gait');
    histogram(T.(feat)(T.class == "Spasm"), 30, 'Normalization', 'probability', 'DisplayName', 'Spasm');
    xlabel(labels{i});
    ylabel('Probability');
    title(['LabChart-style window feature: ', strrep(feat, '_', ' ')]);
    legend('Location', 'best');
    grid on;
    hold off;
    saveas(fig, fullfile(outputFolder, ['hist_', feat, '.png']));
end
end

function plot_feature_by_muscle(T, outputFolder, bandHz)
fig = figure('Name', 'Band power by muscle', 'NumberTitle', 'off');
boxchart(categorical(strcat(T.class, "_", T.muscle)), T.band_power);
ylabel(sprintf('Total power %.0f-%.0f Hz', bandHz(1), bandHz(2)));
title('LabChart-style total band power by class and muscle');
grid on;
saveas(fig, fullfile(outputFolder, 'box_band_power_by_muscle.png'));
end
