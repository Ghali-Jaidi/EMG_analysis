function batch_spectral_analysis()
% batch_spectral_analysis
% Automated comparison of multiple spasm vs gait pairs
%
% This function allows analysis of multiple recordings in batch mode,
% automatically computing and storing spectral statistics.

clear; clc;

fs = 10000;

%% Setup
fprintf('========================================\n');
fprintf('BATCH SPECTRAL ANALYSIS\n');
fprintf('========================================\n\n');

% Ask how many pairs to analyze
answer = inputdlg('How many gait-spasm pairs to analyze?', 'Batch Size', [1 40], {'1'});
if isempty(answer), return; end
n_pairs = str2double(answer{1});

% Storage
results = struct( ...
    'pair', {}, 'gait_file', {}, 'spasm_file', {}, ...
    'gait_intervals', {}, 'spasm_intervals', {}, ...
    'peak_freq_ta_gait', {}, 'peak_freq_ta_spasm', {}, ...
    'peak_freq_mg_gait', {}, 'peak_freq_mg_spasm', {}, ...
    'mean_freq_ta_gait', {}, 'mean_freq_ta_spasm', {}, ...
    'mean_freq_mg_gait', {}, 'mean_freq_mg_spasm', {} ...
);

%% Process each pair
for pair_idx = 1:n_pairs
    
    fprintf('\n--- PAIR %d of %d ---\n', pair_idx, n_pairs);
    
    % Load gait
    msgbox(sprintf('Pair %d: Select GAIT recording', pair_idx), 'Load Gait', 'modal');
    [f_gait, p_gait] = uigetfile('*.mat', sprintf('Gait file (pair %d)', pair_idx));
    if isequal(f_gait, 0), warning('Pair %d cancelled.', pair_idx); continue; end
    
    fullFile_gait = fullfile(p_gait, f_gait);
    [~, srcName_gait, ~] = fileparts(f_gait);
    paramFile_gait = fullfile(p_gait, [srcName_gait, '_param.mat']);
    if isfile(paramFile_gait)
        P = load(paramFile_gait, 'P').P;
    else
        P = default_emg_parameters();
    end
    
    [TT_gait, ~, ~] = preprocess_and_label(P, fs, 'fullFile', fullFile_gait, ...
        'plot_figures', false, 'save_figures', false);
    
    % Load spasm
    msgbox(sprintf('Pair %d: Select SPASM recording', pair_idx), 'Load Spasm', 'modal');
    [f_spasm, p_spasm] = uigetfile('*.mat', sprintf('Spasm file (pair %d)', pair_idx));
    if isequal(f_spasm, 0), warning('Pair %d cancelled.', pair_idx); continue; end
    
    fullFile_spasm = fullfile(p_spasm, f_spasm);
    [~, srcName_spasm, ~] = fileparts(f_spasm);
    paramFile_spasm = fullfile(p_spasm, [srcName_spasm, '_param.mat']);
    if isfile(paramFile_spasm)
        P = load(paramFile_spasm, 'P').P;
    else
        P = default_emg_parameters();
    end
    
    [TT_spasm, ~, ~] = preprocess_and_label(P, fs, 'fullFile', fullFile_spasm, ...
        'plot_figures', false, 'save_figures', false);
    
    % Select intervals
    duration_gait = numel(TT_gait.TA_rect) / fs;
    duration_spasm = numel(TT_spasm.TA_rect) / fs;
    
    fprintf('  Gait: %.1f s, Spasm: %.1f s\n', duration_gait, duration_spasm);
    
    gait_intervals = select_signal_intervals(duration_gait, 'Gait');
    spasm_intervals = select_signal_intervals(duration_spasm, 'Spasm');
    
    % Extract and compute
    gait_TA_segs = extract_segments(TT_gait.TA_rect, fs, gait_intervals);
    gait_MG_segs = extract_segments(TT_gait.MG_rect, fs, gait_intervals);
    spasm_TA_segs = extract_segments(TT_spasm.TA_rect, fs, spasm_intervals);
    spasm_MG_segs = extract_segments(TT_spasm.MG_rect, fs, spasm_intervals);
    
    gait_TA = vertcat(gait_TA_segs{:});
    gait_MG = vertcat(gait_MG_segs{:});
    spasm_TA = vertcat(spasm_TA_segs{:});
    spasm_MG = vertcat(spasm_MG_segs{:});
    
    % Compute spectra
    [f, P_gait_TA] = compute_fft_spectrum(gait_TA, fs);
    [~, P_gait_MG] = compute_fft_spectrum(gait_MG, fs);
    [~, P_spasm_TA] = compute_fft_spectrum(spasm_TA, fs);
    [~, P_spasm_MG] = compute_fft_spectrum(spasm_MG, fs);
    
    % Extract key metrics
    [~, idx_ta_g] = max(P_gait_TA);
    [~, idx_ta_s] = max(P_spasm_TA);
    [~, idx_mg_g] = max(P_gait_MG);
    [~, idx_mg_s] = max(P_spasm_MG);
    
    peak_f_gait_ta = f(idx_ta_g);
    peak_f_spasm_ta = f(idx_ta_s);
    peak_f_gait_mg = f(idx_mg_g);
    peak_f_spasm_mg = f(idx_mg_s);
    
    mean_freq_gait_ta = sum(f .* P_gait_TA) / sum(P_gait_TA);
    mean_freq_spasm_ta = sum(f .* P_spasm_TA) / sum(P_spasm_TA);
    mean_freq_gait_mg = sum(f .* P_gait_MG) / sum(P_gait_MG);
    mean_freq_spasm_mg = sum(f .* P_spasm_MG) / sum(P_spasm_MG);
    
    % Store results
    results(pair_idx).pair = pair_idx;
    results(pair_idx).gait_file = f_gait;
    results(pair_idx).spasm_file = f_spasm;
    results(pair_idx).peak_freq_ta_gait = peak_f_gait_ta;
    results(pair_idx).peak_freq_ta_spasm = peak_f_spasm_ta;
    results(pair_idx).peak_freq_mg_gait = peak_f_gait_mg;
    results(pair_idx).peak_freq_mg_spasm = peak_f_spasm_mg;
    results(pair_idx).mean_freq_ta_gait = mean_freq_gait_ta;
    results(pair_idx).mean_freq_ta_spasm = mean_freq_spasm_ta;
    results(pair_idx).mean_freq_mg_gait = mean_freq_gait_mg;
    results(pair_idx).mean_freq_mg_spasm = mean_freq_spasm_mg;
    
    fprintf('  ✓ Peak freq TA: Gait=%.1f Hz, Spasm=%.1f Hz (Δ%.1f Hz)\n', ...
        peak_f_gait_ta, peak_f_spasm_ta, peak_f_spasm_ta - peak_f_gait_ta);
    fprintf('  ✓ Peak freq MG: Gait=%.1f Hz, Spasm=%.1f Hz (Δ%.1f Hz)\n', ...
        peak_f_gait_mg, peak_f_spasm_mg, peak_f_spasm_mg - peak_f_gait_mg);
    
