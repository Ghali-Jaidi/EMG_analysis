%% =========================================================================
% Compare Spasm Amplitude vs Active Amplitude
%% =========================================================================
% This script:
% 1. Prompts user to select recordings (like preprocess_and_label)
% 2. Asks for condition and spasm intervals (like ask_condition_and_intervals)
% 3. Extracts amplitude measurements for:
%    - Spasm periods (for injured mice only)
%    - Normal active periods (for both injured and uninjured)
% 4. Displays bar plot with error bars comparing amplitudes
%
% Reuses:
% - preprocess_and_label for signal processing
% - ask_condition_and_intervals for condition/interval selection
% - peak_to_noise_masked_peak for amplitude extraction

clear; clc;

% Apply white background style for all figures
set_white_background_style();

fs = 10000;

%% ---- Ask how many recordings ----
answer = inputdlg('How many recordings do you want to analyze?', ...
                  'Number of recordings', [1 60], {'3'});
if isempty(answer), error('Selection cancelled.'); end

nFiles = str2double(answer{1});
if isnan(nFiles) || nFiles <= 0
    error('Invalid number of files.');
end

%% ---- Preallocate storage ----
R = struct( ...
    'file', "", 'fullFile', "", 'recID', NaN, ...
    'cond', "", 'group', "", 'intervals', [], ...
    'ampTA_active', [], 'ampMG_active', [], ...
    'ampTA_spasm', [], 'ampMG_spasm', [], ...
    'meanAmpTA_active', NaN, 'meanAmpMG_active', NaN, ...
    'meanAmpTA_spasm', NaN, 'meanAmpMG_spasm', NaN, ...
    'sdAmpTA_active', NaN, 'sdAmpMG_active', NaN, ...
    'sdAmpTA_spasm', NaN, 'sdAmpMG_spasm', NaN, ...
    'TA_env', [], 'MG_env', [], ...
    'is_act_TA', [], 'is_act_MG', [], ...
    'is_rest_TA', [], 'is_rest_MG', []);
R = repmat(R, nFiles, 1);

%% ---- Load parameters strategy ----
ans_params = questdlg(['How would you like to handle processing parameters?'], ...
    'Parameter Strategy', ...
    'Use best params per file', 'Use defaults for all', 'Use best params per file');
use_best_params_per_file = strcmp(ans_params, 'Use best params per file');

if use_best_params_per_file
    fprintf('\n*** MODE: Using best parameters for each recording (if available) ***\n');
else
    fprintf('\n*** MODE: Using default parameters for all recordings ***\n');
end

