function [] = plot_filtered(channel_1,channel_2, channel_3, t)
%
% This function plots three EMG channels after filtering and vertical offsetting.
% Inputs:
%   channel_1, channel_2, channel_3 - vectors containing time-series signals.
% Behavior:
%   - Designs and applies a bandpass filter (20-450 Hz) and a notch at 50/60 Hz to each input.
%   - Scales and offsets the filtered signals for clear stacked plotting.
%   - Plots the processed channels with distinct colors and labeled y-ticks.
% Note:
%   The inputs must be vectors of equal length. 
arguments 
    channel_1
    channel_2
    channel_3
    t
end

spacing = max([range(channel_1), range(channel_2), range(channel_3)]) * 1.5;
off1 = 0;
off2 = spacing;
off3 = 2*spacing;

figure;
plot(t, channel_1 + off1, 'g', 'LineWidth', 1); hold on;
plot(t, channel_2 + off2, 'b', 'LineWidth', 1);
plot(t, channel_3 + off3, 'r', 'LineWidth', 1);
hold off;

yticks([off1 off2 off3]);
yticklabels({'Left TA','Left MG','Channel 3'});
xlabel('Time (s)');
title('Scaled and offset channels');
grid on;
box on;


end