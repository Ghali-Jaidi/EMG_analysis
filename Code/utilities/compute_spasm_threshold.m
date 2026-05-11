%% =========================
% Compute Spasm Detection Threshold
%% =========================
% This script computes an appropriate threshold for live spasm detection
% by analyzing normal gait amplitudes and spasm amplitudes.
%
% Workflow:
%   1. Load multiple normal gait recordings and compute median amplitude
%   2. Load a spasm recording and compute median spasm amplitude
%   3. Compute threshold to separate the two
%   4. Display comparative plot

clear; clc;

fs = 10000;

%% ============================================================
%  PART 1 — Collect normal gait amplitudes (uninjured)
%% ============================================================

answer = inputdlg('How many uninjured (normal gait) MAT files do you want to use for threshold inference?', ...
                  'Number of recordings', [1 60], {'2'});
if isempty(answer), error('Selection cancelled.'); end

nFiles_gait = str2double(answer{1});
if isnan(nFiles_gait) || nFiles_gait <= 0
    error('Invalid number of files.');
end

%% ---- Preallocate gait data ----
gait_data = struct( ...
    'file', "", 'fullFile', "", 'recID', NaN, ...
    'TA_rect', [], 'MG_rect', [], ...
    'is_act_TA', [], 'is_act_MG', [], ...
    'TA_median_amp', NaN, 'MG_median_amp', NaN);
gait_data = repmat(gait_data, nFiles_gait, 1);

%% ---- Load and process gait recordings ----
for k = 1:nFiles_gait

    msg = sprintf(['Select uninjured (normal gait) recording %d of %d.\n' ...
                   'Select ONE experiment MAT file.'], k, nFiles_gait);
    uiwait(msgbox(msg, 'Select gait file', 'modal'));

    [f, p] = uigetfile('*.mat', sprintf('Select gait MAT file (%d/%d)', k, nFiles_gait));
    if isequal(f, 0), error('File selection cancelled.'); end

    fullFile = fullfile(p, f);
    fprintf('\n=== [%d/%d] Processing gait: %s ===\n', k, nFiles_gait, fullFile);

    % --- Load params if exists, otherwise use defaults ---
    [~, srcName, ~] = fileparts(f);
    paramFile = fullfile(p, [srcName, '_param.mat']);
    if isfile(paramFile)
        fprintf('    Found param file: %s\n', paramFile);
        tmp = load(paramFile, 'P');
        P = tmp.P;
    else
        fprintf('    No param file found, using defaults.\n');
        P = default_emg_parameters();
    end

    [TTk, snrk, metak] = preprocess_and_label(P, fs, ...
        'fullFile', fullFile, ...
        'plot_figures', false, ...
        'save_figures', false);

    % Store rectified signal and activity masks
    gait_data(k).file = string(f);
    gait_data(k).fullFile = string(fullFile);
    gait_data(k).recID = metak.recID;
    gait_data(k).TA_rect = TTk.TA_rect(:);
    gait_data(k).MG_rect = TTk.MG_rect(:);
    gait_data(k).is_act_TA = snrk.is_act(:);
    gait_data(k).is_act_MG = snrk.is_act_MG(:);

    % For gait: identify continuous active bursts and take top amplitudes per burst
    N_gait_k = numel(gait_data(k).TA_rect);
    TA_bursts = find_bursts(gait_data(k).is_act_TA);
    MG_bursts = find_bursts(gait_data(k).is_act_MG);
    
    % Collect top 10% of amplitudes from each burst
    TA_top_amps = [];
    for b = 1:size(TA_bursts, 1)
        burst_mask = false(N_gait_k, 1);
        burst_mask(TA_bursts(b,1):TA_bursts(b,2)) = true;
        burst_amps = gait_data(k).TA_rect(burst_mask);
        % Take top 10% of amplitudes from this burst
        top_amp_threshold = prctile(burst_amps, 90);
        burst_top_amps = burst_amps(burst_amps >= top_amp_threshold);
        TA_top_amps = [TA_top_amps; burst_top_amps];
    end
    
    MG_top_amps = [];
    for b = 1:size(MG_bursts, 1)
        burst_mask = false(N_gait_k, 1);
        burst_mask(MG_bursts(b,1):MG_bursts(b,2)) = true;
        burst_amps = gait_data(k).MG_rect(burst_mask);
        % Take top 10% of amplitudes from this burst
        top_amp_threshold = prctile(burst_amps, 90);
        burst_top_amps = burst_amps(burst_amps >= top_amp_threshold);
        MG_top_amps = [MG_top_amps; burst_top_amps];
    end
    
    gait_data(k).TA_median_amp = median(TA_top_amps, 'omitnan');
    gait_data(k).MG_median_amp = median(MG_top_amps, 'omitnan');

    fprintf('    TA median amplitude (top 10%% per burst): %.6f V (%d samples from %d bursts)\n', gait_data(k).TA_median_amp, numel(TA_top_amps), size(TA_bursts, 1));
    fprintf('    MG median amplitude (top 10%% per burst): %.6f V (%d samples from %d bursts)\n', gait_data(k).MG_median_amp, numel(MG_top_amps), size(MG_bursts, 1));
