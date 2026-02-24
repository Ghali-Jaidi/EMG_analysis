function plot_amplitudes(signal, options)
arguments
    signal (:,1) double
    options.NumBins (1,1) double {mustBePositive} = 50
    options.Axes = []
    options.ThrAct (1,1) double = NaN
    options.NoiseRMS (1,1) double = NaN
end

if isempty(options.Axes)
    figure;
    ax = gca;
else
    ax = options.Axes;
end

xMin = prctile(signal, 1);
xMax = prctile(signal, 99);
edges = linspace(xMin, xMax, options.NumBins + 1);

histogram(ax, signal, edges, ...
    'FaceColor', [0.2 0.6 1], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.8);

xlabel(ax, 'Amplitude');
ylabel(ax, 'Count');
title(ax, 'Amplitude Distribution');
grid(ax, 'on'); box(ax, 'on');

xMean = mean(signal);
xStd  = std(signal);
xline(ax, xMean,        '-k',  sprintf('Mean: %.3f', xMean),           'LineWidth', 1.5);
xline(ax, xMean + xStd, '--r', sprintf('+1 STD: %.3f', xMean + xStd), 'LineWidth', 1);
xline(ax, xMean - xStd, '--r', sprintf('-1 STD: %.3f', xMean - xStd), 'LineWidth', 1);

if ~isnan(options.ThrAct)
    xline(ax, options.ThrAct, '-', sprintf('Active thr: %.3f', options.ThrAct), ...
        'Color', [1 0.5 0], 'LineWidth', 1.5);
end

if ~isnan(options.NoiseRMS)
    xline(ax, options.NoiseRMS, '-', sprintf('Noise RMS: %.3f', options.NoiseRMS), ...
        'Color', [0.5 0 1], 'LineWidth', 1.5);
end

end