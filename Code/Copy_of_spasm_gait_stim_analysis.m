function out = Copy_of_spasm_gait_stim_analysis(TT_clean, snrValue, fs, varargin)
% spasm_gait_stim_analysis
%
% Classifies each sample into four mutually exclusive states:
%   - Spasm  : TA or MG amplitude exceeds a high percentile threshold
%   - Active : active but not classified as spasm and not classified as rest
%   - Rest   : taken preferentially from the rest masks produced by
%              preprocess_and_label / snr_emg
%   - Other  : everything not included in the first three classes
%
% For each context (Spasm / Active / Rest / Other), the function then
% splits samples by Ch3 ON vs OFF and computes amplitude statistics and
% a Wilcoxon signed-rank test per event.
%
% INPUTS
%   TT_clean   : timetable output of preprocess_and_label
%   snrValue   : snr struct output of preprocess_and_label
%   fs         : sampling frequency (Hz)
%
% NAME-VALUE OPTIONS
%   'SpasmPrcTA'     : percentile threshold on TA envelope for spasm (default 70)
%   'SpasmPrcMG'     : percentile threshold on MG envelope for spasm (default 70)
%   'GaitMinOverlapS': kept for compatibility, not used in current active definition
%   'SpasmMinDurS'   : minimum spasm duration in seconds (default 0.1)
%   'FuseGapMs'      : gap in ms to fuse nearby events of same type (default 50)
%   'Ch3Threshold'   : manual Ch3 ON threshold (auto if empty)
%   'Ch3MinOnMs'     : minimum Ch3 ON duration in ms (default 100)
%   'PlotResult'     : whether to produce the annot_ated figure (default true)
%   'TitleStr'       : figure title string

p = inputParser;
p.addParameter('SpasmPrcTA',      65,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('SpasmPrcMG',      65,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('GaitMinOverlapS', 0.05,  @(x) isnumeric(x) && isscalar(x));
p.addParameter('SpasmMinDurS',    0.1,   @(x) isnumeric(x) && isscalar(x));
p.addParameter('FuseGapMs',       50,    @(x) isnumeric(x) && isscalar(x));
p.addParameter('Ch3Threshold',    [],    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Ch3MinOnMs',      100,   @(x) isnumeric(x) && isscalar(x));
p.addParameter('PlotResult',      false,  @(x) islogical(x) && isscalar(x));
p.addParameter('TitleStr', 'Spasm / Active / Rest / Other / Stim analysis', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

%% ================================================================
%  1. EXTRACT SIGNALS
%% ================================================================
t      = seconds(TT_clean.tDur);
TA_env = TT_clean.TA_env(:);
MG_env = TT_clean.MG_env(:);
Ch3    = TT_clean.Ch3_raw(:);
N      = numel(TA_env);

is_act_TA = snrValue.is_act(:);
is_act_MG = snrValue.is_act_MG(:);

%% ================================================================
%  2. SPASM DETECTION
%% ================================================================




TA_filt = TT_clean.TA_filt(:);
MG_filt = TT_clean.MG_filt(:);

% --- Causal local RMS (50ms window) ---
win = round(0.050 * fs);
TA_rms = sqrt(movmean(TA_filt.^2, [win-1, 0]));
MG_rms = sqrt(movmean(MG_filt.^2, [win-1, 0]));

% --- Adaptive baseline (10s trailing median) ---
bwin = round(10 * fs);
TA_baseline = movmedian(TA_rms, [bwin, 0]);
MG_baseline = movmedian(MG_rms, [bwin, 0]);

% --- Threshold ---
thresh_factor = 4.0;
thr_spasm_TA = thresh_factor;   % kept for figure/output compatibility
thr_spasm_MG = thresh_factor;   % (now a factor, not an absolute level)
fprintf('Spasm threshold  ->  TA: %.4f x baseline  MG: %.4f x baseline\n', ...
    thr_spasm_TA, thr_spasm_MG);

is_spasm_raw = (TA_rms > thresh_factor * TA_baseline) | ...
               (MG_rms > thresh_factor * MG_baseline);

min_spasm_samples = max(1, round(opt.SpasmMinDurS * fs));
is_spasm = keep_long_runs(is_spasm_raw, min_spasm_samples);
is_spasm = fuse_masks(is_spasm, fs, opt.FuseGapMs*10);
%% ================================================================
%  3. REST DETECTION
%  Prefer masks produced by preprocess_and_label / snr_emg.
%  If they are unavailable, fall back to complement of activity.
%% ================================================================
is_active_any = is_act_TA | is_act_MG;

if isfield(snrValue, 'is_rest') && numel(snrValue.is_rest) == N
    is_rest = logical(snrValue.is_rest(:));
elseif isfield(snrValue, 'is_rest_TA') && isfield(snrValue, 'is_rest_MG') && ...
        numel(snrValue.is_rest_TA) == N && numel(snrValue.is_rest_MG) == N
    is_rest = logical(snrValue.is_rest_TA(:) & snrValue.is_rest_MG(:));
elseif isfield(snrValue, 'is_rest_MG') && numel(snrValue.is_rest_MG) == N
    is_rest = logical(snrValue.is_rest_MG(:));
else
    warning('No compatible rest mask found in snrValue. Falling back to ~is_active_any.');
    is_rest = ~is_active_any;
end

%% ================================================================
%  4. BUILD 4 MUTUALLY EXCLUSIVE STATES
%  Priority:
%    1) Spasm
%    2) Rest
%    3) Active
%    4) Other
%% ================================================================
% Rest should not include spasm
is_rest = is_rest & ~is_spasm;

