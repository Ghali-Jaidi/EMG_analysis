function plot_spectral_comparison_advanced(varargin)
% plot_spectral_comparison_advanced
% Advanced frequency analysis comparing spasm vs gait with multiple metrics
% Modified to compute per-epoch PSDs for individual burst visualization
%
% Usage:
%   plot_spectral_comparison_advanced()                      % Interactive, loads from hardcoded paths
%   plot_spectral_comparison_advanced(TT)                    % Uses preprocessed TT data
%   plot_spectral_comparison_advanced(TT, label)             % With condition label
%   plot_spectral_comparison_advanced(TT, label, snrValue)   % With activity mask from preprocessing

% Parse optional input arguments
use_input_data = false;
TT_input = [];
snr_input = [];
condition_label = 'Recording';

if nargin > 0 && istimetable(varargin{1})
    TT_input = varargin{1};
    use_input_data = true;
    fprintf('\n=== Using preprocessed data ===\n');
end

if nargin > 1 && ischar(varargin{2})
    condition_label = varargin{2};
end

if nargin > 2 && isstruct(varargin{3})
    snr_input = varargin{3};
    fprintf('  Using provided activity masks from preprocessing\n');
end

fs = 10000;
window_length_ms = 100;
window_length = round(window_length_ms * fs / 1000);
min_epoch_length = round(50 * fs / 1000); % minimum 50ms epoch to compute PSD

%% ---- Use Input Data or Load from Hardcoded Paths ----
if use_input_data
    % Use the provided TT data
    fprintf('Processing condition: %s\n', condition_label);
    
    % Extract TA and MG signals
    ta_raw = TT_input.TA_raw;
    mg_raw = TT_input.MG_raw;
    
    % Try to get activity mask from different sources
    activity_mask = [];
    
    % Try 1: Use provided snrValue struct (has priority)
    if ~isempty(snr_input) && isstruct(snr_input) && isfield(snr_input, 'is_act')
        activity_mask = snr_input.is_act > 0;
        fprintf('  ✓ Using preprocessed activity mask (%.1f%% active)\n', ...
            100 * sum(activity_mask) / numel(activity_mask));
    % Try 2: Use activity mask column in TT if present
    elseif ismember('is_act', TT_input.Properties.VariableNames)
        activity_mask = TT_input.is_act > 0;
    % Try 3: Use envelope-based detection
    elseif ismember('TA_env', TT_input.Properties.VariableNames)
        activity_mask = TT_input.TA_env > 0.1 * max(TT_input.TA_env);
    % Try 4: Use filtered signal-based detection
    elseif ismember('TA_filt', TT_input.Properties.VariableNames)
        activity_mask = abs(TT_input.TA_filt) > 0.1 * max(abs(TT_input.TA_filt));
    else
        % Fall back to using all data
        activity_mask = true(height(TT_input), 1);
        fprintf('  ⚠ Warning: No activity mask found, using all data as active\n');
    end
    
    % Extract epochs
    epochs_ta = {};
    epochs_mg = {};
    
    % Simple epoch extraction
    active_idx = find(activity_mask);
    if ~isempty(active_idx)
        % Split into continuous segments
        diffs = diff(active_idx);
        breaks = find(diffs > 1);
        
        if ~isempty(breaks)
            start_idx = 1;
            for break_idx = 1:length(breaks)
                end_idx = breaks(break_idx);
                segment_indices = active_idx(start_idx:end_idx);
                
                if length(segment_indices) >= min_epoch_length
                    epochs_ta{end+1} = ta_raw(segment_indices);
                    epochs_mg{end+1} = mg_raw(segment_indices);
                end
                
                start_idx = end_idx + 1;
            end
            
            % Last segment
            segment_indices = active_idx(start_idx:end);
            if length(segment_indices) >= min_epoch_length
                epochs_ta{end+1} = ta_raw(segment_indices);
                epochs_mg{end+1} = mg_raw(segment_indices);
            end
        else
            % No breaks, entire active region is one epoch
            if length(active_idx) >= min_epoch_length
                epochs_ta{end+1} = ta_raw(active_idx);
                epochs_mg{end+1} = mg_raw(active_idx);
            end
        end
    else
        fprintf('  Warning: No active samples found, using entire signal\n');
        if numel(ta_raw) >= min_epoch_length
            epochs_ta{end+1} = ta_raw;
            epochs_mg{end+1} = mg_raw;
        end
    end
    
    epochs_gait_TA = epochs_ta;
    epochs_gait_MG = epochs_mg;
    
    fprintf('Extracted %d TA epochs\n', numel(epochs_gait_TA));
    fprintf('Extracted %d MG epochs\n\n', numel(epochs_gait_MG));
    
    % For comparison, use same data as reference
    epochs_spasm_TA = epochs_ta;
    epochs_spasm_MG = epochs_mg;
    
