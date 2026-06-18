function [s1, s2, envOff1, envOff2, envOff3] = plot_rect_and_env(t, rectRy1, rectRy2, env1, env2, ch3, spacing, envWindowMs)
% plot_rect_and_env
% Plots (1) rectified EMG + channel 3, and (2) envelopes with per-channel scaling + offsets.
%
% Inputs:
%   t          : time vector (seconds), Nx1 or 1xN
%   rectRy1    : rectified TA (Nx1)
%   rectRy2    : rectified MG (Nx1)
%   env1       : envelope TA (Nx1)
%   env2       : envelope MG (Nx1)
%   ch3        : channel 3 raw (Nx1)
%   spacing    : baseline spacing used in main plots (scalar)
%   envWindowMs: envelope window size in ms (for title)
%
% Outputs (useful for debugging/logging):
%   s1, s2     : per-channel envelope scale factors
%   envOff1..3 : offsets used in the envelope subplot

arguments
    t (:,1) double
    rectRy1 (:,1) double
    rectRy2 (:,1) double
    env1 (:,1) double
    env2 (:,1) double
    ch3 (:,1) double
    spacing (1,1) double
    envWindowMs (1,1) double
end

% --- Compute offsets for rectified subplot (match your existing style) ---

% Normalization for display clarity: scale each signal to fill its space
% Maximum value of each signal spans full height, preserving relative amplitudes
% This is for visualization only and does not affect actual data values
rectRy1_norm = normalize_signal_for_display(rectRy1);
rectRy2_norm = normalize_signal_for_display(rectRy2);
ch3_norm = normalize_signal_for_display(ch3);
env1_norm = normalize_signal_for_display(env1);
env2_norm = normalize_signal_for_display(env2);

% Get actual min/max values for label display
rectRy1_min = min(rectRy1(~isnan(rectRy1)));
rectRy1_max = max(rectRy1(~isnan(rectRy1)));
rectRy2_min = min(rectRy2(~isnan(rectRy2)));
rectRy2_max = max(rectRy2(~isnan(rectRy2)));
ch3_min = min(ch3(~isnan(ch3)));
ch3_max = max(ch3(~isnan(ch3)));
env1_min = min(env1(~isnan(env1)));
env1_max = max(env1(~isnan(env1)));
env2_min = min(env2(~isnan(env2)));
env2_max = max(env2(~isnan(env2)));

figure;

% --- Subplot 1: Rectified TA ---
subplot(3, 2, 1);
plot(t, rectRy1_norm, 'g', 'LineWidth', 0.5);
ylabel('Amplitude (V)');
title('TA Rectified');
grid on; box on;
rectRy1_ticks_voltage = compute_logical_ticks(rectRy1_min, rectRy1_max);
rectRy1_ticks_norm = (rectRy1_ticks_voltage - rectRy1_min) / (rectRy1_max - rectRy1_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', rectRy1_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), rectRy1_ticks_voltage, 'UniformOutput', false));

% --- Subplot 2: Rectified MG ---
subplot(3, 2, 2);
plot(t, rectRy2_norm, 'b', 'LineWidth', 0.5);
ylabel('Amplitude (V)');
title('MG Rectified');
grid on; box on;
rectRy2_ticks_voltage = compute_logical_ticks(rectRy2_min, rectRy2_max);
rectRy2_ticks_norm = (rectRy2_ticks_voltage - rectRy2_min) / (rectRy2_max - rectRy2_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', rectRy2_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), rectRy2_ticks_voltage, 'UniformOutput', false));

% --- Subplot 3: Envelope TA ---
subplot(3, 2, 3);
plot(t, env1_norm, 'g', 'LineWidth', 1.5);
ylabel('Amplitude (V)');
title(sprintf('TA Envelope (%d ms)', envWindowMs));
grid on; box on;
env1_ticks_voltage = compute_logical_ticks(env1_min, env1_max);
env1_ticks_norm = (env1_ticks_voltage - env1_min) / (env1_max - env1_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', env1_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), env1_ticks_voltage, 'UniformOutput', false));

% --- Subplot 4: Envelope MG ---
subplot(3, 2, 4);
plot(t, env2_norm, 'b', 'LineWidth', 1.5);
ylabel('Amplitude (V)');
title(sprintf('MG Envelope (%d ms)', envWindowMs));
grid on; box on;
env2_ticks_voltage = compute_logical_ticks(env2_min, env2_max);
env2_ticks_norm = (env2_ticks_voltage - env2_min) / (env2_max - env2_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', env2_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), env2_ticks_voltage, 'UniformOutput', false));

% --- Subplot 5: Channel 3 (bottom, spans both columns) ---
subplot(3, 1, 3);
plot(t, ch3_norm, 'r', 'LineWidth', 1);
ylabel('Amplitude (V)');
xlabel('Time (s)');
title('Channel 3');
grid on; box on;
ch3_ticks_voltage = compute_logical_ticks(ch3_min, ch3_max);
ch3_ticks_norm = (ch3_ticks_voltage - ch3_min) / (ch3_max - ch3_min);
set(gca, 'YLim', [0 1]);
set(gca, 'YTick', ch3_ticks_norm);
set(gca, 'YTickLabel', arrayfun(@(x) sprintf('%.3f', x), ch3_ticks_voltage, 'UniformOutput', false));

% Return values (for compatibility with function signature)
s1 = 1;
s2 = 1;
envOff1 = 0;
envOff2 = 1.5;
envOff3 = 3;

end
