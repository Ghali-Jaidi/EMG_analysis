function [] = plot_filtered_labeled(channel_1, channel_2, channel_3, t, snrValue, ax)
arguments
    channel_1 (:,1)
    channel_2 (:,1)
    channel_3 (:,1)
    t (:,1)
    snrValue struct
    ax = []  % This argument is kept for compatibility but not used
end

if ~isempty(ax) && isvalid(ax)
    % Clear the provided axes
    cla(ax);
else
    % Create new figure with 3 subplots
    figure;
end

% Normalization for display clarity: scale each signal to fill its space
% Maximum value of each signal spans full height, preserving relative amplitudes
% This is for visualization only and does not affect actual data values
ch1_norm = normalize_signal_for_display(channel_1);
ch2_norm = normalize_signal_for_display(channel_2);
ch3_norm = normalize_signal_for_display(channel_3);

% Get actual min/max values for label display
ch1_min = min(channel_1(~isnan(channel_1)));
ch1_max = max(channel_1(~isnan(channel_1)));
ch2_min = min(channel_2(~isnan(channel_2)));
ch2_max = max(channel_2(~isnan(channel_2)));
ch3_min = min(channel_3(~isnan(channel_3)));
ch3_max = max(channel_3(~isnan(channel_3)));

% ---- Masks ----
rest_idx_TA = snrValue.is_rest(:);
rest_idx_MG = snrValue.is_rest_MG(:);
act_idx_TA  = snrValue.is_act(:);
act_idx_MG  = snrValue.is_act_MG(:);

% ---- Subplot 1: TA with activity masks ----
subplot(3, 1, 1); hold on;
% Highlight active/rest regions
plot_mask_regions_normalized(gca, t, act_idx_TA, [1 1 0], 'Active');
plot_mask_regions_normalized(gca, t, rest_idx_TA, [1 0.85 0.85], 'Rest');
% Plot signal
plot(t, ch1_norm, 'g', 'LineWidth', 1, 'DisplayName', 'TA (filtered)');
% Threshold lines
ch1_thr_norm_rest = (snrValue.thr_rest - ch1_min) / (ch1_max - ch1_min);
ch1_thr_norm_act = (snrValue.thr_act - ch1_min) / (ch1_max - ch1_min);
yline(ch1_thr_norm_rest, '--k', 'LineWidth', 1.5, 'DisplayName', 'Rest threshold');
yline(ch1_thr_norm_act, '--r', 'LineWidth', 1.5, 'DisplayName', 'Active threshold');
ylabel('Amplitude (V)');
title('TA (Tibialis Anterior)');
grid on; box on;
ch1_ticks_voltage = compute_logical_ticks(ch1_min, ch1_max);
ch1_ticks_norm = (ch1_ticks_voltage - ch1_min) / (ch1_max - ch1_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', ch1_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch1_ticks_voltage, 'UniformOutput', false));
legend('Location', 'best');
hold off;

% ---- Subplot 2: MG with activity masks ----
subplot(3, 1, 2); hold on;
% Highlight active/rest regions
plot_mask_regions_normalized(gca, t, act_idx_MG, [1 1 0], 'Active');
plot_mask_regions_normalized(gca, t, rest_idx_MG, [0.85 0.85 1], 'Rest');
% Plot signal
plot(t, ch2_norm, 'b', 'LineWidth', 1, 'DisplayName', 'MG (filtered)');
% Threshold lines
ch2_thr_norm_rest = (snrValue.thr_rest_MG - ch2_min) / (ch2_max - ch2_min);
ch2_thr_norm_act = (snrValue.thr_act_MG - ch2_min) / (ch2_max - ch2_min);
yline(ch2_thr_norm_rest, '--k', 'LineWidth', 1.5, 'DisplayName', 'Rest threshold');
yline(ch2_thr_norm_act, '--r', 'LineWidth', 1.5, 'DisplayName', 'Active threshold');
ylabel('Amplitude (V)');
title('MG (Medial Gastrocnemius)');
grid on; box on;
ch2_ticks_voltage = compute_logical_ticks(ch2_min, ch2_max);
ch2_ticks_norm = (ch2_ticks_voltage - ch2_min) / (ch2_max - ch2_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', ch2_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch2_ticks_voltage, 'UniformOutput', false));
legend('Location', 'best');
hold off;

% ---- Subplot 3: Channel 3 (raw) ----
subplot(3, 1, 3);
plot(t, ch3_norm, 'r', 'LineWidth', 1, 'DisplayName', 'Channel 3 (raw)');
ylabel('Amplitude (V)');
xlabel('Time (s)');
title('Channel 3');
grid on; box on;
ch3_ticks_voltage = compute_logical_ticks(ch3_min, ch3_max);
ch3_ticks_norm = (ch3_ticks_voltage - ch3_min) / (ch3_max - ch3_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', ch3_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch3_ticks_voltage, 'UniformOutput', false));
legend('Location', 'best');

end

function plot_mask_regions_normalized(ax, timeVec, mask, color, displayName)
% Plot activity/rest regions as patches for normalized signals (0-1 range)

if isempty(timeVec) || isempty(mask) || all(~mask)
    return
end

mask = logical(mask(:));
t = timeVec(:);

if numel(t) ~= numel(mask)
    return
end

d = diff([false; mask; false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;

holdState = ishold(ax);
hold(ax, 'on');

for k = 1:numel(starts)
    ts = t(starts(k));
    te = t(ends(k));

    xpoly = [ts; te; te; ts];
    ypoly = [0; 0; 1; 1];

    if k == 1 && ~isempty(displayName)
        patch(ax, 'XData', xpoly, 'YData', ypoly, ...
            'FaceColor', color, 'EdgeColor', 'none', ...
            'FaceAlpha', 0.3, 'DisplayName', displayName);
    else
        patch(ax, 'XData', xpoly, 'YData', ypoly, ...
            'FaceColor', color, 'EdgeColor', 'none', ...
            'FaceAlpha', 0.3, 'HandleVisibility', 'off');
    end
end

if ~holdState
    hold(ax, 'off');
end
end