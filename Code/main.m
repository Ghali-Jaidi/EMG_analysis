function main
% EMG Analysis Pipeline - Main Entry Point
% 
% This function provides a menu-driven interface for accessing all EMG analysis
% workflows. Users can preprocess data, detect spasms, analyze frequency content,
% extract features, and visualize results.
%
% Usage:
%   main
%   
% This launches an interactive menu in the MATLAB command window.

% =========================================================================
% Setup: Add all subfolders to MATLAB path
% =========================================================================
current_dir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(current_dir, 'preprocessing')));
addpath(genpath(fullfile(current_dir, 'detection')));
addpath(genpath(fullfile(current_dir, 'analysis')));
addpath(genpath(fullfile(current_dir, 'visualization')));
addpath(genpath(fullfile(current_dir, 'utilities')));
addpath(genpath(fullfile(current_dir, 'tests')));
addpath(genpath(fullfile(current_dir, 'data')));
addpath(genpath(fullfile(current_dir, 'config')));

fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                 EMG ANALYSIS PIPELINE v1.0                    ║\n');
fprintf('║         Interactive Menu for Signal Processing & Analysis      ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

% =========================================================================
% Main Menu Loop
% =========================================================================
while true
    fprintf('\n--- MAIN MENU ---\n');
    fprintf('1. Preprocess single recording file\n');
    fprintf('2. Spasm detection & analysis (single recording)\n');
    fprintf('3. Frequency analysis (spectral features)\n');
    fprintf('4. Cross-recording group analyses (multiple files)\n');
    fprintf('5. Run validation tests\n');
    fprintf('6. Launch GUI interface\n');
    fprintf('7. Display help & documentation\n');
    fprintf('0. Exit\n');
    fprintf('\n');
    
    choice = input('Select an option (0-7): ', 's');
    
    switch choice
        case '1'
            run_single_file_preprocessing();
            
        case '2'
            run_spasm_detection_menu();
            
        case '3'
            run_frequency_analysis_menu();
            
        case '4'
            run_feature_extraction_menu();
            
        case '5'
            run_validation_tests_menu();
            
        case '6'
            run_gui_interface();
            
        case '7'
            display_help_menu();
            
        case '0'
            fprintf('\nGoodbye!\n');
            return;
            
        otherwise
            fprintf('Invalid choice. Please enter 0-7.\n');
    end
end

end

% =========================================================================
% PREPROCESSING
% =========================================================================
function [TT, snrValue] = run_single_file_preprocessing()
    TT = [];  % Initialize as empty
    fprintf('\n--- PREPROCESS SINGLE FILE ---\n');
    
    % File selection
    [filename, filepath] = uigetfile({'*.csv;*.mat', 'EMG Files (*.csv, *.mat)'; '*.*', 'All Files (*.*)'}, 'Select EMG recording');
    if isequal(filename, 0)
        fprintf('File selection cancelled.\n');
        return;
    end
    filepath_full = fullfile(filepath, filename);
    
    % Get default parameters
    P = default_emg_parameters();
    
    % Preprocessing options
    fprintf('\nPreprocessing options:\n');
    fprintf('1. Show plots during preprocessing\n');
    fprintf('2. Skip plots\n');
    plot_choice = input('Choice (1-2) [default: 1]: ', 's');
    if isempty(plot_choice), plot_choice = '1'; end
    
    plot_choice_num = str2double(plot_choice);
    if isnan(plot_choice_num) || plot_choice_num < 1 || plot_choice_num > 2
        plot_choice_num = 1;
    end
    plot_figs = (plot_choice_num == 1);
    
    % Preprocessing
    fprintf('\nPreprocessing... ');
    try
        [TT, snrValue, ~, ~] = preprocess_and_label(P, 10000, 'plot_figures', plot_figs, 'fullFile', filepath_full);
        fprintf('Done!\n');
        
        % Display summary
        fprintf('\nPreprocessing Summary:\n');
        fprintf('  File: %s\n', filename);
        fprintf('  Duration: %.2f seconds\n', height(TT) / 10000);
        fprintf('  Sampling rate: 10000 Hz\n');
        
        % Check if activity masks exist
        if istimetable(TT) && ismember('TA_env', TT.Properties.VariableNames)
            fprintf('  Preprocessing completed successfully.\n');
        end
        
        % If plots were generated, pause briefly so user can see them
        if plot_figs
            % Give plots time to render on screen
            pause(2);
        end
        
        % Optionally save
        save_choice = input('\nSave preprocessed data? (y/n) [default: y]: ', 's');
        if isempty(save_choice) || lower(save_choice) == 'y'
            [save_name, save_path] = uiputfile('*.mat', 'Save as', 'TT_preprocessed.mat');
            if ~isequal(save_name, 0)
                % Save snrValue alongside TT: the spasm/stim analyses need its
                % activity and rest masks. Saving only TT would force a re-run.
                save(fullfile(save_path, save_name), 'TT', 'snrValue', '-v7.3');
                fprintf('Saved to: %s\n', fullfile(save_path, save_name));
            end
        end
        
        fprintf('\nTT structure ready for analysis!\n');
        fprintf('DEBUG: Returning TT with %d samples.\n', height(TT));
        
    catch ME
        fprintf('Error during preprocessing: %s\n', ME.message);
        TT = [];
        return;
    end
end

% =========================================================================
% SPASM DETECTION
% =========================================================================
function run_spasm_detection_menu()
    fprintf('\n--- SPASM DETECTION & ANALYSIS ---\n');
    
    % Load or preprocess
    [TT, snrValue, success] = load_or_preprocess();
    if ~success, return; end

    % Defaults sourced from the central config
    P = default_emg_parameters();

    % Get spasm detection percentile thresholds
    fprintf('\nSpasm detection uses percentile thresholds of active amplitudes.\n');
    fprintf('Higher percentile = stricter spasm detection (fewer events detected).\n');
    fprintf('\nEnter spasm percentile for TA (default %g): ', P.spasm.prc_TA);
    ta_input = input('', 's');
    if isempty(ta_input)
        spasm_prc_ta = P.spasm.prc_TA;
    else
        spasm_prc_ta = str2double(ta_input);
    end

    fprintf('Enter spasm percentile for MG (default %g): ', P.spasm.prc_MG);
    mg_input = input('', 's');
    if isempty(mg_input)
        spasm_prc_mg = P.spasm.prc_MG;
    else
        spasm_prc_mg = str2double(mg_input);
    end
    
    % Analysis choice
    fprintf('\nSelect analysis type:\n');
    fprintf('1. State-stratified amplitude: Spasm/Active/Rest x Stim ON/OFF\n');
    fprintf('2. Stimulated vs unstimulated spasms (matched-window amplitude)\n');
    fprintf('3. TA-MG correlation\n');
    choice = input('Choice (1-3): ', 's');

    % Sampling frequency (from central config)
    fs = P.fs;

    % Analyses 1 and 2 need the activity/rest masks carried in snrValue.
    % A TT-only loaded file (legacy save) does not have them.
    if ismember(choice, {'1','2'}) && ...
            (isempty(snrValue) || ~isstruct(snrValue) || ~isfield(snrValue, 'is_act'))
        fprintf(['\nThis analysis needs snrValue (activity/rest masks), which is\n' ...
                 'missing from the loaded data. Re-run preprocessing (main > 1, or\n' ...
                 'option 2 here) so snrValue is regenerated and saved alongside TT.\n']);
        return;
    end

    switch choice
        case '1'
            fprintf('\nRunning state-stratified amplitude analysis... ');
            try
                results = spasm_gait_stim_analysis(TT, snrValue, fs, ...
                    'SpasmPrcTA', spasm_prc_ta, ...
                    'SpasmPrcMG', spasm_prc_mg, ...
                    'PlotResult', true);
                fprintf('Done!\n');
                
                % Display results
                if isfield(results, 'thr_spasm_TA')
                    fprintf('\nSpasm Detection Results:\n');
                    fprintf('  TA spasm threshold: %.4f\n', results.thr_spasm_TA);
                    fprintf('  MG spasm threshold: %.4f\n', results.thr_spasm_MG);
                end
                
                % Display figures if generated
                if isfield(results, 'figures') && ~isempty(results.figures)
                    fprintf('  Figures generated and displayed.\n');
                end
                
            catch ME
                fprintf('Error: %s\n', ME.message);
            end

        case '2'
            % Stimulated vs unstimulated spasms (compare_spasm_stim_vs_nostim)
            % Uses same SpasmPrcTA / SpasmPrcMG as case 1. Ask once for the
            % amplitude percentile used to summarise each matched window
            % (the function's other knobs keep their defaults).
            fprintf('\nEnter amplitude percentile for per-window summary (default 100): ');
            amp_input = input('', 's');
            if isempty(amp_input)
                amp_prc = 100;
            else
                amp_prc = str2double(amp_input);
                if isnan(amp_prc) || amp_prc <= 0 || amp_prc > 100
                    fprintf('Invalid percentile, falling back to 100.\n');
                    amp_prc = 100;
                end
            end
            
            fprintf('\nRunning stimulated vs unstimulated spasm comparison... ');
            try
                results = compare_spasm_stim_vs_nostim(TT, snrValue, fs, ...
                    'SpasmPrcTA',    spasm_prc_ta, ...
                    'SpasmPrcMG',    spasm_prc_mg, ...
                    'AmpPercentile', amp_prc, ...
                    'PlotResult',    true);
                fprintf('Done!\n');
                
                n_stim   = sum(results.is_stimulated);
                n_nostim = numel(results.is_stimulated) - n_stim;
                
                fprintf('\nStimulated vs Unstimulated Spasm Results:\n');
                fprintf('  Spasm thresholds       : TA=%.4f  MG=%.4f\n', ...
                    results.thr_spasm_TA, results.thr_spasm_MG);
                fprintf('  Ch3 ON threshold       : %.4f\n', results.thr_ch3);
                fprintf('  Spasms stimulated      : %d\n', n_stim);
                fprintf('  Spasms unstimulated    : %d\n', n_nostim);
                fprintf('  Wilcoxon rank-sum TA   : p = %.4g\n', results.p_TA);
                fprintf('  Wilcoxon rank-sum MG   : p = %.4g\n', results.p_MG);
                
                if n_stim < 2
                    fprintf('  (warning: <2 stimulated spasms — p-values unreliable)\n');
                end
                if n_nostim < 2
                    fprintf('  (warning: <2 unstimulated spasms — p-values unreliable)\n');
                end
                
            catch ME
                fprintf('Error: %s\n', ME.message);
            end

        case '3'
            fprintf('\nRunning TA-MG correlation analysis... ');
            try
                results = compare_files_xcorr(TT.TA_env, TT.MG_env);
                fprintf('Done!\n');
                
                if isfield(results, 'correlation')
                    fprintf('\nTA-MG Correlation Results:\n');
                    fprintf('  Peak correlation: %.3f\n', results.correlation);
                    fprintf('  Lag (ms): %.2f\n', results.lag_ms);
                end
                
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
    end
end

% =========================================================================
% FREQUENCY ANALYSIS
% =========================================================================
function run_frequency_analysis_menu()
    fprintf('\n--- FREQUENCY ANALYSIS ---\n');
    
    % Analysis choice - ask BEFORE loading data
    fprintf('\nSelect analysis type:\n');
    fprintf('1. LabChart protocol validation (100-500 Hz band power)\n');
    fprintf('2. Advanced spectral comparison (100-500 Hz and 500-1000 Hz)\n');
    fprintf('3. Batch spectral analysis (multiple files)\n');
    fprintf('4. Frequency content comparison (gait vs spasm)\n');
    choice = input('Choice (1-4): ', 's');
    
    % If case 4 or 2, skip loading since compare_frequency_content handles
    % its own file I/O and advanced spectral comparison loads all files .
    if strcmp(choice, '4')
        fprintf('\nFrequency content comparison:\n');
        try
            % compare_frequency_content is a standalone function that handles its own file loading
            compare_frequency_content();
            fprintf('Comparison complete.\n');
        catch ME
            fprintf('Error: %s\n', ME.message);
        end
        return;
    end

    if strcmp(choice, '2')
            fprintf('\nRunning spectral comparison (100-500 Hz and 500-1000 Hz)...\n');
            try
                % Call without arguments - function will handle file loading from hardcoded paths
                plot_spectral_comparison_advanced();
                fprintf('Done!\n');
                fprintf('Figure displayed and saved.\n');
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
            return;
    end

    % Batch spectral analysis handles its own gait/spasm pair selection and
    % preprocessing, so it must not go through load_or_preprocess first.
    if strcmp(choice, '3')
        fprintf('\nRunning batch spectral analysis (multiple gait/spasm pairs)...\n');
        try
            batch_spectral_analysis();
            fprintf('Batch spectral analysis complete.\n');
        catch ME
            fprintf('Error: %s\n', ME.message);
        end
        return;
    end


    % For case 1, load or preprocess data
    [TT, snrValue, success] = load_or_preprocess();
    if ~success, return; end

    % Sampling frequency (fixed at 10 kHz)
    fs = 10000;

    switch choice
        case '1'
            fprintf('\nRunning LabChart protocol validation... ');
            try
                results = labchart_protocol_check_gait_vs_spasm(TT, [], fs);
                fprintf('Done!\n');
                fprintf('Results saved to LabChart_protocol_results/\n');
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
    end
end

% =========================================================================
% GROUP COMPARISON ANALYSIS (historically named "Feature Extraction")
% =========================================================================
function run_feature_extraction_menu()
    fprintf('\n--- GROUP COMPARISON ANALYSIS ---\n');
    fprintf('Note: this menu runs GROUP-LEVEL comparisons (injured vs uninjured,\n');
    fprintf('stim ON vs OFF), not per-window feature extraction. The name is\n');
    fprintf('kept for backward compatibility with Feature_Extraction.m.\n');
    fprintf('\nThe function will prompt for file selection interactively.\n');
    
    try
        out = Feature_Extraction();
        fprintf('Done!\n');
        
        % Summarise what ran
        if isfield(out, 'group_compare')
            fprintf('  Group comparison: %d recordings processed.\n', ...
                numel(out.group_compare.R));
            fprintf('  Figure saved to: group_comparison.pdf\n');
        end
        if isfield(out, 'stim_compare')
            n_mg = out.stim_compare.MG.summary.n_events_pre;
            n_ta = out.stim_compare.TA.summary.n_events_pre;
            fprintf('  Stim ON/OFF comparison: MG n=%d events, TA n=%d events\n', ...
                n_mg, n_ta);
            fprintf('  Figure saved to: overall_stim_comparison.pdf\n');
        end
        
        % Save option
        save_choice = input('\nSave full results struct to .mat? (y/n) [default: n]: ', 's');
        if ~isempty(save_choice) && lower(save_choice) == 'y'
            [save_name, save_path] = uiputfile('*.mat', 'Save as', 'group_comparison_results.mat');
            if ~isequal(save_name, 0)
                save(fullfile(save_path, save_name), 'out', '-v7.3');
                fprintf('Saved to: %s\n', fullfile(save_path, save_name));
            end
        end
        
    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

% =========================================================================
% VALIDATION TESTS
% =========================================================================
function run_validation_tests_menu()
    fprintf('\n--- VALIDATION & TESTING ---\n');
    fprintf('Select test to run:\n');
    fprintf('1. Full spasm detection test\n');
    fprintf('2. Amplitude distribution analysis\n');
    fprintf('3. Generate synthetic EMG data\n');
    choice = input('Choice (1-3): ', 's');
    
    switch choice
        case '1'
            fprintf('\nRunning full spasm detection test...\n');
            try
                % Test_full_spasm_detection is a script, use run() to execute it
                run(fullfile(fileparts(mfilename('fullpath')), 'tests', 'Test_full_spasm_detection.m'));
                fprintf('\nTest complete.\n');
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
            
        case '2'
            fprintf('\nAnalyzing amplitude distribution...\n');
            % For this test, automatically skip plots to avoid display clutter
            P = default_emg_parameters();
            try
                fprintf('\nPreprocessing options:\nSkipping plots automatically for this analysis.\n\n');
                [TT, snrValue, ~, ~] = preprocess_and_label(P, 10000, 'plot_figures', false, 'save_figures', false);
                
                % amplitude_distribution requires (signal1, signal2, fs, varargin)
                fs = 10000;
                
                % Extract numeric arrays from timetable columns
                % Convert to double arrays to ensure compatibility
                if ismember('TA_env', TT.Properties.VariableNames) && ismember('MG_env', TT.Properties.VariableNames)
                    ta_env = double(table2array(TT(:, 'TA_env')));
                    mg_env = double(table2array(TT(:, 'MG_env')));
                    
                    % Also check for Ch3 signal
                    if ismember('Ch3_raw', TT.Properties.VariableNames)
                        ch3_sig = double(table2array(TT(:, 'Ch3_raw')));
                    elseif ismember('Ch3_f', TT.Properties.VariableNames)
                        ch3_sig = double(table2array(TT(:, 'Ch3_f')));
                    else
                        % Fallback: use zeros if no Ch3
                        ch3_sig = zeros(numel(ta_env), 1);
                    end
                    
                    % Analyze TA amplitude distribution
                    fprintf('\n--- TA Amplitude Distribution ---\n');
                    dist_results_ta = amplitude_distribution(ta_env, ch3_sig, fs, ...
                        'MGAlreadyAmplitude', true, ...
                        'TitleStr', 'TA amplitude distribution');
                    fprintf('TA analysis complete.\n');
                    
                    % Analyze MG amplitude distribution
                    fprintf('\n--- MG Amplitude Distribution ---\n');
                    dist_results_mg = amplitude_distribution(mg_env, ch3_sig, fs, ...
                        'MGAlreadyAmplitude', true, ...
                        'TitleStr', 'MG amplitude distribution');
                    fprintf('MG analysis complete.\n');
                    
                else
                    fprintf('Error: Required signal columns not found in preprocessed data.\n');
                end
            catch ME
                fprintf('Error: %s\n', ME.message);
                fprintf('Stack:\n');
                disp(ME.stack);
            end
            
        case '3'
            fprintf('\nGenerating synthetic EMG data...\n');
            try
                % generate_synthetic_emg returns a struct with data__chan_X_rec_Y fields
                S = generate_synthetic_emg('DurS', 300, 'NSpasms', 9, 'PlotResult', true);
                fprintf('Synthetic signal generated:\n');
                fprintf('  Duration: 300.0 seconds\n');
                fprintf('  Number of spasms: 10\n');
                fprintf('  File: synthetic_rec.mat\n');
                
                % Save option
                save_choice = input('Save synthetic data? (y/n) [default: n]: ', 's');
                if lower(save_choice) == 'y'
                    save('synthetic_test_data.mat', 'S');
                    fprintf('Saved to: synthetic_test_data.mat\n');
                end
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
    end
end

% =========================================================================
% GUI INTERFACE
% =========================================================================
function run_gui_interface()
    fprintf('\nLaunching GUI interface...\n');
    try
        Interface_GUI;
    catch ME
        fprintf('Error launching GUI: %s\n', ME.message);
        fprintf('Make sure interface.mlapp exists in config/ folder.\n');
    end
end

% =========================================================================
% HELP & DOCUMENTATION
% =========================================================================
function display_help_menu()
    fprintf('\n--- HELP & DOCUMENTATION ---\n');
    fprintf('Select topic:\n');
    fprintf('1. Project overview\n');
    fprintf('2. Parameters & configuration\n');
    fprintf('3. Preprocessing pipeline\n');
    fprintf('4. Spasm detection algorithm\n');
    fprintf('5. Frequency analysis methods\n');
    fprintf('6. Data format specifications\n');
    fprintf('7. Common workflows\n');
    fprintf('8. Troubleshooting\n');
    choice = input('Choice (1-8): ', 's');

    switch choice
        case '1'
            fprintf('\n=== PROJECT OVERVIEW ===\n');
            fprintf('This EMG analysis pipeline provides integrated workflows for:\n');
            fprintf('  • Signal preprocessing (filtering, envelope, SNR/activity masks)\n');
            fprintf('  • Spasm detection and stim (Ch3) ON/OFF characterization\n');
            fprintf('  • Frequency-domain analysis (spectral features)\n');
            fprintf('  • Group-level comparisons (injured/uninjured, stim ON/OFF)\n');
            fprintf('  • Publication-quality visualizations\n');
            fprintf('\nFor detailed information, see README.md in the project root.\n');

        case '2'
            fprintf('\n=== PARAMETERS & CONFIGURATION ===\n');
            fprintf('All tunable values live in one place: config/default_emg_parameters.m\n');
            fprintf('It returns a struct P grouped by pipeline stage, e.g.:\n');
            fprintf('  P.fs               sampling frequency (10000 Hz)\n');
            fprintf('  P.filter.bp_fc     band-pass cutoffs [5 500] Hz\n');
            fprintf('  P.filter.notch_f0  power-line notch (50 Hz)\n');
            fprintf('  P.envWindowMs      envelope moving-average window (3 ms)\n');
            fprintf('  P.act_prc          TA activity-detection percentile (70)\n');
            fprintf('  P.spasm.prc_TA     spasm threshold percentile (65)\n');
            fprintf('  P.artifact.rms_mult artifact ceiling (x active RMS)\n');
            fprintf('Every function reads its defaults from here (directly or via its\n');
            fprintf('default arguments). To customize:\n');
            fprintf('  1. Edit config/default_emg_parameters.m to change defaults globally, or\n');
            fprintf('  2. P = default_emg_parameters(); P.spasm.prc_TA = 70;\n');
            fprintf('     [TT, snr] = preprocess_and_label(P, P.fs);\n');
            fprintf('\nFor details, see: config/README.md\n');

        case '3'
            fprintf('\n=== PREPROCESSING PIPELINE ===\n');
            fprintf('preprocess_and_label(P, fs) does, in order:\n');
            fprintf('  1. Load recording from .mat (data__chan_{1,2,3}_rec_{N})\n');
            fprintf('  2. Filter: notch_filter(butter_filter(.)) using P.filter / P.fs\n');
            fprintf('  3. Rectify (abs) + envelope (moving average of width P.envWindowMs)\n');
            fprintf('  4. (optional) detect valid acquisition start (P.detect_acq_start)\n');
            fprintf('  5. Quiet/rest masks via find_quiet_mask (P.thresholds)\n');
            fprintf('  6. SNR + activity masks via snr_emg (P.snr_win_ms, P.act_prc, P.act_prc_MG)\n');
            fprintf('  7. Artifact removal via remove_artifacts (P.artifact)\n');
            fprintf('  8. Final rest/activity masks, gaps fused with P.fuse_gap_ms\n');
            fprintf('\nFor details, see: preprocessing/README.md\n');

        case '4'
            fprintf('\n=== SPASM DETECTION ALGORITHM ===\n');
            fprintf('Method: envelope percentile thresholding (spasm_gait_stim_analysis).\n');
            fprintf('Defaults from config/default_emg_parameters.m (P.spasm); steps:\n');
            fprintf('  1. Filter (band-pass P.filter.bp_fc, default [5 500] Hz) + 50 Hz notch\n');
            fprintf('  2. Rectify: |filtered_signal|\n');
            fprintf('  3. Envelope: moving average (P.envWindowMs, default 3 ms)\n');
            fprintf('  4. Threshold: prctile(env(is_active), P.spasm.prc_TA/prc_MG)  [default 65]\n');
            fprintf('  5. Detect spasm: TA or MG envelope >= its threshold\n');
            fprintf('  6. Keep bursts >= P.spasm.min_dur_s (0.1 s), fuse gaps <= P.spasm.fuse_gap_ms (50 ms)\n');
            fprintf('  7. Classify Spasm/Active/Rest/Other, split by Ch3 ON/OFF, Wilcoxon signed-rank\n');
            fprintf('\nFor details, see: detection/README.md\n');

        case '5'
            fprintf('\n=== FREQUENCY ANALYSIS METHODS ===\n');
            fprintf('Two complementary methods:\n');
            fprintf('  PSD-integrated (Welch):\n');
            fprintf('    • FFT size: 1000 (df = 10 Hz @ 10 kHz fs)\n');
            fprintf('    • Window: Hann periodic\n');
            fprintf('    • Overlap: none (zero overlap)\n');
            fprintf('    • Band power: sum(Pxx) × df  [V^2 units]\n');
            fprintf('  Time-domain (Butterworth bandpass):\n');
            fprintf('    • butter_filter(x, fc, fs, order), zero-phase via filtfilt\n');
            fprintf('    • Mean-square power: mean(filtered_signal^2)  [V^2 units]\n');
            fprintf('\nBoth methods should agree closely (within ~10%%).\n');
            fprintf('For details, see: analysis/README.md\n');

        case '6'
            fprintf('\n=== DATA FORMAT SPECIFICATIONS ===\n');
            fprintf('Input: MATLAB .mat file with per-channel, per-recording variables:\n');
            fprintf('  data__chan_1_rec_N (TA), data__chan_2_rec_N (MG), data__chan_3_rec_N (Ch3/stim)\n');
            fprintf('  Sampling: 10 kHz (100 us intervals)\n');
            fprintf('  (LabChart exports are converted to this .mat layout beforehand)\n');
            fprintf('\nOutput: TT timetable (TA/MG raw, filtered, rectified, envelope) +\n');
            fprintf('  snrValue masks, plus CSV/figure result files per analysis.\n');
            fprintf('\nFor details, see: data/README.md\n');

        case '7'
            fprintf('\n=== COMMON WORKFLOWS ===\n');
            fprintf('Workflow 1: Preprocess + spasm analysis of one recording\n');
            fprintf('  main > 1 (preprocess) > then main > 2 > 1 (state-stratified analysis)\n');
            fprintf('\nWorkflow 2: Frequency analysis\n');
            fprintf('  main > 3 > choose method\n');
            fprintf('\nWorkflow 3: Cross-recording group comparison\n');
            fprintf('  main > 4 (Feature_Extraction, selects multiple recordings)\n');
            fprintf('\nWorkflow 4: Interactive GUI\n');
            fprintf('  main > 6 > launch interface\n');

        case '8'
            fprintf('\n=== TROUBLESHOOTING ===\n');
            fprintf('Problem: "Undefined function" errors\n');
            fprintf('  Solution: Ensure you ran main.m (it adds all paths)\n');
            fprintf('\nProblem: .mat file not loading / no recordings found\n');
            fprintf('  Solution: File must contain data__chan_1_rec_N, _chan_2_, _chan_3_ variables\n');
            fprintf('\nProblem: Spasm detection finding too many/few events\n');
            fprintf('  Solution: Raise/lower P.spasm.prc_TA/prc_MG in config (or at the prompt)\n');
            fprintf('\nProblem: Too many/few active samples\n');
            fprintf('  Solution: Adjust P.act_prc / P.act_prc_MG in config/default_emg_parameters.m\n');
            fprintf('\nFor additional help, see the README.md files in each folder.\n');
    end
end

% =========================================================================
% HELPER FUNCTIONS
% =========================================================================
function [TT, snrValue, success] = load_or_preprocess()
    % Helper: Check if TT exists; if not, offer preprocessing
    % Returns: [TT, snrValue, success_flag]
    
    TT = [];
    snrValue = [];
    success = false;
    
    % Check if TT already exists in workspace
    caller_workspace = evalin('caller', 'whos');
    has_TT = any(strcmp({caller_workspace.name}, 'TT'));
    
    if has_TT
        % TT already loaded
        fprintf('\nUsing previously loaded TT structure.\n');
        TT = evalin('caller', 'TT');
        % Try to get snrValue if it exists
        if any(strcmp({caller_workspace.name}, 'snrValue'))
            snrValue = evalin('caller', 'snrValue');
        end
        success = true;
        return;
    end
    
    % Offer to preprocess
    fprintf('\nTT structure not found in workspace.\n');
    fprintf('Options:\n');
    fprintf('1. Load existing preprocessed file (.mat)\n');
    fprintf('2. Preprocess new raw data (.csv or .mat)\n');
    fprintf('3. Cancel\n');
    
    choice = input('Choice (1-3) [default: 2]: ', 's');
    if isempty(choice), choice = '2'; end
    
    switch choice
        case '1'
            % Load existing
            [filename, filepath] = uigetfile('*.mat', 'Load preprocessed data');
            if ~isequal(filename, 0)
                try
                    % Only request snrValue if the file actually contains it,
                    % so a legacy TT-only file does not trigger a load warning.
                    vars = who('-file', fullfile(filepath, filename));
                    if ismember('snrValue', vars)
                        load(fullfile(filepath, filename), 'TT', 'snrValue');
                    else
                        load(fullfile(filepath, filename), 'TT');
                    end
                    fprintf('\nLoaded: %s\n', filename);
                    fprintf('TT structure contains %d samples at 10 kHz.\n', height(TT));
                    assignin('caller', 'TT', TT);
                    if ~isempty(snrValue)
                        assignin('caller', 'snrValue', snrValue);
                    else
                        fprintf(['\nNote: this file has no snrValue (activity/rest masks).\n' ...
                                 '      TA-MG correlation will still work, but the spasm/stim\n' ...
                                 '      analyses need it - re-preprocess (option 2) to regenerate.\n']);
                    end
                    success = true;
                    return;
                catch ME
                    fprintf('Error loading file: %s\n', ME.message);
                    success = false;
                    return;
                end
            else
                fprintf('File selection cancelled.\n');
                success = false;
                return;
            end
            
        case '2'
            % Preprocess - capture return values
            [TT, snrValue] = run_single_file_preprocessing();
            
            % Debug: Check if TT is valid
            if isempty(TT)
                fprintf('DEBUG: TT is empty after preprocessing.\n');
                success = false;
            elseif ~istimetable(TT)
                fprintf('DEBUG: TT is not a timetable (class: %s).\n', class(TT));
                success = false;
            else
                fprintf('\nTT structure successfully created!\n');
                % Store in caller workspace (should be the menu function)
                assignin('caller', 'TT', TT);
                if ~isempty(snrValue)
                    assignin('caller', 'snrValue', snrValue);
                end
                success = true;
            end
            
        case '3'
            fprintf('Cancelled.\n');
            success = false;
            return;
            
        otherwise
            fprintf('Invalid choice.\n');
            success = false;
            return;
    end
end