else
    %% ---- Load Gait Recording(s) from Hardcoded Paths ----
    fprintf('========================================\n');
    fprintf('GAIT RECORDING SELECTION\n');
    fprintf('========================================\n\n');
    
    uninjured_path = '/Users/ghalijaidi/Desktop/LSBI/EMG_analysis/Data/Uninjured ';
    
    if ~isfolder(uninjured_path)
        error('Uninjured folder not found at: %s', uninjured_path);
    end
    
    gait_files_all = dir(fullfile(uninjured_path, '*.mat'));
    gait_files_filtered = {};
    for i = 1:length(gait_files_all)
        if ~contains(gait_files_all(i).name, '_param')
            gait_files_filtered{end+1} = gait_files_all(i).name;
        end
    end
    
    if isempty(gait_files_filtered)
        error('No .mat recording files found in Uninjured folder: %s', uninjured_path);
    end
    
    gait_files_filtered = sort(gait_files_filtered);
    gait_files = gait_files_filtered;
    path = uninjured_path;
    
    fprintf('Found %d recording files in Uninjured folder\n', length(gait_files));
    
    % Storage for individual epoch PSDs
    epochs_gait_TA = {};   % each cell = one burst epoch signal
    epochs_gait_MG = {};
    
    for file_idx = 1:numel(gait_files)
        f_gait = gait_files{file_idx};
        fullFile_gait = fullfile(path, f_gait);
        
        fprintf('[%d/%d] Loading: %s\n', file_idx, numel(gait_files), f_gait);
        
        [~, srcName_gait, ~] = fileparts(f_gait);
        paramFile_gait = fullfile(path, [srcName_gait, '_param.mat']);
        if isfile(paramFile_gait)
            tmp = load(paramFile_gait, 'P');
            P = tmp.P;
        else
            P = default_emg_parameters();
        end
        
        [TT_gait, snr_gait, ~] = preprocess_and_label(P, fs, ...
            'fullFile', fullFile_gait, ...
            'recID', 1, ...
            'plot_figures', false, ...
            'save_figures', false);
        
        % Extract individual burst epochs for TA (use raw signal)
        [ta_epochs, n_ta] = extract_burst_epochs(TT_gait.TA_raw, snr_gait.is_act, min_epoch_length);
        epochs_gait_TA = [epochs_gait_TA; ta_epochs(:)];
        
        % Extract individual burst epochs for MG
        [mg_epochs, n_mg] = extract_burst_epochs(TT_gait.MG_raw, snr_gait.is_act_MG, min_epoch_length);
        epochs_gait_MG = [epochs_gait_MG; mg_epochs(:)];
        
        fprintf('  ✓ TA bursts: %d epochs\n', n_ta);
        fprintf('  ✓ MG bursts: %d epochs\n\n', n_mg);
    end
    
    fprintf('========================================\n');
    fprintf('GAIT SUMMARY:\n');
    fprintf('Total gait TA burst epochs: %d\n', numel(epochs_gait_TA));
    fprintf('Total gait MG burst epochs: %d\n\n', numel(epochs_gait_MG));
    
    %% ---- Load Spasm Recording ----
    fprintf('\n========================================\n');
    fprintf('SPASM RECORDING SELECTION\n');
    fprintf('========================================\n\n');
    
    fullFile_spasm = '/Users/ghalijaidi/Desktop/LSBI/EMG_analysis/Data/Injured/OP70 F4 10-Dec-2025.mat';
    [p_spasm, f_spasm_name, ext] = fileparts(fullFile_spasm);
    f_spasm = [f_spasm_name, ext];
    
    fprintf('Spasm file: %s\n', f_spasm);
    
    [~, srcName_spasm, ~] = fileparts(f_spasm);
    paramFile_spasm = fullfile(p_spasm, [srcName_spasm, '_param.mat']);
    if isfile(paramFile_spasm)
        tmp = load(paramFile_spasm, 'P');
        P = tmp.P;
    else
        P = default_emg_parameters();
    end
