%% =========================
% Batch preprocessing + group comparisons (single summary figure with 4 subplots)
%   1) SNR (TA/MG): Uninjured vs Spastic
%   2) PNR (TA/MG): Uninjured vs Spastic
%       - Uninjured: peak over full recording
%       - Spastic: peak restricted to user spasm intervals (if provided)
%   3) Contraction duration (TA/MG):
%       - Uninjured: mean bout duration during normal active (all recording)
%       - Spastic: longest bout duration during spasm intervals
%   4) TA–MG cross-correlation (group mean curve):
%       - Uninjured: per-recording xcorr on active samples (is_act_TA OR is_act_MG)
%       - Spastic: per-recording xcorr averaged over spasm segments (intervals),
%                  then averaged across recordings
%
% Requires on path:
%   - preprocess_and_label.m
%   - ask_condition_and_intervals.m   (separate file, already)
%   - compare_files_xcorr_avg.m       (the modular version that accepts 'R')
%% =========================

fs = 10000;
max_lag_s = 2.0;

%% ---- Number of recordings ----
answer = inputdlg('How many experiment MAT files do you want to process?', ...
                  'Number of recordings', [1 50], {'2'});
if isempty(answer), error('Selection cancelled.'); end

nFiles = str2double(answer{1});
if isnan(nFiles) || nFiles <= 0, error('Invalid number of files.'); end

%% ---- Preallocate ----
R = struct( ...
    'file', "", 'fullFile', "", 'recID', NaN, ...
    'cond', "", 'group', "", 'intervals', [], ...
    'snrTA', NaN, 'snrMG', NaN, ...
    'pnrTA', NaN, 'pnrMG', NaN, ...
    'durNormTA', NaN, 'durNormMG', NaN, ...
    'durSpasmTA', NaN, 'durSpasmMG', NaN, ...
    'TA_env', [], 'MG_env', [], ...
    'TA_rect', [], 'MG_rect', [], ...
    'is_act_TA', [], 'is_act_MG', [] );
R = repmat(R, nFiles, 1);

