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
addpath(genpath(fullfile(current_dir, 'core')));
addpath(genpath(fullfile(current_dir, 'filters')));
addpath(genpath(fullfile(current_dir, 'utilities')));
addpath(genpath(fullfile(current_dir, 'analysis')));
addpath(genpath(fullfile(current_dir, 'plotting')));
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
    fprintf('5. Parameter tuning\n');
    fprintf('6. Run validation tests\n');
    fprintf('7. Launch GUI interface\n');
    fprintf('8. Display help & documentation\n');
    fprintf('0. Exit\n');
    fprintf('\n');
    
    choice = input('Select an option (0-8): ', 's');
    
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
            run_parameter_tuning_menu();
            
        case '6'
            run_validation_tests_menu();
            
        case '7'
            run_gui_interface();
            
        case '8'
            display_help_menu();
            
        case '0'
            fprintf('\nGoodbye!\n');
            return;
            
        otherwise
            fprintf('Invalid choice. Please enter 0-8.\n');
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
                save(fullfile(save_path, save_name), 'TT', '-v7.3');
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
    
    % Get spasm detection percentile thresholds
    fprintf('\nSpasm detection uses percentile thresholds of active amplitudes.\n');
    fprintf('Higher percentile = stricter spasm detection (fewer events detected).\n');
    fprintf('\nEnter spasm percentile for TA (default 65): ');
    ta_input = input('', 's');
    if isempty(ta_input)
        spasm_prc_ta = 65;
    else
        spasm_prc_ta = str2double(ta_input);
    end
    
    fprintf('Enter spasm percentile for MG (default 65): ');
    mg_input = input('', 's');
    if isempty(mg_input)
        spasm_prc_mg = 65;
    else
        spasm_prc_mg = str2double(mg_input);
    end
    
    % Analysis choice
    fprintf('\nSelect analysis type:\n');
    fprintf('1. State-stratified amplitude: Spasm/Active/Rest x Stim ON/OFF\n');
    fprintf('2. Stimulated vs unstimulated spasms (matched-window amplitude)\n');
    fprintf('3. TA-MG correlation\n');
    choice = input('Choice (1-3): ', 's');
    
    % Sampling frequency (fixed at 10 kHz)
    fs = 10000;
    
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
            fprintf('\nEnter amplitude percentile for per-window summary (default 90): ');
            amp_input = input('', 's');
            if isempty(amp_input)
                amp_prc = 90;
            else
                amp_prc = str2double(amp_input);
                if isnan(amp_prc) || amp_prc <= 0 || amp_prc > 100
                    fprintf('Invalid percentile, falling back to 90.\n');
                    amp_prc = 90;
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
          
    
    % For cases 1 and 3, load or preprocess data
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
            
       
            
        case '3'
            fprintf('\nBatch spectral analysis not yet implemented in menu.\n');
            fprintf('Use: batch_spectral_analysis(file_list, conditions)\n');
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
% PARAMETER TUNING
% =========================================================================
function run_parameter_tuning_menu()
    fprintf('\n--- PARAMETER TUNING ---\n');
    
    % Load or preprocess
    [TT, ~, success] = load_or_preprocess();
    if ~success, return; end
    
    fprintf('\nParameter tuning for spasm detection:\n');
    fprintf('Select tuning method:\n');
    fprintf('1. Percentile threshold (automatic search)\n');
    fprintf('2. Manual threshold adjustment\n');
    choice = input('Choice (1-2): ', 's');
    
    switch choice
        case '1'
            fprintf('\nTesting percentile range (50th to 95th)...\n');
            try
                % Create activity mask from envelope if not available in TT
                if ismember('is_act_TA', TT.Properties.VariableNames)
                    is_act_TA = TT.is_act_TA;
                else
                    % Create simple activity mask: samples where envelope is above minimum
                    is_act_TA = TT.TA_env > 0.1 * max(TT.TA_env);
                end
                
                prc_range = 50:5:95;
                results = emg_parameter_tuning(TT, is_act_TA, prc_range, ...
                    'Method', 'percentile', 'Metric', 'f1');
                
                if isfield(results, 'optimal_threshold')
                    fprintf('Optimal threshold: %.1f percentile\n', results.optimal_threshold);
                    fprintf('Sensitivity: %.2f%%\n', results.sensitivity*100);
                    fprintf('Specificity: %.2f%%\n', results.specificity*100);
                end
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
            
        case '2'
            fprintf('\nManual threshold adjustment:\n');
            fprintf('Current parameters:\n');
            opt = default_emg_parameters();
            fprintf('  TA spasm threshold (percentile): %d\n', opt.SpasmPrcTA);
            fprintf('  MG spasm threshold (percentile): %d\n', opt.SpasmPrcMG);
            fprintf('  Min spasm duration: %.2f s\n', opt.MinSpasmDuration / opt.fs);
            
            % Get user inputs
            new_prc = input('Enter new percentile for TA spasm (50-95, or empty to skip): ', 's');
            if ~isempty(new_prc)
                opt.SpasmPrcTA = str2double(new_prc);
                fprintf('Updated TA spasm threshold to: %.1f percentile\n', opt.SpasmPrcTA);
            end
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
            fprintf('\nRunning full spasm detection test... ');
            try
                test_results = Test_full_spasm_detection();
                fprintf('Test complete.\n');
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
            
        case '2'
            fprintf('\nAnalyzing amplitude distribution...\n');
            [TT, ~, success] = load_or_preprocess();
            if success
                try
                    dist_results = amplitude_distribution(TT.TA_env, TT.MG_env, {'TA', 'MG'});
                    fprintf('Analysis complete.\n');
                catch ME
                    fprintf('Error: %s\n', ME.message);
                end
            end
            
        case '3'
            fprintf('\nGenerating synthetic EMG data...\n');
            try
                [signal, ground_truth, params] = generate_synthetic_emg(...
                    'duration', 30, 'num_spasms', 5, 'snr_db', 20);
                fprintf('Synthetic signal generated:\n');
                fprintf('  Duration: %.1f seconds\n', params.duration);
                fprintf('  Number of spasms: %d\n', params.num_spasms);
                fprintf('  SNR: %d dB\n', params.snr_db);
                
                % Save option
                save_choice = input('Save synthetic data? (y/n) [default: n]: ', 's');
                if lower(save_choice) == 'y'
                    save('synthetic_test_data.mat', 'signal', 'ground_truth', 'params');
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
        interface;
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
    fprintf('2. Signal basis explanation\n');
    fprintf('3. Spasm detection algorithm\n');
    fprintf('4. Frequency analysis methods\n');
    fprintf('5. Data format specifications\n');
    fprintf('6. Common workflows\n');
    fprintf('7. Troubleshooting\n');
    choice = input('Choice (1-7): ', 's');
    
    switch choice
        case '1'
            fprintf('\n=== PROJECT OVERVIEW ===\n');
            fprintf('This EMG analysis pipeline provides integrated workflows for:\n');
            fprintf('  • Signal preprocessing (filtering, envelope computation)\n');
            fprintf('  • Spasm detection and characterization\n');
            fprintf('  • Frequency-domain analysis (spectral features)\n');
            fprintf('  • Group-level comparisons (injured/uninjured, stim ON/OFF)\n');
            fprintf('  • Publication-quality visualizations\n');
            fprintf('\nFor detailed information, see README.md in project root.\n');
            
        case '2'
            fprintf('\n=== SIGNAL BASIS EXPLANATION ===\n');
            fprintf('The preprocess_and_label function uses parameters from default_emg_parameters().\n');
            fprintf('To customize preprocessing:\n');
            fprintf('  1. Edit core/default_emg_parameters.m to change default settings\n');
            fprintf('  2. Or pass modified parameters directly to preprocess_and_label\n');
            
        case '3'
            fprintf('\n=== SPASM DETECTION ALGORITHM ===\n');
            fprintf('Current method: Envelope percentile thresholding\n');
            fprintf('Steps:\n');
            fprintf('  1. Filter signal (20-450 Hz bandpass)\n');
            fprintf('  2. Rectify: |filtered_signal|\n');
            fprintf('  3. Smooth envelope: gaussian window (50 ms)\n');
            fprintf('  4. Compute threshold: percentile(envelope, 75th percentile)\n');
            fprintf('  5. Detect spasms: envelope > threshold\n');
            fprintf('  6. Filter bursts: keep only >200 ms events\n');
            fprintf('\nFor details, see: analysis/spasm_detection/README.md\n');
            
        case '4'
            fprintf('\n=== FREQUENCY ANALYSIS METHODS ===\n');
            fprintf('Two complementary methods:\n');
            fprintf('  PSD-integrated (Welch):\n');
            fprintf('    • FFT size: 1000 (df = 10 Hz @ 10 kHz fs)\n');
            fprintf('    • Window: Hann periodic\n');
            fprintf('    • Overlap: none (zero overlap)\n');
            fprintf('    • Band power: sum(Pxx) × df  [V^2 units]\n');
            fprintf('  Time-domain (causal bandpass):\n');
            fprintf('    • Butterworth bandpass (order 4)\n');
            fprintf('    • Mean-square power: mean(filtered_signal^2)  [V^2 units]\n');
            fprintf('\nBoth methods should agree closely (within ~10%%).\n');
            fprintf('For details, see: analysis/frequency_analysis/README.md\n');
            
        case '5'
            fprintf('\n=== DATA FORMAT SPECIFICATIONS ===\n');
            fprintf('Input: CSV files from LabChart with columns:\n');
            fprintf('  Time(s), TA(V), MG(V), Stim(V), [optional columns]\n');
            fprintf('  Sampling: 10 kHz (100 µs intervals)\n');
            fprintf('\nOutput: MATLAB MAT files and CSV result tables\n');
            fprintf('  TT struct: preprocessed signals with metadata\n');
            fprintf('  Results: band powers, spasm rates, statistics\n');
            fprintf('\nFor details, see: data/README.md\n');
            
        case '6'
            fprintf('\n=== COMMON WORKFLOWS ===\n');
            fprintf('Workflow 1: Quick analysis of single file\n');
            fprintf('  main > 1 > select file > 2 > 1 > results\n');
            fprintf('\nWorkflow 2: Parameter optimization\n');
            fprintf('  main > 1 > preprocess > 5 > 1 > optimal threshold\n');
            fprintf('\nWorkflow 3: Interactive GUI\n');
            fprintf('  main > 7 > launch interface.mlapp\n');
            
        case '7'
            fprintf('\n=== TROUBLESHOOTING ===\n');
            fprintf('Problem: "Undefined function" errors\n');
            fprintf('  Solution: Ensure you ran main.m (adds paths)\n');
            fprintf('\nProblem: CSV file not loading\n');
            fprintf('  Solution: Check format (LabChart CSV with Time, TA, MG columns)\n');
            fprintf('\nProblem: Spasm detection finding too many/few events\n');
            fprintf('  Solution: Use parameter tuning (main > 5) to adjust percentile\n');
            fprintf('\nProblem: Spectral analysis looks noisy\n');
            fprintf('  Solution: Use ''filtered'' signal basis (main > 1)\n');
            fprintf('\nFor additional help, see README.md files in each folder.\n');
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
                    load(fullfile(filepath, filename), 'TT', 'snrValue');
                    fprintf('\nLoaded: %s\n', filename);
                    fprintf('TT structure contains %d samples at 10 kHz.\n', height(TT));
                    assignin('caller', 'TT', TT);
                    if ~isempty(snrValue)
                        assignin('caller', 'snrValue', snrValue);
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
