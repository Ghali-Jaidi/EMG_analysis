function out = snr_emg(x, is_rest, fs, win_ms, act_prc, options)
arguments
    x (:,1) double
    is_rest (:,1) {mustBeNumericOrLogical, mustBeNonempty}
    fs (1,1) double {mustBePositive} = 10000
    win_ms (1,1) double {mustBePositive} = 20
    act_prc (1,1) double {mustBePositive} = 80
    options.xMG (:,1) double = []
    options.is_rest_MG (:,1) {mustBeNumericOrLogical} = []
end

assert(all(isfinite(x)), "x contains NaN/Inf");
is_rest = logical(is_rest(:));
assert(numel(is_rest) == numel(x), "is_rest must be same length as x");

% ---- Windowed RMS (moving) ----
win  = max(1, round((win_ms/1000)*fs));
rmsw = sqrt(movmean(x.^2, win));

% ---- REST level from ALL rest samples (robust) ----
nRest = nnz(is_rest);
assert(nRest > 0, "No REST samples. Rest mask is empty.");
Rrest_TA = median(rmsw(is_rest));   % or mean(rmsw(is_rest))

% ---- ACTIVE detection (same as before) ----
thr_act = prctile(rmsw, act_prc);
is_act  = rmsw >= thr_act;
minAct  = round(0.05*fs);
is_act  = keep_long_runs(is_act, minAct);
is_act  = fuse_masks(is_act, fs, 50);

nAct = nnz(is_act);
assert(nAct > 0, "No ACTIVE samples left. Try decreasing act_prc or lowering minAct.");

Ract_TA = median(rmsw(is_act));

% ---- Outputs ----
out.SNR_ratio = Ract_TA / Rrest_TA;
out.SNR_dB    = 20*log10(out.SNR_ratio);

% backward compatible fields
out.SNR      = out.SNR_ratio;
out.SNR_TA   = out.SNR_ratio;

out.Ract_TA  = Ract_TA;
out.Rrest_TA = Rrest_TA;
out.thr_act  = thr_act;
out.is_act   = is_act;
out.is_rest  = is_rest;
out.rmsw     = rmsw;

% ---- MG channel if provided ----
if ~isempty(options.xMG)
    assert(~isempty(options.is_rest_MG), "Provide options.is_rest_MG when xMG is provided.");
    assert(all(isfinite(options.xMG)), "xMG contains NaN/Inf");

    xMG = options.xMG(:);
    is_rest_MG = logical(options.is_rest_MG(:));
    assert(numel(is_rest_MG) == numel(xMG), "is_rest_MG must be same length as xMG");

    rmsw_MG = sqrt(movmean(xMG.^2, win));

    nRest_MG = nnz(is_rest_MG);
    assert(nRest_MG > 0, "No REST MG samples.");

    Rrest_MG = median(rmsw_MG(is_rest_MG));

    thr_act_MG = prctile(rmsw_MG, act_prc);
    is_act_MG  = rmsw_MG >= thr_act_MG;
    minAct_MG  = round(0.05*fs);
    is_act_MG  = keep_long_runs(is_act_MG, minAct_MG);
    is_act_MG  = fuse_masks(is_act_MG, fs, 50);

    nAct_MG = nnz(is_act_MG);
    assert(nAct_MG > 0, "No ACTIVE MG samples left. Try decreasing act_prc or lowering minAct.");

    Ract_MG = median(rmsw_MG(is_act_MG));

    out.SNR_MG_ratio = Ract_MG / Rrest_MG;
    out.SNR_MG_dB    = 20*log10(out.SNR_MG_ratio);

    % backward compatible field
    out.SNR_MG   = out.SNR_MG_ratio;

    out.Ract_MG  = Ract_MG;
    out.Rrest_MG = Rrest_MG;
    out.thr_act_MG = thr_act_MG;
    out.is_act_MG  = is_act_MG;
    out.is_rest_MG = is_rest_MG;
    out.rmsw_MG     = rmsw_MG;
end
end