%% ---- Process each recording ----
for k = 1:nFiles

    msg = sprintf(['Select recording %d of %d\n' ...
                   'Select ONE experiment MAT file.'], k, nFiles);
    uiwait(msgbox(msg, 'Select experiment file', 'modal'));

    [f, p] = uigetfile('*.mat', sprintf('Select experiment MAT file (%d/%d)', k, nFiles));
    if isequal(f, 0), error('File selection cancelled.'); end

    fullFile = fullfile(p, f);
    fprintf('\n=== [%d/%d] Processing: %s ===\n', k, nFiles, fullFile);

    %% --- Load parameters ---
    [~, srcName, ~] = fileparts(f);
    paramFile = fullfile(p, [srcName, '_param.mat']);
    
    if use_best_params_per_file && isfile(paramFile)
        fprintf('    Found param file: %s\n', paramFile);
        tmp = load(paramFile, 'P');
        P = tmp.P;
    else
        if use_best_params_per_file && ~isfile(paramFile)
            fprintf('    No param file found, using defaults.\n');
        end
        P = default_emg_parameters();
    end

    %% --- Build options struct ---
    % CRITICAL: Ensure plots are disabled during batch processing
    options = struct();
    options.envWindowMs = P.envWindowMs;
    options.thresholds = P.thresholds;
    options.min_quiet_dur_ms = P.min_quiet_dur_ms;
    options.fuse_gap_ms = P.fuse_gap_ms;
    options.snr_win_ms = P.snr_win_ms;
    options.act_prc = P.act_prc;
    options.act_prc_MG = P.act_prc_MG;
    options.plot_figures = false;  % Disable all plots in preprocess_and_label
    options.save_figures = false;  % Don't save figures
    options.fig_folder = 'Figures';
    options.use_envelope = P.use_envelope;
    options.fullFile = fullFile;
    options.recID = NaN;
    options.detect_valid_acq = false;  % Turn off valid acquisition detection for amplitude analysis

    %% --- Preprocess and label ---
    % This will NOT produce any figures because plot_figures=false
    % Valid acquisition detection is disabled to use full recording for amplitude analysis
    [TTk, snrk, metak] = preprocess_and_label(fs, options);

    %% --- Ask condition and intervals ---
    tag = sprintf('%s (rec %d)', f, metak.recID);
    [condk, intervalsk] = ask_condition_and_intervals(tag);

    if strcmpi(condk, 'Spastic')
        groupk = "injured";
    elseif strcmpi(condk, 'Uninjured')
        groupk = "uninjured";
    else
        groupk = lower(string(condk));
    end

    %% --- Store basic info ---
    R(k).file      = string(f);
    R(k).fullFile  = string(fullFile);
    R(k).recID     = metak.recID;
    R(k).cond      = string(condk);
    R(k).group     = groupk;
    R(k).intervals = intervalsk;

    N = height(TTk);

    %% --- Extract activity masks ---
    R(k).TA_env    = TTk.TA_env(:);
    R(k).MG_env    = TTk.MG_env(:);
    R(k).is_act_TA = snrk.is_act(:);
    R(k).is_act_MG = snrk.is_act_MG(:);
    R(k).is_rest_TA = snrk.is_rest(:);
    R(k).is_rest_MG = snrk.is_rest_MG(:);

    %% --- Build masks for spasm and active periods ---
    if ~isempty(intervalsk)
        spasmWin = build_interval_mask(N, fs, intervalsk);
    else
        spasmWin = false(N, 1);
    end

    % Active periods: where activity is detected (not rest)
    activePeriodTA = R(k).is_act_TA;
    activePeriodMG = R(k).is_act_MG;

    %% --- Extract amplitudes ---
    % For each contraction (active period), get the max amplitude
    
    % ACTIVE PERIODS: Extract peak amplitudes during active periods
    [amp_TA_active, amp_MG_active] = extract_amplitudes_per_contraction(...
        R(k).TA_env, R(k).MG_env, activePeriodTA, activePeriodMG, fs);

    R(k).ampTA_active = amp_TA_active;
    R(k).ampMG_active = amp_MG_active;
    R(k).meanAmpTA_active = mean(amp_TA_active, 'omitnan');
    R(k).meanAmpMG_active = mean(amp_MG_active, 'omitnan');
    R(k).sdAmpTA_active = std(amp_TA_active, 0, 'omitnan');
    R(k).sdAmpMG_active = std(amp_MG_active, 0, 'omitnan');

    % SPASM PERIODS: Only for injured mice with defined intervals
    if groupk == "injured" && any(spasmWin)
        [amp_TA_spasm, amp_MG_spasm] = extract_amplitudes_per_contraction(...
            R(k).TA_env, R(k).MG_env, activePeriodTA & spasmWin, activePeriodMG & spasmWin, fs);

        R(k).ampTA_spasm = amp_TA_spasm;
        R(k).ampMG_spasm = amp_MG_spasm;
        R(k).meanAmpTA_spasm = mean(amp_TA_spasm, 'omitnan');
        R(k).meanAmpMG_spasm = mean(amp_MG_spasm, 'omitnan');
        R(k).sdAmpTA_spasm = std(amp_TA_spasm, 0, 'omitnan');
        R(k).sdAmpMG_spasm = std(amp_MG_spasm, 0, 'omitnan');
    end

    fprintf('    TA active: %.2f ± %.2f (n=%d)\n', ...
        R(k).meanAmpTA_active, R(k).sdAmpTA_active, numel(amp_TA_active));
    fprintf('    MG active: %.2f ± %.2f (n=%d)\n', ...
        R(k).meanAmpMG_active, R(k).sdAmpMG_active, numel(amp_MG_active));

    if ~isnan(R(k).meanAmpTA_spasm)
        fprintf('    TA spasm: %.2f ± %.2f (n=%d)\n', ...
            R(k).meanAmpTA_spasm, R(k).sdAmpTA_spasm, numel(amp_TA_spasm));
        fprintf('    MG spasm: %.2f ± %.2f (n=%d)\n', ...
            R(k).meanAmpMG_spasm, R(k).sdAmpMG_spasm, numel(amp_MG_spasm));
    end
end

%% ---- Separate by group and spasm status ----
groups = lower(string({R.group}));
isUninj = groups == "uninjured";
isInj   = groups == "injured";

% For uninjured: only active amplitudes (safely concatenate)
uninj_ampTA_active = safe_vertcat({R(isUninj).ampTA_active});
uninj_ampMG_active = safe_vertcat({R(isUninj).ampMG_active});