%% ---- File selection + preprocess + metrics ----
for k = 1:nFiles

    msg = sprintf([ ...
        'Select recording %d of %d.\n\n' ...
        'Select ONE experiment MAT file.\n' ...
        'Preprocessing will start after selection.'], ...
        k, nFiles);
    uiwait(msgbox(msg,'Select experiment file','modal'));

    [f,p] = uigetfile('*.mat', sprintf('Select experiment MAT file (%d/%d)', k, nFiles));
    if isequal(f,0), error('File selection cancelled.'); end

    fullFile = fullfile(p,f);
    fprintf('\n=== [%d/%d] Processing: %s ===\n', k, nFiles, fullFile);

    [TTk, snrk, metak] = preprocess_and_label(fs, ...
        'fullFile', fullFile, ...
        'plot_figures', false, ...
        'save_figures', false);

    tag = sprintf('%s (rec %d)', f, metak.recID);
    [condk, intervalsk] = ask_condition_and_intervals(tag);

    if strcmpi(condk,'Spastic')
        groupk = "injured";
    elseif strcmpi(condk,'Uninjured')
        groupk = "uninjured";
    else
        groupk = lower(string(condk));
    end

    R(k).file      = string(f);
    R(k).fullFile  = string(fullFile);
    R(k).recID     = metak.recID;
    R(k).cond      = string(condk);
    R(k).group     = groupk;
    R(k).intervals = intervalsk;

    N = height(TTk);

    %% ---- Save xcorr inputs for later (no UI / no reprocessing) ----
    R(k).TA_env   = TTk.TA_env(:);
    R(k).MG_env   = TTk.MG_env(:);
    R(k).TA_rect  = TTk.TA_rect(:);
    R(k).MG_rect  = TTk.MG_rect(:);
    R(k).is_act_TA = snrk.is_act(:);
    R(k).is_act_MG = snrk.is_act_MG(:);

    %% ---- SNR ----
    R(k).snrTA = snrk.SNR_TA;
    R(k).snrMG = snrk.SNR_MG;

    %% ---- Interval mask (clean timeline) ----
    if ~isempty(intervalsk)
        spasmWin = build_interval_mask(N, fs, intervalsk);
    else
        spasmWin = false(N,1);
    end

    %% ---- PNR (rectified; no envelope) ----
    if groupk == "injured" && any(spasmWin)
        peakMask = spasmWin;
    else
        peakMask = true(N,1);
    end

    R(k).pnrTA = peak_to_noise_masked_peak(TTk.TA_rect, snrk.is_rest,     peakMask, 100);
    R(k).pnrMG = peak_to_noise_masked_peak(TTk.MG_rect, snrk.is_rest_MG,  peakMask, 100);

    %% ---- Contraction durations ----
    actTA = snrk.is_act(:);
    actMG = snrk.is_act_MG(:);

    if groupk == "uninjured"
        R(k).durNormTA  = mean_bout_duration(actTA, fs);
        R(k).durNormMG  = mean_bout_duration(actMG, fs);
        R(k).durSpasmTA = NaN;
        R(k).durSpasmMG = NaN;

    elseif groupk == "injured"

        R(k).durNormTA  = NaN;
        R(k).durNormMG  = NaN;
    
        if ~isempty(intervalsk)
    
            nSp = size(intervalsk,1);
            durTA_each = nan(nSp,1);
            durMG_each = nan(nSp,1);
    
            for ii = 1:nSp
                mask_i = build_interval_mask(N, fs, intervalsk(ii,:));
    
                if ~any(mask_i), continue; end
    
                durTA_each(ii) = max_bout_duration(actTA & mask_i, fs);
                durMG_each(ii) = max_bout_duration(actMG & mask_i, fs);
            end
    
            % Bar height (mean of per-spasm maxima)
            R(k).durSpasmTA = mean(durTA_each, 'omitnan');
            R(k).durSpasmMG = mean(durMG_each, 'omitnan');
    
            % SD between spasms (for error bars)
            R(k).durSpasmTA_sd = std(durTA_each, 0, 'omitnan');
            R(k).durSpasmMG_sd = std(durMG_each, 0, 'omitnan');
    
        else
            R(k).durSpasmTA = NaN;
            R(k).durSpasmMG = NaN;
            R(k).durSpasmTA_sd = NaN;
            R(k).durSpasmMG_sd = NaN;
        end
    
    else
            R(k).durNormTA  = mean_bout_duration(actTA, fs);
            R(k).durNormMG  = mean_bout_duration(actMG, fs);
            R(k).durSpasmTA = NaN;
            R(k).durSpasmMG = NaN;
    end

end

%% ---- Group masks ----
groups = lower(string({R.group}));
isUninj = groups == "uninjured";
isInj   = groups == "injured";
assert(any(isUninj) && any(isInj), "Need at least one Uninjured and one Spastic recording.");

%% ---- Group means: SNR ----
muSNR_uninj = [mean([R(isUninj).snrTA], 'omitnan'), mean([R(isUninj).snrMG], 'omitnan')];
muSNR_inj   = [mean([R(isInj).snrTA],   'omitnan'), mean([R(isInj).snrMG],   'omitnan')];
M_SNR = [muSNR_uninj; muSNR_inj];

%% ---- Group means: PNR ----
muPNR_uninj = [mean([R(isUninj).pnrTA], 'omitnan'), mean([R(isUninj).pnrMG], 'omitnan')];
muPNR_inj   = [mean([R(isInj).pnrTA],   'omitnan'), mean([R(isInj).pnrMG],   'omitnan')];
M_PNR = [muPNR_uninj; muPNR_inj];

