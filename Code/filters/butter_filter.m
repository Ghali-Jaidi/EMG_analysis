

function y = butter_filter(x, fc, fs, order)
% Bandpass Butterworth filter with zero-phase filtering for EMG
%   y = butter_filter(x, fc, fs, order) filters input signal x with a zero-phase
%   bandpass Butterworth filter of specified order and cutoff fc = [f1 f2].
%   fs is the sampling frequency. x can be a vector or a matrix; filtering
%   is applied along the first non-singleton dimension.
%
%   Example:
%     y = butter_filter(x, [20 450], 1000, 4);

arguments
    x {mustBeNumeric}
    fc (1,2) {mustBePositive} = [5, 500]
    fs (1,1) {mustBePositive} = 10000
    order (1,1) {mustBeNonnegative, mustBeInteger} = 2
end

% Normalize cutoff by Nyquist
Wn = fc(:).' / (fs/2); % 1x2
disp(Wn);

% Design bandpass Butterworth
[b,a] = butter(order, Wn, 'bandpass');

% Apply zero-phase filtering 
y = filtfilt(b,a, x);

end