end

%% ---- Compute overall gait statistics ----
all_gait_TA_amps = [gait_data.TA_median_amp]';
all_gait_MG_amps = [gait_data.MG_median_amp]';

median_gait_TA = median(all_gait_TA_amps, 'omitnan');
median_gait_MG = median(all_gait_MG_amps, 'omitnan');

std_gait_TA = std(all_gait_TA_amps, 0, 'omitnan');
std_gait_MG = std(all_gait_MG_amps, 0, 'omitnan');

fprintf('\n========== GAIT STATISTICS ==========\n');
fprintf('Methodology: During active periods, keep only samples ABOVE the activity threshold\n');
fprintf('This filters out sample-to-sample noise, capturing only high-amplitude contractions\n\n');
fprintf('TA median gait amplitude (active & above threshold): %.4f +/- %.4f V\n', median_gait_TA, std_gait_TA);
fprintf('MG median gait amplitude (active & above threshold): %.4f +/- %.4f V\n', median_gait_MG, std_gait_MG);
fprintf('  (Raw values, no scaling applied)\n');

%% ============================================================
%  PART 2 — Load spasm recording
%% ============================================================

uiwait(msgbox('Select ONE spasm recording for threshold validation.', 'Select spasm file', 'modal'));

[f_spasm, p_spasm] = uigetfile('*.mat', 'Select spasm MAT file');
if isequal(f_spasm, 0), error('File selection cancelled.'); end

fullFile_spasm = fullfile(p_spasm, f_spasm);
fprintf('\n=== Processing spasm: %s ===\n', fullFile_spasm);

% --- Load params if exists ---
[~, srcName_spasm, ~] = fileparts(f_spasm);
paramFile_spasm = fullfile(p_spasm, [srcName_spasm, '_param.mat']);
if isfile(paramFile_spasm)
    fprintf('    Found param file: %s\n', paramFile_spasm);
    tmp = load(paramFile_spasm, 'P');
    P = tmp.P;
else
    fprintf('    No param file found, using defaults.\n');
    P = default_emg_parameters();
end

[TT_spasm, snr_spasm, meta_spasm] = preprocess_and_label(P, fs, ...
    'fullFile', fullFile_spasm, ...
    'plot_figures', false, ...
    'save_figures', false);

tag_spasm = sprintf('%s (rec %d)', f_spasm, meta_spasm.recID);
[~, intervals_spasm] = ask_condition_and_intervals(tag_spasm);

%% ---- Separate spasm and non-spasm periods ----
N_spasm = height(TT_spasm);
if ~isempty(intervals_spasm)
    spasm_mask = build_interval_mask(N_spasm, fs, intervals_spasm);
else
    spasm_mask = true(N_spasm, 1);
end

% Use RECTIFIED signals (not envelopes)
TA_rect_spasm = TT_spasm.TA_rect(:);
MG_rect_spasm = TT_spasm.MG_rect(:);

% For spasm: identify continuous bursts WITHIN the user-defined spasm intervals only
% Do NOT use activity mask - only use the user-defined time intervals
% Find contiguous regions within spasm_mask where amplitude is significant
spasm_TA_bursts = find_bursts(spasm_mask);  % These are time regions user defined as spasm
spasm_MG_bursts = find_bursts(spasm_mask);

% Collect top 10% of amplitudes from each spasm interval
TA_spasm_top_amps = [];
for b = 1:size(spasm_TA_bursts, 1)
    burst_mask = false(N_spasm, 1);
    burst_mask(spasm_TA_bursts(b,1):spasm_TA_bursts(b,2)) = true;
    burst_amps = TA_rect_spasm(burst_mask);
    % Take top 10% of amplitudes from this interval
    top_amp_threshold = prctile(burst_amps, 90);
    burst_top_amps = burst_amps(burst_amps >= top_amp_threshold);
    TA_spasm_top_amps = [TA_spasm_top_amps; burst_top_amps];
