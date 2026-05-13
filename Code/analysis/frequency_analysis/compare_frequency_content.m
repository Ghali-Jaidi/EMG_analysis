function compare_frequency_content()
% compare_frequency_content
% Compare the frequency content of spasm vs gait signals
%
% This function allows you to:
%   1. Load one or more gait recordings (automatically uses ALL active samples)
%   2. Load spasm recording and select time intervals
%   3. Visualize and compare the frequency spectra of TA and MG channels
%
% Workflow:
%   - User selects one or more gait MAT files (uses all active periods automatically)
%   - User selects spasm MAT file and chooses time intervals
%   - Frequency spectra are computed using FFT with Hann windowing
%   - Results displayed in comparative plots (gait vs spasm)
%
% Advantages:
%   - Automatic active period detection for gait (no manual selection needed)
%   - Multiple gait recordings can be combined for better statistical estimates
%   - More robust frequency analysis with more data

clear; clc;

fs = 10000;  % Sampling frequency in Hz

%% ---- Load Gait Recording(s) ----
fprintf('========================================\n');
fprintf('GAIT RECORDING SELECTION\n');
fprintf('========================================\n\n');
fprintf('You can select multiple gait recordings to improve\n');
fprintf('statistical estimates. All active samples will be\n');
fprintf('automatically extracted from each recording.\n\n');

% Ask user if they want multiple gait files
choice = questdlg('Load multiple gait recordings for better estimates?', ...
    'Multiple Gait Files', 'Yes', 'No', 'Yes');

gait_files = {};
gait_data = {};

if strcmp(choice, 'Yes')
    % Load multiple files
    [files, path] = uigetfile('*.mat', 'Select gait MAT files (can select multiple)', ...
        'MultiSelect', 'on');
    
    if isequal(files, 0)
        error('Gait file selection cancelled.');
    end
    
    % Convert single file to cell array for consistent handling
    if ischar(files)
        files = {files};
    end
    
    gait_files = files;
else
    % Load single file
    msgbox('Select a GAIT recording (normal, uninjured movement)', 'Load Gait', 'modal');
    [f_gait, p_gait] = uigetfile('*.mat', 'Select gait MAT file');
    if isequal(f_gait, 0)
        error('Gait file selection cancelled.');
    end
    
    gait_files = {f_gait};
    path = p_gait;
end

% Load all gait recordings and extract active samples
fprintf('\nLoading %d gait recording(s)...\n\n', numel(gait_files));

gait_TA_all = [];
gait_MG_all = [];

