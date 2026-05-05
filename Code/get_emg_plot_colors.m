function colors = get_emg_plot_colors()
% GET_EMG_PLOT_COLORS
%   Returns a consistent set of darker, high-contrast colors optimized
%   for white backgrounds in EMG plots.
%
% Returns:
%   colors - struct with fields:
%     - TA: dark green for TA channel
%     - MG: dark blue for MG channel
%     - Ch3: dark red for Channel 3
%     - rest: pinkish tone for rest regions
%     - active: yellow-green for active regions
%     - threshold: black for threshold lines

% Define darker, more saturated colors for better contrast on white
colors.TA = [0 0.5 0];           % Dark green (instead of light 'g')
colors.MG = [0 0 0.7];           % Dark blue (instead of light 'b')
colors.Ch3 = [0.8 0 0];          % Dark red (instead of light 'r')
colors.rest = [1 0.85 0.85];     % Light pink for rest regions
colors.active = [1 1 0];         % Yellow for active regions
colors.threshold = [0 0 0];      % Black for threshold lines

end
