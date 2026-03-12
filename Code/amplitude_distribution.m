function out = pamplitude_distribution(MG_signals, Ch3_signals, fs, varargin)

%
% Compares MG amplitude during Channel 3 ON episodes to a local OFF control
% window 1–2 s before each ON onset (or any user-defined pre-window).
%
% INPUTS
%   MG_signals   : cell array, one MG signal per experiment
%   Ch3_signals  : cell array, one Ch3 signal per experiment
%   fs           : sampling frequency
%
% NAME-VALUE OPTIONS
%   'MGAlreadyAmplitude' : if true, MG is already an amplitude/envelope
%   'OnThreshold'        : threshold used to define Ch3 ON
%   'OnMinDurMs'         : minimum ON duration to keep an event
%   'PreWindowS'         : [start end] in seconds relative to ON onset, e.g. [-2 -0.2]
%   'UseMedian'          : true -> compare medians, false -> compare means
%   'TitleStr'           : figure title
%   'PlotPerEvent'       : show paired lines for each event
%
% OUTPUT
%   out.event_table      : one row per event
%   out.delta            : ON - PRE amplitude difference per event
%   out.summary          : summary stats
%
% EXAMPLE
%   out = plot_MG_amplitude_vs_trigger_prepost( ...
%       {TT1.MG_f, TT2.MG_f}, {TT1.Ch3_raw, TT2.Ch3_raw}, fs, ...
%       'MGAlreadyAmplitude', false, ...
%       'OnThreshold', 0.5, ...
%       'PreWindowS', [-2 -0.2]);

