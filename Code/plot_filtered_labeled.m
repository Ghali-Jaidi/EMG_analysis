function [] = plot_filtered_labeled(channel_1, channel_2, channel_3, t, snrValue)
arguments
    channel_1 (:,1)
    channel_2 (:,1)
    channel_3 (:,1)
    t (:,1)
    snrValue struct
end
spacing = max([range(channel_1), range(channel_2), range(channel_3)]) * 1.5;
off1 = 0;
off2 = spacing;
off3 = 2*spacing;
figure; hold on;

% ---- Highlight REST and ACTIVE regions (per channel, lane height only) ----
rest_idx_TA = snrValue.is_rest;
rest_idx_MG = snrValue.is_rest_MG;
act_idx_TA  = snrValue.is_act;
act_idx_MG  = snrValue.is_act_MG;

lane_half = 0.3 * spacing;

yl_TA  = [off1 - lane_half, off1 + lane_half];
yl_MG  = [off2 - lane_half, off2 + lane_half];

% Draw active first (behind rest)
plot_mask_regions(t, act_idx_TA,  yl_TA,  [1 1 0]);        % yellow for TA active
plot_mask_regions(t, act_idx_MG,  yl_MG,  [1 1 0]);        % yellow for MG active
% Then rest on top
plot_mask_regions(t, rest_idx_TA, yl_TA,  [1 0.85 0.85]);  % light red for TA rest
plot_mask_regions(t, rest_idx_MG, yl_MG,  [0.85 0.85 1]);  % light blue for MG rest

% ---- Plot signals ----
plot(t, channel_1 + off1, 'g', 'LineWidth', 1);
plot(t, channel_2 + off2, 'b', 'LineWidth', 1);
plot(t, channel_3 + off3, 'r', 'LineWidth', 1);

% ---- Threshold lines ----
yline( snrValue.thr_rest    + off1, '--k', 'HandleVisibility', 'off');
yline(-snrValue.thr_rest    + off1, '--k', 'HandleVisibility', 'off');
yline( snrValue.thr_act     + off1, '--r', 'HandleVisibility', 'off');
yline(-snrValue.thr_act     + off1, '--r', 'HandleVisibility', 'off');
yline( snrValue.thr_rest_MG + off2, '--k', 'HandleVisibility', 'off');
yline(-snrValue.thr_rest_MG + off2, '--k', 'HandleVisibility', 'off');
yline( snrValue.thr_act_MG  + off2, '--r', 'HandleVisibility', 'off');
yline(-snrValue.thr_act_MG  + off2, '--r', 'HandleVisibility', 'off');

% ---- Noise baseline patch for MG lane ----
if isfield(snrValue, 't_quiet_MG_start') && isfield(snrValue, 't_quiet_MG_end')
    patch([snrValue.t_quiet_MG_start, snrValue.t_quiet_MG_end, ...
           snrValue.t_quiet_MG_end,   snrValue.t_quiet_MG_start], ...
          [off2 - lane_half, off2 - lane_half, ...
           off2 + lane_half, off2 + lane_half], ...
          [1 0.6 0], 'FaceAlpha', 0.18, 'EdgeColor', [1 0.4 0], ...
          'LineWidth', 1, 'HandleVisibility', 'off');
end

% ---- Noise baseline patch for TA lane ----
if isfield(snrValue, 't_quiet_TA_start') && isfield(snrValue, 't_quiet_TA_end')
    patch([snrValue.t_quiet_TA_start, snrValue.t_quiet_TA_end, ...
           snrValue.t_quiet_TA_end,   snrValue.t_quiet_TA_start], ...
          [off1 - lane_half, off1 - lane_half, ...
           off1 + lane_half, off1 + lane_half], ...
          [1 0.6 0], 'FaceAlpha', 0.18, 'EdgeColor', [1 0.4 0], ...
          'LineWidth', 1, 'HandleVisibility', 'off');
end

% ---- Formatting ----
yticks([off1 off2 off3]);
yticklabels({'Left TA (filtered)', ...
             'Left MG (filtered)', ...
             'Channel 3 (raw)'});
xlabel('Time (s)');
title('Filtered EMG (offset) + Channel 3 (raw)');
grid on; box on;

% ---- Manual legend with dummy handles ----
h1 = patch(NaN, NaN, [1 0.85 0.85], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
h2 = patch(NaN, NaN, [0.85 0.85 1], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
h3 = patch(NaN, NaN, [1 1 0],       'FaceAlpha', 0.4, 'EdgeColor', 'none');
h4 = plot(NaN, NaN, 'g', 'LineWidth', 1);
h5 = plot(NaN, NaN, 'b', 'LineWidth', 1);
h6 = plot(NaN, NaN, 'r', 'LineWidth', 1);
h7 = plot(NaN, NaN, '--k');
h8 = plot(NaN, NaN, '--r');

legend([h1 h2 h3 h4 h5 h6 h7 h8], ...
    {'TA rest regions', 'MG rest regions', 'Active regions', ...
     'Left TA (filtered)', 'Left MG (filtered)', 'Channel 3 (raw)', ...
     'Rest threshold', 'Active threshold'}, ...
    'Location', 'best');
end

function plot_mask_regions(timeVec, mask, ylimits, color)
if isempty(timeVec) || isempty(mask) || all(~mask)
    return
end
mask = logical(mask(:));
t = timeVec(:);
if numel(t) ~= numel(mask)
    error('Time vector and mask must have same length.');
end
d = diff([0; mask; 0]);
starts = find(d == 1);
ends   = find(d == -1) - 1;
holdState = ishold;
hold on;
for k = 1:numel(starts)
    ts = t(starts(k));
    te = t(ends(k));
    xpoly = [ts; te; te; ts];
    ypoly = [ylimits(1); ylimits(1); ylimits(2); ylimits(2)];
    patch('XData', xpoly, 'YData', ypoly, 'FaceColor', color, ...
          'EdgeColor', 'none', 'FaceAlpha', 0.4, 'HandleVisibility', 'off');
end
if ~holdState
    hold off;
end
end