function [f, psd1_before, psd1_after, psd2_before, psd2_after] = plot_PSD(ry1, filteredRy1, ry2, filteredRy2, fs)

% Compute and plot Welch PSD for two EMG channels (before/after filtering)

arguments
    ry1 (:,1) double
    filteredRy1 (:,1) double
    ry2 (:,1) double
    filteredRy2 (:,1) double
    fs (1,1) double = 10000
end

fprintf('[plot_PSD] Starting - sizes: ry1=%d, filteredRy1=%d, ry2=%d, filteredRy2=%d, fs=%d\n', ...
    length(ry1), length(filteredRy1), length(ry2), length(filteredRy2), fs);

N = min([numel(ry1), numel(ry2), numel(filteredRy1), numel(filteredRy2)]);

% ---- Welch parameters (kept identical to your script) ----
nfft = 2^nextpow2(min(4096, N));
window = hamming(floor(N/8));
noverlap = floor(0.5 * numel(window));

% ---- PSD computation ----
fprintf('[plot_PSD] Computing PSD...\n');
[psd1_before, f] = pwelch(ry1,          window, noverlap, nfft, fs);
 psd1_after       = pwelch(filteredRy1, window, noverlap, nfft, fs);

[psd2_before, ~] = pwelch(ry2,          window, noverlap, nfft, fs);
 psd2_after       = pwelch(filteredRy2, window, noverlap, nfft, fs);

fprintf('[plot_PSD] PSD computed successfully\n');

% ---- Plot ----
fig = figure('Visible','on');
set(fig, 'NumberTitle', 'off', 'Name', 'Power Spectral Density');
fprintf('[plot_PSD] Figure created, plotting subplots...\n');

try
    subplot(2,1,1);
    fprintf('[plot_PSD] Plotting subplot 1...\n');
    plot(f, 10*log10(psd1_before), 'r', ...
         f, 10*log10(psd1_after),  'b', 'LineWidth', 1);
    legend('Left TA Before','Left TA After');
    xlabel('Frequency (Hz)');
    ylabel('PSD (dB/Hz)');
    title(sprintf('Welch PSD - Left TA (fs = %d Hz)', fs));
    grid on;
    fprintf('[plot_PSD] Subplot 1 completed\n');
catch ME
    fprintf('[plot_PSD ERROR] Subplot 1 failed: %s\n', ME.message);
    disp(ME.stack);
end

try
    subplot(2,1,2);
    fprintf('[plot_PSD] Plotting subplot 2...\n');
    plot(f, 10*log10(psd2_before), 'r', ...
         f, 10*log10(psd2_after),  'b', 'LineWidth', 1);
    legend('Left MG Before','Left MG After');
    xlabel('Frequency (Hz)');
    ylabel('PSD (dB/Hz)');
    title(sprintf('Welch PSD - Left MG (fs = %d Hz)', fs));
    grid on;
    fprintf('[plot_PSD] Subplot 2 completed\n');
catch ME
    fprintf('[plot_PSD ERROR] Subplot 2 failed: %s\n', ME.message);
    disp(ME.stack);
end

fprintf('[plot_PSD] All subplots completed\n');

end