end

if ~use_input_data
    % Load spasm data for hardcoded path mode
    [TT_spasm, ~, ~] = preprocess_and_label(P, fs, ...
        'fullFile', fullFile_spasm, ...
        'recID', 4, ...
        'plot_figures', false, ...
        'save_figures', false);
    
    % Hardcoded spasm intervals
    spasm_intervals = [67.8 69.0; 88.2 89.2];
    fprintf('Using hardcoded spasm intervals:\n');
    for k = 1:size(spasm_intervals, 1)
        fprintf('  Interval %d: %.1f - %.1f s\n', k, spasm_intervals(k,1), spasm_intervals(k,2));
    end
    
    % Extract spasm epochs — one epoch per interval (use raw signal)
    spasm_TA_segs = extract_segments(TT_spasm.TA_raw, fs, spasm_intervals);
    spasm_MG_segs = extract_segments(TT_spasm.MG_raw, fs, spasm_intervals);
else
    spasm_TA_segs = epochs_spasm_TA;
    spasm_MG_segs = epochs_spasm_MG;
end

fprintf('\n  ✓ Spasm TA: %d epochs\n', numel(spasm_TA_segs));
fprintf('  ✓ Spasm MG: %d epochs\n\n', numel(spasm_MG_segs));

%% ---- Compute Per-Epoch PSDs ----
fprintf('Computing per-epoch PSDs...\n');

[psd_gait_TA_epochs, f_psd] = compute_epoch_psds(epochs_gait_TA, fs, window_length);
[psd_gait_MG_epochs, ~]     = compute_epoch_psds(epochs_gait_MG, fs, window_length);
[psd_spasm_TA_epochs, ~]    = compute_epoch_psds(spasm_TA_segs, fs, window_length);
[psd_spasm_MG_epochs, ~]    = compute_epoch_psds(spasm_MG_segs, fs, window_length);

fprintf('  ✓ Gait TA: %d valid PSDs\n', size(psd_gait_TA_epochs, 1));
fprintf('  ✓ Gait MG: %d valid PSDs\n', size(psd_gait_MG_epochs, 1));
fprintf('  ✓ Spasm TA: %d valid PSDs\n', size(psd_spasm_TA_epochs, 1));
fprintf('  ✓ Spasm MG: %d valid PSDs\n\n', size(psd_spasm_MG_epochs, 1));

% Check if any valid PSDs were computed
if isempty(psd_gait_TA_epochs) || isempty(psd_spasm_TA_epochs)
    fprintf('\n❌ ERROR: No valid PSDs extracted from epochs.\n');
    fprintf('This typically means:\n');
    fprintf('  1. Epochs are too short (< 50ms)\n');
    fprintf('  2. Activity masks are incorrect\n');
    fprintf('  3. Signal quality is too low\n\n');
    fprintf('Gait TA epochs: %d | Spasm TA epochs: %d\n', ...
        numel(epochs_gait_TA), numel(spasm_TA_segs));
    return;
end

% Mean PSDs across epochs
mean_psd_gait_TA  = mean(psd_gait_TA_epochs, 1);
mean_psd_gait_MG  = mean(psd_gait_MG_epochs, 1);
mean_psd_spasm_TA = mean(psd_spasm_TA_epochs, 1);
mean_psd_spasm_MG = mean(psd_spasm_MG_epochs, 1);
%% ---- DATA-DRIVEN THRESHOLDING (TA HIGH-FREQ POWER) ----

fprintf('\n========================================\n');
fprintf('DATA-DRIVEN THRESHOLD ANALYSIS (TA)\n');
fprintf('========================================\n');

% Define band
hf_band = (f_psd >= 100) & (f_psd <= 500);

% Compute feature per epoch
% Multiply by df to integrate PSD (V^2)
if numel(f_psd) >= 2
    df_psd = f_psd(2) - f_psd(1);
else
    df_psd = fs / (window_length);
end

feat_gait  = sum(psd_gait_TA_epochs(:, hf_band), 2) * df_psd;
feat_spasm = sum(psd_spasm_TA_epochs(:, hf_band), 2) * df_psd;

% (time-domain comparison moved later to avoid referencing variables before definition)

% Log-transform
feat_gait_log  = log10(feat_gait + eps);
feat_spasm_log = log10(feat_spasm + eps);

%% Histogram (RAW POWER)