% For injured: both active and spasm
inj_ampTA_active = safe_vertcat({R(isInj).ampTA_active});
inj_ampMG_active = safe_vertcat({R(isInj).ampMG_active});

inj_ampTA_spasm = safe_vertcat({R(isInj).ampTA_spasm});
inj_ampMG_spasm = safe_vertcat({R(isInj).ampMG_spasm});

%% ---- Compute means and SDs across all recordings ----
meanTA_uninj = mean(uninj_ampTA_active, 'omitnan');
sdTA_uninj   = std(uninj_ampTA_active, 0, 'omitnan');
meanMG_uninj = mean(uninj_ampMG_active, 'omitnan');
sdMG_uninj   = std(uninj_ampMG_active, 0, 'omitnan');

meanTA_inj_active = mean(inj_ampTA_active, 'omitnan');
sdTA_inj_active   = std(inj_ampTA_active, 0, 'omitnan');
meanMG_inj_active = mean(inj_ampMG_active, 'omitnan');
sdMG_inj_active   = std(inj_ampMG_active, 0, 'omitnan');

meanTA_inj_spasm = mean(inj_ampTA_spasm, 'omitnan');
sdTA_inj_spasm   = std(inj_ampTA_spasm, 0, 'omitnan');
meanMG_inj_spasm = mean(inj_ampMG_spasm, 'omitnan');
sdMG_inj_spasm   = std(inj_ampMG_spasm, 0, 'omitnan');

%% ---- Plot comparison ----
fig = figure('Name', 'Amplitude Comparison: Spasm vs Active', 'NumberTitle', 'off');
fig.Position = [100 100 1200 500];

% TA comparison
ax1 = subplot(1, 2, 1);
hold on;

x_pos = [1, 2, 3];
means_TA = [meanTA_uninj, meanTA_inj_active, meanTA_inj_spasm];
sds_TA   = [sdTA_uninj, sdTA_inj_active, sdTA_inj_spasm];

% Remove NaN values
valid_TA = isfinite(means_TA);
x_pos_TA = x_pos(valid_TA);
means_TA = means_TA(valid_TA);
sds_TA = sds_TA(valid_TA);

