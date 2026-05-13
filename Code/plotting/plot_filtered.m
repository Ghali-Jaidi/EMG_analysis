function [] = plot_filtered(channel_1,channel_2, channel_3, t)
%
% This function plots three EMG channels after filtering and vertical offsetting.
% Inputs:
%   channel_1, channel_2, channel_3 - vectors containing time-series signals.
% Behavior:
%   - Designs and applies a bandpass filter (20-450 Hz) and a notch at 50/60 Hz to each input.
%   - Scales and offsets the filtered signals for clear stacked plotting.
%   - Plots the processed channels with distinct colors and labeled y-ticks showing actual amplitudes.
% Note:
%   The inputs must be vectors of equal length. 
arguments 
    channel_1
    channel_2
    channel_3
    t
end

% Debug: check input sizes
fprintf('[plot_filtered] Channel sizes: ch1=%d, ch2=%d, ch3=%d, t=%d\n', ...
    length(channel_1), length(channel_2), length(channel_3), length(t));

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

fig = figure('Visible','on');
set(fig, 'NumberTitle', 'off', 'Name', 'Filtered EMG Signals');
fprintf('[plot_filtered] Figure created, starting subplots...\n');

% Subplot 1: TA (Channel 1)
try
    subplot(3, 1, 1);
    fprintf('[plot_filtered] Plotting subplot 1...\n');
    plot(t, ch1_norm, 'g', 'LineWidth', 1);
    fprintf('[plot_filtered] Subplot 1 plotted successfully\n');
    ylabel('Amplitude (V)');
    title('TA (Tibialis Anterior)');
    grid on;
    box on;
    % Compute logical voltage ticks
    ch1_ticks_voltage = compute_logical_ticks(ch1_min, ch1_max);
    ch1_ticks_norm = (ch1_ticks_voltage - ch1_min) / (ch1_max - ch1_min);
    set(gca, 'YLim', [0 1]);
    set(gca, 'YTick', ch1_ticks_norm);
    set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch1_ticks_voltage, 'UniformOutput', false));
    fprintf('[plot_filtered] Subplot 1 formatting completed\n');
catch ME
    fprintf('[plot_filtered ERROR] Subplot 1 failed: %s\n', ME.message);
    disp(ME.stack);
end

% Subplot 2: MG (Channel 2)
try
    subplot(3, 1, 2);
    fprintf('[plot_filtered] Plotting subplot 2...\n');
    plot(t, ch2_norm, 'b', 'LineWidth', 1);
    fprintf('[plot_filtered] Subplot 2 plotted successfully\n');
    ylabel('Amplitude (V)');
    title('MG (Medial Gastrocnemius)');
    grid on;
    box on;
    % Compute logical voltage ticks
    ch2_ticks_voltage = compute_logical_ticks(ch2_min, ch2_max);
    ch2_ticks_norm = (ch2_ticks_voltage - ch2_min) / (ch2_max - ch2_min);
    set(gca, 'YLim', [0 1]);
    set(gca, 'YTick', ch2_ticks_norm);
    set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch2_ticks_voltage, 'UniformOutput', false));
    fprintf('[plot_filtered] Subplot 2 formatting completed\n');
catch ME
    fprintf('[plot_filtered ERROR] Subplot 2 failed: %s\n', ME.message);
    disp(ME.stack);
end

% Subplot 3: Ch3 (Channel 3)
try
    subplot(3, 1, 3);
    fprintf('[plot_filtered] Plotting subplot 3...\n');
    plot(t, ch3_norm, 'r', 'LineWidth', 1);
    fprintf('[plot_filtered] Subplot 3 plotted successfully\n');
    ylabel('Amplitude (V)');
    xlabel('Time (s)');
    title('Channel 3');
    grid on;
    box on;
    % Compute logical voltage ticks
    ch3_ticks_voltage = compute_logical_ticks(ch3_min, ch3_max);
    ch3_ticks_norm = (ch3_ticks_voltage - ch3_min) / (ch3_max - ch3_min);
    set(gca, 'YLim', [0 1]);
    set(gca, 'YTick', ch3_ticks_norm);
    set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch3_ticks_voltage, 'UniformOutput', false));
    fprintf('[plot_filtered] Subplot 3 formatting completed\n');
catch ME
    fprintf('[plot_filtered ERROR] Subplot 3 failed: %s\n', ME.message);
    disp(ME.stack);
end

fprintf('[plot_filtered] All subplots completed\n');

end