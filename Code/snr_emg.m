function out = snr_emg(x, is_rest, fs, win_ms, act_prc, options)
arguments
    x (:,1) double
    is_rest (:,1) {mustBeNumericOrLogical, mustBeNonempty}
    fs (1,1) double {mustBePositive} = 10000
    win_ms (1,1) double {mustBePositive} = 20
    act_prc (1,1) double {mustBePositive} = 80

    options.xMG (:,1) double = []
    options.is_rest_MG (:,1) {mustBeNumericOrLogical} = []
    options.act_prc_MG (1,1) double {mustBePositive} = act_prc
    options.valid_mask (:,1) logical = []
end

% ---------- Valid mask ----------
if isempty(options.valid_mask)
    valid_mask = true(size(x));
else
    valid_mask = options.valid_mask(:);
end

assert(numel(valid_mask) == numel(x), "valid_mask must match x length");
assert(all(isfinite(x(valid_mask))), "x(valid_mask) contains NaN/Inf");

is_rest = logical(is_rest(:));
assert(numel(is_rest) == numel(x), "is_rest must be same length as x");

% ---------- Windowed RMS ----------
win  = max(1, round((win_ms/1000)*fs));
rmsw = sqrt(movmean(x.^2, win));

% ---------- REST level ----------
rest_mask = is_rest & valid_mask;
nRest = nnz(rest_mask);
assert(nRest > 0, "No REST samples. Rest mask is empty.");

Rrest_TA = median(rmsw(rest_mask));

% ---------- ACTIVE detection ----------
thr_act = prctile(rmsw(valid_mask), act_prc);

is_act = false(size(x));
is_act(valid_mask) = rmsw(valid_mask) >= thr_act;

minAct = round(0.05*fs);
is_act = keep_long_runs(is_act, minAct);
is_act = fuse_masks(is_act, fs, 50);

% ensure active only inside valid region
is_act(~valid_mask) = false;

nAct = nnz(is_act);
assert(nAct > 0, "No ACTIVE samples left. Try decreasing act_prc.");

Ract_TA = median(rmsw(is_act));

% ---------- Outputs ----------
out.SNR_ratio = Ract_TA / Rrest_TA;
out.SNR_dB    = 20*log10(out.SNR_ratio);

out.SNR      = out.SNR_ratio;
out.SNR_TA   = out.SNR_ratio;

out.Ract_TA  = Ract_TA;
out.Rrest_TA = Rrest_TA;
out.thr_act  = thr_act;
out.is_act   = is_act;
out.is_rest  = is_rest;
out.rmsw     = rmsw;

% ---------- MG channel ----------
if ~isempty(options.xMG)

    xMG = options.xMG(:);
    assert(all(isfinite(xMG(valid_mask))), "xMG(valid_mask) contains NaN/Inf");

    is_rest_MG = logical(options.is_rest_MG(:));
    assert(numel(is_rest_MG) == numel(xMG), "is_rest_MG must match xMG");

    rmsw_MG = sqrt(movmean(xMG.^2, win));

    rest_mask_MG = is_rest_MG & valid_mask;
    nRest_MG = nnz(rest_mask_MG);
    assert(nRest_MG > 0, "No REST MG samples.");

    Rrest_MG = median(rmsw_MG(rest_mask_MG));

    thr_act_MG = prctile(rmsw_MG(valid_mask), options.act_prc_MG);

    is_act_MG = false(size(xMG));
    is_act_MG(valid_mask) = rmsw_MG(valid_mask) >= thr_act_MG;

    minAct_MG = round(0.05*fs);
    is_act_MG = keep_long_runs(is_act_MG, minAct_MG);
    is_act_MG = fuse_masks(is_act_MG, fs, 50);

    is_act_MG(~valid_mask) = false;

    nAct_MG = nnz(is_act_MG);
    assert(nAct_MG > 0, "No ACTIVE MG samples left.");

    Ract_MG = median(rmsw_MG(is_act_MG));

    out.SNR_MG_ratio = Ract_MG / Rrest_MG;
    out.SNR_MG_dB    = 20*log10(out.SNR_MG_ratio);

    out.SNR_MG   = out.SNR_MG_ratio;
    out.Ract_MG  = Ract_MG;
    out.Rrest_MG = Rrest_MG;
    out.thr_act_MG = thr_act_MG;
    out.is_act_MG  = is_act_MG;
    out.is_rest_MG = is_rest_MG;
    out.rmsw_MG    = rmsw_MG;
end
end