figure('Name', 'TA High-Frequency Power Distributions');

edges = linspace(min([feat_gait; feat_spasm]), ...
                 max([feat_gait; feat_spasm]), 50);

histogram(feat_gait, edges, ...
    'Normalization', 'probability', ...
    'FaceColor', 'g', ...
    'FaceAlpha', 0.5);
hold on;

histogram(feat_spasm, edges, ...
    'Normalization', 'probability', ...
    'FaceColor', 'r', ...
    'FaceAlpha', 0.5);

xlabel('High-Frequency Power (100–500 Hz)');
ylabel('Probability');
legend('Gait', 'Spasm');
title('TA Feature Distribution (Raw Power)');
grid on;
%% ROC
labels = [zeros(size(feat_gait_log)); ones(size(feat_spasm_log))];
scores = [feat_gait_log; feat_spasm_log];

[FPR, TPR, T, AUC] = perfcurve(labels, scores, 1);

[~, idx] = max(TPR - FPR);
opt_threshold = T(idx);

fprintf('Optimal threshold (log10 scale): %.4f\n', opt_threshold);
fprintf('AUC: %.4f\n', AUC);
fprintf('Chosen ROC point: FPR = %.4f, TPR = %.4f\n', FPR(idx), TPR(idx));


%% ROC Plot
figure('Name', 'ROC Curve');
plot(FPR, TPR, 'LineWidth', 2); hold on;
plot(FPR(idx), TPR(idx), 'ro', 'MarkerSize', 10, 'LineWidth', 2);

xlabel('False Positive Rate');
ylabel('True Positive Rate');
title(sprintf('ROC Curve (AUC = %.3f)', AUC));
xline(opt_threshold, 'k--', 'LineWidth', 2, 'DisplayName', 'Optimal Threshold');
legend('Gait', 'Spasm', 'Optimal Threshold');
xlim([0 1]);
ylim([0 1]); 
grid on;

%% Performance
pred = scores > opt_threshold;

TP = sum((pred == 1) & (labels == 1));
TN = sum((pred == 0) & (labels == 0));
FP = sum((pred == 1) & (labels == 0));
FN = sum((pred == 0) & (labels == 1));

fprintf('\nPerformance at optimal threshold:\n');
fprintf('Sensitivity: %.3f\n', TP/(TP+FN));
fprintf('Specificity: %.3f\n', TN/(TN+FP));


% ---- Also plot histograms for the 500-1000 Hz band (raw and log10) ----
fprintf('\nPlotting 500-1000 Hz histograms (raw and log10)...\n');

hf_band2 = (f_psd >= 500) & (f_psd <= 1000);

% Compute features (integrated PSD across band) per epoch
feat_gait_500_1000  = sum(psd_gait_TA_epochs(:, hf_band2), 2) * df_psd;
feat_spasm_500_1000 = sum(psd_spasm_TA_epochs(:, hf_band2), 2) * df_psd;

% Raw-power histogram (500-1000 Hz)
figure('Name', 'TA High-Frequency Power Distributions 500-1000 Hz');
edges2 = linspace(min([feat_gait_500_1000; feat_spasm_500_1000]), ...
                 max([feat_gait_500_1000; feat_spasm_500_1000]), 50);
histogram(feat_gait_500_1000, edges2, ...
    'Normalization', 'probability', ...
    'FaceColor', 'g', 'FaceAlpha', 0.5);
hold on;
histogram(feat_spasm_500_1000, edges2, ...
    'Normalization', 'probability', ...
    'FaceColor', 'r', 'FaceAlpha', 0.5);
xlabel('High-Frequency Power (500–1000 Hz)');
ylabel('Probability');
legend('Gait', 'Spasm');
title('TA Feature Distribution (Raw Power, 500–1000 Hz)');
grid on;

% Log10 histogram (500-1000 Hz)
feat_gait_500_1000_log  = log10(feat_gait_500_1000 + eps);
feat_spasm_500_1000_log = log10(feat_spasm_500_1000 + eps);
figure('Name', 'TA High-Frequency Power Distributions (log10 500-1000 Hz)');
edges_log = linspace(min([feat_gait_500_1000_log; feat_spasm_500_1000_log]), ...
                    max([feat_gait_500_1000_log; feat_spasm_500_1000_log]), 50);
histogram(feat_gait_500_1000_log, edges_log, ...
    'Normalization', 'probability', ...
    'FaceColor', 'g', 'FaceAlpha', 0.5);
