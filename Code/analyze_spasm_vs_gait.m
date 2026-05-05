%% ================================================================
%  SPASM vs GAIT: Comprehensive Amplitude and Frequency Analysis
%  
%  Validates separation between:
%  - Healthy gait (validated uninjured recordings)
%  - Pathological spasms (OP70-F4 Record 4, 2 known events)
%  
%  Analysis on BOTH channels with detailed visualizations
%% ================================================================

clear; clc; close all;

fs = 10000;
uninjured_dir = '/Users/ghalijaidi/Desktop/LSBI/EMG_analysis/Data/Uninjured ';
injured_dir = '/Users/ghalijaidi/Desktop/LSBI/EMG_analysis/Data/Injured';

% Validated uninjured recordings (user-specified)
uninjured_specs = {
    'OP89 F1 14-Jan-2026.mat';
    'OP81 F3 20-Nov-2025.mat';
    'OP81 F3 19-Nov-2025-2.mat';
    'OP81 F2 03-Nov-2025.mat'
};

% Initialize storage for both channels
gait_data = struct();
gait_data.chan1.envelopes = [];
gait_data.chan1.filtered = [];
gait_data.chan1.rms = [];
gait_data.chan2.envelopes = [];
gait_data.chan2.filtered = [];
gait_data.chan2.rms = [];

%% STEP 1: Load and process uninjured gait recordings
fprintf('=== STEP 1: LOADING UNINJURED GAIT DATA ===\n');

for g = 1:length(uninjured_specs)
    fname = uninjured_specs{g};
    fpath = fullfile(uninjured_dir, fname);
    
    if ~isfile(fpath)
        fprintf('  WARNING: %s not found\n', fname);
        continue;
    end
    
    fprintf('  Loading: %s (rec 1)\n', fname);
    S = load(fpath);
    
    % Process both channels
    for ch = 1:2
        var_name = sprintf('data__chan_%d_rec_1', ch);
        if isfield(S, var_name)
            signal = S.(var_name)(:);
            
            % Filter: 1-500 Hz bandpass, order 1
            signal_filt = notch_filter(butter_filter(signal, [1 500], fs, 1));
            
            % Rectify and compute envelope
            signal_rect = abs(signal_filt);
            env_win = round(0.003 * fs);
            b = ones(env_win, 1) / env_win;
            signal_env = filtfilt(b, 1, signal_rect);
            
            % Compute RMS in 50ms windows
            rms_win = round(0.050 * fs);
            signal_rms = sqrt(movmean(signal_filt.^2, [rms_win-1, 0]));
            
            % Store
            if ch == 1
                gait_data.chan1.envelopes = [gait_data.chan1.envelopes; signal_env(:)];
                gait_data.chan1.filtered = [gait_data.chan1.filtered; signal_filt(:)];
                gait_data.chan1.rms = [gait_data.chan1.rms; signal_rms(:)];
            else
                gait_data.chan2.envelopes = [gait_data.chan2.envelopes; signal_env(:)];
                gait_data.chan2.filtered = [gait_data.chan2.filtered; signal_filt(:)];
                gait_data.chan2.rms = [gait_data.chan2.rms; signal_rms(:)];
            end
        end
    end
end

fprintf('  Channel 1 gait samples: %d\n', numel(gait_data.chan1.envelopes));
fprintf('  Channel 2 gait samples: %d\n', numel(gait_data.chan2.envelopes));

%% STEP 2: Load spasm recording (OP70-F4 Record 4)
fprintf('\n=== STEP 2: LOADING SPASM DATA ===\n');

spasm_file = fullfile(injured_dir, 'OP70 F4 10-Dec-2025.mat');
if ~isfile(spasm_file)
    fprintf('ERROR: Spasm file not found\n');
    return;
end

S_spasm = load(spasm_file);
fprintf('  Loaded OP70-F4 (Record 4)\n');

