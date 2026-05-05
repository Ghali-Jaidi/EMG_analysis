%% Test the new subplot-based plot_filtered_labeled.m
clear all; close all;

% Load default parameters
default_emg_parameters;

% Use synthetic data for testing
load('synthetic_rec.mat', 'channel_1', 'channel_2', 'channel_3', 'fs');

fprintf('Loaded synthetic recording: %d samples at %d Hz\n', length(channel_1), fs);

% Filter the data
options.plot_figures = false;
options.save_figures = false;
options.detect_valid_acq = false;

[snrValue, ~, ~, ~, ~, ~] = preprocess_and_label(fs, options);

fprintf('SNR computation complete.\n');
fprintf('  - TA activity: %d segments\n', sum(snrValue.is_act));
fprintf('  - MG activity: %d segments\n', sum(snrValue.is_act_MG));
fprintf('  - TA rest: %d segments\n', sum(snrValue.is_rest));
fprintf('  - MG rest: %d segments\n', sum(snrValue.is_rest_MG));

% Create time vector
t = (0:length(channel_1)-1)' / fs;

% Test the new subplot plot
fprintf('\nCreating subplot visualization...\n');
figure('Name', 'New Subplot Plot Test', 'NumberTitle', 'off');

% Call the new subplot-based plot function
plot_filtered_labeled(channel_1, channel_2, channel_3, t, snrValue);

fprintf('Subplot plot created successfully!\n');
fprintf('  - Each channel has independent Y-axis scale\n');
fprintf('  - Active/rest regions are highlighted\n');
fprintf('  - Threshold lines are displayed\n');