end

MG_spasm_top_amps = [];
for b = 1:size(spasm_MG_bursts, 1)
    burst_mask = false(N_spasm, 1);
    burst_mask(spasm_MG_bursts(b,1):spasm_MG_bursts(b,2)) = true;
    burst_amps = MG_rect_spasm(burst_mask);
    % Take top 10% of amplitudes from this interval
    top_amp_threshold = prctile(burst_amps, 90);
    burst_top_amps = burst_amps(burst_amps >= top_amp_threshold);
    MG_spasm_top_amps = [MG_spasm_top_amps; burst_top_amps];
end

% Compute medians
median_spasm_TA = median(TA_spasm_top_amps, 'omitnan');
median_spasm_MG = median(MG_spasm_top_amps, 'omitnan');

% For error bars, compute median for each spasm interval separately
% Compute median of top 10% for each interval to get burst-to-burst variability
TA_spasm_interval_medians = [];
for b = 1:size(spasm_TA_bursts, 1)
    burst_mask = false(N_spasm, 1);
    burst_mask(spasm_TA_bursts(b,1):spasm_TA_bursts(b,2)) = true;
    burst_amps = TA_rect_spasm(burst_mask);
    top_amp_threshold = prctile(burst_amps, 90);
    burst_top_amps = burst_amps(burst_amps >= top_amp_threshold);
    if ~isempty(burst_top_amps)
        TA_spasm_interval_medians = [TA_spasm_interval_medians; median(burst_top_amps, 'omitnan')];
    end
end

MG_spasm_interval_medians = [];
for b = 1:size(spasm_MG_bursts, 1)
    burst_mask = false(N_spasm, 1);
    burst_mask(spasm_MG_bursts(b,1):spasm_MG_bursts(b,2)) = true;
    burst_amps = MG_rect_spasm(burst_mask);
    top_amp_threshold = prctile(burst_amps, 90);
    burst_top_amps = burst_amps(burst_amps >= top_amp_threshold);
    if ~isempty(burst_top_amps)
        MG_spasm_interval_medians = [MG_spasm_interval_medians; median(burst_top_amps, 'omitnan')];
    end
end

% Compute variability across intervals
std_spasm_TA = std(TA_spasm_interval_medians, 0, 'omitnan');
std_spasm_MG = std(MG_spasm_interval_medians, 0, 'omitnan');

fprintf('\n========== SPASM STATISTICS ==========\n');
fprintf('Methodology: During spasm intervals, keep only top 10%% per interval\n');
fprintf('This filters out sample-to-sample noise, capturing only high-amplitude spasm activity\n\n');
fprintf('TA median spasm amplitude (top 10%% per interval): %.6f +/- %.6f V\n', median_spasm_TA, std_spasm_TA);
fprintf('MG median spasm amplitude (top 10%% per interval): %.6f +/- %.6f V\n', median_spasm_MG, std_spasm_MG);
fprintf('  (Raw values, no scaling applied)\n');
fprintf('\nDEBUG: Sample raw signal ranges:\n');
fprintf('  Gait TA (top 10%% per burst): min=%.6f, max=%.6f, range=%.6f\n', min(all_gait_TA_amps), max(all_gait_TA_amps), range(all_gait_TA_amps));
fprintf('  Spasm TA (top 10%% per interval): min=%.6f, max=%.6f, range=%.6f\n', min(TA_spasm_top_amps), max(TA_spasm_top_amps), range(TA_spasm_top_amps));

%% ============================================================
%  PART 2b — Visual inspection of signals
%% ============================================================
% Plot one representative gait recording and the spasm recording for visual inspection