% Active = any activity that is not spasm and not rest
is_active = is_active_any & ~is_spasm & ~is_rest;
is_active = keep_long_runs(is_active, 1);
is_active = fuse_masks(is_active, fs, opt.FuseGapMs);
is_active = is_active & ~is_spasm & ~is_rest;

% Other = everything not classified above
is_other = ~(is_spasm | is_active | is_rest);

% Final exclusivity safeguard
is_spasm  = is_spasm  & ~is_active & ~is_rest & ~is_other;
is_rest   = is_rest   & ~is_spasm  & ~is_active & ~is_other;
is_active = is_active & ~is_spasm  & ~is_rest   & ~is_other;
is_other  = ~(is_spasm | is_active | is_rest);

%% ================================================================
%  5. CH3 ON MASK
%% ================================================================
Ch3_finite = Ch3;
Ch3_finite(~isfinite(Ch3)) = NaN;

if isempty(opt.Ch3Threshold)
    ch3_vals = Ch3_finite(isfinite(Ch3_finite));
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

is_ch3_on = Ch3_finite >= thr_ch3;
is_ch3_on(~isfinite(Ch3_finite)) = false;

min_ch3_samples = max(1, round(opt.Ch3MinOnMs/1000 * fs));
is_ch3_on = keep_long_runs(is_ch3_on, min_ch3_samples);

fprintf('Ch3 ON threshold: %.4f  |  ON samples: %d / %d (%.1f%%)\n', ...
    thr_ch3, sum(is_ch3_on), N, 100*sum(is_ch3_on)/N);

%% ================================================================
%  6. AMPLITUDE STATISTICS PER CONTEXT × STIM STATE
%% ================================================================
contexts      = {'Spasm', 'Active', 'Rest', 'Other'};
context_masks = {is_spasm, is_active, is_rest, is_other};
stats = struct();

