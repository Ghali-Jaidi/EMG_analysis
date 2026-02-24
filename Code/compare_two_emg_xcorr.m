function fig = compare_two_files_xcorr(fs, max_lag_s)
% compare_two_files_xcorr
% Select 2 MAT files, preprocess each (recording chosen inside),
% then overlay TA–MG cross-correlation curves (+/- max_lag_s).
%
% Uninjured: uses active mask (is_act_TA | is_act_MG)
% Spastic:   uses ONLY user spasm intervals (ignores activity masks)
%
% Requires:
%   preprocess_and_label.m
%   plot_TA_MG_correlation.m (updated with options.Mode + IntervalMask + Axes)

arguments
    fs (1,1) double {mustBePositive} = 10000
    max_lag_s (1,1) double {mustBePositive} = 5.0
end

%% ---- Select two files ----
[f1,p1] = uigetfile('*.mat','Select FIRST experiment MAT file');
if isequal(f1,0), error('No first file selected.'); end
full1 = fullfile(p1,f1);

[f2,p2] = uigetfile('*.mat','Select SECOND experiment MAT file');
if isequal(f2,0), error('No second file selected.'); end
full2 = fullfile(p2,f2);

%% ---- Preprocess both (recording selection happens inside) ----
[TT1, snr1, meta1] = preprocess_and_label(fs, ...
    'fullFile', full1, ...
    'plot_figures', false, ...
    'save_figures', false);

[TT2, snr2, meta2] = preprocess_and_label(fs, ...
    'fullFile', full2, ...
    'plot_figures', false, ...
    'save_figures', false);

%% ---- Ask condition + spasm intervals (if needed) ----
[cond1, intervals1] = ask_condition_and_intervals(sprintf('%s (rec %d)', f1, meta1.recID));
[cond2, intervals2] = ask_condition_and_intervals(sprintf('%s (rec %d)', f2, meta2.recID));

%% ---- Build interval masks in the CLEAN timeline ----
mask1 = build_interval_mask(height(TT1), fs, intervals1); % all-true if empty
mask2 = build_interval_mask(height(TT2), fs, intervals2);

%% ---- Overlay plot ----
fig = figure;
ax = axes(fig);
hold(ax,'on');

plot_TA_MG_correlation( ...
    TT1.TA_env, TT1.MG_env, ...
    snr1.is_act, snr1.is_act_MG, ...
    fs, max_lag_s, ...
    'Axes', ax, ...
    'Color', [0 0 1], ...
    'Label', sprintf('%s (%s, rec %d)', meta1.fileName, cond1, meta1.recID), ...
    'IntervalMask', mask1, ...
    'Mode', lower(cond1));

plot_TA_MG_correlation( ...
    TT2.TA_env, TT2.MG_env, ...
    snr2.is_act, snr2.is_act_MG, ...
    fs, max_lag_s, ...
    'Axes', ax, ...
    'Color', [1 0 0], ...
    'Label', sprintf('%s (%s, rec %d)', meta2.fileName, cond2, meta2.recID), ...
    'IntervalMask', mask2, ...
    'Mode', lower(cond2));

legend(ax,'Location','best');
title(ax, sprintf('TA–MG cross-correlation (\\pm %.1f s)', max_lag_s));

end

% ===================== helpers =====================

function [condLabel, intervals] = ask_condition_and_intervals(fileTag)

choice = questdlg(sprintf('%s: condition?', fileTag), ...
                  'Condition', 'Spastic', 'Uninjured', 'Uninjured');
if isempty(choice)
    error('Condition selection canceled.');
end

condLabel = choice;

if strcmpi(choice, 'Spastic')
    prompt = ['Enter spasm intervals as Nx2 matrix in seconds, e.g.:' newline ...
              '[12.5 14.0; 33.2 35.1]' newline ...
              'Leave empty to use FULL recording.'];
    answ = inputdlg(prompt, 'Spasm intervals', [6 60], {''});

    if isempty(answ)
        error('Interval input canceled.');
    end

    if isempty(strtrim(answ{1}))
        intervals = []; % full recording
    else
        intervals = str2num(answ{1}); %#ok<ST2NM>
        if isempty(intervals) || size(intervals,2) ~= 2
            error('Intervals must be an Nx2 numeric matrix [t_start t_end].');
        end
    end
else
    intervals = [];
end

end

function mask = build_interval_mask(N, fs, intervals)
% intervals Nx2 [t0 t1] in seconds
% if empty => mask all true
mask = true(N,1);
if isempty(intervals)
    return;
end

mask(:) = false;
for k = 1:size(intervals,1)
    t0 = intervals(k,1);
    t1 = intervals(k,2);
    if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0
        continue;
    end
    i0 = max(1, floor(t0*fs) + 1);
    i1 = min(N, floor(t1*fs));
    if i1 > i0
        mask(i0:i1) = true;
    end
end
end