for file_idx = 1:numel(gait_files)
    f_gait = gait_files{file_idx};
    fullFile_gait = fullfile(path, f_gait);
    
    fprintf('[%d/%d] Loading: %s\n', file_idx, numel(gait_files), f_gait);
    
    % Load gait data - preprocess to get proper TT structure
    % but skip filtering and rectification for frequency analysis
    [~, srcName_gait, ~] = fileparts(f_gait);
    paramFile_gait = fullfile(path, [srcName_gait, '_param.mat']);
    if isfile(paramFile_gait)
        tmp = load(paramFile_gait, 'P');
        P = tmp.P;
    else
        P = default_emg_parameters();
    end
    
    % Call preprocess but without filtering/rectification
    % by using minimal processing options
    try
        [TT_gait, snr_gait, ~] = preprocess_and_label(P, fs, ...
            'fullFile', fullFile_gait, ...
            'plot_figures', false, ...
            'save_figures', false, ...
            'skip_filter', true, ...
            'skip_rectify', true);
    catch
        % If the skip options don't exist, try alternative approach
        % Load the file and create minimal TT structure
        fprintf('  Creating minimal TT structure (no filters/rectification)...\n');
        data = load(fullFile_gait);
        
        % Try to find signal columns - multiple formats supported
        TA_raw = [];
        MG_raw = [];
        
        % Format 1: Standard format with data__chan_X_rec_Y fields
        fieldnames_data = fieldnames(data);
        rec_fields = fieldnames_data(~cellfun(@isempty, regexp(fieldnames_data, 'data__chan_\d_rec_\d', 'match')));
        
        if ~isempty(rec_fields)
            % Found standard format - ask user to select recording
            % Extract recording numbers
            rec_nums = [];
            expr = '^data__chan_1_rec_(\d+)$';
            for i = 1:numel(rec_fields)
                tok = regexp(rec_fields{i}, expr, 'tokens');
                if ~isempty(tok)
                    rec_nums(end+1) = str2double(tok{1}{1}); %#ok<AGROW>
                end
            end
            rec_nums = unique(rec_nums);
            
            if ~isempty(rec_nums)
                % Ask user which recording to use
                if numel(rec_nums) == 1
                    selected_rec = rec_nums(1);
                    fprintf('  Using recording %d\n', selected_rec);
                else
                    recLabels = arrayfun(@(r) sprintf('Recording %d', r), rec_nums, 'UniformOutput', false);
                    [idx, ok] = listdlg('PromptString', sprintf('Select recording from %s:', f_gait), ...
                                        'SelectionMode', 'single', ...
                                        'ListString', recLabels);
                    if ~ok, error('Recording selection cancelled.'); end
                    selected_rec = rec_nums(idx);
                end
                
                % Extract selected recording
                v1 = sprintf('data__chan_1_rec_%d', selected_rec);
                v2 = sprintf('data__chan_2_rec_%d', selected_rec);
                TA_raw = data.(v1)(:);
                MG_raw = data.(v2)(:);
            end
        end
        
        % Format 2: Direct 'data' field with columns
        if isempty(TA_raw) && isfield(data, 'data')
            raw_data = data.data;
            if size(raw_data, 2) >= 2
                TA_raw = raw_data(:, 1);
                MG_raw = raw_data(:, 2);
            end
        end
        
        % Format 3: data_matrix field
        if isempty(TA_raw) && isfield(data, 'data_matrix')
            raw_data = data.data_matrix;
            if size(raw_data, 2) >= 2
                TA_raw = raw_data(:, 1);
                MG_raw = raw_data(:, 2);
            end
        end
        
        % Format 4: Individual channel variables (TA_V, MG_V)
        if isempty(TA_raw) && isfield(data, 'TA_V')
            TA_raw = data.TA_V(:);
            if isfield(data, 'MG_V')
                MG_raw = data.MG_V(:);
            end
        end
        
        % Check if we found the data
        if isempty(TA_raw) || isempty(MG_raw)
            error('Cannot identify signal columns in file. Available fields: %s', ...
                sprintf('%s ', fieldnames_data{:}));
        end
        
        % Create minimal TT structure for frequency analysis
        N_gait = numel(TA_raw);
        time_vector = (0:N_gait-1)' / fs;
        
        TT_gait = timetable(seconds(time_vector), TA_raw, MG_raw, ...
            'VariableNames', {'TA_raw', 'MG_raw'});
        
        % Create activity mask (use all data as active)
        snr_gait.is_act = true(N_gait, 1);
        snr_gait.is_act_MG = true(N_gait, 1);
        fprintf('  Warning: Using all samples as active (no SNR analysis)\n');
    end
    
    % Get recording duration
    N_gait = numel(TT_gait.TA_raw);
    duration_gait = N_gait / fs;
    
    fprintf('  Duration: %.2f seconds\n', duration_gait);
    
    % Extract ALL active samples for TA and MG using RAW signals
    % TA: extract all samples where is_act = 1
    TA_active_mask = snr_gait.is_act == 1;
    TA_active = TT_gait.TA_raw(TA_active_mask);
    
    % MG: extract all samples where is_act_MG = 1
    MG_active_mask = snr_gait.is_act_MG == 1;
    MG_active = TT_gait.MG_raw(MG_active_mask);
    
    % Calculate active percentages
    pct_TA = 100 * sum(TA_active_mask) / N_gait;
    pct_MG = 100 * sum(MG_active_mask) / N_gait;
    
    fprintf('  ✓ TA active: %.1f%% (%.2f sec)\n', pct_TA, numel(TA_active)/fs);
    fprintf('  ✓ MG active: %.1f%% (%.2f sec)\n\n', pct_MG, numel(MG_active)/fs);
    
    % Concatenate with previous recordings
    gait_TA_all = [gait_TA_all; TA_active(:)];
    gait_MG_all = [gait_MG_all; MG_active(:)];
    
    % Store for reference
    gait_data{file_idx}.filename = f_gait;
    gait_data{file_idx}.TA_active = numel(TA_active);
    gait_data{file_idx}.MG_active = numel(MG_active);