for c = 1:4
    ctx  = contexts{c};
    mask = context_masks{c};

    mask_on  = mask & is_ch3_on;
    mask_off = mask & ~is_ch3_on;

    amp_TA_on  = TA_env(mask_on  & isfinite(TA_env));
    amp_TA_off = TA_env(mask_off & isfinite(TA_env));
    amp_MG_on  = MG_env(mask_on  & isfinite(MG_env));
    amp_MG_off = MG_env(mask_off & isfinite(MG_env));

    s.n_on_samples  = sum(mask_on);
    s.n_off_samples = sum(mask_off);

    s.mean_TA_on  = mean(amp_TA_on,  'omitnan');
    s.mean_TA_off = mean(amp_TA_off, 'omitnan');
    s.mean_MG_on  = mean(amp_MG_on,  'omitnan');
    s.mean_MG_off = mean(amp_MG_off, 'omitnan');

    s.median_TA_on  = median(amp_TA_on,  'omitnan');
    s.median_TA_off = median(amp_TA_off, 'omitnan');
    s.median_MG_on  = median(amp_MG_on,  'omitnan');
    s.median_MG_off = median(amp_MG_off, 'omitnan');

    [ev_on_TA, ev_off_TA, ev_on_MG, ev_off_MG] = ...
        per_event_amplitudes(TA_env, MG_env, mask, is_ch3_on, fs);

    s.ev_on_TA  = ev_on_TA;
    s.ev_off_TA = ev_off_TA;
    s.ev_on_MG  = ev_on_MG;
    s.ev_off_MG = ev_off_MG;

    valid_TA = isfinite(ev_on_TA) & isfinite(ev_off_TA);
    if sum(valid_TA) >= 2
        [s.p_TA, ~, sr_TA] = signrank(ev_on_TA(valid_TA), ev_off_TA(valid_TA));
        s.signedrank_TA = sr_TA.signedrank;
    else
        s.p_TA = NaN;
        s.signedrank_TA = NaN;
    end

    valid_MG = isfinite(ev_on_MG) & isfinite(ev_off_MG);
    if sum(valid_MG) >= 2
        [s.p_MG, ~, sr_MG] = signrank(ev_on_MG(valid_MG), ev_off_MG(valid_MG));
        s.signedrank_MG = sr_MG.signedrank;
    else
        s.p_MG = NaN;
        s.signedrank_MG = NaN;
    end

    stats.(ctx) = s;

    fprintf('\n--- %s ---\n', ctx);
    fprintf('  ON samples: %d  |  OFF samples: %d\n', s.n_on_samples, s.n_off_samples);
    fprintf('  TA  median ON=%.4f  OFF=%.4f  p(signrank)=%.4g\n', ...
        s.median_TA_on, s.median_TA_off, s.p_TA);
    fprintf('  MG  median ON=%.4f  OFF=%.4f  p(signrank)=%.4g\n', ...
        s.median_MG_on, s.median_MG_off, s.p_MG);
end

