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
    fprintf('2. Spasm detection & analysis\n');
    fprintf('3. Frequency analysis (spectral features)\n');
    fprintf('4. Feature extraction\n');
    fprintf('5. Batch processing\n');
    fprintf('6. Parameter tuning\n');
    fprintf('7. Run validation tests\n');
    fprintf('8. Launch GUI interface\n');
    fprintf('9. Display help & documentation\n');
    fprintf('0. Exit\n');
    fprintf('\n');
    
    choice = input('Select an option (0-9): ', 's');
    
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
            run_batch_processing_menu();
            
        case '6'
            run_parameter_tuning_menu();
            
        case '7'
            run_validation_tests_menu();
            
        case '8'
            run_gui_interface();
            
        case '9'
            display_help_menu();
            
        case '0'
            fprintf('\nGoodbye!\n');
            return;
            
        otherwise
            fprintf('Invalid choice. Please enter 0-9.\n');
    end
end

end

% =========================================================================
% PREPROCESSING
% =========================================================================
function TT = run_single_file_preprocessing()
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
        TT = preprocess_and_label(P, 10000, 'plot_figures', plot_figs, 'fullFile', filepath_full);
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
        
        % If plots were generated, allow user to view them
        if plot_figs
            drawnow;  % Force rendering of all figures
            fig_handles = findall(0, 'Type', 'figure');
            if ~isempty(fig_handles)
                fprintf('\nPlots displayed. Press any key to continue...\n');
                pause;  % Wait for user to view plots
            end
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
    [TT, success] = load_or_preprocess();
    if ~success, return; end
    
    % Get SNR value
    fprintf('\nEnter SNR value for activity detection (default 2.0): ');
    snr_input = input('', 's');
    if isempty(snr_input)
        snrValue = 2.0;
    else
        snrValue = str2double(snr_input);
    end
    
    % Analysis choice
    fprintf('\nSelect analysis type:\n');
    fprintf('1. Spasm vs. Gait comparison\n');
    fprintf('2. Stimulus effect (ON vs. OFF)\n');
    fprintf('3. TA-MG correlation\n');
    choice = input('Choice (1-3): ', 's');
    
    % Sampling frequency (fixed at 10 kHz)
    fs = 10000;
    
    switch choice
        case '1'
            fprintf('\nRunning spasm vs. gait analysis... ');
            try
                results = spasm_gait_stim_analysis(TT, snrValue, fs);
                fprintf('Done!\n');
                
                % Display results
                if isfield(results, 'spasm_rate')
                    fprintf('\nSpasm Detection Results:\n');
                    fprintf('  TA spasm rate: %.2f spasms/min\n', results.spasm_rate);
                    if isfield(results, 'MG_spasm_rate')
                        fprintf('  MG spasm rate: %.2f spasms/min\n', results.MG_spasm_rate);
                    end
                end
                
                % Display figures if generated
                if isfield(results, 'figures') && ~isempty(results.figures)
                    fprintf('  Figures generated and displayed.\n');
                end
                
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
            
        case '2'
            fprintf('\nRunning stimulus effect analysis... ');
            try
                results = compare_spasm_stim_vs_nostim(TT, snrValue, fs);
                fprintf('Done!\n');
                
                if isfield(results, 'p_value')
                    fprintf('\nStimulus Effect Results:\n');
                    fprintf('  Spasm rate (stim ON): %.2f spasms/min\n', results.spasm_rate_stim_on);
                    fprintf('  Spasm rate (stim OFF): %.2f spasms/min\n', results.spasm_rate_stim_off);
                    fprintf('  P-value: %.4f\n', results.p_value);
                    if results.p_value < 0.05
                        fprintf('  Result: Statistically significant effect (p < 0.05)\n');
                    else
                        fprintf('  Result: No significant effect (p >= 0.05)\n');
                    end
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
    
    % Load or preprocess
    [TT, success] = load_or_preprocess();
    if ~success, return; end
    
    % Sampling frequency (fixed at 10 kHz)
    fs = 10000;
    
    % Analysis choice
    fprintf('\nSelect analysis type:\n');
    fprintf('1. LabChart protocol validation (100-500 Hz band power)\n');
    fprintf('2. Advanced spectral comparison (100-500 Hz and 500-1000 Hz)\n');
    fprintf('3. Batch spectral analysis (multiple files)\n');
    fprintf('4. Frequency content comparison\n');
    choice = input('Choice (1-4): ', 's');
    
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
            
        case '2'
            fprintf('\nRunning spectral comparison (100-500 Hz and 500-1000 Hz)... ');
            try
                condition_label = input('Enter condition label (e.g., "Gait", "Spasm"): ', 's');
                if isempty(condition_label), condition_label = 'Recording'; end
                
                plot_spectral_comparison_advanced(TT, condition_label);
                fprintf('Done!\n');
                fprintf('Figure displayed and saved.\n');
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
            
        case '3'
            fprintf('\nBatch spectral analysis not yet implemented in menu.\n');
            fprintf('Use: batch_spectral_analysis(file_list, conditions)\n');
            
        case '4'
            fprintf('\nFrequency content comparison:\n');
            try
                % This requires comparison between two signals/conditions
                % For now, just compare TA and MG within same recording
                results = compare_frequency_content(TT.TA_raw, TT.MG_raw, fs);
                fprintf('Comparison complete.\n');
            catch ME
                fprintf('Error: %s\n', ME.message);
            end
    end