% Process both channels
spasm_data = struct();
for ch = 1:2
    var_name = sprintf('data__chan_%d_rec_4', ch);
    if ~isfield(S_spasm, var_name)
        fprintf('  ERROR: %s not found\n', var_name);
        return;
    end
    
    signal_spasm = S_spasm.(var_name)(:);
    
    % Filter: 1-500 Hz bandpass, order 1
    signal_spasm_filt = notch_filter(butter_filter(signal_spasm, [1 500], fs, 1));
    
    % Rectify and compute envelope
    signal_spasm_rect = abs(signal_spasm_filt);
    env_win = round(0.003 * fs);
    b = ones(env_win, 1) / env_win;
    signal_spasm_env = filtfilt(b, 1, signal_spasm_rect);
    
    % Compute RMS
    rms_win = round(0.050 * fs);
    signal_spasm_rms = sqrt(movmean(signal_spasm_filt.^2, [rms_win-1, 0]));
    
    if ch == 1
        spasm_data.chan1.raw = signal_spasm;
        spasm_data.chan1.filtered = signal_spasm_filt;
        spasm_data.chan1.envelope = signal_spasm_env;
        spasm_data.chan1.rms = signal_spasm_rms;
    else
        spasm_data.chan2.raw = signal_spasm;
        spasm_data.chan2.filtered = signal_spasm_filt;
        spasm_data.chan2.envelope = signal_spasm_env;
        spasm_data.chan2.rms = signal_spasm_rms;
    end
end

fprintf('  Spasm signal length: %d samples (%.2f sec)\n', numel(spasm_data.chan1.raw), numel(spasm_data.chan1.raw)/fs);

%% STEP 3: Extract specified spasm events
fprintf('\n=== STEP 3: EXTRACTING SPASM EVENTS ===\n');

% Spasm 1: 66-69.4s @ 10kHz = samples 660000-694000
% Spasm 2: 87-89.43s @ 10kHz = samples 870000-894300
spasm_events = struct();
spasm_events(1).time_start = 66.0;
spasm_events(1).time_end = 69.4;
spasm_events(1).sample_start = 660000;
spasm_events(1).sample_end = 694000;
spasm_events(1).label = 'Spasm_1_66-69.4s';

spasm_events(2).time_start = 87.0;
spasm_events(2).time_end = 89.43;
spasm_events(2).sample_start = 870000;
spasm_events(2).sample_end = 894300;
spasm_events(2).label = 'Spasm_2_87-89.43s';

spasm_extracted = struct();
spasm_extracted.chan1.envelopes = [];
spasm_extracted.chan1.filtered = [];
spasm_extracted.chan1.rms = [];
spasm_extracted.chan2.envelopes = [];
spasm_extracted.chan2.filtered = [];
spasm_extracted.chan2.rms = [];

for s = 1:length(spasm_events)
    idx_start = spasm_events(s).sample_start;
    idx_end = min(spasm_events(s).sample_end, numel(spasm_data.chan1.envelope));
    idx_range = idx_start:idx_end;
    
    if ~isempty(idx_range)
        % Channel 1
        spasm_extracted.chan1.envelopes = [spasm_extracted.chan1.envelopes; spasm_data.chan1.envelope(idx_range)];
        spasm_extracted.chan1.filtered = [spasm_extracted.chan1.filtered; spasm_data.chan1.filtered(idx_range)];
        spasm_extracted.chan1.rms = [spasm_extracted.chan1.rms; spasm_data.chan1.rms(idx_range)];
        
        % Channel 2
        spasm_extracted.chan2.envelopes = [spasm_extracted.chan2.envelopes; spasm_data.chan2.envelope(idx_range)];
        spasm_extracted.chan2.filtered = [spasm_extracted.chan2.filtered; spasm_data.chan2.filtered(idx_range)];
        spasm_extracted.chan2.rms = [spasm_extracted.chan2.rms; spasm_data.chan2.rms(idx_range)];
        
        fprintf('  %s: %d samples\n', spasm_events(s).label, numel(idx_range));
    end
end

%% STEP 4: Amplitude distribution analysis
fprintf('\n=== STEP 4: AMPLITUDE DISTRIBUTION ANALYSIS ===\n');

amp_stats = struct();

