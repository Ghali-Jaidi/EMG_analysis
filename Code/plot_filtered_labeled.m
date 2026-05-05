function [] = plot_filtered_labeled(channel_1, channel_2, channel_3, t, snrValue, ax)
arguments
    channel_1 (:,1)
    channel_2 (:,1)
    channel_3 (:,1)
    t (:,1)
    snrValue struct
    ax = []
end

if isempty(ax)
    f = figure('Position', [100 100 1400 600]);
    % Create 3 subplots for separate channels with individual scales
    ax = gobjects(3, 1);
    ax(1) = subplot(3, 1, 1, 'Parent', f);
    ax(2) = subplot(3, 1, 2, 'Parent', f);
    ax(3) = subplot(3, 1, 3, 'Parent', f);
end

% If ax is a single axes object, convert to cell array for flexibility
if ~isvector(ax) || isscalar(ax)
    ax_single = ax;
    ax = gobjects(3, 1);
    ax(1) = ax_single;
    ax(2) = ax_single;
    ax(3) = ax_single;
end

cla(ax(1));
cla(ax(2));
cla(ax(3));
hold(ax(1), 'on');
hold(ax(2), 'on');
hold(ax(3), 'on');

% ---- Masks ----
rest_idx_TA = snrValue.is_rest(:);
rest_idx_MG = snrValue.is_rest_MG(:);
act_idx_TA  = snrValue.is_act(:);
act_idx_MG  = snrValue.is_act_MG(:);

% Get colors for better contrast
colors = get_emg_plot_colors();

% ===== SUBPLOT 1: TA Channel =====
cla(ax(1));
hold(ax(1), 'on');

% Get y limits for current subplot
y_min_1 = min(channel_1);
y_max_1 = max(channel_1);

% Highlight active/rest regions with current subplot's y-range
if any(act_idx_TA)
    plot_mask_regions(ax(1), t, act_idx_TA,  [y_min_1 y_max_1], [1 1 0],       'Active regions');
end
if any(rest_idx_TA)
    plot_mask_regions(ax(1), t, rest_idx_TA, [y_min_1 y_max_1], [1 0.85 0.85], 'Rest regions');
end

% Plot signal
plot(ax(1), t, channel_1, 'Color', colors.TA, 'LineWidth', 1.5, 'DisplayName', 'TA (filtered)');

% Threshold lines
yline(ax(1),  snrValue.thr_rest,    '--k', 'DisplayName', sprintf('Rest thr: %.2f', snrValue.thr_rest));
yline(ax(1), -snrValue.thr_rest,    '--k', 'HandleVisibility', 'off');
yline(ax(1),  snrValue.thr_act,     '--r', 'DisplayName', sprintf('Active thr: %.2f', snrValue.thr_act));
yline(ax(1), -snrValue.thr_act,     '--r', 'HandleVisibility', 'off');

xlabel(ax(1), 'Time (s)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel(ax(1), sprintf('Amplitude (mV)\nRange: %.2f', range(channel_1)), 'FontSize', 10, 'FontWeight', 'bold');
title(ax(1), 'Left TA (filtered) - Independent Scale', 'FontSize', 11, 'FontWeight', 'bold');
grid(ax(1), 'on');
legend(ax(1), 'Location', 'best', 'FontSize', 9);
box(ax(1), 'on');
hold(ax(1), 'off');

% ===== SUBPLOT 2: MG Channel =====
cla(ax(2));
hold(ax(2), 'on');

% Get y limits for current subplot
y_min_2 = min(channel_2);
y_max_2 = max(channel_2);

% Highlight active/rest regions with current subplot's y-range
if any(act_idx_MG)
    plot_mask_regions(ax(2), t, act_idx_MG,  [y_min_2 y_max_2], [1 1 0],       'Active regions');
end
if any(rest_idx_MG)
    plot_mask_regions(ax(2), t, rest_idx_MG, [y_min_2 y_max_2], [0.85 0.85 1], 'Rest regions');
end

% Plot signal
plot(ax(2), t, channel_2, 'Color', colors.MG, 'LineWidth', 1.5, 'DisplayName', 'MG (filtered)');

% Threshold lines
yline(ax(2),  snrValue.thr_rest_MG,    '--k', 'DisplayName', sprintf('Rest thr: %.2f', snrValue.thr_rest_MG));
yline(ax(2), -snrValue.thr_rest_MG,    '--k', 'HandleVisibility', 'off');
yline(ax(2),  snrValue.thr_act_MG,     '--r', 'DisplayName', sprintf('Active thr: %.2f', snrValue.thr_act_MG));
yline(ax(2), -snrValue.thr_act_MG,     '--r', 'HandleVisibility', 'off');

xlabel(ax(2), 'Time (s)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel(ax(2), sprintf('Amplitude (mV)\nRange: %.2f', range(channel_2)), 'FontSize', 10, 'FontWeight', 'bold');
title(ax(2), 'Left MG (filtered) - Independent Scale', 'FontSize', 11, 'FontWeight', 'bold');
grid(ax(2), 'on');
legend(ax(2), 'Location', 'best', 'FontSize', 9);
box(ax(2), 'on');
hold(ax(2), 'off');

% ===== SUBPLOT 3: Channel 3 (raw) =====
cla(ax(3));
hold(ax(3), 'on');

% Plot signal
plot(ax(3), t, channel_3, 'Color', colors.Ch3, 'LineWidth', 1.5, 'DisplayName', 'Channel 3 (raw)');

xlabel(ax(3), 'Time (s)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel(ax(3), sprintf('Amplitude (mV)\nRange: %.2f', range(channel_3)), 'FontSize', 10, 'FontWeight', 'bold');
title(ax(3), 'Channel 3 (raw) - Independent Scale', 'FontSize', 11, 'FontWeight', 'bold');
grid(ax(3), 'on');
legend(ax(3), 'Location', 'best', 'FontSize', 9);
box(ax(3), 'on');
hold(ax(3), 'off');
end

function plot_mask_regions(ax, timeVec, mask, ylimits, color, displayName)
if isempty(timeVec) || isempty(mask) || all(~mask)
    return
end

mask = logical(mask(:));
t = timeVec(:);

if numel(t) ~= numel(mask)
    error('Time vector and mask must have same length.');
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
    ypoly = [ylimits(1); ylimits(1); ylimits(2); ylimits(2)];

    if k == 1 && ~isempty(displayName)
        patch(ax, 'XData', xpoly, 'YData', ypoly, ...
            'FaceColor', color, 'EdgeColor', 'none', ...
            'FaceAlpha', 0.4, 'DisplayName', displayName);
    else
        patch(ax, 'XData', xpoly, 'YData', ypoly, ...
            'FaceColor', color, 'EdgeColor', 'none', ...
            'FaceAlpha', 0.4, 'HandleVisibility', 'off');
    end
end

if ~holdState
    hold(ax, 'off');
end
end