if nFiles_gait > 0
    % ---- Visualization scaling setup ----
    viz_scale_factor = 100;  % Scale UP by 100× for visibility (display only)
    scale_label = ' (mV × 100)';  % Label shows the scaling is applied for visualization
    
    fprintf('\n========== VISUALIZATION SCALING ==========\n');
    fprintf('Display scale factor: %.0f× (for visual clarity only, actual data unchanged)\n', viz_scale_factor);
    
    % Use the first gait recording as representative
    gait_idx = 1;
    TA_rect_gait = gait_data(gait_idx).TA_rect;
    MG_rect_gait = gait_data(gait_idx).MG_rect;
    is_act_TA_gait = gait_data(gait_idx).is_act_TA;
    is_act_MG_gait = gait_data(gait_idx).is_act_MG;
    N_gait = numel(TA_rect_gait);
    t_gait = (0:N_gait-1)' / fs;
    
    % Time vector for spasm recording
    N_spasm_full = numel(TA_rect_spasm);
    t_spasm_full = (0:N_spasm_full-1)' / fs;
    
    % Scale signals for visualization only (does not modify actual data)
    TA_rect_gait_viz = TA_rect_gait * viz_scale_factor;
    MG_rect_gait_viz = MG_rect_gait * viz_scale_factor;
    TA_rect_spasm_viz = TA_rect_spasm * viz_scale_factor;
    MG_rect_spasm_viz = MG_rect_spasm * viz_scale_factor;
    
    % Scale thresholds for visualization
    median_gait_TA_viz = median_gait_TA * viz_scale_factor;
    median_gait_MG_viz = median_gait_MG * viz_scale_factor;
    median_spasm_TA_viz = median_spasm_TA * viz_scale_factor;
    median_spasm_MG_viz = median_spasm_MG * viz_scale_factor;
    
    fprintf('Gait TA: median=%.4f +/- %.4f mV (displayed as %.2f%s)\n', median_gait_TA, std_gait_TA, median_gait_TA*viz_scale_factor, scale_label);
    fprintf('Gait MG: median=%.4f +/- %.4f mV (displayed as %.2f%s)\n', median_gait_MG, std_gait_MG, median_gait_MG*viz_scale_factor, scale_label);
    fprintf('Spasm TA: median=%.4f +/- %.4f mV (displayed as %.2f%s)\n', median_spasm_TA, std_spasm_TA, median_spasm_TA*viz_scale_factor, scale_label);
    fprintf('Spasm MG: median=%.4f +/- %.4f mV (displayed as %.2f%s)\n', median_spasm_MG, std_spasm_MG, median_spasm_MG*viz_scale_factor, scale_label);
    
    % Create figure with 4 subplots
    fig_inspect = figure('Name', 'Signal Inspection: Gait vs Spasm', 'NumberTitle', 'off');
    
    % ---- TA Gait ----
    subplot(2, 2, 1); hold on; grid on;
    plot(t_gait, TA_rect_gait_viz, 'LineWidth', 1, 'Color', [0.5 0.5 0.5], 'DisplayName', 'Rectified signal');
    plot(t_gait(is_act_TA_gait), TA_rect_gait_viz(is_act_TA_gait), 'b.', 'MarkerSize', 2, 'DisplayName', 'Active periods');
    yline(median_gait_TA_viz, 'r--', 'LineWidth', 2, 'DisplayName', sprintf('Median gait: %.3f', median_gait_TA_viz));
    xlabel('Time (s)');
    ylabel(['Amplitude' scale_label]);
    title(sprintf('TA - Normal Gait (Recording %d)', gait_data(gait_idx).recID));
    legend('Location', 'best');
    
    % ---- MG Gait ----
    subplot(2, 2, 2); hold on; grid on;
    plot(t_gait, MG_rect_gait_viz, 'LineWidth', 1, 'Color', [0.5 0.5 0.5], 'DisplayName', 'Rectified signal');
    plot(t_gait(is_act_MG_gait), MG_rect_gait_viz(is_act_MG_gait), 'b.', 'MarkerSize', 2, 'DisplayName', 'Active periods');
    yline(median_gait_MG_viz, 'r--', 'LineWidth', 2, 'DisplayName', sprintf('Median gait: %.3f', median_gait_MG_viz));
    xlabel('Time (s)');
    ylabel(['Amplitude' scale_label]);
    title(sprintf('MG - Normal Gait (Recording %d)', gait_data(gait_idx).recID));
    legend('Location', 'best');
    
    % ---- TA Spasm ----
    subplot(2, 2, 3); hold on; grid on;
    plot(t_spasm_full, TA_rect_spasm_viz, 'LineWidth', 1, 'Color', [0.5 0.5 0.5], 'DisplayName', 'Rectified signal');
    % Highlight spasm intervals
    if ~isempty(intervals_spasm)
        for ii = 1:size(intervals_spasm, 1)
            t_start = intervals_spasm(ii, 1);
            t_end = intervals_spasm(ii, 2);
            patch_indices = (t_spasm_full >= t_start) & (t_spasm_full <= t_end);
            plot(t_spasm_full(patch_indices), TA_rect_spasm_viz(patch_indices), 'r.', 'MarkerSize', 2, 'DisplayName', 'Spasm interval');
        end
    end
    yline(median_spasm_TA_viz, 'g--', 'LineWidth', 2, 'DisplayName', sprintf('Median spasm: %.3f', median_spasm_TA_viz));
    yline(median_gait_TA_viz, 'b--', 'LineWidth', 1.5, 'DisplayName', sprintf('Median gait: %.3f', median_gait_TA_viz));
    xlabel('Time (s)');
    ylabel(['Amplitude' scale_label]);
    title('TA - Spasm Recording (with spasm intervals marked)');
    legend('Location', 'best');
    
    % ---- MG Spasm ----
    subplot(2, 2, 4); hold on; grid on;
    plot(t_spasm_full, MG_rect_spasm_viz, 'LineWidth', 1, 'Color', [0.5 0.5 0.5], 'DisplayName', 'Rectified signal');
    % Highlight spasm intervals
    if ~isempty(intervals_spasm)
        for ii = 1:size(intervals_spasm, 1)
            t_start = intervals_spasm(ii, 1);
            t_end = intervals_spasm(ii, 2);
            patch_indices = (t_spasm_full >= t_start) & (t_spasm_full <= t_end);
            plot(t_spasm_full(patch_indices), MG_rect_spasm_viz(patch_indices), 'r.', 'MarkerSize', 2, 'DisplayName', 'Spasm interval');
        end
    end
    yline(median_spasm_MG_viz, 'g--', 'LineWidth', 2, 'DisplayName', sprintf('Median spasm: %.3f', median_spasm_MG_viz));
    yline(median_gait_MG_viz, 'b--', 'LineWidth', 1.5, 'DisplayName', sprintf('Median gait: %.3f', median_gait_MG_viz));
    xlabel('Time (s)');
    ylabel(['Amplitude' scale_label]);
    title('MG - Spasm Recording (with spasm intervals marked)');
    legend('Location', 'best');
    
    sgtitle('Signal Inspection: Comparing Gait and Spasm Amplitudes', 'FontSize', 14, 'FontWeight', 'bold');