%% ================================================================
%  7. FIGURE
%% ================================================================
if opt.PlotResult
    fig = figure('Color','k','Name', char(opt.TitleStr), ...
        'Position', [50 50 1400 900]); %#ok<NASGU>

    %% --- Top panel: annotated signal ---
    ax_sig = subplot(3,3,[1 2 3]);
    hold(ax_sig,'on');
    set(ax_sig,'Color','k','XColor','w','YColor','w','GridColor',[0.3 0.3 0.3]);
    grid(ax_sig,'on');

    spacing = max(range(TA_env), range(MG_env)) * 1.5;
    if spacing == 0 || ~isfinite(spacing)
        spacing = 1;
    end

    off_TA = 0;
    off_MG = spacing;
    lane   = 0.35 * spacing;

    % Shade classified regions
    shade_mask(ax_sig, t, is_spasm,  [off_TA-lane, off_TA+lane], [1 0.2 0.2], 0.35);
    shade_mask(ax_sig, t, is_spasm,  [off_MG-lane, off_MG+lane], [1 0.2 0.2], 0.35);
    shade_mask(ax_sig, t, is_active, [off_TA-lane, off_TA+lane], [0.2 1 0.4], 0.30);
    shade_mask(ax_sig, t, is_active, [off_MG-lane, off_MG+lane], [0.2 1 0.4], 0.30);
    shade_mask(ax_sig, t, is_rest,   [off_TA-lane, off_TA+lane], [1 0.85 0],  0.25);
    shade_mask(ax_sig, t, is_rest,   [off_MG-lane, off_MG+lane], [1 0.85 0],  0.25);
    shade_mask(ax_sig, t, is_other,  [off_TA-lane, off_TA+lane], [0.7 0.7 0.7], 0.20);
    shade_mask(ax_sig, t, is_other,  [off_MG-lane, off_MG+lane], [0.7 0.7 0.7], 0.20);

    % Plot signals
    plot(ax_sig, t, TA_env + off_TA, 'Color', [0.4 0.8 1], 'LineWidth', 0.8, ...
        'DisplayName', 'TA env');
    plot(ax_sig, t, MG_env + off_MG, 'Color', [0.8 0.5 1], 'LineWidth', 0.8, ...
        'DisplayName', 'MG env');

    % Ch3 ON overlay
    shade_mask(ax_sig, t, is_ch3_on, [off_TA+lane*0.7, off_TA+lane], [0 1 1], 0.6);
    shade_mask(ax_sig, t, is_ch3_on, [off_MG+lane*0.7, off_MG+lane], [0 1 1], 0.6);

    % Now variable thresholds
    yline(ax_sig, thresh_factor * median(TA_baseline) + off_TA, '--', ...
        'Color', [1 0.2 0.2], 'LineWidth', 1, 'Label', 'Spasm thr TA', ...
        'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
    yline(ax_sig, thresh_factor * median(MG_baseline) + off_MG, '--', ...
        'Color', [1 0.2 0.2], 'LineWidth', 1, 'Label', 'Spasm thr MG', ...
        'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');

    % Legend proxies only
    patch(ax_sig, NaN, NaN, [1 0.2 0.2], 'FaceAlpha', 0.35, 'EdgeColor','none', 'DisplayName','Spasm');
    patch(ax_sig, NaN, NaN, [0.2 1 0.4], 'FaceAlpha', 0.30, 'EdgeColor','none', 'DisplayName','Active');
    patch(ax_sig, NaN, NaN, [1 0.85 0],  'FaceAlpha', 0.25, 'EdgeColor','none', 'DisplayName','Rest');
    patch(ax_sig, NaN, NaN, [0.7 0.7 0.7], 'FaceAlpha', 0.20, 'EdgeColor','none', 'DisplayName','Other');
    patch(ax_sig, NaN, NaN, [0 1 1],     'FaceAlpha', 0.60, 'EdgeColor','none', 'DisplayName','Ch3 ON');

    yticks(ax_sig, [off_TA, off_MG]);
    yticklabels(ax_sig, {'TA env', 'MG env'});
    xlabel(ax_sig, 'Time (s)', 'Color','w');
    title(ax_sig, char(opt.TitleStr), 'Color','w');
    legend(ax_sig, 'TextColor','w', 'Color','k', 'Location','northeast', 'FontSize',7, ...
        'AutoUpdate', 'off');

    %% --- Bottom panels: bar plots ON vs OFF per context ---
    ctx_colors = {[1 0.2 0.2], [0.2 1 0.4], [1 0.85 0], [0.7 0.7 0.7]};

    for c = 1:4
        ctx = contexts{c};
        s   = stats.(ctx);
        col = ctx_colors{c};

        % TA panel
        ax = subplot(3,4,4+c);
        hold(ax,'on');
        set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.3 0.3 0.3]);
        grid(ax,'on');

        vals = [s.median_TA_off, s.median_TA_on];
        xbar = [1 2];
        b = bar(ax, xbar, vals, 0.6, 'FaceColor','flat', 'HandleVisibility','off');
        b.CData(1,:) = [0.4 0.4 0.4];
        b.CData(2,:) = col;

        set(ax, 'XTick', xbar, 'XTickLabel', {'Ch3 OFF','Ch3 ON'}, ...
            'XColor','w', 'YColor','w');
        xlim(ax, [0.5 2.5]);
        ylabel(ax,'TA amplitude','Color','w');
        title(ax, sprintf('TA | %s\np=%.3g', ctx, s.p_TA), 'Color','w');

        ymax = max(vals);
        if ~isfinite(ymax) || ymax <= 0
            ymax = 1;
        end
        ylim(ax, [0, ymax*1.3]);

        % MG panel
        ax = subplot(3,4,8+c);
        hold(ax,'on');
        set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.3 0.3 0.3]);
        grid(ax,'on');

        vals = [s.median_MG_off, s.median_MG_on];
        xbar = [1 2];
        b = bar(ax, xbar, vals, 0.6, 'FaceColor','flat', 'HandleVisibility','off');
        b.CData(1,:) = [0.4 0.4 0.4];
        b.CData(2,:) = col;

        set(ax, 'XTick', xbar, 'XTickLabel', {'Ch3 OFF','Ch3 ON'}, ...
            'XColor','w', 'YColor','w');
        xlim(ax, [0.5 2.5]);
        ylabel(ax,'MG amplitude','Color','w');
        title(ax, sprintf('MG | %s\np=%.3g', ctx, s.p_MG), 'Color','w');

        ymax = max(vals);
        if ~isfinite(ymax) || ymax <= 0
            ymax = 1;
        end
        ylim(ax, [0, ymax*1.3]);

        legend(ax, 'off');
    end