bar(x_pos_TA, means_TA, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black', 'LineWidth', 1.5);
errorbar(x_pos_TA, means_TA, sds_TA, 'k.', 'LineWidth', 2, 'CapSize', 8);

ax1.XTick = x_pos_TA;
ax1.XTickLabel = {'Uninjured', 'Injured (Active)', 'Injured (Spasm)'};
ylabel('Amplitude (mV)', 'FontSize', 12);
title('TA Amplitude Comparison', 'FontSize', 14, 'FontWeight', 'bold');
grid on; grid minor;
ax1.YGrid = 'on';
ax1.XGrid = 'off';
set(ax1, 'Color', 'white');

% MG comparison
ax2 = subplot(1, 2, 2);
hold on;

means_MG = [meanMG_uninj, meanMG_inj_active, meanMG_inj_spasm];
sds_MG   = [sdMG_uninj, sdMG_inj_active, sdMG_inj_spasm];

% Remove NaN values
valid_MG = isfinite(means_MG);
x_pos_MG = x_pos(valid_MG);
means_MG = means_MG(valid_MG);
sds_MG = sds_MG(valid_MG);

bar(x_pos_MG, means_MG, 'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'black', 'LineWidth', 1.5);
errorbar(x_pos_MG, means_MG, sds_MG, 'k.', 'LineWidth', 2, 'CapSize', 8);

ax2.XTick = x_pos_MG;
ax2.XTickLabel = {'Uninjured', 'Injured (Active)', 'Injured (Spasm)'};
ylabel('Amplitude (mV)', 'FontSize', 12);
title('MG Amplitude Comparison', 'FontSize', 14, 'FontWeight', 'bold');
grid on; grid minor;
ax2.YGrid = 'on';
ax2.XGrid = 'off';
set(ax2, 'Color', 'white');

sgtitle('Spasm vs Active Period Amplitude', 'FontSize', 16, 'FontWeight', 'bold');

%% ---- Print summary statistics ----
fprintf('\n========== SUMMARY STATISTICS ==========\n');
fprintf('TA - Uninjured Active:  %.2f ± %.2f mV\n', meanTA_uninj, sdTA_uninj);
fprintf('TA - Injured Active:    %.2f ± %.2f mV\n', meanTA_inj_active, sdTA_inj_active);
fprintf('TA - Injured Spasm:     %.2f ± %.2f mV\n', meanTA_inj_spasm, sdTA_inj_spasm);
fprintf('\n');
fprintf('MG - Uninjured Active:  %.2f ± %.2f mV\n', meanMG_uninj, sdMG_uninj);
fprintf('MG - Injured Active:    %.2f ± %.2f mV\n', meanMG_inj_active, sdMG_inj_active);
fprintf('MG - Injured Spasm:     %.2f ± %.2f mV\n', meanMG_inj_spasm, sdMG_inj_spasm);
fprintf('=========================================\n\n');

%% ---- Statistical tests (optional) ----
if ~isnan(meanTA_inj_spasm) && ~isnan(meanTA_inj_active)
    [h_ta, p_ta] = ttest2(inj_ampTA_active, inj_ampTA_spasm);
    fprintf('t-test: TA Active vs TA Spasm: p = %.4f\n', p_ta);
end

if ~isnan(meanMG_inj_spasm) && ~isnan(meanMG_inj_active)
    [h_mg, p_mg] = ttest2(inj_ampMG_active, inj_ampMG_spasm);
    fprintf('t-test: MG Active vs MG Spasm: p = %.4f\n', p_mg);
end

%% ============================================================================
% HELPER FUNCTIONS
%% ============================================================================

function [ampTA, ampMG] = extract_amplitudes_per_contraction(envTA, envMG, actTA, actMG, ~)
% Extract peak amplitude for each contraction (continuous active period)
%
% Input:
%   envTA, envMG: Amplitude envelopes (column vectors)
%   actTA, actMG: Activity masks (true = active)
%   ~: Sampling frequency (unused)
%
% Output:
%   ampTA, ampMG: Column vectors of peak amplitudes for each contraction

    % Find contractions (continuous runs of activity) in TA
    ampTA = extract_peak_amplitudes(envTA, actTA);

    % Find contractions (continuous runs of activity) in MG
    ampMG = extract_peak_amplitudes(envMG, actMG);
end

function peaks = extract_peak_amplitudes(env, mask)
% Find continuous active periods and extract peak amplitude from each
% Applies extra smoothing to the envelope for more robust amplitude estimation
%
% Input:
%   env: Amplitude envelope (column vector)
%   mask: Activity mask (true = active)
%
% Output:
%   peaks: Column vector of peak amplitudes (from smoothed envelope)

    % Ensure column vector
    env = env(:);
    mask = mask(:);

    % Apply additional smoothing to reduce noise and artifacts
    % Use a larger moving average window (100ms at 10kHz = 1000 samples)
    % This helps smooth out noise while preserving true peak amplitudes
    smoothing_window = 1000;  % samples (100 ms at 10 kHz)
    if length(env) > smoothing_window
        env_smooth = movmean(env, smoothing_window, 'omitnan');
    else
        env_smooth = env;  % Skip smoothing if signal too short
    end

    % Find transitions: start and end of each active period
    diff_mask = diff([false; mask; false]);
    starts = find(diff_mask == 1);
    ends = find(diff_mask == -1) - 1;

    % Extract peak from each contraction (from smoothed envelope)
    n_contractions = numel(starts);
    peaks = nan(n_contractions, 1);

    for i = 1:n_contractions
        peaks(i) = max(env_smooth(starts(i):ends(i)));
    end

    % Remove NaN and empty
    peaks(~isfinite(peaks)) = [];
    peaks = peaks(:);
end

function mask = build_interval_mask(N, fs, intervals)
% Build binary mask for time intervals
%
% Input:
%   N: Length of signal
%   fs: Sampling frequency
%   intervals: Nx2 matrix [t_start t_end] in seconds (empty = all true)
%
% Output:
%   mask: Binary column vector

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
        i0 = max(1, floor(t0 * fs) + 1);
        i1 = min(N, floor(t1 * fs));
        if i1 > i0
            mask(i0:i1) = true;
        end
    end
end

function result = safe_vertcat(cell_arrays)
% Safely concatenate cell arrays, handling empty arrays
%
% Input:
%   cell_arrays: Cell array of column vectors (may be empty)
%
% Output:
%   result: Concatenated column vector (empty if all inputs empty)

    % Filter out empty arrays
    non_empty = cellfun(@(x) ~isempty(x), cell_arrays);
    valid_arrays = cell_arrays(non_empty);
    
    if isempty(valid_arrays)
        result = [];
    else
        result = vertcat(valid_arrays{:});
    end
end

