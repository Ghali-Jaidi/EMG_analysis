function [epochs, n_epochs] = extract_burst_epochs(signal, active_mask, min_length)
% extract_burst_epochs  Split a signal into contiguous active-region epochs.
%
% Each run of consecutive true samples in active_mask becomes one epoch
% (a segment of signal). Runs shorter than min_length samples are dropped.
%
% INPUTS
%   signal      : column/row vector signal
%   active_mask : logical (or 0/1) mask, same length as signal
%   min_length  : minimum run length in samples to keep an epoch
%
% OUTPUTS
%   epochs   : cell array, one signal segment per kept burst
%   n_epochs : numel(epochs)

epochs = {};
in_burst = false;
start_idx = 0;

for i = 1:numel(active_mask)
    if active_mask(i) == 1 && ~in_burst
        in_burst = true;
        start_idx = i;
    elseif active_mask(i) == 0 && in_burst
        in_burst = false;
        epoch_len = i - start_idx;
        if epoch_len >= min_length
            epochs{end+1} = signal(start_idx:i-1); %#ok<AGROW>
        end
    end
end
% Handle a burst that extends to the end of the signal
if in_burst
    epoch_len = numel(active_mask) - start_idx + 1;
    if epoch_len >= min_length
        epochs{end+1} = signal(start_idx:end); %#ok<AGROW>
    end
end

n_epochs = numel(epochs);
end