%% ---- Duration comparison: Uninjured normal vs Spastic spasm ----
muDur_uninj = [mean([R(isUninj).durNormTA], 'omitnan'), mean([R(isUninj).durNormMG], 'omitnan')];
muDur_spasm = [mean([R(isInj).durSpasmTA],  'omitnan'), mean([R(isInj).durSpasmMG],  'omitnan')];
M_DUR = [muDur_uninj; muDur_spasm];

%% ---- Cross-correlation: NO UI, reuse R ----
xcOut = compare_files_xcorr(fs, max_lag_s, 'R', R, 'UseEnvelope', true, ...
    'GroupUninj', "uninjured", 'GroupSpastic', "injured");

lags_ref     = xcOut.lags_s(:);
meanXC_uninj = xcOut.meanU(:);
sdXC_uninj   = xcOut.sdU(:);
nU           = xcOut.n_uninj_used;


meanXC_inj   = xcOut.meanS(:);
sdXC_inj   = xcOut.sdS(:);

nS         = xcOut.n_spas_used;

z = 1.96;  % ~95% CI
ciU = z * (sdXC_uninj ./ sqrt(max(nU,1)));
% --- choose spastic CI source ---
if isfield(xcOut,'ciS_within') && nS < 2 && isfield(xcOut,'meanS_seg')
    % fallback: CI across spasm segments within the single recording
    meanXC_inj = xcOut.meanS_seg(:);
    ciS        = xcOut.ciS_within(:);
    ciLabelS   = sprintf('Spastic 95%% CI within spasms (nSeg=%d)', xcOut.nSeg);
else
    % default: CI across recordings
    ciLabelS = sprintf('Spastic 95%% CI across recs (n=%d)', nS);
end

%% ---- Y-limits ----
yMaxSNR = max(M_SNR(:), [], 'omitnan') * 1.1;  if ~isfinite(yMaxSNR) || yMaxSNR<=0, yMaxSNR=1; end
yMaxPNR = max(M_PNR(:), [], 'omitnan') * 1.1;  if ~isfinite(yMaxPNR) || yMaxPNR<=0, yMaxPNR=1; end
yMaxDur = max(M_DUR(:), [], 'omitnan') * 1.1;  if ~isfinite(yMaxDur) || yMaxDur<=0, yMaxDur=1; end
yMaxXC  = max([abs(meanXC_uninj); abs(meanXC_inj)], [], 'omitnan') * 1.1;
if ~isfinite(yMaxXC) || yMaxXC<=0, yMaxXC = 1; end



%% ---- Group SDs: SNR ----
sdSNR_uninj = [std([R(isUninj).snrTA], 0, 'omitnan'), std([R(isUninj).snrMG], 0, 'omitnan')];
sdSNR_inj   = [std([R(isInj).snrTA],   0, 'omitnan'), std([R(isInj).snrMG],   0, 'omitnan')];
SD_SNR = [sdSNR_uninj; sdSNR_inj];

%% ---- Group SDs: PNR ----
sdPNR_uninj = [std([R(isUninj).pnrTA], 0, 'omitnan'), std([R(isUninj).pnrMG], 0, 'omitnan')];
sdPNR_inj   = [std([R(isInj).pnrTA],   0, 'omitnan'), std([R(isInj).pnrMG],   0, 'omitnan')];
SD_PNR = [sdPNR_uninj; sdPNR_inj];

%% ---- Group SDs: Duration ----
sdDur_uninj = [std([R(isUninj).durNormTA], 0, 'omitnan'), std([R(isUninj).durNormMG], 0, 'omitnan')];
sdDur_spasm = [mean([R(isInj).durSpasmTA_sd],'omitnan'), ...
               mean([R(isInj).durSpasmMG_sd],'omitnan')];
SD_DUR = [sdDur_uninj; sdDur_spasm];