end

%% Print Summary Table
fprintf('\n\n========================================\n');
fprintf('BATCH ANALYSIS SUMMARY\n');
fprintf('========================================\n\n');

fprintf('%-4s  %-8s  %-8s  %-8s  %-8s  %-8s  %-8s\n', ...
    'Pair', 'PF_TA_G', 'PF_TA_S', 'Δ TA', 'PF_MG_G', 'PF_MG_S', 'Δ MG');
fprintf('-%-3s  -%-7s  -%-7s  -%-7s  -%-7s  -%-7s  -%-7s\n', ...
    repmat('-', 1, 3), repmat('-', 1, 7), repmat('-', 1, 7), repmat('-', 1, 7), ...
    repmat('-', 1, 7), repmat('-', 1, 7), repmat('-', 1, 7));

for k = 1:length(results)
    if ~isempty(results(k).pair)
        fprintf('%4d  %8.1f  %8.1f  %8.1f  %8.1f  %8.1f  %8.1f\n', ...
            results(k).pair, ...
            results(k).peak_freq_ta_gait, ...
            results(k).peak_freq_ta_spasm, ...
            results(k).peak_freq_ta_spasm - results(k).peak_freq_ta_gait, ...
            results(k).peak_freq_mg_gait, ...
            results(k).peak_freq_mg_spasm, ...
            results(k).peak_freq_mg_spasm - results(k).peak_freq_mg_gait);
    end
end

% Save results
save_it = questdlg('Save results to file?', 'Save Results', 'Yes', 'No', 'Yes');
if strcmp(save_it, 'Yes')
    [f_out, p_out] = uiputfile('*.mat', 'Save batch results');
    if ~isequal(f_out, 0)
        fullFile_out = fullfile(p_out, f_out);
        save(fullFile_out, 'results');
        fprintf('\nResults saved to: %s\n', fullFile_out);
    end
end

fprintf('\n========================================\n');

end

%% Helper functions (duplicated from compare_frequency_content)

function intervals = select_signal_intervals(duration, ~)
intervals = [];
count = 0;
while true
    count = count + 1;
    answer = inputdlg(sprintf(['Interval %d (duration: %.1f s):\n' ...
        'Enter [start_sec end_sec] or Cancel to finish'], count, duration), ...
        'Select Interval', [1 50], {sprintf('0 %.1f', min(5, duration))});
    
    if isempty(answer)
        if count == 1, error('At least one interval required.'); end
        break;
    end
    
    try
        vals = str2num(answer{1});
        if numel(vals) ~= 2, error('Need 2 values'); end
        t_start = vals(1); t_end = vals(2);
        if t_start < 0 || t_end > duration || t_start >= t_end, error('Invalid range'); end
        intervals = [intervals; t_start, t_end];
        fprintf('  ✓ Interval %d: %.2f - %.2f s\n', count, t_start, t_end);
    catch
        msgbox('Invalid input', 'Error', 'modal');
        count = count - 1;
    end
end
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

function [f, P] = compute_fft_spectrum(signal, fs)
signal = signal(:);
N = length(signal);
signal = signal - mean(signal);
w = hann(N);
signal = signal .* w;
X = fft(signal);
P2 = abs(X) / N;
P = P2(1:floor(N/2)+1);
P(2:end-1) = 2 * P(2:end-1);
f = fs * (0:length(P)-1) / N;
end
