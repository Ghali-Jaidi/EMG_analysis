function [iSNR_start, iSNR_end] = find_snr_window(is_rest, TT_clean, fs, min_snr_window_s, label)
% find_snr_window - Finds the longest quiet window for SNR computation
%
% Inputs:
%   is_rest          : logical mask of rest samples (aligned to TT_clean)
%   TT_clean         : cleaned timetable
%   fs               : sampling frequency
%   min_snr_window_s : minimum window duration in seconds (default 1.0)
%   label            : string label for fprintf (e.g. 'TA' or 'MG')
%
% Outputs:
%   iSNR_start : start index of SNR baseline window
%   iSNR_end   : end index of SNR baseline window

arguments
    is_rest (:,1) logical
    TT_clean timetable
    fs (1,1) double {mustBePositive} = 10000
    min_snr_window_s (1,1) double {mustBePositive} = 1.0
    label (1,:) char = 'Signal'
end

min_snr_samples = round(min_snr_window_s * fs);

d_snr      = diff([false; is_rest; false]);
starts_snr = find(d_snr ==  1);
ends_snr   = find(d_snr == -1) - 1;
lens_snr   = ends_snr - starts_snr + 1;

valid_snr = lens_snr >= min_snr_samples;

if any(valid_snr)
    [~, best] = max(lens_snr .* valid_snr);
else
    warning('%s: No quiet window of %.1fs found. Using longest available.', label, min_snr_window_s);
    [~, best] = max(lens_snr);
end

iSNR_start = starts_snr(best);
iSNR_end   = ends_snr(best);

fprintf('%s SNR baseline: %.3f s -> %.3f s (%d samples)\n', ...
    label, ...
    double(seconds(TT_clean.tDur(iSNR_start))), ...
    double(seconds(TT_clean.tDur(iSNR_end))), ...
    iSNR_end - iSNR_start + 1);

end