function y = notch_filter(x, f0, nyq , Q )

% Define the notch filter parameters and apply the notch filter to clean
% the power grid noise and its first 3 harmonics. 
% f0 = 50 because of the power grid frequency in Europe, Nyq = 5000 due to
% our data and 30 is a conservative estimate for the Quality factor

arguments 
    x {mustBeNumeric}
    f0 {mustBePositive} = 50
    nyq {mustBePositive} = 5000
    Q {mustBePositive} = 30
end


for fh = [f0 ]  %only 0 harmonics after the 50Hz base noise,
                        % or else we risk losing useful info 
    wo = fh/nyq; % Computes the normalized notch center frequency ( between 0 and 1)
    bw = wo/Q; % Normalized Bandwidth frim qualit factor
    [b,a] = iirnotch(wo,bw);
    y = filtfilt(b,a,x);
 
end