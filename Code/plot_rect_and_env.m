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

figure;
% --- Subplot 1: Rectified signals (scaled individually) + Channel 3 ---

subplot(2,1,1);

% Robust amplitude ranges (avoid spikes dominating)
r1 = prctile(rectRy1, 99) - prctile(rectRy1, 1);
r2 = prctile(rectRy2, 99) - prctile(rectRy2, 1);

% Target visual height (use same logic as envelope plot)
targetHeight = 0.6 * spacing;

% Per-channel scale factors
s1 = targetHeight / max(r1, eps);
s2 = targetHeight / max(r2, eps);

rect1s = s1 * rectRy1;
rect2s = s2 * rectRy2;

% Spacing exactly like envelope logic
rectSpacing = 1.5 * max([range(rect1s), range(rect2s), range(ch3)]);

off1 = 0;
off2 = rectSpacing;
off3 = 2*rectSpacing;

plot(t, rect1s + off1, 'g', 'LineWidth', 0.5); hold on;
plot(t, rect2s + off2, 'b', 'LineWidth', 0.5);
plot(t, ch3    + off3, 'r', 'LineWidth', 1);
hold off;

yticks([off1 off2 off3]);
yticklabels({sprintf('Left TA (rect x%.2g)', s1), ...
             sprintf('Left MG (rect x%.2g)', s2), ...
             'Channel 3 (raw)'});
xlabel('Time (s)');
title('Rectified EMG (scaled + offset)');
legend(sprintf('TA rect (x%.2g)', s1), sprintf('MG rect (x%.2g)', s2), 'Channel 3');
grid on; box on;

% --- Subplot 2: Envelopes (separately scaled + offset) + Channel 3 (raw) ---
subplot(2,1,2);



% Robust amplitude ranges (avoid a few spikes dominating)
r1 = prctile(env1, 99) - prctile(env1, 1);
r2 = prctile(env2, 99) - prctile(env2, 1);

% Target visual height for each envelope trace (relative to original spacing)
targetHeight = 0.6 * spacing;

% Per-channel scale factors
s1 = targetHeight / max(r1, eps);
s2 = targetHeight / max(r2, eps);

env1s = s1 * env1;
env2s = s2 * env2;

% Envelope-specific spacing so they don't overlap
envSpacing = 1.5 * max([range(env1s), range(env2s), range(ch3)]);
envOff1 = 0;
envOff2 = envSpacing;
envOff3 = 2*envSpacing;

plot(t, env1s + envOff1, 'g', 'LineWidth', 1.5); hold on;
plot(t, env2s + envOff2, 'b', 'LineWidth', 1.5);
plot(t, ch3   + envOff3, 'r', 'LineWidth', 1);   % channel 3 raw
hold off;

yticks([envOff1 envOff2 envOff3]);
yticklabels({sprintf('Left TA (env x%.2g)', s1), ...
             sprintf('Left MG (env x%.2g)', s2), ...
             'Channel 3 (raw)'});
xlabel('Time (s)');
title(sprintf('Envelopes (scaled+offset) + Channel 3 (raw), window = %d ms', envWindowMs));
legend(sprintf('TA envelope (x%.2g)', s1), sprintf('MG envelope (x%.2g)', s2), 'Channel 3');
grid on; box on;

end
