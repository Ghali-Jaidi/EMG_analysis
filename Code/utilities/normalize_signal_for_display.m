function normalized = normalize_signal_for_display(signal)
% NORMALIZE_SIGNAL_FOR_DISPLAY
% Normalizes a signal so that its maximum value spans the full available space.
% The minimum value is mapped to 0, and the maximum value is mapped to 1.
%
% Input:
%   signal - vector of signal values
% Output:
%   normalized - signal scaled from 0 to 1, preserving relative amplitudes

% Remove NaN values for min/max calculation
signal_clean = signal(~isnan(signal));

if isempty(signal_clean)
    normalized = signal;
    return;
end

% Get min and max
sig_min = min(signal_clean);
sig_max = max(signal_clean);

% Handle case where all values are the same (avoid division by zero)
if sig_max == sig_min
    normalized = ones(size(signal)) * 0.5;
else
    % Normalize: map [sig_min, sig_max] to [0, 1]
    normalized = (signal - sig_min) / (sig_max - sig_min);
end

end
