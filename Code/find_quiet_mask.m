function [is_quiet, thresh_final] = find_quiet_mask(signal, thresholds, label)
% find_quiet_mask - Build a per-sample "quiet/rest" mask from a rectified signal.
% This function ONLY returns a mask; it does NOT search for any contiguous window.
%
% Inputs:
%   signal      : rectified signal (vector)
%   thresholds  : vector of percentile thresholds to try (e.g. [40 50])
%   label       : string label for warnings/prints (e.g. 'TA' or 'MG')
%
% Outputs:
%   is_quiet     : logical mask of quiet samples (signal <= percentile threshold)
%   thresh_final : amplitude threshold used (in signal units)

arguments
    signal (:,1) double
    thresholds (1,:) double {mustBeNonempty}
    label (1,:) char = 'Signal'
end

signal = signal(:);
is_quiet = false(size(signal));
thresh_final = NaN;

% Try thresholds in order: first one that yields at least some quiet samples
for i = 1:numel(thresholds)
    thr = prctile(signal, thresholds(i));
    mask = signal <= thr;

    if nnz(mask) > 0
        is_quiet = mask;
        thresh_final = thr;
        fprintf('%s: Quiet mask using percentile=%d%% (thr=%.4g), quiet=%.1f%% samples\n', ...
            label, thresholds(i), thr, 100*nnz(mask)/numel(mask));
        return;
    end
end

% Fallback: guarantee a non-empty mask by taking the minimum value
warning('%s: No quiet samples found from given thresholds. Falling back to minimum-based mask.', label);
[~, idxMin] = min(signal);
is_quiet(idxMin) = true;
thresh_final = signal(idxMin);

end