end



%% ============================================================
%  PART 3 — Compute thresholds (separate for TA and MG)
%% ============================================================
% Strategy: Set threshold between median gait and median spasm for each muscle
% Use 75% gait + 25% spasm to bias toward gait (fewer false positives)

threshold_TA = 0.75 * median_gait_TA + 0.25 * median_spasm_TA;
threshold_MG = 0.75 * median_gait_MG + 0.25 * median_spasm_MG;

fprintf('\n========== COMPUTED THRESHOLDS ==========\n');
fprintf('TA threshold:  %.6f V (75%% gait + 25%% spasm)\n', threshold_TA);
fprintf('MG threshold:  %.6f V (75%% gait + 25%% spasm)\n', threshold_MG);

% Estimate how often threshold is crossed
gait_cross_TA = sum(all_gait_TA_amps > threshold_TA) / numel(all_gait_TA_amps);
gait_cross_MG = sum(all_gait_MG_amps > threshold_MG) / numel(all_gait_MG_amps);

spasm_cross_TA = sum(TA_spasm_interval_medians > threshold_TA) / numel(TA_spasm_interval_medians);
spasm_cross_MG = sum(MG_spasm_interval_medians > threshold_MG) / numel(MG_spasm_interval_medians);

fprintf('\n========== THRESHOLD PERFORMANCE ==========\n');
fprintf('TA: %.1f%% of normal gait crosses threshold | %.1f%% of spasm intervals exceed threshold\n', ...
    100*gait_cross_TA, 100*spasm_cross_TA);
fprintf('MG: %.1f%% of normal gait crosses threshold | %.1f%% of spasm intervals exceed threshold\n', ...
    100*gait_cross_MG, 100*spasm_cross_MG);

%% ============================================================
%  PART 4 — Plot comparison
%% ============================================================

figure('Name', 'Spasm Detection Threshold Analysis', 'NumberTitle', 'off');

% ---- Subplot 1: TA comparison ----
subplot(1, 2, 1); hold on; grid on;

% Plot gait data with error bars
errorbar(1, median_gait_TA, std_gait_TA, 'o', 'MarkerSize', 10, 'LineWidth', 2.5, ...
    'Color', [0 0.4 0.8], 'CapSize', 12, 'DisplayName', 'Normal Gait');

% Plot spasm data with error bars
errorbar(2, median_spasm_TA, std_spasm_TA, 's', 'MarkerSize', 10, 'LineWidth', 2.5, ...
    'Color', [0.8 0.2 0.2], 'CapSize', 12, 'DisplayName', 'Spasm');

