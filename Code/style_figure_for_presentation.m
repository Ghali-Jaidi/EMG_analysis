function style_figure_for_presentation(figHandle)
% STYLE_FIGURE_FOR_PRESENTATION
%   Applies white background styling to all axes and legends in a figure
%   for better presentation/printing appearance.
%
% Usage:
%   figHandle = gcf();  % Get current figure
%   style_figure_for_presentation(figHandle);
%
% This function:
%   1. Sets figure background to white
%   2. Sets all axes backgrounds to white
%   3. Styles all legends with white background and black border
%   4. Makes gridlines visible
%   5. Ensures text is black for readability
%   6. Converts error bars to black for visibility

if nargin < 1 || isempty(figHandle)
    figHandle = gcf();  % Use current figure if none provided
end

% Set figure background to white
set(figHandle, 'Color', 'white');

% Get all axes in this figure
axHandles = findall(figHandle, 'Type', 'axes');

for i = 1:length(axHandles)
    ax = axHandles(i);
    
    % Set axes background to white
    set(ax, 'Color', 'white');
    
    % Configure gridlines
    grid(ax, 'on');
    set(ax, 'GridColor', [0.2 0.2 0.2]);
    set(ax, 'GridAlpha', 0.3);
    set(ax, 'GridLineStyle', '-');
    
    % Set axis colors to black
    set(ax, 'XColor', 'black', 'YColor', 'black', 'ZColor', 'black');
    set(ax, 'TickLabelInterpreter', 'tex');
    
    % Fix text colors (title, labels)
    titleHandle = get(ax, 'Title');
    if ~isempty(titleHandle)
        set(titleHandle, 'Color', 'black');
    end
    
    xLabelHandle = get(ax, 'XLabel');
    if ~isempty(xLabelHandle)
        set(xLabelHandle, 'Color', 'black');
    end
    
    yLabelHandle = get(ax, 'YLabel');
    if ~isempty(yLabelHandle)
        set(yLabelHandle, 'Color', 'black');
    end
    
    zLabelHandle = get(ax, 'ZLabel');
    if ~isempty(zLabelHandle)
        set(zLabelHandle, 'Color', 'black');
    end
    
    % Fix error bars - they should be black not white
    errorBarHandles = findall(ax, 'Type', 'errorbar');
    for j = 1:length(errorBarHandles)
        set(errorBarHandles(j), 'Color', 'black', 'LineWidth', 1.5);
    end
    
    % Style legend if it exists
    legHandle = get(ax, 'Legend');
    if ~isempty(legHandle)
        set(legHandle, ...
            'Color', 'white', ...
            'EdgeColor', 'black', ...
            'TextColor', 'black', ...
            'LineWidth', 1, ...
            'Box', 'on');
    end
end

% Get all legend objects in the figure (in case they're not tied to specific axes)
legHandles = findall(figHandle, 'Type', 'legend');
for i = 1:length(legHandles)
    set(legHandles(i), ...
        'Color', 'white', ...
        'EdgeColor', 'black', ...
        'TextColor', 'black', ...
        'LineWidth', 1, ...
        'Box', 'on');
end

% Fix any text objects that might have white color
textHandles = findall(figHandle, 'Type', 'text');
for i = 1:length(textHandles)
    currColor = get(textHandles(i), 'Color');
    % If color is white or very light, change to black
    if isequal(currColor, [1 1 1]) || isequal(currColor, 'w') || ...
       (isnumeric(currColor) && all(currColor > 0.8))
        set(textHandles(i), 'Color', 'black');
    end
end

end
