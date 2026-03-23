%% =========================
% Master analysis script
%% =========================
clear; clc;

fs = 10000;
max_lag_s = 2.0;

%% ---- Ask user what to run ----
ans1 = questdlg('Do you want to run the comparison between injured and uninjured mice?', ...
    'Group comparison', 'Yes', 'No', 'Yes');
run_group_compare = strcmp(ans1, 'Yes');

ans2 = questdlg('Do you want to run the comparison between stim ON and stim OFF?', ...
    'Stim ON/OFF comparison', 'Yes', 'No', 'Yes');
run_stim_compare = strcmp(ans2, 'Yes');

if ~run_group_compare && ~run_stim_compare
    error('Nothing selected.');
end

%% ============================================================
%  PART 1 — Injured vs Uninjured comparison
%% ============================================================
if run_group_compare

    answer = inputdlg('How many experiment MAT files do you want to process for injured/uninjured comparison?', ...
                      'Number of recordings', [1 60], {'2'});
    if isempty(answer), error('Selection cancelled.'); end

    nFiles = str2double(answer{1});
    if isnan(nFiles) || nFiles <= 0
        error('Invalid number of files.');
    end

    %% ---- Preallocate ----
    R = struct( ...
        'file', "", 'fullFile', "", 'recID', NaN, ...
        'cond', "", 'group', "", 'intervals', [], ...
        'snrTA', NaN, 'snrMG', NaN, ...
        'pnrTA', NaN, 'pnrMG', NaN, ...
        'durNormTA', NaN, 'durNormMG', NaN, ...
        'durSpasmTA', NaN, 'durSpasmMG', NaN, ...
        'durSpasmTA_sd', NaN, 'durSpasmMG_sd', NaN, ...
        'TA_env', [], 'MG_env', [], ...
        'TA_rect', [], 'MG_rect', [], ...
        'is_act_TA', [], 'is_act_MG', [], ...
        'ovNormTA_MG', NaN, ...
        'ovSpasmTA_MG', NaN, ...
        'ovSpasmTA_MG_sd', NaN);
    R = repmat(R, nFiles, 1);

    %% ---- File selection + preprocess + metrics ----
    for k = 1:nFiles

        msg = sprintf(['Select recording %d of %d for injured/uninjured comparison.\n' ...
                       'Select ONE experiment MAT file.'], k, nFiles);
        uiwait(msgbox(msg, 'Select experiment file', 'modal'));

        [f,p] = uigetfile('*.mat', sprintf('Select experiment MAT file (%d/%d)', k, nFiles));
        if isequal(f,0), error('File selection cancelled.'); end

        fullFile = fullfile(p,f);
        fprintf('\n=== [%d/%d] Processing: %s ===\n', k, nFiles, fullFile);

        % --- Load params if a _param file exists, otherwise use defaults ---
        [~, srcName, ~] = fileparts(f);
        paramFile = fullfile(p, [srcName, '_param.mat']);
        if isfile(paramFile)
            fprintf('    Found param file: %s\n', paramFile);
            tmp = load(paramFile, 'P');
            P = tmp.P;
        else
            fprintf('    No param file found, using defaults.\n');
            P = default_emg_parameters();
        end

        [TTk, snrk, metak] = preprocess_and_label(P, fs, ...
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

        R(k).TA_env    = TTk.TA_env(:);
        R(k).MG_env    = TTk.MG_env(:);
        R(k).TA_rect   = TTk.TA_rect(:);
        R(k).MG_rect   = TTk.MG_rect(:);
        R(k).is_act_TA = snrk.is_act(:);
        R(k).is_act_MG = snrk.is_act_MG(:);

        R(k).snrTA = snrk.SNR_TA;
        R(k).snrMG = snrk.SNR_MG;

        if ~isempty(intervalsk)
            spasmWin = build_interval_mask(N, fs, intervalsk);
        else
            spasmWin = false(N,1);
        end

        if groupk == "injured" && any(spasmWin)
            peakMask = spasmWin;
        else
            peakMask = true(N,1);
        end

        R(k).pnrTA = peak_to_noise_masked_peak(TTk.TA_env, snrk.is_rest,    peakMask, 100);
        R(k).pnrMG = peak_to_noise_masked_peak(TTk.MG_env, snrk.is_rest_MG, peakMask, 100);

        actTA = snrk.is_act(:);
        actMG = snrk.is_act_MG(:);
        overlap = actTA & actMG;

        if groupk == "uninjured"
            R(k).ovNormTA_MG = mean_bout_duration(overlap, fs);
            R(k).durNormTA   = mean_bout_duration(actTA, fs);
            R(k).durNormMG   = mean_bout_duration(actMG, fs);

        elseif groupk == "injured"
            if ~isempty(intervalsk)
                nSp = size(intervalsk,1);
                ov_each    = nan(nSp,1);
                durTA_each = nan(nSp,1);
                durMG_each = nan(nSp,1);

                for ii = 1:nSp
                    mask_i = build_interval_mask(N, fs, intervalsk(ii,:));
                    if ~any(mask_i), continue; end

                    ov_each(ii)    = max_bout_duration(overlap & mask_i, fs);
                    durTA_each(ii) = max_bout_duration(actTA & mask_i, fs);
                    durMG_each(ii) = max_bout_duration(actMG & mask_i, fs);
                end

                R(k).ovSpasmTA_MG    = mean(ov_each, 'omitnan');
                R(k).ovSpasmTA_MG_sd = std(ov_each, 0, 'omitnan');

                R(k).durSpasmTA    = mean(durTA_each, 'omitnan');
                R(k).durSpasmMG    = mean(durMG_each, 'omitnan');
                R(k).durSpasmTA_sd = std(durTA_each, 0, 'omitnan');
                R(k).durSpasmMG_sd = std(durMG_each, 0, 'omitnan');
            end
        end
    end

    %% ---- Group masks ----
    groups = lower(string({R.group}));
    isUninj = groups == "uninjured";
    isInj   = groups == "injured";
    assert(any(isUninj) && any(isInj), "Need at least one Uninjured and one Spastic recording.");

    %% ---- Group means / SDs ----
    muSNR_uninj = [mean([R(isUninj).snrTA], 'omitnan'), mean([R(isUninj).snrMG], 'omitnan')];
    muSNR_inj   = [mean([R(isInj).snrTA],   'omitnan'), mean([R(isInj).snrMG],   'omitnan')];
    M_SNR = [muSNR_uninj; muSNR_inj];

    sdSNR_uninj = [std([R(isUninj).snrTA], 0, 'omitnan'), std([R(isUninj).snrMG], 0, 'omitnan')];
    sdSNR_inj   = [std([R(isInj).snrTA],   0, 'omitnan'), std([R(isInj).snrMG],   0, 'omitnan')];
    SD_SNR = [sdSNR_uninj; sdSNR_inj];

    muPNR_uninj = [mean([R(isUninj).pnrTA], 'omitnan'), mean([R(isUninj).pnrMG], 'omitnan')];
    muPNR_inj   = [mean([R(isInj).pnrTA],   'omitnan'), mean([R(isInj).pnrMG],   'omitnan')];
    M_PNR = [muPNR_uninj; muPNR_inj];

    sdPNR_uninj = [std([R(isUninj).pnrTA], 0, 'omitnan'), std([R(isUninj).pnrMG], 0, 'omitnan')];
    sdPNR_inj   = [std([R(isInj).pnrTA],   0, 'omitnan'), std([R(isInj).pnrMG],   0, 'omitnan')];
    SD_PNR = [sdPNR_uninj; sdPNR_inj];

    muDur_uninj = [mean([R(isUninj).durNormTA], 'omitnan'), mean([R(isUninj).durNormMG], 'omitnan')];
    muDur_spasm = [mean([R(isInj).durSpasmTA],  'omitnan'), mean([R(isInj).durSpasmMG],  'omitnan')];
    M_DUR = [muDur_uninj; muDur_spasm];

    sdDur_uninj = [std([R(isUninj).durNormTA], 0, 'omitnan'), std([R(isUninj).durNormMG], 0, 'omitnan')];
    sdDur_spasm = [mean([R(isInj).durSpasmTA_sd],'omitnan'), mean([R(isInj).durSpasmMG_sd],'omitnan')];
    SD_DUR = [sdDur_uninj; sdDur_spasm];

    muOv_uninj = mean([R(isUninj).ovNormTA_MG], 'omitnan');
    muOv_spasm = mean([R(isInj).ovSpasmTA_MG], 'omitnan');
    M_OV = [muOv_uninj; muOv_spasm];

    sdOv_uninj = std([R(isUninj).ovNormTA_MG], 0, 'omitnan');
    sdOv_spasm = mean([R(isInj).ovSpasmTA_MG_sd], 'omitnan');
    SD_OV = [sdOv_uninj; sdOv_spasm];

    %% ---- Cross-correlation ----
    xcOut = compare_files_xcorr(fs, max_lag_s, 'R', R, 'UseEnvelope', true, ...
        'GroupUninj', "uninjured", 'GroupSpastic', "injured");

    RecCurves = xcOut.RecCurves;
    nRec = numel(RecCurves);
    peakLag = nan(nRec,1);

    for i = 1:nRec
        xc_i = RecCurves(i).xc;
        lags_i = RecCurves(i).lags_s;
        if any(isfinite(xc_i))
            [~, idx] = max(xc_i);
            peakLag(i) = lags_i(idx);
        end
    end

    groupsXC = lower(string({RecCurves.group}));
    isUninjXC = groupsXC == "uninjured";
    isInjXC   = groupsXC == "injured";

    peak_uninj = peakLag(isUninjXC);
    peak_inj   = peakLag(isInjXC);

    lags_ref     = xcOut.lags_s(:);
    meanXC_uninj = xcOut.meanU(:);
    sdXC_uninj   = xcOut.sdU(:);
    nU           = xcOut.n_uninj_used;

    meanXC_inj = xcOut.meanS(:);
    nS         = xcOut.n_spas_used;
    z = 1.96;
    ciU = z * (sdXC_uninj ./ sqrt(max(nU,1)));

    if isfield(xcOut,'ciS_within') && nS < 2 && isfield(xcOut,'meanS_seg')
        meanXC_inj = xcOut.meanS_seg(:);
        ciS        = xcOut.ciS_within(:);
        ciLabelS   = sprintf('Spastic 95%% CI within spasms (nSeg=%d)', xcOut.nSeg);
    else
        sdXC_inj = xcOut.sdS(:);
        ciS      = z * (sdXC_inj ./ sqrt(max(nS,1)));
        ciLabelS = sprintf('Spastic 95%% CI across recs (n=%d)', nS);
    end

    %% ---- Plot ----
    yMaxSNR = max(M_SNR(:), [], 'omitnan') * 1.1; if ~isfinite(yMaxSNR) || yMaxSNR<=0, yMaxSNR=1; end
    yMaxPNR = max(M_PNR(:), [], 'omitnan') * 1.1; if ~isfinite(yMaxPNR) || yMaxPNR<=0, yMaxPNR=1; end
    yMaxDur = max(M_DUR(:), [], 'omitnan') * 1.1; if ~isfinite(yMaxDur) || yMaxDur<=0, yMaxDur=1; end
    yMaxOv  = max(M_OV(:),  [], 'omitnan') * 1.1; if ~isfinite(yMaxOv)  || yMaxOv<=0,  yMaxOv=1;  end
    yMaxXC  = max([abs(meanXC_uninj)+abs(ciU); abs(meanXC_inj)+abs(ciS)], [], 'omitnan') * 1.1;
    if ~isfinite(yMaxXC) || yMaxXC<=0, yMaxXC=1; end

    figure('Name','Group comparison: SNR, PNR, Duration, XCorr');

    subplot(3,2,1);
    b = bar(M_SNR); hold on;
    x = arrayfun(@(i) b(i).XEndPoints, 1:numel(b), 'UniformOutput', false);
    errorbar(x{1}, M_SNR(:,1), SD_SNR(:,1), 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    errorbar(x{2}, M_SNR(:,2), SD_SNR(:,2), 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    set(gca,'XTickLabel',{'Uninjured','Spastic'}); legend({'TA','MG'},'Location','best');
    ylabel('Mean SNR (linear)'); grid on; ylim([0 yMaxSNR]); title('Signal-to-Noise Ratio');

    subplot(3,2,2);
    b = bar(M_PNR); hold on;
    x = arrayfun(@(i) b(i).XEndPoints, 1:numel(b), 'UniformOutput', false);
    errorbar(x{1}, M_PNR(:,1), SD_PNR(:,1), 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    errorbar(x{2}, M_PNR(:,2), SD_PNR(:,2), 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    set(gca,'XTickLabel',{'Uninjured','Spastic'}); legend({'TA','MG'},'Location','best');
    ylabel('Mean Peak-to-Noise Ratio'); grid on; ylim([0 yMaxPNR]); title('Peak-to-Noise Ratio');

    subplot(3,2,3);
    b = bar(M_DUR); hold on;
    x = arrayfun(@(i) b(i).XEndPoints, 1:numel(b), 'UniformOutput', false);
    errorbar(x{1}, M_DUR(:,1), SD_DUR(:,1), 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    errorbar(x{2}, M_DUR(:,2), SD_DUR(:,2), 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    set(gca,'XTickLabel',{'Uninjured (normal)','Spastic (spasm)'}); legend({'TA','MG'},'Location','best');
    ylabel('Contraction duration (s)'); grid on; ylim([0 yMaxDur]); title('Contraction Duration');

    subplot(3,2,4); hold on; grid on; box on;
    fill([lags_ref; flipud(lags_ref)], [meanXC_uninj-ciU; flipud(meanXC_uninj+ciU)], [0.7 0.7 0.7], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    fill([lags_ref; flipud(lags_ref)], [meanXC_inj-ciS; flipud(meanXC_inj+ciS)], [1 1 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    plot(lags_ref, meanXC_uninj, 'LineWidth', 1.8);
    plot(lags_ref, meanXC_inj, 'LineWidth', 2.5);
    xlabel('Lag (s)'); ylabel('Correlation'); ylim([-yMaxXC yMaxXC]);
    title(sprintf('TA-MG Cross-correlation (mean +/- 95%% CI) | +/- %.1f s', max_lag_s));
    legend({'Uninjured 95% CI', ciLabelS, 'Uninjured mean', 'Spastic mean'}, 'Location','best');

    subplot(3,2,5);
    muPeak = [mean(peak_uninj,'omitnan'), mean(peak_inj,'omitnan')];
    sdPeak = [std(peak_uninj,0,'omitnan'), std(peak_inj,0,'omitnan')];
    b = bar(muPeak); hold on;
    errorbar(b.XEndPoints, muPeak, sdPeak, 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    set(gca,'XTickLabel',{'Uninjured','Spastic'}); ylabel('Lag at peak xcorr (s)');
    title('TA-MG cross-correlation peak lag'); grid on;

    subplot(3,2,6);
    b = bar(M_OV); hold on;
    errorbar(b.XEndPoints, M_OV, SD_OV, 'w', 'LineWidth', 3, 'CapSize', 14, 'LineStyle', 'none');
    set(gca,'XTickLabel',{'Uninjured (normal)','Spastic (spasm)'});
    ylabel('TA-MG overlap bout duration (s)'); grid on; ylim([0 yMaxOv]);
    title('TA & MG overlap duration');

    exportgraphics(gcf, 'group_comparison.pdf', 'ContentType', 'vector');
end

%% ============================================================
%  PART 2 — Stim ON vs Stim OFF comparison
%% ============================================================
if run_stim_compare

    answer = inputdlg('How many experiment MAT files do you want to process for stim ON/OFF analysis?', ...
                      'Number of recordings', [1 60], {'2'});
    if isempty(answer), error('Selection cancelled.'); end

    nStimFiles = str2double(answer{1});
    if isnan(nStimFiles) || nStimFiles <= 0
        error('Invalid number of files.');
    end

    TA_signals  = {};
    MG_signals  = {};
    Ch3_signals = {};

    for k = 1:nStimFiles
        msg = sprintf(['Select recording %d of %d for stim ON/OFF comparison.\n' ...
                       'Select ONE experiment MAT file.'], k, nStimFiles);
        uiwait(msgbox(msg, 'Select experiment file', 'modal'));

        [f,p] = uigetfile('*.mat', sprintf('Select experiment MAT file (%d/%d)', k, nStimFiles));
        if isequal(f,0), error('File selection cancelled.'); end

        fullFile = fullfile(p,f);
        fprintf('\n=== [%d/%d] Stim analysis: %s ===\n', k, nStimFiles, fullFile);

        % --- Load params if a _param file exists, otherwise use defaults ---
        [~, srcName, ~] = fileparts(f);
        paramFile = fullfile(p, [srcName, '_param.mat']);
        if isfile(paramFile)
            fprintf('    Found param file: %s\n', paramFile);
            tmp = load(paramFile, 'P');
            P = tmp.P;
        else
            fprintf('    No param file found, using defaults.\n');
            P = default_emg_parameters();
        end

        [TTk, ~, metak] = preprocess_and_label(P, fs, ...
            'fullFile', fullFile, ...
            'plot_figures', false, ...
            'save_figures', false);

        ta_full  = TTk.TA_env;
        mg_full  = TTk.MG_env;
        ch3_full = TTk.Ch3_raw;

        % Replace invalid samples with NaN instead of removing them
        ta_full(~metak.is_valid)  = NaN;
        mg_full(~metak.is_valid)  = NaN;
        ch3_full(~metak.is_valid) = NaN;

        TA_signals{end+1}  = ta_full;   %#ok<AGROW>
        MG_signals{end+1}  = mg_full;   %#ok<AGROW>
        Ch3_signals{end+1} = ch3_full;  %#ok<AGROW>
    end

    % -------- MG figure --------

    outStim_MG = amplitude_distribution( ...
        MG_signals, Ch3_signals, fs, ...
        'MGAlreadyAmplitude', true, ...
        'PreWindowS', [-2 -0.2], ...
        'OnMinDurMs', 100, ...
        'TitleStr', 'MG amplitude during Ch3 ON vs local pre-ON OFF window');

    disp('--- MG summary ---');
    disp(outStim_MG.summary);

    % -------- TA figure --------

    outStim_TA = amplitude_distribution( ...
        TA_signals, Ch3_signals, fs, ...
        'MGAlreadyAmplitude', true, ...
        'PreWindowS', [-2 -0.2], ...
        'OnMinDurMs', 100, ...
        'TitleStr', 'TA amplitude during Ch3 ON vs local pre-ON OFF window');

    disp('--- TA summary ---');
    disp(outStim_TA.summary);

    % -------- Overall collapsed comparison --------
    overall_comparison_stim(TA_signals, MG_signals, Ch3_signals, fs, ...
        'PreWindowS', [-2 -0.2], ...
        'OnMinDurMs', 100);
end

%% =========================
% Local functions
%% =========================
function pnr = peak_to_noise_masked_peak(xRect, isRest, peakMask, peakPrct)
xRect = xRect(:); isRest = isRest(:); peakMask = peakMask(:);
if isempty(xRect) || numel(isRest) ~= numel(xRect) || numel(peakMask) ~= numel(xRect), pnr = NaN; return; end
if ~any(isRest) || ~any(peakMask), pnr = NaN; return; end
noise = rms(xRect(isRest));
xpk = xRect(peakMask);
if nargin < 4 || isempty(peakPrct) || peakPrct >= 100, pk = max(xpk); else, pk = prctile(xpk, peakPrct); end
pnr = pk / (noise + eps);
end

function m = mean_bout_duration(isOn, fs)
isOn = isOn(:) ~= 0;
if ~any(isOn), m = NaN; return; end
d = diff([false; isOn; false]);
starts = find(d == 1); ends = find(d == -1) - 1;
durS = (ends - starts + 1) / fs;
m = mean(durS, 'omitnan');
end

function m = max_bout_duration(isOn, fs)
isOn = isOn(:) ~= 0;
if ~any(isOn), m = NaN; return; end
d = diff([false; isOn; false]);
starts = find(d == 1); ends = find(d == -1) - 1;
durS = (ends - starts + 1) / fs;
m = max(durS);
end

function mask = build_interval_mask(N, fs, intervals)
mask = false(N,1);
if isempty(intervals), return; end
for k = 1:size(intervals,1)
    t0 = intervals(k,1); t1 = intervals(k,2);
    if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0, continue; end
    i0 = max(1, floor(t0*fs) + 1);
    i1 = min(N, floor(t1*fs));
    if i1 >= i0, mask(i0:i1) = true; end
end
end

% -----------------------------------------------------------------------
% overall_comparison_stim
%   Collapses all stim-ON bouts and all stim-OFF (pre-ON) windows across
%   every recording into a single mean +/- SD bar chart for TA and MG,
%   mirroring the per-recording amplitude_distribution plots.
%
%   The ON/OFF window detection uses the same parameters that were passed
%   to amplitude_distribution so results are directly comparable.
%
%   Inputs
%     TA_signals  - cell array of TA envelope vectors (one per recording)
%     MG_signals  - cell array of MG envelope vectors (one per recording)
%     Ch3_signals - cell array of Ch3 raw vectors     (one per recording)
%     fs          - sampling frequency (Hz)
%   Optional name-value pairs (match those passed to amplitude_distribution)
%     'PreWindowS'  - [t_start t_end] in seconds relative to each ON onset
%                     (default [-2 -0.2])
%     'OnMinDurMs'  - minimum stim-ON bout duration in ms (default 100)
%     'OnThreshPct' - percentile of |Ch3| used to threshold ON detection
%                     (default 20)
% -----------------------------------------------------------------------
function overall_comparison_stim(TA_signals, MG_signals, Ch3_signals, fs, varargin)

%% --- Parse options ---
p = inputParser;
addParameter(p, 'PreWindowS',   [-2 -0.2]);
addParameter(p, 'OnMinDurMs',   100);
addParameter(p, 'OnThreshPct',  20);
parse(p, varargin{:});

preWin      = p.Results.PreWindowS;
minDurSmp   = round(p.Results.OnMinDurMs / 1000 * fs);
onThreshPct = p.Results.OnThreshPct;

nRec = numel(TA_signals);

%% --- Collect per-bout mean amplitudes across all recordings ---
ta_on_vals  = [];
ta_off_vals = [];
mg_on_vals  = [];
mg_off_vals = [];

for k = 1:nRec
    ta  = TA_signals{k}(:);
    mg  = MG_signals{k}(:);
    ch3 = Ch3_signals{k}(:);
    N   = numel(ta);

    % ---- Detect stim-ON from Ch3 ----
    ch3_valid = ch3(isfinite(ch3));
    if isempty(ch3_valid)
        warning('overall_comparison_stim: recording %d has no valid Ch3 samples, skipping.', k);
        continue;
    end
    thresh   = prctile(abs(ch3_valid), onThreshPct);
    isOn_raw = abs(ch3) > thresh;

    % Remove bouts shorter than OnMinDurMs
    isOn = stim_filter_short_bouts(isOn_raw, minDurSmp);

    % ---- Find ON-bout boundaries ----
    d        = diff([false; isOn(:); false]);
    onStarts = find(d ==  1);
    onEnds   = find(d == -1) - 1;

    for b = 1:numel(onStarts)
        i0_on = onStarts(b);
        i1_on = onEnds(b);

        % --- ON window: mean amplitude over the entire bout ---
        ta_seg = ta(i0_on:i1_on);
        mg_seg = mg(i0_on:i1_on);

        if any(isfinite(ta_seg))
            ta_on_vals(end+1) = mean(ta_seg, 'omitnan'); %#ok<AGROW>
        end
        if any(isfinite(mg_seg))
            mg_on_vals(end+1) = mean(mg_seg, 'omitnan'); %#ok<AGROW>
        end

        % --- OFF window: pre-ON window, excluding any stim-ON samples ---
        t_on_start = (i0_on - 1) / fs;           % time of ON onset (s)
        ip0 = max(1, round((t_on_start + preWin(1)) * fs) + 1);
        ip1 = min(N, round((t_on_start + preWin(2)) * fs));

        if ip1 > ip0
            ta_pre = ta(ip0:ip1);
            mg_pre = mg(ip0:ip1);

            % Blank any samples that were themselves stim-ON
            ta_pre(isOn(ip0:ip1)) = NaN;
            mg_pre(isOn(ip0:ip1)) = NaN;

            if any(isfinite(ta_pre))
                ta_off_vals(end+1) = mean(ta_pre, 'omitnan'); %#ok<AGROW>
            end
            if any(isfinite(mg_pre))
                mg_off_vals(end+1) = mean(mg_pre, 'omitnan'); %#ok<AGROW>
            end
        end
    end
end

%% --- Compute group-level statistics ---
mu_ta = [mean(ta_off_vals, 'omitnan'), mean(ta_on_vals, 'omitnan')];
sd_ta = [std( ta_off_vals, 0, 'omitnan'), std( ta_on_vals, 0, 'omitnan')];
n_ta  = [sum(isfinite(ta_off_vals)), sum(isfinite(ta_on_vals))];

mu_mg = [mean(mg_off_vals, 'omitnan'), mean(mg_on_vals, 'omitnan')];
sd_mg = [std( mg_off_vals, 0, 'omitnan'), std( mg_on_vals, 0, 'omitnan')];
n_mg  = [sum(isfinite(mg_off_vals)), sum(isfinite(mg_on_vals))];

fprintf('\n--- Overall stim comparison (all recordings pooled) ---\n');
fprintf('TA  OFF: mean = %.4f  SD = %.4f  n = %d bouts\n', mu_ta(1), sd_ta(1), n_ta(1));
fprintf('TA  ON : mean = %.4f  SD = %.4f  n = %d bouts\n', mu_ta(2), sd_ta(2), n_ta(2));
fprintf('MG  OFF: mean = %.4f  SD = %.4f  n = %d bouts\n', mu_mg(1), sd_mg(1), n_mg(1));
fprintf('MG  ON : mean = %.4f  SD = %.4f  n = %d bouts\n', mu_mg(2), sd_mg(2), n_mg(2));

%% --- Plot ---
clrOFF = [0.40 0.60 0.90];   % blue  - stim OFF
clrON  = [0.90 0.40 0.40];   % red   - stim ON

yMaxTA = max(mu_ta + sd_ta, [], 'omitnan') * 1.25;
yMaxMG = max(mu_mg + sd_mg, [], 'omitnan') * 1.25;
if ~isfinite(yMaxTA) || yMaxTA <= 0, yMaxTA = 1; end
if ~isfinite(yMaxMG) || yMaxMG <= 0, yMaxMG = 1; end

figure('Name', 'Overall Stim ON vs OFF - collapsed across all recordings');

% ---- TA subplot ----
subplot(1, 2, 1);
b = bar(mu_ta, 'FaceColor', 'flat');
b.CData(1,:) = clrOFF;
b.CData(2,:) = clrON;
hold on;
errorbar(b.XEndPoints, mu_ta, sd_ta, ...
    'w', 'LineWidth', 2, 'CapSize', 12, 'LineStyle', 'none');
set(gca, 'XTick', 1:2, 'XTickLabel', {'Stim OFF', 'Stim ON'});
ylabel('Mean EMG Amplitude');
ylim([0, yMaxTA]);
grid on;
title(sprintf('TA: Overall Stim ON vs OFF\n(n_{OFF} = %d, n_{ON} = %d bouts)', n_ta(1), n_ta(2)));

% ---- MG subplot ----
subplot(1, 2, 2);
b = bar(mu_mg, 'FaceColor', 'flat');
b.CData(1,:) = clrOFF;
b.CData(2,:) = clrON;
hold on;
errorbar(b.XEndPoints, mu_mg, sd_mg, ...
    'w', 'LineWidth', 2, 'CapSize', 12, 'LineStyle', 'none');
set(gca, 'XTick', 1:2, 'XTickLabel', {'Stim OFF', 'Stim ON'});
ylabel('Mean EMG Amplitude');
ylim([0, yMaxMG]);
grid on;
title(sprintf('MG: Overall Stim ON vs OFF\n(n_{OFF} = %d, n_{ON} = %d bouts)', n_mg(1), n_mg(2)));

sgtitle(sprintf('Overall Amplitude: Stim ON vs OFF  (%d recording(s), mean +/- SD)', nRec));
exportgraphics(gcf, 'overall_stim_comparison.pdf', 'ContentType', 'vector');
end

% -----------------------------------------------------------------------
% stim_filter_short_bouts  (private helper for overall_comparison_stim)
%   Removes ON bouts shorter than minDurSmp samples from a logical vector.
% -----------------------------------------------------------------------
function isOn = stim_filter_short_bouts(isOn_raw, minDurSmp)
isOn   = isOn_raw(:);
d      = diff([false; isOn; false]);
starts = find(d ==  1);
ends   = find(d == -1) - 1;
for i = 1:numel(starts)
    if (ends(i) - starts(i) + 1) < minDurSmp
        isOn(starts(i):ends(i)) = false;
    end
end
end