%% ---- XCorr SD across recordings (needs per-recording curves) ----
% Requires compare_files_xcorr to also return per-recording curves, OR recompute here.
% If your compare_files_xcorr already returns XC matrices, use them. Otherwise see note below.
sdXC_uninj = xcOut.sdU(:);
sdXC_inj   = xcOut.sdS(:);

%% ---- Single summary figure (4 subplots) ----
figure('Name','Group comparison: SNR, PNR, Duration, XCorr');

% ---------- SNR ----------
subplot(2,2,1);
b = bar(M_SNR); hold on;

% Bar centers for grouped bars:
x = arrayfun(@(i) b(i).XEndPoints, 1:numel(b), 'UniformOutput', false);

errorbar(x{1}, M_SNR(:,1), SD_SNR(:,1), ...
    'Color', [1 1 1], ...   % white
    'LineWidth', 3, ...     % thicker
    'CapSize', 14, ...
    'LineStyle', 'none'); 
errorbar(x{2}, M_SNR(:,2), SD_SNR(:,2), ...
    'Color', [1 1 1], ...   % white
    'LineWidth', 3, ...     % thicker
    'CapSize', 14, ...
    'LineStyle', 'none'); 

set(gca,'XTickLabel',{'Uninjured','Spastic'});
legend({'TA','MG'},'Location','best');
ylabel('Mean SNR (linear)');
grid on;
ylim([0 yMaxSNR]);
title(sprintf(['Signal-to-Noise Ratio\n' ...
    'Uninjured: TA %.2f±%.2f  MG %.2f±%.2f | Spastic: TA %.2f±%.2f  MG %.2f±%.2f'], ...
    muSNR_uninj(1), sdSNR_uninj(1), muSNR_uninj(2), sdSNR_uninj(2), ...
    muSNR_inj(1),   sdSNR_inj(1),   muSNR_inj(2),   sdSNR_inj(2)));

% ---------- PNR ----------
subplot(2,2,2);
b = bar(M_PNR); hold on;
x = arrayfun(@(i) b(i).XEndPoints, 1:numel(b), 'UniformOutput', false);

errorbar(x{1}, M_PNR(:,1), SD_PNR(:,1), ...
    'Color', [1 1 1], ...   % white
    'LineWidth', 3, ...     % thicker
    'CapSize', 14, ...
    'LineStyle', 'none'); 

errorbar(x{2}, M_PNR(:,2), SD_PNR(:,2), ...
    'Color', [1 1 1], ...   % white
    'LineWidth', 3, ...     % thicker
    'CapSize', 14, ...
    'LineStyle', 'none'); 

set(gca,'XTickLabel',{'Uninjured','Spastic'});
legend({'TA','MG'},'Location','best');
ylabel('Mean Peak-to-Noise Ratio');
grid on;
ylim([0 yMaxPNR]);
title(sprintf(['Peak-to-Noise Ratio\n' ...
    'Uninjured: TA %.2f±%.2f  MG %.2f±%.2f | Spastic: TA %.2f±%.2f  MG %.2f±%.2f'], ...
    muPNR_uninj(1), sdPNR_uninj(1), muPNR_uninj(2), sdPNR_uninj(2), ...
    muPNR_inj(1),   sdPNR_inj(1),   muPNR_inj(2),   sdPNR_inj(2)));

% ---------- Duration ----------
subplot(2,2,3);
b = bar(M_DUR); hold on;
x = arrayfun(@(i) b(i).XEndPoints, 1:numel(b), 'UniformOutput', false);


errorbar(x{1}, M_DUR(:,1), SD_DUR(:,1), ...
    'Color', [1 1 1], ...   % white
    'LineWidth', 3, ...     % thicker
    'CapSize', 14, ...
    'LineStyle', 'none'); 
errorbar(x{2}, M_DUR(:,2), SD_DUR(:,2), ...
    'Color', [1 1 1], ...   % white
    'LineWidth', 3, ...     % thicker
    'CapSize', 14, ...
    'LineStyle', 'none'); 