for ch = 1:2
    if ch == 1
        gait_env = gait_data.chan1.envelopes;
        spasm_env = spasm_extracted.chan1.envelopes;
        channel_name = 'Channel 1 (TA)';
    else
        gait_env = gait_data.chan2.envelopes;
        spasm_env = spasm_extracted.chan2.envelopes;
        channel_name = 'Channel 2 (MG)';
    end
    
    % IMPORTANT: Apply same filtering to BOTH gait and spasm for fair comparison
    % Use 20th percentile threshold on EACH signal independently
    gait_threshold = prctile(gait_env, 20);
    spasm_threshold = prctile(spasm_env, 20);
    
    gait_active_idx = gait_env > gait_threshold;
    gait_active = gait_env(gait_active_idx);
    
    spasm_active_idx = spasm_env > spasm_threshold;
    spasm_active = spasm_env(spasm_active_idx);
    
    fprintf('\n%s:\n', channel_name);
    fprintf('  GAIT (n=%d active samples, threshold=%.4f V):\n', numel(gait_active), gait_threshold);
    fprintf('    Min/Median/Max: %.4f / %.4f / %.4f V\n', min(gait_active), median(gait_active), max(gait_active));
    fprintf('    Mean ± SD: %.4f ± %.4f V\n', mean(gait_active), std(gait_active));
    fprintf('    P10/P25/P50/P75/P90: [%.4f, %.4f, %.4f, %.4f, %.4f]\n', ...
        prctile(gait_active, [10 25 50 75 90]));
    
    fprintf('  SPASM (n=%d active samples, threshold=%.4f V):\n', numel(spasm_active), spasm_threshold);
    fprintf('    Min/Median/Max: %.4f / %.4f / %.4f V\n', min(spasm_active), median(spasm_active), max(spasm_active));
    fprintf('    Mean ± SD: %.4f ± %.4f V\n', mean(spasm_active), std(spasm_active));
    fprintf('    P10/P25/P50/P75/P90: [%.4f, %.4f, %.4f, %.4f, %.4f]\n', ...
        prctile(spasm_active, [10 25 50 75 90]));
    
    sep_ratio = median(spasm_active) / median(gait_active);
    fprintf('  SEPARATION RATIO (median spasm / median gait): %.2f\n', sep_ratio);
    
    amp_stats(ch).gait_active = gait_active;
    amp_stats(ch).spasm_active = spasm_active;
    amp_stats(ch).sep_ratio = sep_ratio;
    amp_stats(ch).gait_p90 = prctile(gait_active, 90);
end

%% STEP 5: Visualize amplitude distributions
fprintf('\n=== STEP 5: PLOTTING AMPLITUDE DISTRIBUTIONS ===\n');

% Create comprehensive amplitude figure
fig1 = figure('Position', [50 50 1600 900], 'Name', 'Amplitude Analysis');