hold on;
histogram(feat_spasm_500_1000_log, edges_log, ...
    'Normalization', 'probability', ...
    'FaceColor', 'r', 'FaceAlpha', 0.5);
xlabel('log10 High-Frequency Power (500–1000 Hz)');
ylabel('Probability');
legend('Gait', 'Spasm');
title('TA Feature Distribution (log10 Power, 500–1000 Hz)');
grid on;

% --- Time-domain causal bandpass + mean-square (option B) ---
% Design causal Butterworth bandpass filters
bp_order = 4;
[b100_500, a100_500] = butter(bp_order, [100 500] / (fs/2), 'bandpass');
[b500_1000, a500_1000] = butter(bp_order, [500 1000] / (fs/2), 'bandpass');

% Compute time-domain mean-square for each epoch (gait)
n_gait_epochs = numel(epochs_gait_TA);
td_feat_gait_100_500 = nan(n_gait_epochs, 1);
td_feat_gait_500_1000 = nan(n_gait_epochs, 1);
for ii = 1:n_gait_epochs
    seg = epochs_gait_TA{ii};
    if isempty(seg), continue; end
    seg = seg(:);
    % causal filtering (real-time equivalent)
    seg_bp1 = filter(b100_500, a100_500, seg);
    seg_bp2 = filter(b500_1000, a500_1000, seg);
    td_feat_gait_100_500(ii) = mean(seg_bp1.^2);
    td_feat_gait_500_1000(ii) = mean(seg_bp2.^2);
end

% Compute time-domain mean-square for each spasm epoch
n_spasm_epochs = numel(spasm_TA_segs);
td_feat_spasm_100_500 = nan(n_spasm_epochs, 1);
td_feat_spasm_500_1000 = nan(n_spasm_epochs, 1);
for ii = 1:n_spasm_epochs
    seg = spasm_TA_segs{ii};
    if isempty(seg), continue; end
    seg = seg(:);
    seg_bp1 = filter(b100_500, a100_500, seg);
    seg_bp2 = filter(b500_1000, a500_1000, seg);
    td_feat_spasm_100_500(ii) = mean(seg_bp1.^2);
    td_feat_spasm_500_1000(ii) = mean(seg_bp2.^2);
end

% Print quick comparison of mean PSD-integrated vs time-domain mean-square
fprintf('\nComparison (mean over epochs): PSD-integrated [100-500 Hz]: gait=%.3e, spasm=%.3e\n', mean(feat_gait, 'omitnan'), mean(feat_spasm, 'omitnan'));
fprintf('                    Time-domain mean-square [100-500 Hz]: gait=%.3e, spasm=%.3e\n', mean(td_feat_gait_100_500, 'omitnan'), mean(td_feat_spasm_100_500, 'omitnan'));
fprintf('Comparison (mean over epochs): PSD-integrated [500-1000 Hz]: gait=%.3e, spasm=%.3e\n', mean(feat_gait_500_1000, 'omitnan'), mean(feat_spasm_500_1000, 'omitnan'));
fprintf('                    Time-domain mean-square [500-1000 Hz]: gait=%.3e, spasm=%.3e\n', mean(td_feat_gait_500_1000, 'omitnan'), mean(td_feat_spasm_500_1000, 'omitnan'));

%% ---- Compute LDA in Frequency Space ----
fprintf('Computing LDA...\n');

freq_mask = (f_psd >= 0) & (f_psd <= 1000);
f_lda = f_psd(freq_mask);

% Normalize per-epoch PSDs for LDA (shape-based comparison)
norm_gait_TA  = normalize_psds(psd_gait_TA_epochs(:, freq_mask));
norm_gait_MG  = normalize_psds(psd_gait_MG_epochs(:, freq_mask));
norm_spasm_TA = normalize_psds(psd_spasm_TA_epochs(:, freq_mask));
norm_spasm_MG = normalize_psds(psd_spasm_MG_epochs(:, freq_mask));

[lda_coef_TA, separation_TA] = compute_lda_coefficients(norm_gait_TA, norm_spasm_TA);
[lda_coef_MG, separation_MG] = compute_lda_coefficients(norm_gait_MG, norm_spasm_MG);

fprintf('  ✓ TA separation: %.4f\n', separation_TA);
fprintf('  ✓ MG separation: %.4f\n\n', separation_MG);