set(gca,'XTickLabel',{'Uninjured (normal)','Spastic (spasm)'});
legend({'TA','MG'},'Location','best');
ylabel('Contraction duration (s)');
grid on;
ylim([0 yMaxDur]);
title(sprintf(['Contraction Duration\n' ...
    'Uninjured: TA %.3f±%.3f  MG %.3f±%.3f | Spastic: TA %.3f±%.3f  MG %.3f±%.3f'], ...
    muDur_uninj(1), sdDur_uninj(1), muDur_uninj(2), sdDur_uninj(2), ...
    muDur_spasm(1), sdDur_spasm(1), muDur_spasm(2), sdDur_spasm(2)));

% ---------- Cross-correlation ----------
subplot(2,2,4);
hold on; grid on;

% Uninjured CI band
fill([lags_ref; flipud(lags_ref)], ...
     [meanXC_uninj - ciU; flipud(meanXC_uninj + ciU)], ...
     [0.7 0.7 0.7], 'FaceAlpha', 0.5, 'EdgeColor', 'none');

% Spastic CI band (either across recs or within-spasm fallback)
fill([lags_ref; flipud(lags_ref)], ...
     [meanXC_inj - ciS; flipud(meanXC_inj + ciS)], ...
     [1 1 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');

% Mean curves (draw on top)
hU = plot(lags_ref, meanXC_uninj, 'LineWidth', 1.8);
hS = plot(lags_ref, meanXC_inj,   'LineWidth', 2.5);
uistack(hS,'top');

xlabel('Lag (s)');
ylabel('Normalized xcorr');

% y-lims should include CI
yMaxXC = max([abs(meanXC_uninj)+abs(ciU); abs(meanXC_inj)+abs(ciS)], [], 'omitnan') * 1.1;
if ~isfinite(yMaxXC) || yMaxXC<=0, yMaxXC=1; end
ylim([-yMaxXC yMaxXC]);

title(sprintf('TA–MG Cross-correlation (mean ± 95%% CI) | \\pm %.1f s', max_lag_s));
legend({'Uninjured 95% CI', ciLabelS, 'Uninjured mean', 'Spastic mean'}, 'Location','best');

%% =========================
% Local functions
%% =========================

function pnr = peak_to_noise_masked_peak(xRect, isRest, peakMask, peakPrct)
xRect = xRect(:);
isRest = isRest(:);
peakMask = peakMask(:);

if isempty(xRect) || numel(isRest) ~= numel(xRect) || numel(peakMask) ~= numel(xRect)
    pnr = NaN;
    return;
end
if ~any(isRest) || ~any(peakMask)
    pnr = NaN;
    return;
end

noise = rms(xRect(isRest));
xpk = xRect(peakMask);

if nargin < 4 || isempty(peakPrct) || peakPrct >= 100
    pk = max(xpk);
else
    pk = prctile(xpk, peakPrct);
end

pnr = pk / (noise + eps);
end

function m = mean_bout_duration(isOn, fs)
isOn = isOn(:) ~= 0;
if ~any(isOn)
    m = NaN;
    return;
end
d = diff([false; isOn; false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;
durS   = (ends - starts + 1) / fs;
m = mean(durS, 'omitnan');
end

function m = max_bout_duration(isOn, fs)
isOn = isOn(:) ~= 0;
if ~any(isOn)
    m = NaN;
    return;
end
d = diff([false; isOn; false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;
durS   = (ends - starts + 1) / fs;
m = max(durS);
end

function mask = build_interval_mask(N, fs, intervals)
mask = false(N,1);
if isempty(intervals), return; end
for k = 1:size(intervals,1)
    t0 = intervals(k,1);
    t1 = intervals(k,2);
    if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0
        continue;
    end
    i0 = max(1, floor(t0*fs) + 1);
    i1 = min(N, floor(t1*fs));
    if i1 >= i0
        mask(i0:i1) = true;
    end
end
end