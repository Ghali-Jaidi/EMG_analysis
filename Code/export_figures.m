%% Export all figures to PNG for PowerPoint
% This script converts the .fig files to high-resolution PNG images

clear; clc;

fig_dir = pwd;
fig_files = {
    '01_amplitude_distributions.fig';
    '02_time_domain_signals.fig';
    '03_frequency_analysis.fig';
    '04_autocorrelation_analysis.fig'
};

fprintf('=== EXPORTING FIGURES TO PNG ===\n');

for f = 1:length(fig_files)
    fig_name = fig_files{f};
    fig_path = fullfile(fig_dir, fig_name);
    png_name = strrep(fig_name, '.fig', '.png');
    png_path = fullfile(fig_dir, png_name);
    
    if isfile(fig_path)
        fprintf('  Converting: %s → %s\n', fig_name, png_name);
        fig = openfig(fig_path, 'invisible');
        exportgraphics(fig, png_path, 'Resolution', 150);
        close(fig);
        fprintf('    ✓ Saved: %s\n', png_path);
    else
        fprintf('  WARNING: %s not found\n', fig_path);
    end
end

fprintf('\n✓ All figures exported to PNG\n');
