function out = compare_spasm_stim_vs_nostim(TT, snr, fs, varargin)
% compare_spasm_stim_vs_nostim
%
% Detects spasms, splits them into stimulated (overlapping Ch3 ON) and
% unstimulated groups, then compares amplitude within exactly matched
% relative windows.
%
% Key design principle:
%   For each stimulated spasm, the comparison window is the actual
%   intersection of the spasm with the Ch3 ON period — expressed as
%   (offset_from_spasm_start, duration). That EXACT same relative window
%   is then applied to every unstimulated spasm, and the per-window
%   amplitude (AmpPercentile of the envelope) is extracted from both
%   groups. Because stimulated and unstimulated spasms are different
%   events, the comparison is UNPAIRED (Wilcoxon rank-sum / Mann-Whitney U).
%
% INPUTS
%   TT   : timetable from preprocess_and_label (must have TA_env, MG_env, Ch3_raw)
%   snr  : snr struct from preprocess_and_label (must have is_act, is_act_MG)
%   fs   : sampling frequency (Hz)
%
% NAME-VALUE OPTIONS
%   'SpasmPrcTA'    : percentile on active TA samples to define spasm threshold (default 65)
%   'SpasmPrcMG'    : percentile on active MG samples to define spasm threshold (default 65)
%   'SpasmMinDurS'  : minimum spasm duration in seconds (default 0.1)
%   'FuseGapMs'     : gap in ms within which adjacent spasms are fused (default 50)
%   'Ch3Threshold'  : manual Ch3 ON threshold — auto if empty
%   'Ch3MinOnMs'    : minimum Ch3 ON duration in ms (default 100)
%   'AmpPercentile' : percentile used to summarise amplitude within each window (default 90)
%   'MinWindowS'    : minimum window duration in seconds to include a comparison (default 0.05)
%   'PlotResult'    : produce summary figure (default true)