end

%% ================================================================
%  8. OUTPUT
%% ================================================================
out.is_spasm      = is_spasm;
out.is_active     = is_active;
out.is_rest       = is_rest;
out.is_other      = is_other;
out.is_ch3_on     = is_ch3_on;
out.thr_spasm_TA  = thr_spasm_TA;
out.thr_spasm_MG  = thr_spasm_MG;
out.thr_ch3       = thr_ch3;
out.stats         = stats;
out.t             = t;

end

%% ================================================================
%  LOCAL HELPERS
%% ================================================================

function [ev_on_TA, ev_off_TA, ev_on_MG, ev_off_MG] = ...
        per_event_amplitudes(TA_env, MG_env, ctx_mask, is_ch3_on, ~)
% For each Ch3 ON episode that overlaps the context mask, compute the
% median amplitude of TA and MG during the ON episode and during the
% nearest available OFF portion within the same context.

d = diff([false; is_ch3_on(:); false]);
on_starts = find(d ==  1);
on_ends   = find(d == -1) - 1;

ev_on_TA  = nan(numel(on_starts), 1);
ev_off_TA = nan(numel(on_starts), 1);
ev_on_MG  = nan(numel(on_starts), 1);
ev_off_MG = nan(numel(on_starts), 1);

for k = 1:numel(on_starts)
    idx_on = on_starts(k):on_ends(k);

    in_ctx_on = ctx_mask(idx_on);
    if ~any(in_ctx_on)
        continue;
    end

    ev_on_TA(k) = median(TA_env(idx_on(in_ctx_on)), 'omitnan');
    ev_on_MG(k) = median(MG_env(idx_on(in_ctx_on)), 'omitnan');

    dur = numel(idx_on);
    pre_start = max(1, on_starts(k) - 2*dur);
    pre_end   = max(1, on_starts(k) - 1);

    idx_off = pre_start:pre_end;
    in_ctx_off = ctx_mask(idx_off) & ~is_ch3_on(idx_off);

    if ~any(in_ctx_off)
        continue;
    end

    ev_off_TA(k) = median(TA_env(idx_off(in_ctx_off)), 'omitnan');
    ev_off_MG(k) = median(MG_env(idx_off(in_ctx_off)), 'omitnan');
end
end

function shade_mask(ax, t, mask, ylims, color, alpha)
% Shade regions where mask is true with a filled patch.
if ~any(mask)
    return;
end

d = diff([false; mask(:); false]);
starts = find(d ==  1);
ends   = find(d == -1) - 1;

for k = 1:numel(starts)
    x0 = t(starts(k));
    x1 = t(ends(k));
    patch(ax, [x0 x1 x1 x0], [ylims(1) ylims(1) ylims(2) ylims(2)], ...
        color, 'FaceAlpha', alpha, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
end
end