end

fprintf('========================================\n');
fprintf('GAIT SUMMARY (all recordings combined):\n');
fprintf('========================================\n');
fprintf('Total gait TA samples: %d (%.2f sec)\n', numel(gait_TA_all), numel(gait_TA_all)/fs);
fprintf('Total gait MG samples: %d (%.2f sec)\n\n', numel(gait_MG_all), numel(gait_MG_all)/fs);

%% ---- Load Spasm Recording ----
msgbox('Select a SPASM recording (with spasm events)', 'Load Spasm', 'modal');
[f_spasm, p_spasm] = uigetfile('*.mat', 'Select spasm MAT file');
if isequal(f_spasm, 0)
    error('Spasm file selection cancelled.');
end

fullFile_spasm = fullfile(p_spasm, f_spasm);
fprintf('\n========================================\n');
fprintf('Loading SPASM recording: %s\n', f_spasm);
fprintf('========================================\n');

% Load spasm data - preprocess to get proper TT structure
% but skip filtering and rectification for frequency analysis
[~, srcName_spasm, ~] = fileparts(f_spasm);
paramFile_spasm = fullfile(p_spasm, [srcName_spasm, '_param.mat']);
if isfile(paramFile_spasm)
    tmp = load(paramFile_spasm, 'P');
    P_spasm = tmp.P;
else
    P_spasm = default_emg_parameters();
end

% Call preprocess but without filtering/rectification
try
    [TT_spasm, ~, ~] = preprocess_and_label(P_spasm, fs, ...
        'fullFile', fullFile_spasm, ...
        'plot_figures', false, ...
        'save_figures', false, ...
        'skip_filter', true, ...
        'skip_rectify', true);
catch
    % If the skip options don't exist, try alternative approach
    % Load the file and create minimal TT structure
    fprintf('  Creating minimal TT structure (no filters/rectification)...\n');
    data = load(fullFile_spasm);
    
    % Try to find signal columns - multiple formats supported
    TA_raw = [];
    MG_raw = [];
    
    % Format 1: Standard format with data__chan_X_rec_Y fields
    fieldnames_data = fieldnames(data);
    rec_fields = fieldnames_data(~cellfun(@isempty, regexp(fieldnames_data, 'data__chan_\d_rec_\d', 'match')));
    
    if ~isempty(rec_fields)
        % Found standard format - ask user to select recording
        % Extract recording numbers
        rec_nums = [];
        expr = '^data__chan_1_rec_(\d+)$';
        for i = 1:numel(rec_fields)
            tok = regexp(rec_fields{i}, expr, 'tokens');
            if ~isempty(tok)
                rec_nums(end+1) = str2double(tok{1}{1}); %#ok<AGROW>
            end
        end
        rec_nums = unique(rec_nums);
        
        if ~isempty(rec_nums)
            % Ask user which recording to use
            if numel(rec_nums) == 1
                selected_rec = rec_nums(1);
                fprintf('  Using recording %d\n', selected_rec);
            else
                recLabels = arrayfun(@(r) sprintf('Recording %d', r), rec_nums, 'UniformOutput', false);
                [idx, ok] = listdlg('PromptString', sprintf('Select recording from %s:', f_spasm), ...
                                    'SelectionMode', 'single', ...
                                    'ListString', recLabels);
                if ~ok, error('Recording selection cancelled.'); end
                selected_rec = rec_nums(idx);
            end
            
            % Extract selected recording
            v1 = sprintf('data__chan_1_rec_%d', selected_rec);
            v2 = sprintf('data__chan_2_rec_%d', selected_rec);
            TA_raw = data.(v1)(:);
            MG_raw = data.(v2)(:);
        end
    end
    
    % Format 2: Direct 'data' field with columns
    if isempty(TA_raw) && isfield(data, 'data')
        raw_data = data.data;
        if size(raw_data, 2) >= 2
            TA_raw = raw_data(:, 1);
            MG_raw = raw_data(:, 2);
        end
    end
    
    % Format 3: data_matrix field
    if isempty(TA_raw) && isfield(data, 'data_matrix')
        raw_data = data.data_matrix;
        if size(raw_data, 2) >= 2
            TA_raw = raw_data(:, 1);
            MG_raw = raw_data(:, 2);
        end
    end
    
    % Format 4: Individual channel variables (TA_V, MG_V)
    if isempty(TA_raw) && isfield(data, 'TA_V')
        TA_raw = data.TA_V(:);
        if isfield(data, 'MG_V')
            MG_raw = data.MG_V(:);
        end
    end
    
    % Check if we found the data
    if isempty(TA_raw) || isempty(MG_raw)
        error('Cannot identify signal columns in file. Available fields: %s', ...
            sprintf('%s ', fieldnames_data{:}));
    end
    
    % Create minimal TT structure for frequency analysis
    N_spasm = numel(TA_raw);
    time_vector = (0:N_spasm-1)' / fs;
    
    TT_spasm = timetable(seconds(time_vector), TA_raw, MG_raw, ...
        'VariableNames', {'TA_raw', 'MG_raw'});