%% ================================================================
%  0. PARSE OPTIONS
%% ================================================================
p = inputParser;
p.addParameter('SpasmPrcTA',    65,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('SpasmPrcMG',    65,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('SpasmMinDurS',  0.1,   @(x) isnumeric(x) && isscalar(x));
p.addParameter('FuseGapMs',     50,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('Ch3Threshold',  [],    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Ch3MinOnMs',    100,   @(x) isnumeric(x) && isscalar(x));
p.addParameter('AmpPercentile', 90,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('MinWindowS',    0.05,  @(x) isnumeric(x) && isscalar(x));
p.addParameter('PlotResult',    true,  @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
opt = p.Results;

min_win_samples = max(1, round(opt.MinWindowS * fs));

%% ================================================================
%  1. EXTRACT SIGNALS
%% ================================================================
t      = seconds(TT.tDur);
TA_env = TT.TA_env(:);
MG_env = TT.MG_env(:);
Ch3    = TT.Ch3_raw(:);
N      = numel(TA_env);

is_act_TA = snr.is_act(:);
is_act_MG = snr.is_act_MG(:);

%% ================================================================
%  2. SPASM DETECTION  (same logic as spasm_gait_stim_analysis)
%% ================================================================
thr_spasm_TA = prctile(TA_env(is_act_TA & isfinite(TA_env)), opt.SpasmPrcTA);
thr_spasm_MG = prctile(MG_env(is_act_MG & isfinite(MG_env)), opt.SpasmPrcMG);

fprintf('Spasm thresholds  ->  TA: %.4f   MG: %.4f\n', thr_spasm_TA, thr_spasm_MG);

is_spasm_raw = (TA_env >= thr_spasm_TA) | (MG_env >= thr_spasm_MG);
is_spasm_raw(~isfinite(TA_env) & ~isfinite(MG_env)) = false;

min_spasm_smp = max(1, round(opt.SpasmMinDurS * fs));
is_spasm = keep_long_runs(is_spasm_raw, min_spasm_smp);
is_spasm = fuse_masks(is_spasm, fs, opt.FuseGapMs * 10);

% Enumerate spasm bouts
d_sp       = diff([false; is_spasm; false]);
sp_starts  = find(d_sp ==  1);
sp_ends    = find(d_sp == -1) - 1;
n_spasms   = numel(sp_starts);

fprintf('Detected %d spasm bouts\n', n_spasms);

if n_spasms == 0
    warning('compare_spasm_stim_vs_nostim: no spasms detected. Returning empty output.');
    out = empty_output();
    return;
end

%% ================================================================
%  3. CH3 ON DETECTION
%% ================================================================
Ch3_f = Ch3;
Ch3_f(~isfinite(Ch3)) = NaN;

if isempty(opt.Ch3Threshold)
    ch3_vals = Ch3_f(isfinite(Ch3_f));
    if isempty(ch3_vals)
        thr_ch3 = Inf;
    elseif max(ch3_vals) == min(ch3_vals)
        thr_ch3 = min(ch3_vals) + eps;
    else
        thr_ch3 = min(ch3_vals) + 0.5*(max(ch3_vals) - min(ch3_vals));
    end
else
    thr_ch3 = opt.Ch3Threshold;
end

is_ch3_on = Ch3_f >= thr_ch3;
is_ch3_on(~isfinite(Ch3_f)) = false;
min_ch3_smp = max(1, round(opt.Ch3MinOnMs / 1000 * fs));
is_ch3_on = keep_long_runs(is_ch3_on, min_ch3_smp);

fprintf('Ch3 threshold: %.4f  |  ON samples: %d / %d (%.1f%%)\n', ...
    thr_ch3, sum(is_ch3_on), N, 100*sum(is_ch3_on)/N);

%% ================================================================
%  4. CLASSIFY EACH SPASM: stimulated vs unstimulated
%     A spasm is "stimulated" if ANY of its samples overlap Ch3 ON.
%     The comparison window for that spasm is the intersection segment.
%% ================================================================
is_stimulated = false(n_spasms, 1);   % does spasm overlap Ch3 ON?
win_offset    = nan(n_spasms, 1);     % samples from spasm start to window start
win_dur       = nan(n_spasms, 1);     % window length in samples

for k = 1:n_spasms
    idx_sp = sp_starts(k):sp_ends(k);
    ch3_in_spasm = is_ch3_on(idx_sp);

    if ~any(ch3_in_spasm)
        continue;   % unstimulated — window assigned later
    end

    % Find the intersection: first and last ON sample inside this spasm
    first_on = find(ch3_in_spasm, 1, 'first');
    last_on  = find(ch3_in_spasm, 1, 'last');

    win_offset(k)    = first_on - 1;   % 0-based offset from spasm start
    win_dur(k)       = last_on - first_on + 1;
    is_stimulated(k) = true;
end

stim_idx   = find(is_stimulated);
nostim_idx = find(~is_stimulated);

fprintf('Stimulated spasms  : %d\n', numel(stim_idx));
fprintf('Unstimulated spasms: %d\n', numel(nostim_idx));

if isempty(stim_idx)
    warning('No stimulated spasms found (no spasm overlaps Ch3 ON).');
    out = empty_output();
    return;
end
if isempty(nostim_idx)
    warning('No unstimulated spasms found — cannot form a comparison group.');
    out = empty_output();
    return;
end

%% ================================================================
%  5. FOR EACH STIMULATED SPASM: extract amplitude in the stim window
%     FOR EACH UNSTIMULATED SPASM: apply the same relative window
%     and extract amplitude — only if the window fits inside the spasm
%% ================================================================
% We get one amplitude per stimulated spasm, and collect a distribution
% across all unstimulated spasms for every window template.
% Then we pool across templates (one mean per unstimulated spasm) to keep
% the comparison balanced.

n_stim = numel(stim_idx);

% Per-stimulated-event records
stim_amp_TA  = nan(n_stim, 1);
stim_amp_MG  = nan(n_stim, 1);
stim_off_s   = nan(n_stim, 1);
stim_dur_s   = nan(n_stim, 1);
stim_sp_idx  = nan(n_stim, 1);

for ki = 1:n_stim
    k   = stim_idx(ki);
    i0  = sp_starts(k) + win_offset(k);
    i1  = i0 + win_dur(k) - 1;
    i0  = max(1, i0);
    i1  = min(N, i1);

    if (i1 - i0 + 1) < min_win_samples
        fprintf('  Stim spasm %d: window too short (%d samples), skipped.\n', k, i1-i0+1);
        continue;
    end

    idx_win = i0:i1;
    stim_amp_TA(ki) = prctile(TA_env(idx_win), opt.AmpPercentile);
    stim_amp_MG(ki) = prctile(MG_env(idx_win), opt.AmpPercentile);
    stim_off_s(ki)  = win_offset(k) / fs;
    stim_dur_s(ki)  = win_dur(k) / fs;
    stim_sp_idx(ki) = k;

    fprintf('  Stim spasm %d: window %.3f + %.3f s  |  TA=%.4f  MG=%.4f\n', ...
        k, stim_off_s(ki), stim_dur_s(ki), stim_amp_TA(ki), stim_amp_MG(ki));
end

% For each unstimulated spasm, try ALL stimulated window templates and
% store the mean across templates that fit → one value per nostim spasm.
n_nostim = numel(nostim_idx);
nostim_amp_TA = nan(n_nostim, 1);
nostim_amp_MG = nan(n_nostim, 1);

for ni = 1:n_nostim
    k       = nostim_idx(ni);
    sp_len  = sp_ends(k) - sp_starts(k) + 1;

    template_TA = [];
    template_MG = [];

    for ki = 1:n_stim
        if isnan(stim_amp_TA(ki))
            continue;   % this template was skipped
        end

        off_smp = win_offset(stim_idx(ki));
        dur_smp = win_dur(stim_idx(ki));

        % Clip to whatever fits — a shorter spasm is still valid data
        if off_smp >= sp_len
            continue;   % offset already past spasm end — nothing to extract
        end
        dur_smp = min(dur_smp, sp_len - off_smp);
        if dur_smp < min_win_samples
            continue;   % even the clipped version is too short
        end

        i0 = sp_starts(k) + off_smp;
        i1 = i0 + dur_smp - 1;
        i1 = min(N, i1);

        idx_win = i0:i1;
        if numel(idx_win) < min_win_samples
            continue;
        end

        template_TA(end+1) = prctile(TA_env(idx_win), opt.AmpPercentile); %#ok<AGROW>
        template_MG(end+1) = prctile(MG_env(idx_win), opt.AmpPercentile); %#ok<AGROW>
    end

    if ~isempty(template_TA)
        nostim_amp_TA(ni) = mean(template_TA, 'omitnan');
        nostim_amp_MG(ni) = mean(template_MG, 'omitnan');
        fprintf('  NoStim spasm %d: %d template(s) fit  |  TA=%.4f  MG=%.4f\n', ...
            k, numel(template_TA), nostim_amp_TA(ni), nostim_amp_MG(ni));
    else
        fprintf('  NoStim spasm %d: no template window fits spasm length (%.3f s), skipped.\n', ...
            k, sp_len/fs);
    end
end

%% ================================================================
%  6. STATISTICAL TEST  (unpaired — different spasm events)
%     Wilcoxon rank-sum = Mann-Whitney U
%% ================================================================
valid_stim_TA   = stim_amp_TA(isfinite(stim_amp_TA));
valid_nostim_TA = nostim_amp_TA(isfinite(nostim_amp_TA));
valid_stim_MG   = stim_amp_MG(isfinite(stim_amp_MG));
valid_nostim_MG = nostim_amp_MG(isfinite(nostim_amp_MG));

[p_TA, h_TA, stats_TA] = run_ranksum(valid_stim_TA, valid_nostim_TA);
[p_MG, h_MG, stats_MG] = run_ranksum(valid_stim_MG, valid_nostim_MG);

fprintf('\n============ RESULTS ============\n');
fprintf('TA  |  stim: n=%d  mean=%.4f  median=%.4f\n', ...
    numel(valid_stim_TA), mean(valid_stim_TA,'omitnan'), median(valid_stim_TA,'omitnan'));
fprintf('    | nostim: n=%d  mean=%.4f  median=%.4f\n', ...
    numel(valid_nostim_TA), mean(valid_nostim_TA,'omitnan'), median(valid_nostim_TA,'omitnan'));
fprintf('    | rank-sum p = %.4g  (h=%d)\n', p_TA, h_TA);
fprintf('MG  |  stim: n=%d  mean=%.4f  median=%.4f\n', ...
    numel(valid_stim_MG), mean(valid_stim_MG,'omitnan'), median(valid_stim_MG,'omitnan'));
fprintf('    | nostim: n=%d  mean=%.4f  median=%.4f\n', ...
    numel(valid_nostim_MG), mean(valid_nostim_MG,'omitnan'), median(valid_nostim_MG,'omitnan'));
fprintf('    | rank-sum p = %.4g  (h=%d)\n', p_MG, h_MG);
fprintf('=================================\n');

%% ================================================================
%  7. FIGURE
%% ================================================================
if opt.PlotResult
    fig = figure('Color','k','Name','Spasm amplitude: stimulated vs unstimulated', ...
        'Position',[50 50 1300 800]);

    col_stim   = [1.0  0.35 0.35];   % red   — stimulated
    col_nostim = [0.35 0.65 1.00];   % blue  — unstimulated

    % ---- Top panel: signal overview with labelled spasms ----
    ax_sig = subplot(3,2,[1 2]);
    hold(ax_sig,'on');
    set(ax_sig,'Color','k','XColor','w','YColor','w','GridColor',[0.3 0.3 0.3]);
    grid(ax_sig,'on');

    spacing = max(range(TA_env(isfinite(TA_env))), range(MG_env(isfinite(MG_env)))) * 1.5;
    if ~isfinite(spacing) || spacing <= 0, spacing = 1; end
    off_MG = spacing;
    lane   = 0.38 * spacing;

    plot(ax_sig, t, TA_env,          'Color',[0.4 0.8 1.0],'LineWidth',0.6,'DisplayName','TA env');
    plot(ax_sig, t, MG_env + off_MG, 'Color',[0.8 0.5 1.0],'LineWidth',0.6,'DisplayName','MG env');

    % Shade Ch3 ON
    shade_ax(ax_sig, t, is_ch3_on, [-lane, off_MG+lane], [0 1 1], 0.12);
    patch(ax_sig, NaN, NaN, [0 1 1], 'FaceAlpha',0.35,'EdgeColor','none','DisplayName','Ch3 ON');

    % Shade spasms by type
    for k = 1:n_spasms
        ts = t(sp_starts(k));
        te = t(sp_ends(k));
        if is_stimulated(k)
            col = col_stim;   dn = 'Stim spasm';
        else
            col = col_nostim; dn = 'NoStim spasm';
        end
        xp = [ts te te ts];
        yp = [-lane -lane off_MG+lane off_MG+lane];
        patch(ax_sig, xp, yp, col, 'FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');

        % Mark the comparison window on stimulated spasms
        if is_stimulated(k) && ~isnan(win_offset(k))
            tw0 = t(min(N, sp_starts(k) + win_offset(k)));
            tw1 = t(min(N, sp_starts(k) + win_offset(k) + win_dur(k) - 1));
            xw  = [tw0 tw1 tw1 tw0];
            yw  = [-lane*0.5 -lane*0.5 off_MG+lane*0.5 off_MG+lane*0.5];
            patch(ax_sig, xw, yw, [1 0.9 0], 'FaceAlpha',0.55,'EdgeColor',[1 0.8 0],...
                'LineWidth',1,'HandleVisibility','off');
        end
    end

    % Legend proxies
    patch(ax_sig,NaN,NaN,col_stim,  'FaceAlpha',0.35,'EdgeColor','none','DisplayName','Stim spasm');
    patch(ax_sig,NaN,NaN,col_nostim,'FaceAlpha',0.35,'EdgeColor','none','DisplayName','NoStim spasm');
    patch(ax_sig,NaN,NaN,[1 0.9 0], 'FaceAlpha',0.55,'EdgeColor','none','DisplayName','Comparison window');

    yticks(ax_sig,[0 off_MG]); yticklabels(ax_sig,{'TA','MG'});
    xlabel(ax_sig,'Time (s)','Color','w');
    title(ax_sig,'Spasm overview  |  yellow = comparison window','Color','w');
    legend(ax_sig,'TextColor','w','Color','k','Location','northeast','FontSize',7,'AutoUpdate','off');

    % ---- Middle panels: individual data points + group means ----
    plot_comparison_panel(subplot(3,2,3), valid_stim_TA, valid_nostim_TA, ...
        col_stim, col_nostim, 'TA amplitude', p_TA, opt.AmpPercentile);

    plot_comparison_panel(subplot(3,2,4), valid_stim_MG, valid_nostim_MG, ...
        col_stim, col_nostim, 'MG amplitude', p_MG, opt.AmpPercentile);

    % ---- Bottom panels: distributions ----
    plot_distribution_panel(subplot(3,2,5), valid_stim_TA, valid_nostim_TA, ...
        col_stim, col_nostim, 'TA');

    plot_distribution_panel(subplot(3,2,6), valid_stim_MG, valid_nostim_MG, ...
        col_stim, col_nostim, 'MG');

    sgtitle(fig, sprintf('Spasm amplitude: stimulated vs unstimulated  |  p_{TA}=%.3g   p_{MG}=%.3g', ...
        p_TA, p_MG), 'Color','w','FontSize',11);
end

%% ================================================================
%  8. ASSEMBLE OUTPUT
%% ================================================================
out.is_spasm         = is_spasm;
out.is_ch3_on        = is_ch3_on;
out.sp_starts        = sp_starts;
out.sp_ends          = sp_ends;
out.is_stimulated    = is_stimulated;
out.win_offset_s     = win_offset / fs;
out.win_dur_s        = win_dur    / fs;

out.stim_amp_TA      = valid_stim_TA;
out.stim_amp_MG      = valid_stim_MG;
out.nostim_amp_TA    = valid_nostim_TA;
out.nostim_amp_MG    = valid_nostim_MG;

out.p_TA             = p_TA;
out.h_TA             = h_TA;
out.stats_TA         = stats_TA;
out.p_MG             = p_MG;
out.h_MG             = h_MG;
out.stats_MG         = stats_MG;

out.thr_spasm_TA     = thr_spasm_TA;
out.thr_spasm_MG     = thr_spasm_MG;
out.thr_ch3          = thr_ch3;
end

%% ================================================================
%  LOCAL HELPERS
%% ================================================================

function [p, h, stats] = run_ranksum(a, b)
% Wilcoxon rank-sum (unpaired). Returns NaN if not enough data.
if numel(a) >= 2 && numel(b) >= 2
    try
        [p, h, stats] = ranksum(a, b);
    catch
        p = NaN; h = 0; stats = struct('ranksum', NaN);
    end
else
    p = NaN; h = 0; stats = struct('ranksum', NaN);
    if numel(a) < 2
        warning('compare_spasm_stim_vs_nostim: fewer than 2 stimulated spasm windows — p-value unavailable.');
    end
    if numel(b) < 2
        warning('compare_spasm_stim_vs_nostim: fewer than 2 unstimulated spasm windows — p-value unavailable.');
    end
end
end

function plot_comparison_panel(ax, stim, nostim, c_stim, c_nostim, ylbl, p_val, amp_prc)
hold(ax,'on');
set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.3 0.3 0.3]);
grid(ax,'on');

% Jittered dots
jitter = 0.08;
xs  = 1 + jitter*(rand(numel(stim),1)-0.5);
xns = 2 + jitter*(rand(numel(nostim),1)-0.5);

scatter(ax, xs,  stim,   28, c_stim,   'filled','MarkerFaceAlpha',0.7);
scatter(ax, xns, nostim, 28, c_nostim, 'filled','MarkerFaceAlpha',0.7);

% Mean ± SD
errorbar(ax, 1, mean(stim,'omitnan'),   std(stim,0,'omitnan'), ...
    'w','LineWidth',2.5,'CapSize',14,'LineStyle','none');
errorbar(ax, 2, mean(nostim,'omitnan'), std(nostim,0,'omitnan'), ...
    'w','LineWidth',2.5,'CapSize',14,'LineStyle','none');

plot(ax, 1, mean(stim,'omitnan'),   'w+','MarkerSize',10,'LineWidth',2.5);
plot(ax, 2, mean(nostim,'omitnan'), 'w+','MarkerSize',10,'LineWidth',2.5);

% Significance bracket
all_vals = [stim(:); nostim(:)];
top = max(all_vals,[],'omitnan') * 1.15;
if ~isfinite(top) || top <= 0, top = 1; end
plot(ax,[1 1 2 2],[top*0.97 top top top*0.97],'w-','LineWidth',1);
if isfinite(p_val)
    if     p_val < 0.001, sig_str = '***';
    elseif p_val < 0.01,  sig_str = '**';
    elseif p_val < 0.05,  sig_str = '*';
    else,                 sig_str = 'ns';
    end
    text(ax, 1.5, top*1.02, sig_str, 'Color','w','HorizontalAlignment','center','FontSize',12);
end

set(ax,'XTick',[1 2],'XTickLabel',{'Stim','NoStim'});
xlim(ax,[0.5 2.5]);
ymax = max(all_vals,[],'omitnan') * 1.30;
if isfinite(ymax) && ymax > 0, ylim(ax,[0 ymax]); end
ylabel(ax, sprintf('%s (p%d)', ylbl, amp_prc), 'Color','w');
title(ax, sprintf('%s  p=%.3g (ranksum)', ylbl, p_val), 'Color','w');
end

function plot_distribution_panel(ax, stim, nostim, c_stim, c_nostim, chan)
hold(ax,'on');
set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.3 0.3 0.3]);
grid(ax,'on');

all_vals = [stim(:); nostim(:)];
if isempty(all_vals) || ~any(isfinite(all_vals)), return; end

if max(all_vals) == min(all_vals)
    edges = linspace(min(all_vals)-eps, max(all_vals)+eps, 15);
else
    edges = linspace(min(all_vals), max(all_vals), 15);
end

if ~isempty(stim)
    histogram(ax, stim,   edges, 'FaceColor',c_stim,   'FaceAlpha',0.5,'EdgeColor','none','DisplayName','Stim');
    if numel(stim) > 2
        [f,xi] = ksdensity(stim);
        % Scale KDE to match histogram y-scale
        plot(ax, xi, f * numel(stim) * mean(diff(edges)), '-','Color',c_stim,'LineWidth',2,'HandleVisibility','off');
    end
end
if ~isempty(nostim)
    histogram(ax, nostim, edges, 'FaceColor',c_nostim, 'FaceAlpha',0.5,'EdgeColor','none','DisplayName','NoStim');
    if numel(nostim) > 2
        [f,xi] = ksdensity(nostim);
        plot(ax, xi, f * numel(nostim) * mean(diff(edges)), '-','Color',c_nostim,'LineWidth',2,'HandleVisibility','off');
    end
end

xline(ax, mean(stim,'omitnan'),   '--','Color',c_stim,   'LineWidth',1.5,'HandleVisibility','off');
xline(ax, mean(nostim,'omitnan'), '--','Color',c_nostim, 'LineWidth',1.5,'HandleVisibility','off');

xlabel(ax, sprintf('%s amplitude', chan), 'Color','w');
ylabel(ax, 'Count', 'Color','w');
title(ax, sprintf('%s amplitude distribution', chan), 'Color','w');
legend(ax,'TextColor','w','Color','k','Location','best');
end

function shade_ax(ax, t, mask, ylims, color, alpha)
if ~any(mask), return; end
d = diff([false; mask(:); false]);
s = find(d ==  1);
e = find(d == -1) - 1;
for k = 1:numel(s)
    patch(ax,[t(s(k)) t(e(k)) t(e(k)) t(s(k))], ...
        [ylims(1) ylims(1) ylims(2) ylims(2)], ...
        color,'FaceAlpha',alpha,'EdgeColor','none','HandleVisibility','off');
end
end

function out = empty_output()
out.is_spasm      = [];
out.is_ch3_on     = [];
out.sp_starts     = [];
out.sp_ends       = [];
out.is_stimulated = [];
out.stim_amp_TA   = [];
out.stim_amp_MG   = [];
out.nostim_amp_TA = [];
out.nostim_amp_MG = [];
out.p_TA          = NaN;
out.h_TA          = 0;
out.stats_TA      = struct('ranksum', NaN);
out.p_MG          = NaN;
out.h_MG          = 0;
out.stats_MG      = struct('ranksum', NaN);
end

% ----------------------------------------------------------------
function mask_out = keep_long_runs(mask_in, min_len)
mask_in  = logical(mask_in(:));
d        = diff([false; mask_in; false]);
starts   = find(d ==  1);
ends     = find(d == -1) - 1;
mask_out = false(size(mask_in));
for i = 1:numel(starts)
    if (ends(i) - starts(i) + 1) >= min_len
        mask_out(starts(i):ends(i)) = true;
    end
end
end

% ----------------------------------------------------------------
function mask_out = fuse_masks(mask_in, fs, gap_ms)
% Fuse gaps shorter than gap_ms milliseconds between ON regions.
mask_in  = logical(mask_in(:));
gap_smp  = max(1, round(gap_ms / 1000 * fs));
d        = diff([false; mask_in; false]);
starts   = find(d ==  1);
ends     = find(d == -1) - 1;
mask_out = mask_in;
for i = 1:numel(starts)-1
    if (starts(i+1) - ends(i) - 1) <= gap_smp
        mask_out(ends(i):starts(i+1)) = true;
    end
end
end
