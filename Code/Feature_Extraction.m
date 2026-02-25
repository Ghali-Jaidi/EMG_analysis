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
        if any(spasmWin)
            R(k).durSpasmTA = max_bout_duration(actTA & spasmWin, fs);
            R(k).durSpasmMG = max_bout_duration(actMG & spasmWin, fs);
        else
            R(k).durSpasmTA = NaN;
            R(k).durSpasmMG = NaN;
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
meanXC_inj   = xcOut.meanS(:);

%% ---- Y-limits ----
yMaxSNR = max(M_SNR(:), [], 'omitnan') * 1.1;  if ~isfinite(yMaxSNR) || yMaxSNR<=0, yMaxSNR=1; end
yMaxPNR = max(M_PNR(:), [], 'omitnan') * 1.1;  if ~isfinite(yMaxPNR) || yMaxPNR<=0, yMaxPNR=1; end
yMaxDur = max(M_DUR(:), [], 'omitnan') * 1.1;  if ~isfinite(yMaxDur) || yMaxDur<=0, yMaxDur=1; end
yMaxXC  = max([abs(meanXC_uninj); abs(meanXC_inj)], [], 'omitnan') * 1.1;
if ~isfinite(yMaxXC) || yMaxXC<=0, yMaxXC = 1; end

%% ---- Single summary figure (4 subplots) ----
figure('Name','Group comparison: SNR, PNR, Duration, XCorr');

% ---------- SNR ----------
subplot(1,4,1);
bar(M_SNR);
set(gca,'XTickLabel',{'Uninjured','Spastic'});
legend({'TA','MG'},'Location','best');
ylabel('Mean SNR (linear)');
grid on;
ylim([0 yMaxSNR]);
title(sprintf(['Signal-to-Noise Ratio\n' ...
    'Uninjured: TA %.2f  MG %.2f   |   Spastic: TA %.2f  MG %.2f'], ...
    muSNR_uninj(1), muSNR_uninj(2), muSNR_inj(1), muSNR_inj(2)));

% ---------- PNR ----------
subplot(1,4,2);
bar(M_PNR);
set(gca,'XTickLabel',{'Uninjured','Spastic'});
legend({'TA','MG'},'Location','best');
ylabel('Mean Peak-to-Noise Ratio');
grid on;
ylim([0 yMaxPNR]);
title(sprintf(['Peak-to-Noise Ratio\n' ...
    'Uninjured: TA %.2f  MG %.2f   |   Spastic: TA %.2f  MG %.2f'], ...
    muPNR_uninj(1), muPNR_uninj(2), muPNR_inj(1), muPNR_inj(2)));

% ---------- Duration ----------
subplot(1,4,3);
bar(M_DUR);
set(gca,'XTickLabel',{'Uninjured (normal)','Spastic (spasm)'});
legend({'TA','MG'},'Location','best');
ylabel('Contraction duration (s)');
grid on;
ylim([0 yMaxDur]);
title(sprintf(['Contraction Duration\n' ...
    'Uninjured (normal): TA %.3f  MG %.3f   |   Spastic (spasm): TA %.3f  MG %.3f'], ...
    muDur_uninj(1), muDur_uninj(2), muDur_spasm(1), muDur_spasm(2)));

% ---------- Cross-correlation ----------
subplot(1,4,4);
plot(lags_ref, meanXC_uninj, 'LineWidth', 1.5); 
hold on;
plot(lags_ref, meanXC_inj,   'LineWidth', 1.5);
grid on;
xlabel('Lag (s)');
ylabel('Normalized xcorr');
ylim([-yMaxXC yMaxXC]);
title(sprintf(['TA–MG Cross-correlation (mean)\n' ...
    'Uninjured: active | Spastic: mean over spasm segments | \\pm %.1f s'], max_lag_s));
legend({'Uninjured mean','Spastic mean'}, 'Location','best');


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