end

% Get recording duration
N_spasm = numel(TT_spasm.TA_raw);
duration_spasm = N_spasm / fs;

fprintf('Spasm recording duration: %.2f seconds\n', duration_spasm);
fprintf('Select one or more time intervals from spasm for analysis.\n');

% Let user select intervals
spasm_intervals = select_signal_intervals(duration_spasm, 'Spasm');

%% ---- Extract Signal Segments ----
fprintf('\n========================================\n');
fprintf('Processing segments for frequency analysis...\n');
fprintf('========================================\n\n');

% For GAIT: All active samples have already been extracted and concatenated
fprintf('GAIT segments (all recordings combined):\n');
fprintf('  ✓ TA active samples: %d (%.2f sec)\n', numel(gait_TA_all), numel(gait_TA_all)/fs);
fprintf('  ✓ MG active samples: %d (%.2f sec)\n\n', numel(gait_MG_all), numel(gait_MG_all)/fs);

% For SPASM: Extract entire specified intervals (no activity filtering)
fprintf('SPASM segments (user-selected intervals):\n');

spasm_TA_segments = extract_segments(TT_spasm.TA_raw, fs, spasm_intervals);
spasm_MG_segments = extract_segments(TT_spasm.MG_raw, fs, spasm_intervals);

% Concatenate spasm segments
if isempty(spasm_TA_segments)
    error('No spasm TA data extracted. Check your interval selection.');
end
if isempty(spasm_MG_segments)
    error('No spasm MG data extracted. Check your interval selection.');
end

spasm_TA_concat = vertcat(spasm_TA_segments{:});
spasm_MG_concat = vertcat(spasm_MG_segments{:});

fprintf('  ✓ Spasm TA: %d segments, total %.2f seconds\n', ...
    numel(spasm_TA_segments), numel(spasm_TA_concat)/fs);
fprintf('  ✓ Spasm MG: %d segments, total %.2f seconds\n\n', ...
    numel(spasm_MG_segments), numel(spasm_MG_concat)/fs);

%% ---- Compute Frequency Spectra ----
fprintf('\nComputing frequency spectra...\n');

[f_gait_TA, P_gait_TA] = compute_fft_spectrum(gait_TA_all, fs);
[f_gait_MG, P_gait_MG] = compute_fft_spectrum(gait_MG_all, fs);
[f_spasm_TA, P_spasm_TA] = compute_fft_spectrum(spasm_TA_concat, fs);
[f_spasm_MG, P_spasm_MG] = compute_fft_spectrum(spasm_MG_concat, fs);

% Interpolate all spectra to a common frequency grid for fair comparison
% Use the finest resolution available
max_freq_len = max([numel(f_gait_TA), numel(f_gait_MG), numel(f_spasm_TA), numel(f_spasm_MG)]);
f_common = linspace(0, fs/2, max_freq_len)';

