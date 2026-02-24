function [iQuiet_start, iQuiet_end, thresh_final, is_quiet] = find_quiet_window(signal, fs, winLen, thresholds, percentages, label)
% find_quiet_window - Finds the first quiet window in a signal
%
% Inputs:
%   signal      : rectified signal to search in
%   fs          : sampling frequency
%   winLen      : window length in samples
%   thresholds  : vector of percentile thresholds to try (e.g. [40 50])
%   percentages : vector of coverage fractions to try (e.g. [0.95 0.90])
%   label       : string label for fprintf (e.g. 'TA' or 'MG')
%
% Outputs:
%   iQuiet_start : start index of quiet window
%   iQuiet_end   : end index of quiet window
%   thresh_final : amplitude threshold used
%   is_quiet     : logical mask of quiet samples

arguments
    signal (:,1) double
    fs (1,1) double {mustBePositive}
    winLen (1,1) double {mustBePositive}
    thresholds (1,:) double
    percentages (1,:) double
    label (1,:) char = 'Signal'
end

iQuiet = [];
thresh_final = NaN;
is_quiet     = false(size(signal));

for i = 1:numel(thresholds)
    for j = 1:numel(percentages)
        thresh   = prctile(signal, thresholds(i));
        is_q     = signal <= thresh;
        quiet_sum = conv(double(is_q), ones(winLen, 1), 'valid');
        iQuiet   = find(quiet_sum >= percentages(j) * winLen, 1, 'first');
        if ~isempty(iQuiet)
            fprintf('%s: Found quiet window at percentile=%d%%, coverage=%.0f%%\n', ...
                label, thresholds(i), percentages(j)*100);
            thresh_final = thresh;
            is_quiet     = is_q;
            break;
        end
    end
    if ~isempty(iQuiet), break; end
end

if isempty(iQuiet)
    warning('%s: No quiet window found. Using absolute minimum.', label);
    quiet_sum    = conv(double(signal <= prctile(signal, thresholds(1))), ones(winLen,1), 'valid');
    [~, iQuiet]  = min(quiet_sum);
    thresh_final = prctile(signal, 20);
    is_quiet     = signal <= thresh_final;
end

iQuiet_start = iQuiet;
iQuiet_end   = iQuiet + winLen - 1;

end