for ch = 1:2
    % Histogram
    subplot(2,3,ch);
    gait_active = amp_stats(ch).gait_active;
    spasm_active = amp_stats(ch).spasm_active;
    
    hold on;
    h1 = histogram(gait_active, 150, 'FaceColor', [0.3 0.8 0.3], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    h2 = histogram(spasm_active, 150, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    xlabel('Envelope Amplitude (V)', 'FontSize', 11);
    ylabel('Count', 'FontSize', 11);
    title(sprintf('Histogram: Channel %d', ch), 'FontSize', 12, 'FontWeight', 'bold');
    legend([h1, h2], 'Gait (active)', 'Spasm', 'Location', 'northeast');
    grid on;
    
    % CDF
    subplot(2,3,ch+2);
    [f_gait, x_gait] = ecdf(gait_active);
    [f_spasm, x_spasm] = ecdf(spasm_active);
    hold on;
    plot(x_gait, f_gait, 'Color', [0.3 0.8 0.3], 'LineWidth', 2.5, 'DisplayName', 'Gait');
    plot(x_spasm, f_spasm, 'Color', [1 0.3 0.3], 'LineWidth', 2.5, 'DisplayName', 'Spasm');
    xlabel('Envelope Amplitude (V)', 'FontSize', 11);
    ylabel('Cumulative Probability', 'FontSize', 11);
    title(sprintf('CDF: Channel %d', ch), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'southeast');
    grid on;
    
    % Log-scale histogram for better visualization of tail
    subplot(2,3,ch+4);
    [counts_g, edges_g] = histcounts(gait_active, 150);
    [counts_s, edges_s] = histcounts(spasm_active, 150);
    edges_g_mid = (edges_g(1:end-1) + edges_g(2:end)) / 2;
    edges_s_mid = (edges_s(1:end-1) + edges_s(2:end)) / 2;
    semilogy(edges_g_mid, counts_g, 'o-', 'Color', [0.3 0.8 0.3], 'LineWidth', 2, 'MarkerSize', 4, 'DisplayName', 'Gait');
    hold on;
    semilogy(edges_s_mid, counts_s, 's-', 'Color', [1 0.3 0.3], 'LineWidth', 2, 'MarkerSize', 4, 'DisplayName', 'Spasm');
    xlabel('Envelope Amplitude (V)', 'FontSize', 11);
    ylabel('Count (log scale)', 'FontSize', 11);
    title(sprintf('Log Histogram: Channel %d', ch), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast');
    grid on; grid minor;
end

sgtitle('AMPLITUDE SEPARATION ANALYSIS', 'FontSize', 14, 'FontWeight', 'bold');
savefig('01_amplitude_distributions.fig');
fprintf('  Saved: 01_amplitude_distributions.fig\n');

%% STEP 6: Time-domain visualization of spasm events
fprintf('\n=== STEP 6: PLOTTING TIME-DOMAIN SIGNALS ===\n');

fig2 = figure('Position', [50 50 1600 1000], 'Name', 'Time-Domain Signals');

% Show first 5 seconds of spasm + envelope for both channels
t_display = (0:min(50000, numel(spasm_data.chan1.filtered))-1) / fs;

for ch = 1:2
    if ch == 1
        filtered = spasm_data.chan1.filtered(1:numel(t_display));
        envelope = spasm_data.chan1.envelope(1:numel(t_display));
        title_str = 'Channel 1 (TA)';
    else
        filtered = spasm_data.chan2.filtered(1:numel(t_display));
        envelope = spasm_data.chan2.envelope(1:numel(t_display));
        title_str = 'Channel 2 (MG)';
    end
    
    subplot(2,2,ch);
    plot(t_display, filtered, 'b-', 'LineWidth', 0.5, 'DisplayName', 'Filtered Signal');
    hold on;
    plot(t_display, envelope, 'r-', 'LineWidth', 2, 'DisplayName', 'Envelope');
    plot(t_display, -envelope, 'r-', 'LineWidth', 2);
    xlabel('Time (s)', 'FontSize', 11);
    ylabel('Amplitude (V)', 'FontSize', 11);
    title(sprintf('First 5s of Record 4: %s', title_str), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast');
    grid on;
    
    % RMS over time
    subplot(2,2,ch+2);
    t_rms = (0:numel(spasm_data.chan1.rms)-1) / fs;
    if ch == 1
        rms_signal = spasm_data.chan1.rms;
    else
        rms_signal = spasm_data.chan2.rms;
    end
    plot(t_rms, rms_signal, 'LineWidth', 1.5, 'Color', [0.2 0.2 0.8]);
    % Mark spasm events
    hold on;
    for s = 1:length(spasm_events)
        xline(spasm_events(s).time_start, '--r', 'LineWidth', 2, 'DisplayName', spasm_events(s).label);
        xline(spasm_events(s).time_end, '--r', 'LineWidth', 2);
    end
    xlabel('Time (s)', 'FontSize', 11);
    ylabel('RMS (V)', 'FontSize', 11);
    title(sprintf('RMS Profile (Full Record): %s', title_str), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast');
    grid on;
end

sgtitle('TIME-DOMAIN VISUALIZATION', 'FontSize', 14, 'FontWeight', 'bold');
savefig('02_time_domain_signals.fig');
fprintf('  Saved: 02_time_domain_signals.fig\n');

%% STEP 7: Frequency analysis - Periodogram
fprintf('\n=== STEP 7: FREQUENCY DOMAIN ANALYSIS ===\n');

freq_stats = struct();

for ch = 1:2
    if ch == 1
        gait_filt = gait_data.chan1.filtered;
        spasm_filt = spasm_extracted.chan1.filtered;
        channel_name = 'Channel 1 (TA)';
    else
        gait_filt = gait_data.chan2.filtered;
        spasm_filt = spasm_extracted.chan2.filtered;
        channel_name = 'Channel 2 (MG)';
    end
    
    % Subsample for speed
    if numel(gait_filt) > 100000
        gait_filt_sub = gait_filt(1:100000);
    else
        gait_filt_sub = gait_filt;
    end
    
    if numel(spasm_filt) > 100000
        spasm_filt_sub = spasm_filt(1:100000);
    else
        spasm_filt_sub = spasm_filt;
    end
    
    fprintf('\n%s:\n', channel_name);
    fprintf('  Computing periodogram for gait (%d samples)...\n', numel(gait_filt_sub));
    [pxx_gait, f_gait] = periodogram(gait_filt_sub, [], [], fs);
    
    fprintf('  Computing periodogram for spasm (%d samples)...\n', numel(spasm_filt_sub));
    [pxx_spasm, f_spasm] = periodogram(spasm_filt_sub, [], [], fs);
    
    % Find dominant frequencies in 0.5-20 Hz band
    freq_band_gait = (f_gait >= 0.5) & (f_gait <= 20);
    [~, idx_gait] = max(pxx_gait(freq_band_gait));
    f_band_gait = f_gait(freq_band_gait);
    dom_freq_gait = f_band_gait(idx_gait);
    
    freq_band_spasm = (f_spasm >= 0.5) & (f_spasm <= 20);
    [~, idx_spasm] = max(pxx_spasm(freq_band_spasm));
    f_band_spasm = f_spasm(freq_band_spasm);
    dom_freq_spasm = f_band_spasm(idx_spasm);
    
    fprintf('  Dominant frequencies (0.5-20 Hz band):\n');
    fprintf('    Gait: %.2f Hz\n', dom_freq_gait);
    fprintf('    Spasm: %.2f Hz\n', dom_freq_spasm);
    fprintf('    Difference: %.2f Hz\n', abs(dom_freq_spasm - dom_freq_gait));
    
    freq_stats(ch).pxx_gait = pxx_gait;
    freq_stats(ch).f_gait = f_gait;
    freq_stats(ch).pxx_spasm = pxx_spasm;
    freq_stats(ch).f_spasm = f_spasm;
    freq_stats(ch).dom_freq_gait = dom_freq_gait;
    freq_stats(ch).dom_freq_spasm = dom_freq_spasm;
end

%% STEP 8: Plot frequency content
fprintf('\n=== STEP 8: PLOTTING FREQUENCY CONTENT ===\n');

fig3 = figure('Position', [50 50 1600 900], 'Name', 'Frequency Analysis');

for ch = 1:2
    % Full spectrum
    subplot(2,3,ch);
    semilogy(freq_stats(ch).f_gait, freq_stats(ch).pxx_gait, 'Color', [0.3 0.8 0.3], 'LineWidth', 2, 'DisplayName', 'Gait');
    hold on;
    semilogy(freq_stats(ch).f_spasm, freq_stats(ch).pxx_spasm, 'Color', [1 0.3 0.3], 'LineWidth', 2, 'DisplayName', 'Spasm');
    xlabel('Frequency (Hz)', 'FontSize', 11);
    ylabel('PSD (V^2/Hz)', 'FontSize', 11);
    title(sprintf('Full Spectrum: Channel %d', ch), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast');
    grid on; grid minor;
    xlim([0 500]);
    
    % Low frequency band (0.5-20 Hz)
    subplot(2,3,ch+2);
    freq_mask_g = (freq_stats(ch).f_gait >= 0.5) & (freq_stats(ch).f_gait <= 20);
    freq_mask_s = (freq_stats(ch).f_spasm >= 0.5) & (freq_stats(ch).f_spasm <= 20);
    semilogy(freq_stats(ch).f_gait(freq_mask_g), freq_stats(ch).pxx_gait(freq_mask_g), 'Color', [0.3 0.8 0.3], 'LineWidth', 2.5, 'DisplayName', 'Gait');
    hold on;
    semilogy(freq_stats(ch).f_spasm(freq_mask_s), freq_stats(ch).pxx_spasm(freq_mask_s), 'Color', [1 0.3 0.3], 'LineWidth', 2.5, 'DisplayName', 'Spasm');
    xline(freq_stats(ch).dom_freq_gait, '--g', 'LineWidth', 2, 'DisplayName', sprintf('Gait dom: %.2f Hz', freq_stats(ch).dom_freq_gait));
    xline(freq_stats(ch).dom_freq_spasm, '--r', 'LineWidth', 2, 'DisplayName', sprintf('Spasm dom: %.2f Hz', freq_stats(ch).dom_freq_spasm));
    xlabel('Frequency (Hz)', 'FontSize', 11);
    ylabel('PSD (V^2/Hz)', 'FontSize', 11);
    title(sprintf('Low Freq Band (0.5-20 Hz): Channel %d', ch), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast', 'FontSize', 9);
    grid on; grid minor;
    
    % Linear scale for detail
    subplot(2,3,ch+4);
    plot(freq_stats(ch).f_gait(freq_mask_g), freq_stats(ch).pxx_gait(freq_mask_g), 'Color', [0.3 0.8 0.3], 'LineWidth', 2.5, 'DisplayName', 'Gait');
    hold on;
    plot(freq_stats(ch).f_spasm(freq_mask_s), freq_stats(ch).pxx_spasm(freq_mask_s), 'Color', [1 0.3 0.3], 'LineWidth', 2.5, 'DisplayName', 'Spasm');
    xline(freq_stats(ch).dom_freq_gait, '--g', 'LineWidth', 2);
    xline(freq_stats(ch).dom_freq_spasm, '--r', 'LineWidth', 2);
    xlabel('Frequency (Hz)', 'FontSize', 11);
    ylabel('PSD (V^2/Hz)', 'FontSize', 11);
    title(sprintf('Linear Scale: Channel %d', ch), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast', 'FontSize', 9);
    grid on;
end

sgtitle('FREQUENCY DOMAIN ANALYSIS (Periodogram)', 'FontSize', 14, 'FontWeight', 'bold');
savefig('03_frequency_analysis.fig');
fprintf('  Saved: 03_frequency_analysis.fig\n');

%% STEP 9: Autocorrelation analysis for rhythmicity
fprintf('\n=== STEP 9: AUTOCORRELATION ANALYSIS (Rhythmicity) ===\n');

fig4 = figure('Position', [50 50 1600 600], 'Name', 'Autocorrelation Analysis');

for ch = 1:2
    if ch == 1
        gait_env = gait_data.chan1.envelopes(1:min(50000, numel(gait_data.chan1.envelopes)));
        spasm_env = spasm_extracted.chan1.envelopes;
        title_str = 'Channel 1 (TA)';
    else
        gait_env = gait_data.chan2.envelopes(1:min(50000, numel(gait_data.chan2.envelopes)));
        spasm_env = spasm_extracted.chan2.envelopes;
        title_str = 'Channel 2 (MG)';
    end
    
    % Compute autocorrelation (manual implementation using xcorr)
    max_lags = 1000;
    [xc_gait, lags_gait_full] = xcorr(gait_env - mean(gait_env), max_lags, 'coeff');
    [xc_spasm, lags_spasm_full] = xcorr(spasm_env - mean(spasm_env), max_lags, 'coeff');
    
    % Extract only positive lags (0 to max_lags)
    acf_gait = xc_gait(max_lags+1:end);
    acf_spasm = xc_spasm(max_lags+1:end);
    lags = (0:max_lags)';
    
    subplot(1,2,ch);
    lags_time = lags / fs;
    plot(lags_time, acf_gait, 'LineWidth', 2.5, 'Color', [0.3 0.8 0.3], 'DisplayName', 'Gait');
    hold on;
    plot(lags_time, acf_spasm, 'LineWidth', 2.5, 'Color', [1 0.3 0.3], 'DisplayName', 'Spasm');
    xlabel('Lag (s)', 'FontSize', 11);
    ylabel('Autocorrelation', 'FontSize', 11);
    title(sprintf('ACF Envelope: %s', title_str), 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast');
    grid on;
    xlim([0 0.3]);  % Focus on first 300ms
    
    fprintf('  %s:\n', title_str);
    fprintf('    Gait ACF peak (excluding lag 0): %.4f\n', max(acf_gait(2:end)));
    fprintf('    Spasm ACF peak (excluding lag 0): %.4f\n', max(acf_spasm(2:end)));
end

sgtitle('AUTOCORRELATION: RHYTHMICITY CHECK', 'FontSize', 14, 'FontWeight', 'bold');
savefig('04_autocorrelation_analysis.fig');
fprintf('  Saved: 04_autocorrelation_analysis.fig\n');

%% STEP 10: Summary and recommendations
fprintf('\n%% ====== FINAL SUMMARY & RECOMMENDATIONS ====== %%\n');
fprintf('\n--- AMPLITUDE SEPARATION ---\n');
for ch = 1:2
    sep_ratio = amp_stats(ch).sep_ratio;
    p90_threshold = amp_stats(ch).gait_p90;
    if sep_ratio >= 2.0
        fprintf('✓ Channel %d: GOOD separation (ratio = %.2f)\n', ch, sep_ratio);
        fprintf('  Suggested threshold: %.4f V (gait P90)\n', p90_threshold);
    else
        fprintf('✗ Channel %d: POOR separation (ratio = %.2f)\n', ch, sep_ratio);
    end
end

fprintf('\n--- FREQUENCY SEPARATION ---\n');
for ch = 1:2
    freq_diff = abs(freq_stats(ch).dom_freq_spasm - freq_stats(ch).dom_freq_gait);
    fprintf('Channel %d: Gait=%.2f Hz, Spasm=%.2f Hz, Diff=%.2f Hz\n', ch, ...
        freq_stats(ch).dom_freq_gait, freq_stats(ch).dom_freq_spasm, freq_diff);
    if freq_diff >= 2.0
        fprintf('  ✓ Sufficient frequency separation for detection\n');
    else
        fprintf('  ✗ Limited frequency separation\n');
    end
end

fprintf('\n✓ Analysis complete. 4 figures generated for verification.\n');