% Interpolate all power spectra to common frequency grid
P_gait_TA = interp1(f_gait_TA, P_gait_TA, f_common, 'linear', 0);
P_gait_MG = interp1(f_gait_MG, P_gait_MG, f_common, 'linear', 0);
P_spasm_TA = interp1(f_spasm_TA, P_spasm_TA, f_common, 'linear', 0);
P_spasm_MG = interp1(f_spasm_MG, P_spasm_MG, f_common, 'linear', 0);

f = f_common;

% Add small floor to prevent log(0) and make visualization clearer
% This is purely for visualization, doesn't affect data
floor_val = max([P_gait_TA; P_gait_MG; P_spasm_TA; P_spasm_MG]) / 10000;
P_gait_TA_vis = max(P_gait_TA, floor_val);
P_gait_MG_vis = max(P_gait_MG, floor_val);
P_spasm_TA_vis = max(P_spasm_TA, floor_val);
P_spasm_MG_vis = max(P_spasm_MG, floor_val);

%% ---- Visualization ----
fprintf('Creating comparison plots...\n\n');

% Create figure with 2x2 subplots
fig = figure('Name', 'Frequency Content: Gait vs Spasm', 'NumberTitle', 'off');
set(fig, 'Position', [100 100 1200 800]);

% TA Comparison
subplot(2, 2, 1);
hold on;
plot(f, P_gait_TA, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Gait');
plot(f, P_spasm_TA, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Spasm');
xlabel('Frequency (Hz)');
ylabel('Power');
title('TA (Tibialis Anterior) - Frequency Content');
legend('Location', 'best');
grid on;
xlim([0 1000]);
hold off;

% MG Comparison
subplot(2, 2, 2);
hold on;
plot(f, P_gait_MG, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Gait');
plot(f, P_spasm_MG, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Spasm');
xlabel('Frequency (Hz)');
ylabel('Power');
title('MG (Medial Gastrocnemius) - Frequency Content');
legend('Location', 'best');
grid on;
xlim([0 1000]);
hold off;

% TA Log Scale
subplot(2, 2, 3);
hold on;
semilogy(f, P_gait_TA_vis, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Gait');
semilogy(f, P_spasm_TA_vis, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Spasm');
xlabel('Frequency (Hz)');
ylabel('Power (log scale)');
title('TA - Frequency Content (log scale)');
legend('Location', 'best');
grid on;
set(gca, 'YScale', 'log');  % Ensure log scale is applied
xlim([0 1000]);
hold off;

% MG Log Scale
subplot(2, 2, 4);
hold on;
semilogy(f, P_gait_MG_vis, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Gait');
semilogy(f, P_spasm_MG_vis, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Spasm');
xlabel('Frequency (Hz)');
ylabel('Power (log scale)');
title('MG - Frequency Content (log scale)');
legend('Location', 'best');
grid on;
set(gca, 'YScale', 'log');  % Ensure log scale is applied
xlim([0 1000]);
hold off;

%% ---- Summary Statistics ----
fprintf('\n========================================\n');
fprintf('FREQUENCY ANALYSIS SUMMARY\n');
fprintf('========================================\n\n');
fprintf('NOTE: Gait analysis includes ONLY active periods\n');
fprintf('      (TA and MG analyzed separately during their activity)\n');
fprintf('      Spasm analysis includes entire selected intervals\n\n');

fprintf('--- TA (Tibialis Anterior) ---\n');
print_spectrum_stats(f, P_gait_TA, 'Gait TA (active periods only)');
print_spectrum_stats(f, P_spasm_TA, 'Spasm TA (entire interval)');

fprintf('\n--- MG (Medial Gastrocnemius) ---\n');
print_spectrum_stats(f, P_gait_MG, 'Gait MG (active periods only)');
print_spectrum_stats(f, P_spasm_MG, 'Spasm MG (entire interval)');

fprintf('\n========================================\n');

end

%% ========== HELPER FUNCTIONS ==========

function intervals = select_signal_intervals(duration, label)
% Let user select one or more time intervals interactively
%
% Returns: intervals = Nx2 array where each row is [t_start, t_end]

intervals = [];
interval_count = 0;

while true
    interval_count = interval_count + 1;
    
    prompt = sprintf(...
        'Interval %d of %s recording (duration: %.2f s):\nEnter [start_sec end_sec]\nOr press Cancel to finish.', ...
        interval_count, label, duration);
    
    answer = inputdlg(prompt, 'Select Time Interval', [1 50], ...
        {sprintf('0 %.1f', min(5, duration))});
    
    if isempty(answer)
        % User clicked Cancel
        if interval_count == 1
            error('At least one interval must be selected.');
        else
            break;  % Finish collecting intervals
        end
    end
    
    % Parse input
    try
        vals = str2num(answer{1});
        if numel(vals) ~= 2
            error('Must enter exactly 2 values.');
        end
        t_start = vals(1);
        t_end = vals(2);
    catch
        msgbox('Invalid input. Please enter two numbers separated by space or comma.', ...
            'Input Error', 'modal');
        interval_count = interval_count - 1;
        continue;
    end
    
    % Validate
    if t_start < 0 || t_end > duration || t_start >= t_end
        msgbox(sprintf('Invalid interval. Must satisfy: 0 <= start < end <= %.2f', duration), ...
            'Range Error', 'modal');
        interval_count = interval_count - 1;
        continue;
    end
    
    intervals = [intervals; t_start, t_end];
    fprintf('  ✓ Interval %d: %.2f - %.2f s (duration: %.2f s)\n', interval_count, t_start, t_end, t_end - t_start);
end

end

function segments = extract_segments(signal, fs, intervals)
% Extract multiple time intervals from a signal
%
% Returns: segments = cell array of signal segments

segments = {};
for k = 1:size(intervals, 1)
    t_start = intervals(k, 1);
    t_end = intervals(k, 2);
    
    start_idx = round(t_start * fs) + 1;
    end_idx = round(t_end * fs);
    
    % Clamp to valid range
    start_idx = max(1, start_idx);
    end_idx = min(numel(signal), end_idx);
    
    segment = signal(start_idx:end_idx);
    segments{k} = segment(:);
end

end

function [f, P] = compute_fft_spectrum(signal, fs)
% Compute one-sided amplitude spectrum using FFT with Hann windowing
%
% Inputs:
%   signal : signal vector
%   fs     : sampling frequency
%
% Outputs:
%   f : frequency vector (Hz)
%   P : one-sided power spectrum

signal = signal(:);
N = length(signal);

% Remove DC
signal = signal - mean(signal);

% Apply Hann window
w = hann(N);
signal = signal .* w;

% FFT
X = fft(signal);

% One-sided amplitude spectrum
P2 = abs(X) / N;
P = P2(1:floor(N/2)+1);
P(2:end-1) = 2 * P(2:end-1);

% Frequency axis (must match length of P)
f = fs * (0:length(P)-1) / N;

end

function print_spectrum_stats(f, P, label)
% Print summary statistics for a frequency spectrum

% Find peak frequency
[peak_power, peak_idx] = max(P);
peak_freq = f(peak_idx);

% Compute mean frequency
mean_freq = sum(f .* P) / sum(P);

% Compute median frequency
cumsum_P = cumsum(P);
median_freq = f(find(cumsum_P >= cumsum_P(end)/2, 1));

% Power in common EMG bands
power_band_20_100 = mean(P(f >= 20 & f <= 100));
power_band_100_200 = mean(P(f >= 100 & f <= 200));
power_band_200_400 = mean(P(f >= 200 & f <= 400));

fprintf('  %s:\n', label);
fprintf('    Peak frequency: %.1f Hz (power: %.4f)\n', peak_freq, peak_power);
fprintf('    Mean frequency: %.1f Hz\n', mean_freq);
fprintf('    Median frequency: %.1f Hz\n', median_freq);
fprintf('    Power [20-100 Hz]:   %.4f\n', power_band_20_100);
fprintf('    Power [100-200 Hz]:  %.4f\n', power_band_100_200);
fprintf('    Power [200-400 Hz]:  %.4f\n', power_band_200_400);

end
