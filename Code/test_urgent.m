function fig = test_urgent(fig, rmsw_TA, rmsw_MG, ...
                                      is_act_TA, is_act_MG, ...
                                      fs, max_lag_s)
% plot_TA_MG_correlation
% Adds cross-correlation curve to an existing figure

arguments
    fig (1,1) matlab.ui.Figure
    rmsw_TA (:,1) double
    rmsw_MG (:,1) double
    is_act_TA (:,1) logical
    is_act_MG (:,1) logical
    fs (1,1) double {mustBePositive} = 10000
    max_lag_s (1,1) double {mustBePositive} = 1.0
end

% Activate figure and current axes
figure(fig);
ax = gca;
hold(ax, 'on');

% Weight: 1 during active periods, 0 during rest
weight = double(is_act_TA | is_act_MG);

% Mean-subtract then weight
rmsw_TA_weighted = (rmsw_TA - mean(rmsw_TA)) .* weight;
rmsw_MG_weighted = (rmsw_MG - mean(rmsw_MG)) .* weight;

% Simple correlation (active only)
either_active = logical(weight);
r = corrcoef(rmsw_TA(either_active), rmsw_MG(either_active));
fprintf('TA-MG rmsw correlation (active only): %.3f\n', r(1,2));

% Cross-correlation
[xc, lags] = xcorr(rmsw_TA_weighted, rmsw_MG_weighted, 'normalized');
lags_s     = lags / fs;

mask_lag    = abs(lags_s) <= max_lag_s;
xc_masked   = xc(mask_lag);
lags_masked = lags_s(mask_lag);

% Peak values
[~, idx_min] = min(xc_masked);
[~, idx_max] = max(xc_masked);

% ---- ADD LINE (no new figure) ----
plot(ax, lags_masked, xc_masked, ...
     'Color', [1 0 0], ...
     'LineWidth', 1.5, ...
     'DisplayName', 'Spasm');
% Mark peaks
plot(ax, lags_masked(idx_min), xc_masked(idx_min), 'rv', ...
    'MarkerFaceColor', 'r');

plot(ax, lags_masked(idx_max), xc_masked(idx_max), 'g^', ...
    'MarkerFaceColor', 'g');

% Only add axis labels if empty
if isempty(ax.Title.String)
    xlabel(ax, 'Lag (s)');
    ylabel(ax, 'Cross-correlation');
    title(ax, sprintf('TA-MG cross-correlation (\\pm%.0f ms)', ...
        max_lag_s*1000));
    grid(ax, 'on');
    box(ax, 'on');
end

end