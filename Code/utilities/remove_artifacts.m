function [TT_clean, TT_NaN, bad_seg] = remove_artifacts(TT, snrValue, fs, artifactP)
% remove_artifacts - Removes artifacts from EMG timetable
%
% Inputs:
%   TT       : timetable with TA_rect, MG_rect, TA_env, MG_env fields
%   fs       : sampling frequency
%   snrValue : struct from snr_emg containing Ract_TA and Ract_MG
%
% Outputs:
%   TT_clean : timetable with bad segments removed
%   TT_NaN   : timetable with bad segments set to NaN
%   bad_seg  : logical mask of bad samples

arguments
    TT timetable
    snrValue struct
    fs (1,1) double {mustBePositive} = default_emg_parameters().fs
    artifactP (1,1) struct = default_emg_parameters().artifact
end

% Artifact thresholds: rms_mult x the typical active RMS per channel
artifact_thr_TA = snrValue.Ract_TA * artifactP.rms_mult;
artifact_thr_MG = snrValue.Ract_MG * artifactP.rms_mult;

fprintf('Artifact thresholds  ->  TA: %.4f   MG: %.4f\n', ...
    artifact_thr_TA, artifact_thr_MG);

% Flag samples exceeding threshold on either channel
bad1 = (TT.TA_rect > artifact_thr_TA) | (TT.MG_rect > artifact_thr_MG);

% Also flag sudden amplitude jumps (instantaneous spikes)
bad_jump_TA = abs(diff([0; TT.TA_rect])) > artifact_thr_TA;
bad_jump_MG = abs(diff([0; TT.MG_rect])) > artifact_thr_MG;
bad1 = bad1 | bad_jump_TA | bad_jump_MG;

% Dilate bad regions to catch transition edges
win      = round((artifactP.dilate_win_ms/1000)*fs);
pad      = round((artifactP.pad_ms/1000)*fs);
bad_win1 = movmean(double(bad1), win) > artifactP.frac_thresh;
bad_seg  = logical(conv(double(bad_win1), ones(pad,1), 'same') > 0);

x = bad_seg(:);
d = diff([false; x; false]);
iStart = find(d ==  1);
iEnd   = find(d == -1) - 1;
tStart = TT.tDur(iStart);
tEnd   = TT.tDur(iEnd);

fprintf('Deleted %d interval(s):\n', numel(iStart));
for k = 1:numel(iStart)
    fprintf('  %2d) %.6f s  ->  %.6f s   (%d samples)\n', ...
        k, seconds(tStart(k)), seconds(tEnd(k)), iEnd(k)-iStart(k)+1);
end

TT_clean = TT(~bad_seg, :);
TT_NaN   = TT;
TT_NaN.TA_rect(bad_seg) = NaN;
TT_NaN.MG_rect(bad_seg) = NaN;
TT_NaN.TA_env(bad_seg)  = NaN;
TT_NaN.MG_env(bad_seg)  = NaN;

end