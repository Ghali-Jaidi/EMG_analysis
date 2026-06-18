function plot_frequency_spectrum(x, fs, interval_sec)
% plot_frequency_spectrum
% Plot amplitude spectrum of a signal over a chosen time interval.
%
% INPUTS:
%   x            : signal vector
%   fs           : sampling frequency (Hz)
%   interval_sec : [t_start  t_end] in seconds
%
% Example:
%   plot_frequency_spectrum(emg, 10000, [35 37])

% ---- checks ----
if numel(interval_sec) ~= 2
    error('interval_sec must be [t_start t_end]');
end

t_start = interval_sec(1);
t_end   = interval_sec(2);

if t_end <= t_start
    error('t_end must be greater than t_start');
end

x = x(:); % ensure column vector

% ---- convert seconds -> samples ----
start_idx = round(t_start * fs) + 1;
end_idx   = round(t_end   * fs);

if start_idx < 1 || end_idx > length(x)
    error('Interval exceeds signal bounds.');
end

segment = x(start_idx:end_idx);

% ---- remove DC ----
segment = segment - mean(segment);

N = length(segment);

% ---- apply Hann window ----
w = hann(N);
segment = segment .* w;

% ---- FFT ----
X = fft(segment);

% ---- one-sided amplitude spectrum ----
P2 = abs(X) / N;
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2 * P1(2:end-1);

% ---- frequency axis ----
f = fs*(0:floor(N/2))/N;

% ---- plot ----
figure;
plot(f, P1, 'LineWidth', 1.2);
xlabel('Frequency (Hz)');
ylabel('Amplitude');
title(sprintf('Amplitude Spectrum (%.2f–%.2f s)', t_start, t_end));
grid on;
xlim([0 fs/2]);

end