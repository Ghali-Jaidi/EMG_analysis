function out = amplitude_distribution(MG_signals, Ch3_signals, fs, varargin)

p = inputParser;
p.addParameter('MGAlreadyAmplitude', false, @(x)islogical(x) && isscalar(x));
p.addParameter('OnThreshold', [], @(x) isempty(x) || (isscalar(x) && isnumeric(x)));
p.addParameter('OnMinDurMs', 100, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('PreWindowS',  [-2 -0.01], @(x)isnumeric(x) && numel(x)==2 && x(1) < x(2));
p.addParameter('PostWindowS', [2 3], @(x)isnumeric(x) && numel(x)==2 && x(1) < x(2));
p.addParameter('AmpPercentile', 90, @(x)isnumeric(x) && isscalar(x) && x > 0 && x <= 100);
p.addParameter('NormalizeToOn', false, @(x)islogical(x) && isscalar(x));
p.addParameter('TitleStr', 'MG amplitude during Ch3 ON vs local pre-ON OFF window', @(x)ischar(x) || isstring(x));
p.addParameter('PlotPerEvent', true, @(x)islogical(x) && isscalar(x));

% Optional masks / constraints
p.addParameter('SpasmMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
p.addParameter('RestMask',  [], @(x) isempty(x) || islogical(x) || isnumeric(x));

p.addParameter('DominantFrac', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
p.addParameter('RestFracThreshold', 0.6, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);

p.addParameter('ContextMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
p.addParameter('RequireOnInsideContext', true, @(x)islogical(x) && isscalar(x));
p.addParameter('RequirePreInsideContext', true, @(x)islogical(x) && isscalar(x));
p.addParameter('RequirePostInsideContext', false, @(x)islogical(x) && isscalar(x));

p.parse(varargin{:});
opt = p.Results;

fprintf('\n====================================================\n');
fprintf('DEBUG amplitude_distribution\n');
fprintf('  TitleStr                : %s\n', char(opt.TitleStr));
fprintf('  MGAlreadyAmplitude      : %d\n', opt.MGAlreadyAmplitude);
fprintf('  OnMinDurMs              : %.3f\n', opt.OnMinDurMs);
fprintf('  PreWindowS              : [%.3f %.3f]\n', opt.PreWindowS(1), opt.PreWindowS(2));
fprintf('  PostWindowS             : [%.3f %.3f]\n', opt.PostWindowS(1), opt.PostWindowS(2));
fprintf('  AmpPercentile           : %.1f\n', opt.AmpPercentile);
fprintf('  NormalizeToOn           : %d\n', opt.NormalizeToOn);
fprintf('  PlotPerEvent            : %d\n', opt.PlotPerEvent);
fprintf('  RequireOnInsideContext  : %d\n', opt.RequireOnInsideContext);
fprintf('  RequirePreInsideContext : %d\n', opt.RequirePreInsideContext);
fprintf('  RequirePostInsideContext: %d\n', opt.RequirePostInsideContext);
fprintf('  DominantFrac            : %.3f\n', opt.DominantFrac);
fprintf('  RestFracThreshold       : %.3f\n', opt.RestFracThreshold);
fprintf('====================================================\n');

% ------------------------------------------------
% Accept vectors OR cell arrays
% ------------------------------------------------
if ~iscell(MG_signals)
    MG_signals = {MG_signals};
end
if ~iscell(Ch3_signals)
    Ch3_signals = {Ch3_signals};
end

assert(iscell(MG_signals) && iscell(Ch3_signals), ...
    'MG_signals and Ch3_signals must be vectors or cell arrays.');
assert(numel(MG_signals) == numel(Ch3_signals), ...
    'MG_signals and Ch3_signals must have the same length.');

fprintf('DEBUG input packaging:\n');
fprintf('  numel(MG_signals)  = %d\n', numel(MG_signals));
fprintf('  numel(Ch3_signals) = %d\n', numel(Ch3_signals));

% ------------------------------------------------
% Context masks
% ------------------------------------------------
if isempty(opt.ContextMask)
    context_masks = cell(size(MG_signals));
    for i = 1:numel(context_masks)
        context_masks{i} = [];
    end
    fprintf('  ContextMask = empty -> using full true mask per experiment\n');
else
    if ~iscell(opt.ContextMask)
        context_masks = {logical(opt.ContextMask)};
    else
        context_masks = opt.ContextMask;
    end
    assert(numel(context_masks) == numel(MG_signals), ...
        'ContextMask must be empty, a vector, or a cell array matching MG_signals.');
    fprintf('  ContextMask provided with %d entries\n', numel(context_masks));
end

% ------------------------------------------------
% Spasm masks
% ------------------------------------------------
if isempty(opt.SpasmMask)
    spasm_masks = cell(size(MG_signals));
    for i = 1:numel(spasm_masks)
        spasm_masks{i} = [];
    end
    fprintf('  SpasmMask = empty -> using all false mask per experiment\n');
else
    if ~iscell(opt.SpasmMask)
        spasm_masks = {logical(opt.SpasmMask)};
    else
        spasm_masks = opt.SpasmMask;
    end
    assert(numel(spasm_masks) == numel(MG_signals), ...
        'SpasmMask must be empty, a vector, or a cell array matching MG_signals.');
    fprintf('  SpasmMask provided with %d entries\n', numel(spasm_masks));
end

% ------------------------------------------------
% Rest masks
% ------------------------------------------------
if isempty(opt.RestMask)
    rest_masks = cell(size(MG_signals));
    for i = 1:numel(rest_masks)
        rest_masks{i} = [];
    end
    fprintf('  RestMask = empty -> using all false mask per experiment\n');
else
    if ~iscell(opt.RestMask)
        rest_masks = {logical(opt.RestMask)};
    else
        rest_masks = opt.RestMask;
    end
    assert(numel(rest_masks) == numel(MG_signals), ...
        'RestMask must be empty, a vector, or a cell array matching MG_signals.');
    fprintf('  RestMask provided with %d entries\n', numel(rest_masks));
end

event_rows = [];

for e = 1:numel(MG_signals)
    MG  = MG_signals{e}(:);
    Ch3 = Ch3_signals{e}(:);

    ctx = context_masks{e};
    if isempty(ctx)
        ctx = true(size(MG));
    else
        ctx = logical(ctx(:));
    end

    spasm = spasm_masks{e};
    if isempty(spasm)
        spasm = false(size(MG));
    else
        spasm = logical(spasm(:));
    end

    rest = rest_masks{e};
    if isempty(rest)
        rest = false(size(MG));
    else
        rest = logical(rest(:));
    end

    N = min([numel(MG), numel(Ch3), numel(ctx), numel(spasm), numel(rest)]);
    MG    = MG(1:N);
    Ch3   = Ch3(1:N);
    ctx   = ctx(1:N);
    spasm = spasm(1:N);
    rest  = rest(1:N);

    fprintf('\n==============================\n');
    fprintf('Experiment %d\n', e);
    fprintf('  N = %d samples (%.2f s)\n', N, N/fs);
    fprintf('  raw finite MG = %d | raw finite Ch3 = %d | ctx true = %d | spasm true = %d | rest true = %d\n', ...
        sum(isfinite(MG)), sum(isfinite(Ch3)), sum(ctx), sum(spasm), sum(rest));

    if any(isfinite(MG))
        fprintf('  raw MG range = [%.6f, %.6f]\n', min(MG(isfinite(MG))), max(MG(isfinite(MG))));
    end
    if any(isfinite(Ch3))
        fprintf('  raw Ch3 range = [%.6f, %.6f]\n', min(Ch3(isfinite(Ch3))), max(Ch3(isfinite(Ch3))));
    end

    if opt.MGAlreadyAmplitude
        MG_amp = MG;
    else
        MG_amp = abs(MG);
    end

    valid = isfinite(MG_amp) & isfinite(Ch3);
    MG_amp(~valid) = NaN;
    Ch3(~valid)    = NaN;
    ctx(~valid)    = false;
    spasm(~valid)  = false;
    rest(~valid)   = false;

    fprintf('  after validity masking:\n');
    fprintf('    finite MG_amp = %d\n', sum(isfinite(MG_amp)));
    fprintf('    finite Ch3    = %d\n', sum(isfinite(Ch3)));
    fprintf('    ctx true      = %d\n', sum(ctx));
    fprintf('    spasm true    = %d\n', sum(spasm));
    fprintf('    rest true     = %d\n', sum(rest));

    if isempty(opt.OnThreshold)
        ch3_valid = Ch3(isfinite(Ch3));
        if isempty(ch3_valid)
            fprintf('  REJECT experiment: no finite Ch3 values.\n');
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

    min_on_samples = max(1, round(opt.OnMinDurMs/1000 * fs));
    is_on_raw = is_on;
    is_on = keep_long_runs(is_on, min_on_samples);

    fprintf('  Ch3 threshold = %.4f\n', thr);
    fprintf('  Raw ON samples = %d | ON samples after keep_long_runs = %d\n', ...
        sum(is_on_raw), sum(is_on));

    d = diff([false; is_on; false]);
    on_starts = find(d ==  1);
    on_ends   = find(d == -1) - 1;

    fprintf('  Number of ON events = %d\n', numel(on_starts));

    n_no_ctx_overlap      = 0;
    n_invalid_pre         = 0;
    n_pre_contains_on     = 0;
    n_empty_after_filter  = 0;
    n_spasm_mismatch      = 0;
    n_rest_mismatch       = 0;
    n_bad_on_scale        = 0;
    n_accept              = 0;

    for k = 1:numel(on_starts)
        s_on = on_starts(k);
        e_on = on_ends(k);

        idx_on = s_on:e_on;

        fprintf('\n  ---- Event %d ----\n', k);
        fprintf('    ON: s_on=%d e_on=%d | %.3f to %.3f s | dur=%.3f s\n', ...
            s_on, e_on, (s_on-1)/fs, (e_on-1)/fs, (e_on-s_on+1)/fs);

        % ---- ON/context check ----
        if opt.RequireOnInsideContext
            if ~all(ctx(idx_on))
                fprintf('    REJECT: ON window not fully inside context.\n');
                n_no_ctx_overlap = n_no_ctx_overlap + 1;
                continue;
            end
        end

        % ---- Pre window ----
        pre_start = s_on + round(opt.PreWindowS(1) * fs);
        pre_end   = s_on + round(opt.PreWindowS(2) * fs);

        if pre_start < 1 || pre_end < 1 || pre_start > pre_end || pre_end > N
            fprintf('    REJECT: invalid pre window [%d %d]\n', pre_start, pre_end);
            n_invalid_pre = n_invalid_pre + 1;
            continue;
        end

        idx_pre = pre_start:pre_end;

        if opt.RequirePreInsideContext && ~all(ctx(idx_pre))
            fprintf('    REJECT: PRE window not fully inside context.\n');
            n_no_ctx_overlap = n_no_ctx_overlap + 1;
            continue;
        end

        if any(is_on(idx_pre))
            fprintf('    REJECT: pre window contains ON samples (%d samples)\n', sum(is_on(idx_pre)));
            n_pre_contains_on = n_pre_contains_on + 1;
            continue;
        end

        % ---- Post window ----
        post_start = e_on + round(opt.PostWindowS(1) * fs);
        post_end   = e_on + round(opt.PostWindowS(2) * fs);

        post_valid = (post_start >= 1) && (post_end <= N) && (post_start <= post_end);

        if post_valid
            idx_post = post_start:post_end;

            if any(is_on(idx_post))
                fprintf('    POST invalid: post window contains ON samples (%d samples)\n', ...
                    sum(is_on(idx_post)));
                post_valid = false;
            elseif opt.RequirePostInsideContext && ~all(ctx(idx_post))
                fprintf('    POST invalid: post window not fully inside context.\n');
                post_valid = false;
            end
        else
            idx_post = [];
        end

        % ============================================================
        % 1) Spasm compatibility handled independently for PRE and POST
        % ============================================================
        frac_on_spasm  = mean(spasm(idx_on));
        frac_pre_spasm = mean(spasm(idx_pre));

        frac_post_spasm = NaN;
        if post_valid
            frac_post_spasm = mean(spasm(idx_post));
        end

        on_is_spasm_dominant   = frac_on_spasm  >= opt.DominantFrac;
        pre_is_spasm_dominant  = frac_pre_spasm >= opt.DominantFrac;
        post_is_spasm_dominant = post_valid && (frac_post_spasm >= opt.DominantFrac);

        pre_spasm_compatible  = (pre_is_spasm_dominant  == on_is_spasm_dominant);
        post_spasm_compatible = post_valid && (post_is_spasm_dominant == on_is_spasm_dominant);

        fprintf('    Spasm fractions | ON=%.3f PRE=%.3f POST=%.3f\n', ...
            frac_on_spasm, frac_pre_spasm, frac_post_spasm);
        fprintf('    Spasm compatibility | PRE=%d POST=%d\n', ...
            pre_spasm_compatible, post_spasm_compatible);

        % ============================================================
        % 2) Soft rest-mismatch filter handled independently for PRE/POST
        %    Only penalize when ON is mostly rest and the side is mostly non-rest
        % ============================================================
        frac_on_rest  = mean(rest(idx_on));
        frac_pre_rest = mean(rest(idx_pre));

        frac_post_rest = NaN;
        if post_valid
            frac_post_rest = mean(rest(idx_post));
        end

        on_mostly_rest      = frac_on_rest  >= opt.RestFracThreshold;
        pre_mostly_nonrest  = (1 - frac_pre_rest)  >= opt.RestFracThreshold;
        post_mostly_nonrest = post_valid && ((1 - frac_post_rest) >= opt.RestFracThreshold);

        pre_rest_compatible  = ~(on_mostly_rest && pre_mostly_nonrest);
        post_rest_compatible = post_valid && ~(on_mostly_rest && post_mostly_nonrest);

        fprintf('    Rest fractions  | ON=%.3f PRE=%.3f POST=%.3f\n', ...
            frac_on_rest, frac_pre_rest, frac_post_rest);
        fprintf('    Rest compatibility  | PRE=%d POST=%d\n', ...
            pre_rest_compatible, post_rest_compatible);

        % Final side compatibility = both rules
        pre_compatible  = pre_spasm_compatible  && pre_rest_compatible;
        post_compatible = post_valid && post_spasm_compatible && post_rest_compatible;

        % ---- ON amplitude is always needed ----
        mg_on = MG_amp(idx_on);
        if ~opt.RequireOnInsideContext
            mg_on = mg_on(ctx(idx_on));
        end
        mg_on = mg_on(isfinite(mg_on));

        if isempty(mg_on)
            fprintf('    REJECT: empty mg_on after filtering.\n');
            n_empty_after_filter = n_empty_after_filter + 1;
            continue;
        end

        A_on_raw = prctile(mg_on, opt.AmpPercentile);

        if ~isfinite(A_on_raw) || A_on_raw <= 0
            fprintf('    REJECT: invalid ON amplitude for normalization.\n');
            n_bad_on_scale = n_bad_on_scale + 1;
            continue;
        end

        % ---- PRE side ----
        A_pre_raw = NaN;
        if pre_compatible
            mg_pre = MG_amp(idx_pre);
            if ~opt.RequirePreInsideContext
                mg_pre = mg_pre(ctx(idx_pre));
            end
            mg_pre = mg_pre(isfinite(mg_pre));

            fprintf('    PRE samples after filtering: n_pre=%d\n', numel(mg_pre));

            if ~isempty(mg_pre)
                A_pre_raw = prctile(mg_pre, opt.AmpPercentile);
            else
                fprintf('    PRE invalid: empty after filtering.\n');
            end
        else
            if ~pre_spasm_compatible
                fprintf('    PRE skipped: spasm status mismatch with ON.\n');
            elseif ~pre_rest_compatible
                fprintf('    PRE skipped: ON is mostly rest but PRE is mostly non-rest.\n');
                n_rest_mismatch = n_rest_mismatch + 1;
            end
        end

        % ---- POST side ----
        A_post_raw = NaN;
        if post_compatible
            mg_post_vec = MG_amp(idx_post);
            if ~opt.RequirePostInsideContext
                mg_post_vec = mg_post_vec(ctx(idx_post));
            end
            mg_post_vec = mg_post_vec(isfinite(mg_post_vec));

            fprintf('    POST samples after filtering: n_post=%d\n', numel(mg_post_vec));

            if ~isempty(mg_post_vec)
                A_post_raw = prctile(mg_post_vec, opt.AmpPercentile);
            else
                fprintf('    POST invalid: empty after filtering.\n');
            end
        elseif post_valid
            if ~post_spasm_compatible
                fprintf('    POST skipped: spasm status mismatch with ON.\n');
            elseif ~post_rest_compatible
                fprintf('    POST skipped: ON is mostly rest but POST is mostly non-rest.\n');
                n_rest_mismatch = n_rest_mismatch + 1;
            end
        end

        % Need at least one comparable side
        if ~isfinite(A_pre_raw) && ~isfinite(A_post_raw)
            fprintf('    REJECT: neither PRE nor POST is comparable to ON.\n');
            n_spasm_mismatch = n_spasm_mismatch + 1;
            continue;
        end

        if opt.NormalizeToOn
            A_pre  = A_pre_raw  / A_on_raw;
            A_on   = 1;
            A_post = A_post_raw / A_on_raw;
        else
            A_pre  = A_pre_raw;
            A_on   = A_on_raw;
            A_post = A_post_raw;
        end

        delta_on_pre  = A_on - A_pre;
        delta_on_post = A_on - A_post;

        fprintf('    ACCEPT raw : PRE=%.6f | ON=%.6f | POST=%.6f\n', ...
            A_pre_raw, A_on_raw, A_post_raw);
        fprintf('    ACCEPT norm: PRE=%.6f | ON=%.6f | POST=%.6f\n', ...
            A_pre, A_on, A_post);

        n_accept = n_accept + 1;

        row = [ ...
            e, k, ...
            s_on, e_on, (s_on-1)/fs, (e_on-1)/fs, numel(idx_on)/fs, ...
            pre_start, pre_end, (pre_start-1)/fs, (pre_end-1)/fs, ...
            post_start, post_end, ...
            A_pre_raw, A_on_raw, A_post_raw, ...
            A_pre, A_on, A_post, ...
            delta_on_pre, ...
            delta_on_post, ...
            thr ...
        ];

        event_rows = [event_rows; row]; %#ok<AGROW>
    end

    fprintf('\n  Summary experiment %d:\n', e);
    fprintf('    no ctx overlap       : %d\n', n_no_ctx_overlap);
    fprintf('    invalid pre window   : %d\n', n_invalid_pre);
    fprintf('    pre contains ON      : %d\n', n_pre_contains_on);
    fprintf('    empty after filtering: %d\n', n_empty_after_filter);
    fprintf('    spasm mismatch       : %d\n', n_spasm_mismatch);
    fprintf('    rest mismatch        : %d\n', n_rest_mismatch);
    fprintf('    bad ON scale         : %d\n', n_bad_on_scale);
    fprintf('    accepted events      : %d\n', n_accept);
end

var_names = { ...
    'Experiment', 'EventID', ...
    'OnStartSample', 'OnEndSample', 'OnStartS', 'OnEndS', 'OnDurS', ...
    'PreStartSample', 'PreEndSample', 'PreStartS', 'PreEndS', ...
    'PostStartSample', 'PostEndSample', ...
    'MG_Pre_raw', 'MG_On_raw', 'MG_Post_raw', ...
    'MG_Pre', 'MG_On', 'MG_Post', ...
    'Delta_OnMinusPre', 'Delta_OnMinusPost', ...
    'Ch3Threshold'};

if isempty(event_rows)
    warning('No valid ON events found with usable pre-ON OFF windows.');
    out = struct();
    out.event_table = table();
    out.delta       = [];
    out.summary     = struct();
    return;
end

T = array2table(event_rows, 'VariableNames', var_names);

delta_pre  = T.Delta_OnMinusPre;
delta_post = T.Delta_OnMinusPost;

valid_delta_pre  = isfinite(delta_pre);
valid_delta_post = isfinite(delta_post);

summary = struct();
summary.n_events        = height(T);
summary.n_events_pre    = sum(isfinite(T.MG_Pre));
summary.n_events_post   = sum(isfinite(T.MG_Post));
summary.mean_pre        = mean(T.MG_Pre,  'omitnan');
summary.mean_on         = mean(T.MG_On,   'omitnan');
summary.mean_post       = mean(T.MG_Post, 'omitnan');
summary.mean_delta      = mean(delta_pre, 'omitnan');
summary.median_delta    = median(delta_pre, 'omitnan');
summary.n_negative      = sum(delta_pre(valid_delta_pre) < 0);
summary.frac_negative   = mean(delta_pre(valid_delta_pre) < 0);

summary.mean_pre_raw    = mean(T.MG_Pre_raw,  'omitnan');
summary.mean_on_raw     = mean(T.MG_On_raw,   'omitnan');
summary.mean_post_raw   = mean(T.MG_Post_raw, 'omitnan');

if sum(isfinite(T.MG_On) & isfinite(T.MG_Pre)) >= 2
    try
        valid_pre = isfinite(T.MG_On) & isfinite(T.MG_Pre);
        [p_signrank, ~, stats_signrank] = signrank(T.MG_On(valid_pre), T.MG_Pre(valid_pre));
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

if sum(isfinite(T.MG_On) & isfinite(T.MG_Post)) >= 2
    try
        valid_post_pair = isfinite(T.MG_On) & isfinite(T.MG_Post);
        [p_post, ~, stats_post] = signrank(T.MG_On(valid_post_pair), T.MG_Post(valid_post_pair));
        summary.p_signrank_post = p_post;
        summary.signedrank_post = stats_post.signedrank;
    catch
        summary.p_signrank_post = NaN;
        summary.signedrank_post = NaN;
    end
else
    summary.p_signrank_post = NaN;
    summary.signedrank_post = NaN;
end

col_pre  = [0.2  0.6  1.0];
col_on   = [1.0  0.3  0.3];
col_post = [0.2  0.85 0.4];

figure('Color', 'k', 'Name', char(opt.TitleStr));

% ---------- Subplot 1 ----------
ax1 = subplot(2,2,1);
hold(ax1,'on');
set(ax1,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax1,'on');

colors = lines(height(T));
if opt.PlotPerEvent
    for i = 1:height(T)
        x = [2];
        y = [T.MG_On(i)];

        if isfinite(T.MG_Pre(i))
            x = [1 x];
            y = [T.MG_Pre(i) y];
        end
        if isfinite(T.MG_Post(i))
            x = [x 3];
            y = [y T.MG_Post(i)];
        end

        plot(ax1, x, y, '-o', ...
            'Color', colors(i,:), ...
            'MarkerFaceColor', colors(i,:), ...
            'LineWidth', 1.2, 'MarkerSize', 5);
    end
end

xlim(ax1, [0.5 3.5]);
xticks(ax1, [1 2 3]);

if opt.NormalizeToOn
    ylabel(ax1, 'Amplitude (fraction of ON)', 'Color', 'w');
    xticklabels(ax1, {'Pre/On', 'On/On', 'Post/On'});
else
    ylabel(ax1, 'Amplitude (raw)', 'Color', 'w');
    xticklabels(ax1, {'Pre-ON', 'ON', 'Post-ON'});
end
title(ax1, char(opt.TitleStr), 'Color', 'w');

% ---------- Subplot 2 ----------
ax2 = subplot(2,2,2);
hold(ax2,'on');
set(ax2,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax2,'on');

delta_pre_finite  = delta_pre(valid_delta_pre);
delta_post_finite = delta_post(valid_delta_post);
all_d = [delta_pre_finite; delta_post_finite];

if ~isempty(all_d)
    if max(all_d) == min(all_d)
        edges_d = linspace(min(all_d)-eps, max(all_d)+eps, 31);
    else
        edges_d = linspace(min(all_d), max(all_d), 31);
    end

    if ~isempty(delta_pre_finite)
        histogram(ax2, delta_pre_finite, edges_d, ...
            'Normalization','pdf', ...
            'FaceColor', col_on, 'FaceAlpha', 0.35, ...
            'EdgeColor','none', 'DisplayName','\Delta ON - PRE');
        if numel(delta_pre_finite) > 1
            [f_d, xi_d] = ksdensity(delta_pre_finite);
            plot(ax2, xi_d, f_d, '-', 'Color', col_on, 'LineWidth', 1.8, ...
                'HandleVisibility','off');
        end
    end

    if ~isempty(delta_post_finite)
        histogram(ax2, delta_post_finite, edges_d, ...
            'Normalization','pdf', ...
            'FaceColor', col_post, 'FaceAlpha', 0.35, ...
            'EdgeColor','none', 'DisplayName','\Delta ON - POST');
        if numel(delta_post_finite) > 1
            [f_dp, xi_dp] = ksdensity(delta_post_finite);
            plot(ax2, xi_dp, f_dp, '-', 'Color', col_post, 'LineWidth', 1.8, ...
                'HandleVisibility','off');
        end
    end

    xline(ax2, 0, '--r', 'LineWidth', 1.2, 'HandleVisibility','off');
end


ylabel(ax2, 'Density', 'Color','w');
if opt.NormalizeToOn
    xlabel(ax2, '\Delta normalized amplitude (ON - Pre/On)', 'Color', 'w');
    delta_label = sprintf('med \x394=%.3f', summary.median_delta);
else
    xlabel(ax2, '\Delta raw amplitude (ON - Pre)', 'Color', 'w');
    delta_label = sprintf('med \x394=%.4f', summary.median_delta);
end

title(ax2, sprintf('nPRE=%d nPOST=%d | %s | p=%.3g', ...
    summary.n_events_pre, summary.n_events_post, ...
    delta_label, summary.p_signrank), 'Color', 'w');

legend(ax2, 'TextColor','w','Color','k','Location','best');



% ---------- Subplot 3 ----------
ax3 = subplot(2,2,3);
hold(ax3,'on');
set(ax3,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax3,'on');

if opt.NormalizeToOn
    mg_pre_plot  = T.MG_Pre(isfinite(T.MG_Pre));
    mg_on_plot   = T.MG_On(isfinite(T.MG_On));
    mg_post_plot = T.MG_Post(isfinite(T.MG_Post));
else
    mg_pre_plot  = T.MG_Pre_raw(isfinite(T.MG_Pre_raw));
    mg_on_plot   = T.MG_On_raw(isfinite(T.MG_On_raw));
    mg_post_plot = T.MG_Post_raw(isfinite(T.MG_Post_raw));
end

all_vals = [mg_pre_plot; mg_on_plot; mg_post_plot];

if opt.NormalizeToOn
    xlabel(ax3, 'Amplitude (fraction of ON)', 'Color', 'w');
    lbl_pre = 'Pre-ON (normalized)';
    lbl_on  = 'ON (normalized)';
    lbl_post = 'Post-ON (normalized)';
else
    xlabel(ax3, 'Amplitude (raw)', 'Color', 'w');
    lbl_pre  = 'Pre-ON (OFF)';
    lbl_on   = 'Ch3 ON';
    lbl_post = 'Post-ON (OFF)';
end
if ~isempty(all_vals)
    if max(all_vals) == min(all_vals)
        edges = linspace(min(all_vals)-eps, max(all_vals)+eps, 61);
    else
        edges = linspace(min(all_vals), max(all_vals), 61);
    end

    if ~isempty(mg_pre_plot)
        histogram(ax3, mg_pre_plot, edges, 'Normalization','pdf', ...
            'FaceColor',col_pre, 'FaceAlpha',0.35,'EdgeColor','none', ...
            'DisplayName',lbl_pre);
        if numel(mg_pre_plot) > 1
            [f,xi] = ksdensity(mg_pre_plot);
            plot(ax3,xi,f,'-','Color',col_pre,'LineWidth',2, ...
                'HandleVisibility','off');
        end
    end

    if ~isempty(mg_on_plot)
        histogram(ax3, mg_on_plot, edges, 'Normalization','pdf', ...
            'FaceColor',col_on, 'FaceAlpha',0.35,'EdgeColor','none', ...
            'DisplayName',lbl_on);
        if numel(mg_on_plot) > 1
            [f,xi] = ksdensity(mg_on_plot);
            plot(ax3,xi,f,'-','Color',col_on,'LineWidth',2, ...
                'HandleVisibility','off');
        end
    end

    if ~isempty(mg_post_plot)
        histogram(ax3, mg_post_plot, edges, 'Normalization','pdf', ...
            'FaceColor',col_post,'FaceAlpha',0.35,'EdgeColor','none', ...
            'DisplayName',lbl_post);
        if numel(mg_post_plot) > 1
            [f,xi] = ksdensity(mg_post_plot);
            plot(ax3,xi,f,'-','Color',col_post,'LineWidth',2, ...
                'HandleVisibility','off');
        end
    end
end


ylabel(ax3,'Density','Color','w');
title(ax3,'Amplitude distribution: Pre / ON / Post','Color','w');



legend(ax3,'TextColor','w','Color','k','Location','best');

% ---------- Subplot 4 ----------
ax4 = subplot(2,2,4);
hold(ax4,'on');
set(ax4,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
grid(ax4,'on');
if opt.NormalizeToOn
    xlabel(ax4, 'Amplitude (fraction of ON)', 'Color', 'w');
else
    xlabel(ax4, 'Amplitude (raw)', 'Color', 'w');
end

if ~isempty(mg_pre_plot)
    [f,x] = ecdf(mg_pre_plot);
    plot(ax4,x,f,'-','Color',col_pre,'LineWidth',2,'DisplayName',lbl_pre);
end
if ~isempty(mg_on_plot)
    [f,x] = ecdf(mg_on_plot);
    plot(ax4,x,f,'-','Color',col_on,'LineWidth',2,'DisplayName',lbl_on);
end
if ~isempty(mg_post_plot)
    [f,x] = ecdf(mg_post_plot);
    plot(ax4,x,f,'-','Color',col_post,'LineWidth',2,'DisplayName',lbl_post);
end

xlabel(ax4,'Amplitude','Color','w');
ylabel(ax4,'Cumulative probability','Color','w');
title(ax4,'Cumulative distribution: Pre / ON / Post','Color','w');
legend(ax4,'TextColor','w','Color','k','Location','best');

out.event_table = T;
out.delta       = delta_pre;
out.summary     = summary;
end

% ================================================================
% LOCAL HELPER
% ================================================================
function mask_out = keep_long_runs(mask_in, min_len)
mask_in = logical(mask_in(:));
d = diff([false; mask_in; false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;

mask_out = false(size(mask_in));
for i = 1:numel(starts)
    if (ends(i) - starts(i) + 1) >= min_len
        mask_out(starts(i):ends(i)) = true;
    end
end
end