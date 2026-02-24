function out = snr_emg(x, noiseWindow, fs, win_ms, act_prc, options)
arguments
    x (:,1) double
    noiseWindow (:,1) double {mustBeNonempty}
    fs (1,1) double {mustBePositive} = 10000
    win_ms (1,1) double {mustBePositive} = 20
    act_prc (1,1) double {mustBePositive} = 80
    options.xMG (:,1) double = []
    options.noiseWindowMG (:,1) double = []
end

assert(all(isfinite(x)), "x contains NaN/Inf");

% Noise RMS from TA window
Rrest_TA = rms(noiseWindow);

% Windowed RMS for TA
win  = max(1, round((win_ms/1000)*fs));
rmsw = sqrt(movmean(x.^2, win));

% Active detection for TA
thr_act = prctile(rmsw, act_prc);
is_act  = rmsw >= thr_act;
minAct  = round(0.05*fs);
is_act  = keep_long_runs(is_act, minAct);
is_act  = fuse_masks(is_act, fs, 50);

nAct = nnz(is_act);
assert(nAct > 0, "No ACTIVE samples left. Try decreasing act_prc or lowering minAct.");

Ract_TA = median(rmsw(is_act));

out.SNR      = Ract_TA / Rrest_TA;  % backward compatibility
out.SNR_TA   = out.SNR;
out.Ract_TA  = Ract_TA;
out.Rrest_TA = Rrest_TA;
out.thr_act  = thr_act;
out.is_act   = is_act;
out.rmsw     = rmsw;

% MG SNR if provided
if ~isempty(options.xMG) && ~isempty(options.noiseWindowMG)
    assert(all(isfinite(options.xMG)), "xMG contains NaN/Inf");

    Rrest_MG = rms(options.noiseWindowMG);
    rmsw_MG  = sqrt(movmean(options.xMG.^2, win));

    % Independent active detection for MG
    thr_act_MG = prctile(rmsw_MG, act_prc);
    is_act_MG  = rmsw_MG >= thr_act_MG;
    minAct_MG  = round(0.05*fs);
    is_act_MG  = keep_long_runs(is_act_MG, minAct_MG);
    is_act_MG  = fuse_masks(is_act_MG, fs, 50);

    nAct_MG = nnz(is_act_MG);
    assert(nAct_MG > 0, "No ACTIVE MG samples left. Try decreasing act_prc or lowering minAct.");

    Ract_MG = median(rmsw_MG(is_act_MG));

    out.SNR_MG     = Ract_MG / Rrest_MG;
    out.Ract_MG    = Ract_MG;
    out.Rrest_MG   = Rrest_MG;
    out.thr_act_MG = thr_act_MG;
    out.is_act_MG  = is_act_MG;
    out.rmsw_MG    = rmsw_MG;
end

end
