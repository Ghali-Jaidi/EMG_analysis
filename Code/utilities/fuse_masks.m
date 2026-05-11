function mask_fused = fuse_masks(mask, fs, max_gap_ms)
% fuse_close_intervals - Fuses rest intervals separated by less than max_gap_ms
%
% Inputs:
%   mask       : logical vector of rest periods
%   fs         : sampling frequency (Hz)
%   max_gap_ms : maximum gap in ms between two intervals to fuse them
%
% Output:
%   mask_fused : logical vector with close intervals fused

arguments
    mask (:,1) logical
    fs (1,1) double {mustBePositive} = 10000
    max_gap_ms (1,1) double {mustBePositive} = 30
end

max_gap_samples = round(max_gap_ms / 1000 * fs);

d      = diff([false; mask; false]);
starts = find(d ==  1);
ends   = find(d == -1) - 1;

% Fuse intervals separated by less than max_gap_samples
% More efficient: mark which intervals to keep/merge
keep = true(numel(starts), 1);
for k = 1:numel(starts)-1
    if keep(k)  % Only check if this interval wasn't already merged
        gap = starts(k+1) - ends(k) - 1;
        if gap <= max_gap_samples
            % Merge: extend current interval and mark next for deletion
            ends(k) = ends(k+1);
            keep(k+1) = false;
        end
    end
end

% Extract only kept intervals
starts = starts(keep);
ends = ends(keep);

% Rebuild mask
mask_fused = false(size(mask));
for k = 1:numel(starts)
    mask_fused(starts(k):ends(k)) = true;
end

end