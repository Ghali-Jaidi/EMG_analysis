function set_white_background_style()
% SET_WHITE_BACKGROUND_STYLE
%   Sets all current and future MATLAB figures to have white backgrounds
%   and optimizes colors for printing/presentation.
%
% Usage:
%   set_white_background_style();
%   % Now run your plotting code...
%   preprocess_and_label();
%
% This function:
%   1. Sets default figure background to white
%   2. Sets default axes background to white
%   3. Makes gridlines visible on white background
%   4. Optimizes text colors for readability
%   5. Configures legends with white background and borders
%   6. Uses darker, more visible colors for data lines
%
% Note: Call this BEFORE creating figures for best results

% Set default figure color to white
set(0, 'DefaultFigureColor', 'white');

% Set default axes background to white
set(0, 'DefaultAxesColor', 'white');

% Set default axes grid on and make gridlines darker for visibility
set(0, 'DefaultAxesGridColor', [0.2 0.2 0.2]);
set(0, 'DefaultAxesGridAlpha', 0.3);
set(0, 'DefaultAxesGridLineStyle', '-');

% Set default text color to black (good contrast on white)
set(0, 'DefaultAxesXColor', 'black');
set(0, 'DefaultAxesYColor', 'black');
set(0, 'DefaultAxesZColor', 'black');
set(0, 'DefaultTextColor', 'black');

% Configure legend defaults: white background with edge for visibility
set(0, 'DefaultLegendColor', 'white');
set(0, 'DefaultLegendEdgeColor', 'black');
set(0, 'DefaultLegendTextColor', 'black');

% Use darker line colors for better visibility on white background
set(0, 'DefaultLineLineWidth', 1.2);

% Make existing figures white and update legends (if any are already open)
figHandles = findall(0, 'Type', 'figure');
for i = 1:length(figHandles)
    set(figHandles(i), 'Color', 'white');
    
    axHandles = findall(figHandles(i), 'Type', 'axes');
    for j = 1:length(axHandles)
        set(axHandles(j), 'Color', 'white');
        
        % Update legends in this axes
        legHandle = legend(axHandles(j));
        if ~isempty(legHandle)
            set(legHandle, 'Color', 'white', 'EdgeColor', 'black', 'TextColor', 'black');
        end
    end
end

fprintf('White background style applied to all figures (including legends).\n');

end
