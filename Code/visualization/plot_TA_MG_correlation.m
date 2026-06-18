function fig = plot_TA_MG_correlation(rmsw_TA, rmsw_MG, is_act_TA, is_act_MG, fs, max_lag_s, options)
arguments
    rmsw_TA (:,1) double
    rmsw_MG (:,1) double
    is_act_TA (:,1) logical
    is_act_MG (:,1) logical
    fs (1,1) double {mustBePositive} = 10000
    max_lag_s (1,1) double {mustBePositive} = 1.0
    options.Axes = []
    options.Color = 'w'
    options.Label (1,:) char = ''
    options.IntervalMask (:,1) logical = true(size(rmsw_TA))
    options.Mode (1,:) char {mustBeMember(options.Mode,{'uninjured','spastic'})} = 'uninjured'
    options.ShowPeaks (1,1) logical = true
    options.ShowZeroLag (1,1) logical = true
end

assert(numel(rmsw_TA)==numel(rmsw_MG));
assert(numel(rmsw_TA)==numel(options.IntervalMask));

% ---- SELECT SAMPLES USED FOR CORRELATION ----
switch lower(options.Mode)
    case 'uninjured'
        % Use active-only (either TA or MG active), whole recording
        use_mask = (is_act_TA | is_act_MG);
    case 'spastic'
        % Use only the user-provided spasm intervals (ignore activity masks)
        use_mask = options.IntervalMask;
end

if nnz(use_mask) < 10
    warning('Too few samples selected for correlation.');
end

% Weight: 1 on selected samples, 0 elsewhere
weight = double(use_mask);

% Masked mean
muTA = sum(rmsw_TA(use_mask)) / max(1, nnz(use_mask));
muMG = sum(rmsw_MG(use_mask)) / max(1, nnz(use_mask));

rmsw_TA_weighted = (rmsw_TA - muTA) .* weight;
rmsw_MG_weighted = (rmsw_MG - muMG) .* weight;

% Simple correlation on selected samples
if nnz(use_mask) >= 2
    r = corrcoef(rmsw_TA(use_mask), rmsw_MG(use_mask));
    fprintf('TA-MG correlation (%s): %.3f\n', lower(options.Mode), r(1,2));
end

% Cross-correlation
[xc, lags] = xcorr(rmsw_TA_weighted, rmsw_MG_weighted, 'normalized');
lags_s = lags / fs;

keep = abs(lags_s) <= max_lag_s;
xc_masked   = xc(keep);
lags_masked = lags_s(keep);

% Peaks
[~, idx_min] = min(xc_masked);
[~, idx_max] = max(xc_masked);

% Plot target
if isempty(options.Axes) || ~isvalid(options.Axes)
    fig = figure; ax = axes(fig);
else
    ax = options.Axes; fig = ancestor(ax,'figure');
end
hold(ax,'on');

h = plot(ax, lags_masked, xc_masked, 'LineWidth', 1.5);
set(h,'Color',options.Color);
if ~isempty(options.Label), set(h,'DisplayName',options.Label); end

if options.ShowPeaks
    plot(ax, lags_masked(idx_min), xc_masked(idx_min), 'rv', 'MarkerFaceColor','r', 'HandleVisibility','off');
    plot(ax, lags_masked(idx_max), xc_masked(idx_max), 'g^', 'MarkerFaceColor','g', 'HandleVisibility','off');
end
if options.ShowZeroLag
    xline(ax, 0, '--k', 'HandleVisibility','off');
end

if isempty(ax.Title.String)
    xlabel(ax,'Lag (s)'); ylabel(ax,'Cross-correlation');
    title(ax, sprintf('TA-MG cross-correlation (\\pm%.0f ms)', max_lag_s*1000));
    grid(ax,'on'); box(ax,'on');
end
end