function set_gui_white_background(figHandle)
 % Set the entire figure and all components to have white backgrounds
    % This ensures a professional, consistent appearance
    
    % Set figure background
    figHandle.Color = 'white';
    
    % Find all panels
    panelHandles = findall(figHandle, 'Type', 'uipanel');
    for i = 1:length(panelHandles)
        set(panelHandles(i), 'BackgroundColor', 'white');
        set(panelHandles(i), 'ForegroundColor', 'black');
    end
    
    % Find all grid layouts
    gridLayoutHandles = findall(figHandle, 'Type', 'uigridlayout');
    for i = 1:length(gridLayoutHandles)
        set(gridLayoutHandles(i), 'BackgroundColor', 'white');
    end
    
    % Find all axes
    axesHandles = findall(figHandle, 'Type', 'uiaxes');
    for i = 1:length(axesHandles)
        set(axesHandles(i), 'Color', 'white');
        set(axesHandles(i), 'XColor', 'black', 'YColor', 'black', 'ZColor', 'black');
        set(axesHandles(i), 'GridColor', [0.2 0.2 0.2]);
        set(axesHandles(i), 'GridAlpha', 0.3);
    end
    
    % Find all labels and set text color to black
    labelHandles = findall(figHandle, 'Type', 'uilabel');
    for i = 1:length(labelHandles)
        set(labelHandles(i), 'FontColor', 'black');
    end
    
    % Find all buttons and set to white background
    buttonHandles = findall(figHandle, 'Type', 'uibutton');
    for i = 1:length(buttonHandles)
        set(buttonHandles(i), 'BackgroundColor', 'white');
        set(buttonHandles(i), 'FontColor', 'black');
    end
    
    % Find all edit fields and set to white background
    editFieldHandles = findall(figHandle, 'Type', 'uieditfield');
    for i = 1:length(editFieldHandles)
        set(editFieldHandles(i), 'BackgroundColor', 'white');
        set(editFieldHandles(i), 'FontColor', 'black');
    end
    
    % Find all dropdowns and set to white background
    dropdownHandles = findall(figHandle, 'Type', 'uidropdown');
    for i = 1:length(dropdownHandles)
        set(dropdownHandles(i), 'BackgroundColor', 'white');
        set(dropdownHandles(i), 'FontColor', 'black');
    end
    
    % Find all checkboxes and set font color (no BackgroundColor property)
    checkboxHandles = findall(figHandle, 'Type', 'uicheckbox');
    for i = 1:length(checkboxHandles)
        set(checkboxHandles(i), 'FontColor', 'black');
    end
    
    % Find all state buttons (separate from regular buttons by checking class)
    % StateButton is a different class from regular uibutton
    stateButtonHandles = findall(figHandle, 'Type', 'matlab.ui.control.StateButton');
    for i = 1:length(stateButtonHandles)
        set(stateButtonHandles(i), 'BackgroundColor', 'white');
        set(stateButtonHandles(i), 'FontColor', 'black');
    end
end
