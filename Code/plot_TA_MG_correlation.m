function fig = plot_TA_MG_correlation(rmsw_TA, rmsw_MG, is_act_TA, is_act_MG, fs, max_lag_s)
% plot_TA_MG_correlation - Plots cross-correlation and simple correlation
%                          between TA and MG windowed RMS signals,
%                          weighted by active periods only
%
% Inputs:
%   rmsw_TA   : windowed RMS of TA signal
%   rmsw_MG   : windowed RMS of MG signal
%   is_act_TA : logical mask of TA active periods
%   is_act_MG : logical mask of MG active periods
%   fs        : sampling frequency
%   max_lag_s : maximum lag in seconds to display (default 1.0)

arguments
    rmsw_TA (:,1) double
    rmsw_MG (:,1) double
    is_act_TA (:,1) logical
    is_act_MG (:,1) logical
    fs (1,1) double {mustBePositive} = 10000
    max_lag_s (1,1) double {mustBePositive} = 1.0
end

% Weight: 1 during active periods, 0 during rest
weight = double(is_act_TA | is_act_MG);

% Mean-subtract then weight to preserve time structure
rmsw_TA_weighted = (rmsw_TA - mean(rmsw_TA)) .* weight;
rmsw_MG_weighted = (rmsw_MG - mean(rmsw_MG)) .* weight;

% Simple correlation on active periods only
either_active = logical(weight);
r = corrcoef(rmsw_TA(either_active), rmsw_MG(either_active));
fprintf('TA-MG rmsw correlation (active only): %.3f\n', r(1,2));

% Cross-correlation with time structure preserved
[xc, lags]  = xcorr(rmsw_TA_weighted, rmsw_MG_weighted, 'normalized');
lags_s      = lags / fs;
mask_lag    = abs(lags_s) <= max_lag_s;
xc_masked   = xc(mask_lag);
lags_masked = lags_s(mask_lag);

% Peak negative and positive lags
[~, idx_min] = min(xc_masked);
[~, idx_max] = max(xc_masked);

figure;
plot(lags_masked, xc_masked, 'w', 'LineWidth', 1.5);
hold on;
plot(lags_masked(idx_min), xc_masked(idx_min), 'rv', 'MarkerFaceColor', 'r', ...
    'DisplayName', sprintf('Min: %.3f at %.0f ms', xc_masked(idx_min), lags_masked(idx_min)*1000));
plot(lags_masked(idx_max), xc_masked(idx_max), 'g^', 'MarkerFaceColor', 'g', ...
    'DisplayName', sprintf('Max: %.3f at %.0f ms', xc_masked(idx_max), lags_masked(idx_max)*1000));
xline(0, '--k', 'Zero lag', 'HandleVisibility', 'off');
xlabel('Lag (s)');
ylabel('Cross-correlation');
title(sprintf('TA-MG cross-correlation (\\pm%.0f ms, active periods only)', max_lag_s*1000));
grid on; box on;
legend('Location', 'best');

fig = gcf;

end