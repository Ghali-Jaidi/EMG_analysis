function [f, psd1_before, psd1_after, psd2_before, psd2_after] = plot_PSD(ry1, filteredRy1, ry2, filteredRy2, fs)

% Compute and plot Welch PSD for two EMG channels (before/after filtering)

arguments
    ry1 (:,1) double
    filteredRy1 (:,1) double
    ry2 (:,1) double
    filteredRy2 (:,1) double
    fs (1,1) double = 10000
end

N = min([numel(ry1), numel(ry2), numel(filteredRy1), numel(filteredRy2)]);

% ---- Welch parameters (kept identical to your script) ----
nfft = 2^nextpow2(min(4096, N));
window = hamming(floor(N/8));
noverlap = floor(0.5 * numel(window));

% ---- PSD computation ----
[psd1_before, f] = pwelch(ry1,          window, noverlap, nfft, fs);
 psd1_after       = pwelch(filteredRy1, window, noverlap, nfft, fs);

[psd2_before, ~] = pwelch(ry2,          window, noverlap, nfft, fs);
 psd2_after       = pwelch(filteredRy2, window, noverlap, nfft, fs);

% Get darker colors for better contrast on white background
colors = get_emg_plot_colors();

% ---- Plot ----
figure;

subplot(2,1,1);
plot(f, 10*log10(psd1_before), 'Color', [0.8 0 0], 'LineWidth', 1.5, 'DisplayName', 'Before filter'); hold on;
plot(f, 10*log10(psd1_after),  'Color', colors.TA, 'LineWidth', 1.5, 'DisplayName', 'After filter');
legend('Left TA Before','Left TA After');
xlabel('Frequency (Hz)');
ylabel('PSD (dB/Hz)');
title(sprintf('Welch PSD - Left TA (fs = %d Hz)', fs));
grid on;

subplot(2,1,2);
plot(f, 10*log10(psd2_before), 'Color', [0.8 0 0], 'LineWidth', 1.5, 'DisplayName', 'Before filter'); hold on;
plot(f, 10*log10(psd2_after),  'Color', colors.MG, 'LineWidth', 1.5, 'DisplayName', 'After filter');
legend('Left MG Before','Left MG After');
xlabel('Frequency (Hz)');
ylabel('PSD (dB/Hz)');
title(sprintf('Welch PSD - Left MG (fs = %d Hz)', fs));
grid on;

end
