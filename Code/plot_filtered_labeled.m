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
    f = figure;
    ax = axes('Parent', f);
end

cla(ax);
hold(ax, 'on');

spacing = max([range(channel_1), range(channel_2), range(channel_3)]) * 1.5;
if spacing == 0 || ~isfinite(spacing)
    spacing = 1;
end

off1 = 0;
off2 = spacing;
off3 = 2 * spacing;

% ---- Masks ----
rest_idx_TA = snrValue.is_rest(:);
rest_idx_MG = snrValue.is_rest_MG(:);
act_idx_TA  = snrValue.is_act(:);
act_idx_MG  = snrValue.is_act_MG(:);

lane_half = 0.3 * spacing;
yl_TA = [off1 - lane_half, off1 + lane_half];
yl_MG = [off2 - lane_half, off2 + lane_half];

% ---- Highlight regions (first visible handle only for legend) ----
plot_mask_regions(ax, t, act_idx_TA,  yl_TA, [1 1 0],       'Active regions');
plot_mask_regions(ax, t, act_idx_MG,  yl_MG, [1 1 0],       '');
plot_mask_regions(ax, t, rest_idx_TA, yl_TA, [1 0.85 0.85], 'TA rest regions');
plot_mask_regions(ax, t, rest_idx_MG, yl_MG, [0.85 0.85 1], 'MG rest regions');

% ---- Plot signals ----
plot(ax, t, channel_1 + off1, 'g', 'LineWidth', 1, 'DisplayName', 'Left TA (filtered)');
plot(ax, t, channel_2 + off2, 'b', 'LineWidth', 1, 'DisplayName', 'Left MG (filtered)');
plot(ax, t, channel_3 + off3, 'r', 'LineWidth', 1, 'DisplayName', 'Channel 3 (raw)');

% ---- Threshold lines ----
yline(ax,  snrValue.thr_rest    + off1, '--k', 'DisplayName', 'Rest threshold');
yline(ax, -snrValue.thr_rest    + off1, '--k', 'HandleVisibility', 'off');
yline(ax,  snrValue.thr_act     + off1, '--r', 'DisplayName', 'Active threshold');
yline(ax, -snrValue.thr_act     + off1, '--r', 'HandleVisibility', 'off');

yline(ax,  snrValue.thr_rest_MG + off2, '--k', 'HandleVisibility', 'off');
yline(ax, -snrValue.thr_rest_MG + off2, '--k', 'HandleVisibility', 'off');
yline(ax,  snrValue.thr_act_MG  + off2, '--r', 'HandleVisibility', 'off');
yline(ax, -snrValue.thr_act_MG  + off2, '--r', 'HandleVisibility', 'off');

% ---- Noise baseline patch for MG lane ----
if isfield(snrValue, 't_quiet_MG_start') && isfield(snrValue, 't_quiet_MG_end') ...
        && ~isempty(snrValue.t_quiet_MG_start) && ~isempty(snrValue.t_quiet_MG_end)
    patch(ax, ...
        [snrValue.t_quiet_MG_start, snrValue.t_quiet_MG_end, ...
         snrValue.t_quiet_MG_end,   snrValue.t_quiet_MG_start], ...
        [off2 - lane_half, off2 - lane_half, off2 + lane_half, off2 + lane_half], ...
        [1 0.6 0], ...
        'FaceAlpha', 0.18, 'EdgeColor', [1 0.4 0], 'LineWidth', 1, ...
        'HandleVisibility', 'off');
end

% ---- Noise baseline patch for TA lane ----
if isfield(snrValue, 't_quiet_TA_start') && isfield(snrValue, 't_quiet_TA_end') ...
        && ~isempty(snrValue.t_quiet_TA_start) && ~isempty(snrValue.t_quiet_TA_end)
    patch(ax, ...
        [snrValue.t_quiet_TA_start, snrValue.t_quiet_TA_end, ...
         snrValue.t_quiet_TA_end,   snrValue.t_quiet_TA_start], ...
        [off1 - lane_half, off1 - lane_half, off1 + lane_half, off1 + lane_half], ...
        [1 0.6 0], ...
        'FaceAlpha', 0.18, 'EdgeColor', [1 0.4 0], 'LineWidth', 1, ...
        'HandleVisibility', 'off');
end

% ---- Formatting ----
yticks(ax, [off1 off2 off3]);
yticklabels(ax, {'Left TA (filtered)', 'Left MG (filtered)', 'Channel 3 (raw)'});
xlabel(ax, 'Time (s)');
ylabel(ax, 'Amplitude + offset');
title(ax, 'Filtered EMG (offset) + Channel 3 (raw)');
grid(ax, 'on');
box(ax, 'on');

% ---- Clean and rebuild legend from visible objects only ----
lgd = legend(ax);
if ~isempty(lgd) && isvalid(lgd)
    delete(lgd);
end
legend(ax, 'show', 'Location', 'best');

hold(ax, 'off');
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