p = inputParser;
p.addParameter('MGAlreadyAmplitude', false, @(x)islogical(x) && isscalar(x));
p.addParameter('OnThreshold', [], @(x) isempty(x) || (isscalar(x) && isnumeric(x)));
p.addParameter('OnMinDurMs', 100, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('PreWindowS', [-2 -0.2], @(x)isnumeric(x) && numel(x)==2 && x(1) < x(2));
p.addParameter('UseMedian', true, @(x)islogical(x) && isscalar(x));
p.addParameter('TitleStr', 'MG amplitude during Ch3 ON vs local pre-ON OFF window', @(x)ischar(x) || isstring(x));
p.addParameter('PlotPerEvent', true, @(x)islogical(x) && isscalar(x));
p.parse(varargin{:});
opt = p.Results;

assert(iscell(MG_signals) && iscell(Ch3_signals), 'MG_signals and Ch3_signals must be cell arrays.');
assert(numel(MG_signals) == numel(Ch3_signals), 'MG_signals and Ch3_signals must have the same length.');

event_rows = [];

for e = 1:numel(MG_signals)
    MG  = MG_signals{e}(:);
    Ch3 = Ch3_signals{e}(:);

    N = min(numel(MG), numel(Ch3));
    MG  = MG(1:N);
    Ch3 = Ch3(1:N);

    if opt.MGAlreadyAmplitude
        MG_amp = MG;
    else
        MG_amp = abs(MG);
    end

    valid = isfinite(MG_amp) & isfinite(Ch3);
    MG_amp(~valid) = NaN;
    Ch3(~valid) = NaN;

    % Binary ON mask from Ch3, but threshold is user-set so this stays usable
    % if Ch3 later has several intensity levels.
    if isempty(opt.OnThreshold)
        ch3_valid = Ch3(isfinite(Ch3));
        if isempty(ch3_valid)
            continue;
        end
        if max(ch3_valid) == min(ch3_valid)
            thr = min(ch3_valid) + eps;
        else
            thr = min(ch3_valid) + 0.5*(max(ch3_valid) - min(ch3_valid));
        end
    else
        thr = opt.OnThreshold;
    end

    is_on = Ch3 >= thr;
    is_on(~isfinite(Ch3)) = false;

    % Keep only ON episodes with sufficient duration
    min_on_samples = max(1, round(opt.OnMinDurMs/1000 * fs));
    is_on = keep_long_runs(is_on, min_on_samples);

    d = diff([false; is_on; false]);
    on_starts = find(d == 1);
    on_ends   = find(d == -1) - 1;

    for k = 1:numel(on_starts)
        s_on = on_starts(k);
        e_on = on_ends(k);

        pre_start = s_on + round(opt.PreWindowS(1) * fs);
        pre_end   = s_on + round(opt.PreWindowS(2) * fs);

        if pre_start < 1 || pre_end < 1 || pre_start > pre_end
            continue;
        end

        idx_pre = pre_start:pre_end;
        idx_on  = s_on:e_on;

        % Pre-window must be OFF
        if any(is_on(idx_pre))
            continue;
        end

        mg_pre = MG_amp(idx_pre);
        mg_on  = MG_amp(idx_on);

        mg_pre = mg_pre(isfinite(mg_pre));
        mg_on  = mg_on(isfinite(mg_on));

        if isempty(mg_pre) || isempty(mg_on)
            continue;
        end

        if opt.UseMedian
            A_pre = median(mg_pre, 'omitnan');
            A_on  = median(mg_on,  'omitnan');
        else
            A_pre = mean(mg_pre, 'omitnan');
            A_on  = mean(mg_on,  'omitnan');
        end

        row = [ ...
            e, ...
            k, ...
            s_on, ...
            e_on, ...
            (s_on-1)/fs, ...
            (e_on-1)/fs, ...
            numel(idx_on)/fs, ...
            pre_start, ...
            pre_end, ...
            (pre_start-1)/fs, ...
            (pre_end-1)/fs, ...
            A_pre, ...
            A_on, ...
            A_on - A_pre, ...
            thr ...
        ];

        event_rows = [event_rows; row]; %#ok<AGROW>
    end
end

var_names = { ...
    'Experiment', 'EventID', ...
    'OnStartSample', 'OnEndSample', 'OnStartS', 'OnEndS', 'OnDurS', ...
    'PreStartSample', 'PreEndSample', 'PreStartS', 'PreEndS', ...
    'MG_Pre', 'MG_On', 'Delta_OnMinusPre', 'Ch3Threshold'};

if isempty(event_rows)
    warning('No valid ON events found with usable pre-ON OFF windows.');
    out = struct();
    out.event_table = table();
    out.delta = [];
    out.summary = struct();
    return;
end

T = array2table(event_rows, 'VariableNames', var_names);
delta = T.Delta_OnMinusPre;

% Summary
summary = struct();
summary.n_events = height(T);
summary.mean_pre = mean(T.MG_Pre, 'omitnan');
summary.mean_on  = mean(T.MG_On,  'omitnan');
summary.mean_delta = mean(delta, 'omitnan');
summary.median_delta = median(delta, 'omitnan');
summary.n_negative = sum(delta < 0);
summary.frac_negative = mean(delta < 0);

if numel(delta) >= 2
    try
        [p_signrank, ~, stats_signrank] = signrank(T.MG_On, T.MG_Pre);
        summary.p_signrank = p_signrank;
        summary.signedrank = stats_signrank.signedrank;
    catch
        summary.p_signrank = NaN;
        summary.signedrank = NaN;
    end
else
    summary.p_signrank = NaN;
    summary.signedrank = NaN;
end

% Plot: one figure, three subplots, black background
fig = figure('Color', 'k', 'Name', char(opt.TitleStr));

% ---------- Subplot 1: paired event comparison ----------
ax1 = subplot(2,2,1);
hold(ax1,'on');
set(ax1,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax1,'on');

colors = lines(height(T));



if opt.PlotPerEvent
    for i = 1:height(T)
    plot(ax1, [1 2], [T.MG_Pre(i) T.MG_On(i)], '-o', ...
        'Color', colors(i,:), ...
        'MarkerFaceColor', colors(i,:), ...
        'LineWidth', 1.2, ...
        'MarkerSize', 5);
    end
end

xlim(ax1, [0.5 2.5]);
xticks(ax1, [1 2]);
xticklabels(ax1, {'Pre-ON OFF window', 'Ch3 ON'});
ylabel(ax1, 'MG amplitude', 'Color', 'w');
title(ax1, char(opt.TitleStr), 'Color', 'w');

% ---------- Subplot 2: delta histogram + density line ----------
ax2 = subplot(2,2,2);
hold(ax2,'on');
set(ax2,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax2,'on');

hDelta = histogram(ax2, delta, 30, ...
    'Normalization', 'pdf', ...
    'FaceColor', [0.7 0.7 0.7], ...
    'FaceAlpha', 0.35, ...
    'EdgeColor', 'none');

xline(ax2, 0, '--r', 'LineWidth', 1.2);

if numel(delta) > 1 && any(isfinite(delta))
    [f_delta, xi_delta] = ksdensity(delta);
    plot(ax2, xi_delta, f_delta, 'w-', 'LineWidth', 1.8);
end

xlabel(ax2, '\Delta MG amplitude = ON - PRE', 'Color', 'w');
ylabel(ax2, 'Density', 'Color', 'w');
title(ax2, sprintf('n = %d | median \\Delta = %.4f | frac(\\Delta<0) = %.2f | signrank p = %.3g', ...
    summary.n_events, summary.median_delta, summary.frac_negative, summary.p_signrank), ...
    'Color', 'w');

% ---------- Subplot 3: ON vs OFF histogram overlay + density lines ----------
ax3 = subplot(2,2,3);
hold(ax3,'on');
set(ax3,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax3,'on');

mg_off = T.MG_Pre;
mg_on  = T.MG_On;

mg_off = mg_off(isfinite(mg_off));
mg_on  = mg_on(isfinite(mg_on));

all_vals = [mg_off; mg_on];
if isempty(all_vals)
    warning('No finite MG_Pre / MG_On values available for distribution plot.');
else
    nbins = 60;
    edges = linspace(min(all_vals), max(all_vals), nbins);

    histogram(ax3, mg_off, edges, ...
        'Normalization', 'pdf', ...
        'FaceColor', [0.2 0.6 1], ...
        'FaceAlpha', 0.35, ...
        'EdgeColor', 'none', ...
        'DisplayName', 'Ch3 OFF (pre-window)');

    histogram(ax3, mg_on, edges, ...
        'Normalization', 'pdf', ...
        'FaceColor', [1 0.3 0.3], ...
        'FaceAlpha', 0.35, ...
        'EdgeColor', 'none', ...
        'DisplayName', 'Ch3 ON');

    if numel(mg_off) > 1
        [f_off, xi_off] = ksdensity(mg_off);
        plot(ax3, xi_off, f_off, '-', 'Color', [0.2 0.6 1], 'LineWidth', 2);
    end

    if numel(mg_on) > 1
        [f_on, xi_on] = ksdensity(mg_on);
        plot(ax3, xi_on, f_on, '-', 'Color', [1 0.3 0.3], 'LineWidth', 2);
    end
end

xlabel(ax3, 'MG amplitude', 'Color', 'w');
ylabel(ax3, 'Density', 'Color', 'w');
title(ax3, 'MG amplitude distribution: Ch3 ON vs OFF', 'Color', 'w');

legend(ax3, 'TextColor', 'w', 'Color', 'k', 'Location', 'best');

% ---------- Subplot 4: cumulative distribution ON vs OFF ----------
ax4 = subplot(2,2,4);
hold(ax4,'on');
set(ax4,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax4,'on');

if ~isempty(mg_off)
    [f_off, x_off] = ecdf(mg_off);
    plot(ax4, x_off, f_off, '-', 'Color', [0.2 0.6 1], 'LineWidth', 2, ...
        'DisplayName', 'Ch3 OFF (pre-window)');
end

if ~isempty(mg_on)
    [f_on, x_on] = ecdf(mg_on);
    plot(ax4, x_on, f_on, '-', 'Color', [1 0.3 0.3], 'LineWidth', 2, ...
        'DisplayName', 'Ch3 ON');
end

xlabel(ax4, 'MG amplitude', 'Color', 'w');
ylabel(ax4, 'Cumulative probability', 'Color', 'w');
title(ax4, 'Cumulative distribution: Ch3 ON vs OFF', 'Color', 'w');
legend(ax4, 'TextColor', 'w', 'Color', 'k', 'Location', 'best');


out = struct();
out.event_table = T;
out.delta = delta;
out.summary = summary;
end