%% ---- Plot Individual Epoch PSDs ----
figure('Name', 'Individual Epoch PSDs', 'NumberTitle', 'off', 'Position', [50 50 1400 600]);

% Colors
c_gait_light  = [0.20 0.75 0.20];  % medium green for gait individuals
c_gait_mean   = [0.00 0.45 0.00];  % dark green for gait mean
c_spasm_light = [0.95 0.50 0.20];  % orange for spasm individuals
c_spasm_mean  = [0.80 0.00 0.00];  % dark red for spasm mean

f_plot = f_psd(freq_mask);

subplot(1, 2, 1);
hold on;

% Individual gait epochs — plot without adding to legend
h_gait_ind = gobjects(1);
for i = 1:size(psd_gait_TA_epochs, 1)
    h = semilogy(f_plot, psd_gait_TA_epochs(i, freq_mask), ...
        'Color', [c_gait_light 0.35], 'LineWidth', 0.8);
    h.Annotation.LegendInformation.IconDisplayStyle = 'off';
    if i == 1, h_gait_ind(1) = h; end
end

% Individual spasm epochs — plot without adding to legend
for i = 1:size(psd_spasm_TA_epochs, 1)
    h = semilogy(f_plot, psd_spasm_TA_epochs(i, freq_mask), ...
        'Color', [c_spasm_light 0.7], 'LineWidth', 1.2);
    h.Annotation.LegendInformation.IconDisplayStyle = 'off';
end