% Plot threshold as dashed line
yLim = ylim;
plot([0.5 2.5], [threshold_TA threshold_TA], 'k--', 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Threshold: %.4f', threshold_TA));
ylim(yLim);

set(gca, 'XTick', [1 2], 'XTickLabel', {'Normal Gait', 'Spasm'});
ylabel('Median Amplitude (normalized)', 'FontSize', 12);
title('TA (Tibialis Anterior)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0.5 2.5]);

% ---- Subplot 2: MG comparison ----
subplot(1, 2, 2); hold on; grid on;

% Plot gait data with error bars
errorbar(1, median_gait_MG, std_gait_MG, 'o', 'MarkerSize', 10, 'LineWidth', 2.5, ...
    'Color', [0 0.4 0.8], 'CapSize', 12, 'DisplayName', 'Normal Gait');

% Plot spasm data with error bars
errorbar(2, median_spasm_MG, std_spasm_MG, 's', 'MarkerSize', 10, 'LineWidth', 2.5, ...
    'Color', [0.8 0.2 0.2], 'CapSize', 12, 'DisplayName', 'Spasm');

% Plot threshold as dashed line
yLim = ylim;
plot([0.5 2.5], [threshold_MG threshold_MG], 'k--', 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Threshold: %.4f', threshold_MG));
ylim(yLim);

set(gca, 'XTick', [1 2], 'XTickLabel', {'Normal Gait', 'Spasm'});
ylabel('Median Amplitude (normalized)', 'FontSize', 12);
title('MG (Medial Gastrocnemius)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0.5 2.5]);

sgtitle('Spasm Detection Threshold Analysis', 'FontSize', 14, 'FontWeight', 'bold');

%% ============================================================
%  PART 5 — Save results
%% ============================================================

save_choice = questdlg('Do you want to save the threshold parameters?', ...
    'Save Results', 'Yes', 'No', 'Yes');

if strcmp(save_choice, 'Yes')
    % Create output structure
    thresholdParams = struct( ...
        'threshold_TA', threshold_TA, ...
        'threshold_MG', threshold_MG, ...
        'threshold_combined', threshold_combined, ...
        'median_gait_TA', median_gait_TA, ...
        'median_gait_MG', median_gait_MG, ...
        'std_gait_TA', std_gait_TA, ...
        'std_gait_MG', std_gait_MG, ...
        'median_spasm_TA', median_spasm_TA, ...
        'median_spasm_MG', median_spasm_MG, ...
        'std_spasm_TA', std_spasm_TA, ...
        'std_spasm_MG', std_spasm_MG, ...
        'gait_cross_rate_TA', gait_cross_TA, ...
        'gait_cross_rate_MG', gait_cross_MG, ...
        'spasm_cross_rate_TA', spasm_cross_TA, ...
        'spasm_cross_rate_MG', spasm_cross_MG, ...
        'gait_files', {gait_data.file}, ...
        'spasm_file', string(f_spasm), ...
        'fs', fs);

    [saveName, savePath] = uiputfile('*.mat', 'Save threshold parameters as');
    if ~isequal(saveName, 0)
        fullSavePath = fullfile(savePath, saveName);
        save(fullSavePath, 'thresholdParams');
        fprintf('\nThreshold parameters saved to: %s\n', fullSavePath);
    end
end

fprintf('\n========== ANALYSIS COMPLETE ==========\n');


%% ============================================================
%  HELPER FUNCTIONS
%% ============================================================

function bursts = find_bursts(mask)
% Find contiguous regions (bursts) in a binary mask
% Returns Nx2 matrix where each row is [start_idx, end_idx]

mask = mask(:);
diff_mask = diff([0; double(mask); 0]);

% Start of bursts (transition from 0 to 1)
starts = find(diff_mask == 1);
% End of bursts (transition from 1 to 0)
ends = find(diff_mask == -1) - 1;

bursts = [starts, ends];
end

function mask = build_interval_mask(N, fs, intervals)
% intervals Nx2 [t0 t1] in seconds
% if empty => mask all true
mask = true(N, 1);
if isempty(intervals)
    return;
end

mask(:) = false;
for k = 1:size(intervals, 1)
    t0 = intervals(k, 1);
    t1 = intervals(k, 2);
    if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0
        continue;
    end
    i0 = max(1, floor(t0*fs) + 1);
    i1 = min(N, floor(t1*fs));
    if i1 > i0
        mask(i0:i1) = true;
    end
end
end