end

% =========================================================================
% FEATURE EXTRACTION
% =========================================================================
function run_feature_extraction_menu()
    fprintf('\n--- FEATURE EXTRACTION ---\n');
    
    % Load or preprocess
    [TT, success] = load_or_preprocess();
    if ~success, return; end
    
    fprintf('\nExtracting features... ');
    try
        features = Feature_Extraction(TT, 'WindowLength', 0.1, 'Overlap', 0.5);
        fprintf('Done!\n');
        
        % Display summary
        fprintf('\nExtracted features:\n');
        fprintf('  Number of windows: %d\n', height(features));
        fprintf('  Number of features: %d\n', width(features));
        fprintf('  Feature names: %s\n', strjoin(features.Properties.VariableNames(1:min(5, width(features))), ', '));
        if width(features) > 5
            fprintf('                  ... and %d more\n', width(features) - 5);
        end
        
        % Save option
        save_choice = input('Save feature table? (y/n) [default: y]: ', 's');
        if isempty(save_choice) || lower(save_choice) == 'y'
            [save_name, save_path] = uiputfile('*.csv', 'Save features as', 'features.csv');
            if ~isequal(save_name, 0)
                writetable(features, fullfile(save_path, save_name));
                fprintf('Saved to: %s\n', fullfile(save_path, save_name));
            end
        end
        
    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

% =========================================================================
% BATCH PROCESSING
% =========================================================================
function run_batch_processing_menu()
    fprintf('\n--- BATCH PROCESSING ---\n');
    fprintf('Batch processing setup:\n');
    
    % Get file list
    fprintf('Select CSV files for batch processing (uiopen for multiple selection)\n');
    [filenames, filepath] = uigetfile('*.csv', 'Select recordings (Ctrl+click for multiple)', 'MultiSelect', 'on');
    if isequal(filenames, 0)
        fprintf('No files selected.\n');
        return;
    end
    if ischar(filenames)
        filenames = {filenames};
    end
    
    fprintf('Processing %d files...\n', length(filenames));
    
    results_all = {};
    for i = 1:length(filenames)
        fprintf('[%d/%d] Processing %s... ', i, length(filenames), filenames{i});
        try
            filepath_full = fullfile(filepath, filenames{i});
            P = default_emg_parameters();
            TT = preprocess_and_label(P, 10000, 'plot_figures', false, 'fullFile', filepath_full);
            results_all{i} = labchart_protocol_check_gait_vs_spasm(TT, [], 10000);
            fprintf('Done.\n');
        catch ME
            fprintf('Error: %s\n', ME.message);
        end
    end
    
    fprintf('\nBatch processing complete! %d/%d files processed successfully.\n', ...
        length(results_all), length(filenames));
end

% =========================================================================
% PARAMETER TUNING
% =========================================================================
function run_parameter_tuning_menu()
    fprintf('\n--- PARAMETER TUNING ---\n');
    
    % Load or preprocess
    [TT, success] = load_or_preprocess();
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
                prc_range = 50:5:95;
                results = emg_parameter_tuning(TT, TT.is_act_TA, prc_range, ...
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
            [TT, success] = load_or_preprocess();
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
            fprintf('  • Feature extraction for ML/statistical analysis\n');
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
            fprintf('\nWorkflow 2: Batch processing multiple files\n');
            fprintf('  main > 5 > select files > automatic batch analysis\n');
            fprintf('\nWorkflow 3: Parameter optimization\n');
            fprintf('  main > 1 > preprocess > 6 > 1 > optimal threshold\n');
            fprintf('\nWorkflow 4: Interactive GUI\n');
            fprintf('  main > 8 > launch interface.mlapp\n');
            
        case '7'
            fprintf('\n=== TROUBLESHOOTING ===\n');
            fprintf('Problem: "Undefined function" errors\n');
            fprintf('  Solution: Ensure you ran main.m (adds paths)\n');
            fprintf('\nProblem: CSV file not loading\n');
            fprintf('  Solution: Check format (LabChart CSV with Time, TA, MG columns)\n');
            fprintf('\nProblem: Spasm detection finding too many/few events\n');
            fprintf('  Solution: Use parameter tuning (main > 6) to adjust percentile\n');
            fprintf('\nProblem: Spectral analysis looks noisy\n');
            fprintf('  Solution: Use ''filtered'' signal basis (main > 1)\n');
            fprintf('\nFor additional help, see README.md files in each folder.\n');
    end
end

% =========================================================================
% HELPER FUNCTIONS
% =========================================================================
function [TT, success] = load_or_preprocess()
    % Helper: Check if TT exists; if not, offer preprocessing
    % Returns: [TT, success_flag]
    
    TT = [];
    success = false;
    
    % Check if TT already exists in workspace
    caller_workspace = evalin('caller', 'whos');
    has_TT = any(strcmp({caller_workspace.name}, 'TT'));
    
    if has_TT
        % TT already loaded
        fprintf('\nUsing previously loaded TT structure.\n');
        TT = evalin('caller', 'TT');
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
                    load(fullfile(filepath, filename), 'TT');
                    fprintf('\nLoaded: %s\n', filename);
                    fprintf('TT structure contains %d samples at 10 kHz.\n', height(TT));
                    assignin('caller', 'TT', TT);
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
            % Preprocess - capture return value
            TT = run_single_file_preprocessing();
            
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