% Mean lines — these go in the legend
h1 = semilogy(f_plot, mean_psd_gait_TA(freq_mask), '-', ...
    'Color', c_gait_mean, 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Gait TA mean (n=%d)', size(psd_gait_TA_epochs,1)));
h2 = semilogy(f_plot, mean_psd_spasm_TA(freq_mask), '-', ...
    'Color', c_spasm_mean, 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Spasm TA mean (n=%d)', size(psd_spasm_TA_epochs,1)));

% Dummy handles for individual lines in legend
h3 = plot(nan, nan, '-', 'Color', [c_gait_light 0.6], 'LineWidth', 1.5, ...
    'DisplayName', 'Gait individual epochs');
h4 = plot(nan, nan, '-', 'Color', [c_spasm_light 0.8], 'LineWidth', 1.5, ...
    'DisplayName', 'Spasm individual epochs');

legend([h3 h4 h1 h2], 'Location', 'northeast', 'FontSize', 9);
xlabel('Frequency (Hz)');
ylabel('PSD (V²/Hz)');
title(sprintf('TA — Individual Epoch PSDs\n(Gait: %d epochs, Spasm: %d epochs)', ...
    size(psd_gait_TA_epochs,1), size(psd_spasm_TA_epochs,1)));
ylim([1e-5 1e-3]);
grid on;
xlim([0 1000]);
hold off;

subplot(1, 2, 2);
hold on;

for i = 1:size(psd_gait_MG_epochs, 1)
    h = semilogy(f_plot, psd_gait_MG_epochs(i, freq_mask), ...
        'Color', [c_gait_light 0.35], 'LineWidth', 0.8);
    h.Annotation.LegendInformation.IconDisplayStyle = 'off';
end

for i = 1:size(psd_spasm_MG_epochs, 1)
    h = semilogy(f_plot, psd_spasm_MG_epochs(i, freq_mask), ...
        'Color', [c_spasm_light 0.7], 'LineWidth', 1.2);
    h.Annotation.LegendInformation.IconDisplayStyle = 'off';
end

h1 = semilogy(f_plot, mean_psd_gait_MG(freq_mask), '-', ...
    'Color', c_gait_mean, 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Gait MG mean (n=%d)', size(psd_gait_MG_epochs,1)));
h2 = semilogy(f_plot, mean_psd_spasm_MG(freq_mask), '-', ...
    'Color', c_spasm_mean, 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Spasm MG mean (n=%d)', size(psd_spasm_MG_epochs,1)));

h3 = plot(nan, nan, '-', 'Color', [c_gait_light 0.6], 'LineWidth', 1.5, ...
    'DisplayName', 'Gait individual epochs');
h4 = plot(nan, nan, '-', 'Color', [c_spasm_light 0.8], 'LineWidth', 1.5, ...
    'DisplayName', 'Spasm individual epochs');

legend([h3 h4 h1 h2], 'Location', 'northeast', 'FontSize', 9);
xlabel('Frequency (Hz)');
ylabel('PSD (V²/Hz)');
title(sprintf('MG — Individual Epoch PSDs\n(Gait: %d epochs, Spasm: %d epochs)', ...
    size(psd_gait_MG_epochs,1), size(psd_spasm_MG_epochs,1)));
grid on;
xlim([0 1000]);
ylim([1e-6 5e-5]);

hold off;

%% ---- Original Summary Figure ----
fig = figure('Name', 'Advanced Spectral Analysis: Gait vs Spasm', 'NumberTitle', 'off');
set(fig, 'Position', [50 50 1400 900]);

subplot(2, 3, 1);
semilogy(f_psd, mean_psd_gait_TA, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Gait TA (active)');
hold on;
semilogy(f_psd, mean_psd_spasm_TA, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Spasm TA');
xlabel('Frequency (Hz)'); ylabel('PSD (V²/Hz)');
title('TA - Power Spectral Density'); legend; grid on; xlim([0 1000]); hold off;

subplot(2, 3, 2);
semilogy(f_psd, mean_psd_gait_MG, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Gait MG (active)');
hold on;
semilogy(f_psd, mean_psd_spasm_MG, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Spasm MG');
xlabel('Frequency (Hz)'); ylabel('PSD (V²/Hz)');
title('MG - Power Spectral Density'); legend; grid on; xlim([0 1000]); hold off;

subplot(2, 3, 3);
bar(f_lda, abs(lda_coef_TA), 'FaceColor', [0.3 0.6 1], 'EdgeColor', 'none');
xlabel('Frequency (Hz)'); ylabel('|LDA Coefficient|');
title(sprintf('TA - LDA Discriminability\n(Separation: %.3f)', separation_TA));
grid on; xlim([0 1000]);

subplot(2, 3, 4);
bar(f_lda, abs(lda_coef_MG), 'FaceColor', [1 0.3 0.3], 'EdgeColor', 'none');
xlabel('Frequency (Hz)'); ylabel('|LDA Coefficient|');
title(sprintf('MG - LDA Discriminability\n(Separation: %.3f)', separation_MG));
grid on; xlim([0 1000]);

subplot(2, 3, 5);
ratio_TA = mean_psd_spasm_TA ./ (mean_psd_gait_TA + 1e-10);
ratio_MG = mean_psd_spasm_MG ./ (mean_psd_gait_MG + 1e-10);
semilogy(f_psd, ratio_TA, 'b-', 'LineWidth', 1.2, 'DisplayName', 'TA');
hold on;
semilogy(f_psd, ratio_MG, 'm-', 'LineWidth', 1.2, 'DisplayName', 'MG');
yline(1, 'k--', 'LineWidth', 1, 'DisplayName', 'Equal power');
xlabel('Frequency (Hz)'); ylabel('Power Ratio (Spasm/Gait)');
title('Spectral Power Ratio'); legend; grid on; xlim([0 1000]); hold off;

%% ---- Print band statistics ----
fprintf('\n========================================\n');
fprintf('FREQUENCY BAND POWER ANALYSIS\n');
fprintf('========================================\n');
fprintf('%-12s %-12s %-12s %-12s %-12s\n', 'Frequency Band', 'Gait TA', 'Spasm TA', 'Gait MG', 'Spasm MG');
fprintf('%s\n', repmat('-', 1, 60));

bands = [20 100; 100 200; 200 400];
for i = 1:size(bands, 1)
    mask = (f_psd >= bands(i,1)) & (f_psd <= bands(i,2));
    fprintf('[%d-%d Hz]    %.2e      %.2e      %.2e      %.2e\n', ...
        bands(i,1), bands(i,2), ...
        mean(mean_psd_gait_TA(mask)), mean(mean_psd_spasm_TA(mask)), ...
        mean(mean_psd_gait_MG(mask)), mean(mean_psd_spasm_MG(mask)));
end
fprintf('\nPower values in V²/Hz\n');

%% Save all figures
fprintf('\nSaving figures...\n');
output_dir = 'Figures';
if ~isfolder(output_dir)
    mkdir(output_dir);
end

% Get all figure handles
fig_handles = findall(0, 'Type', 'figure');
for i = 1:length(fig_handles)
    fig = fig_handles(i);
    fig_name = fig.Name;
    if isempty(fig_name), fig_name = sprintf('Figure_%d', i); end
    
    % Replace spaces and special characters in filename
    fig_name = regexprep(fig_name, '[^a-zA-Z0-9_]', '_');
    
    % Save as PNG
    savename = fullfile(output_dir, [fig_name, '.png']);
    saveas(fig, savename);
    fprintf('  Saved: %s\n', savename);
end

fprintf('\nAnalysis complete!\n');
fprintf('All figures saved to: %s/\n', output_dir);

end

%% ========== HELPER FUNCTIONS ==========

function [epochs, n_epochs] = extract_burst_epochs(signal, active_mask, min_length)
% Extract contiguous active regions as individual epochs
epochs = {};
in_burst = false;
start_idx = 0;

for i = 1:numel(active_mask)
    if active_mask(i) == 1 && ~in_burst
        in_burst = true;
        start_idx = i;
    elseif active_mask(i) == 0 && in_burst
        in_burst = false;
        epoch_len = i - start_idx;
        if epoch_len >= min_length
            epochs{end+1} = signal(start_idx:i-1);
        end
    end
end
% Handle burst that extends to end of signal
if in_burst
    epoch_len = numel(active_mask) - start_idx + 1;
    if epoch_len >= min_length
        epochs{end+1} = signal(start_idx:end);
    end
end

n_epochs = numel(epochs);
end

function [psd_matrix, f] = compute_epoch_psds(epochs, fs, window_length)

% Compute Welch PSD for each epoch, return as matrix (n_epochs x n_freqs)
% Use fixed nfft = window_length so frequency resolution matches a 1000-sample FFT
% and explicitly use a Hann window with zero overlap (to match LabChart-style windows).

nfft = window_length; % target FFT size (controls df = fs / nfft)
[~, f] = pwelch(zeros(window_length,1), hann(window_length), 0, nfft, fs); % reference freq axis

psd_list = {};

for i = 1:numel(epochs)
    seg = epochs{i};
    seg = seg(:) - mean(seg);

    win_len = min(window_length, floor(numel(seg) / 2));
    if win_len < 8
        continue; % skip epochs that are too short
    end

    % Hann window, zero overlap. Keep nfft fixed to window_length for consistent df.
    win = hann(win_len);
    curr_nfft = max(nfft, win_len);
    [pxx, ~] = pwelch(seg, win, 0, curr_nfft, fs);
    
    psd_list{end+1} = pxx(:)';
end

if isempty(psd_list)
    psd_matrix = zeros(0, numel(f));
    return;
end

% All rows now have identical length = numel(f)
psd_matrix = vertcat(psd_list{:});
end

function normed = normalize_psds(psd_matrix)
% Normalize each row (epoch) by its total power
row_sums = sum(psd_matrix, 2) + eps;
normed = psd_matrix ./ row_sums;
end

function segments = extract_segments(signal, fs, intervals)
segments = {};
for k = 1:size(intervals, 1)
    t_start = intervals(k, 1);
    t_end = intervals(k, 2);
    start_idx = max(1, round(t_start * fs) + 1);
    end_idx = min(numel(signal), round(t_end * fs));
    segments{k} = signal(start_idx:end_idx);
end
end

function [coef, separation] = compute_lda_coefficients(class1_features, class2_features)

if size(class1_features, 2) == 1, class1_features = class1_features'; end
if size(class2_features, 2) == 1, class2_features = class2_features'; end

class1_features(~isfinite(class1_features)) = 0;
class2_features(~isfinite(class2_features)) = 0;

mu1 = mean(class1_features, 1);
mu2 = mean(class2_features, 1);
mu_diff = (mu2 - mu1)';

if norm(mu_diff) < 1e-10
    coef = ones(size(mu_diff)) / sqrt(length(mu_diff));
    separation = 0.01;
    return;
end

S1 = cov(class1_features);
S2 = cov(class2_features);

S1(~isfinite(S1)) = 0;
S2(~isfinite(S2)) = 0;

n1 = size(class1_features, 1);
n2 = size(class2_features, 1);

Sw = ((n1 - 1) * S1 + (n2 - 1) * S2) / (n1 + n2 - 2);
Sw = Sw + eye(size(Sw)) * max(1e-6, 1e-3 * trace(Sw) / size(Sw, 1));

coef = Sw \ mu_diff;
coef = coef / (norm(coef) + eps);

std_within = sqrt(diag(Sw))' + eps;
separation = mean(abs(mu2 - mu1) ./ std_within);

end

