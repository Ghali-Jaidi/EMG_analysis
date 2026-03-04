function out = compare_files_xcorr(fs, max_lag_s, varargin)
% compare_files_xcorr_avg
% Computes TA–MG cross-correlation curves per recording, then:
%   - If called without R: selects files (UI), preprocesses, computes curves, and PLOTS (overlay)
%   - If called with R: uses provided R (no UI), computes curves, and returns group means
%
% Preprocessing is identical for both groups:
%   UseEnvelope = true  -> uses rectified envelope 
%   UseEnvelope = false -> uses rectified filtered signal (TA_rect / MG_rect)
%
% Uninjured curve per recording: xcorr on active samples (is_act_TA OR is_act_MG)
% Spastic curve per recording: xcorr per spasm interval segment, average within recording
% Group mean curves: average per-recording curves within each group.
%
% Requires (UI mode):
%   preprocess_and_label.m
%   ask_condition_and_intervals.m
%
% Requires (R mode):
%   R must contain: group, intervals, is_act_TA, is_act_MG, TA_rect, MG_rect, TA_env, MG_env

arguments
    fs (1,1) double {mustBePositive} = 10000
    max_lag_s (1,1) double {mustBePositive} = 5.0
end
arguments (Repeating)
    varargin
end

p = inputParser;
p.addParameter('R', [], @(x) isempty(x) || isstruct(x));
p.addParameter('UseEnvelope', true, @(x) islogical(x) && isscalar(x));
p.addParameter('MinSegS', 0.10, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('GroupUninj', "uninjured", @(x) isstring(x) || ischar(x));
p.addParameter('GroupSpastic', "injured", @(x) isstring(x) || ischar(x));
p.parse(varargin{:});

Rin = p.Results.R;
use_env = p.Results.UseEnvelope;
min_seg_s = p.Results.MinSegS;
grpU = lower(string(p.Results.GroupUninj));
grpS = lower(string(p.Results.GroupSpastic));

min_seg_n = max(10, round(min_seg_s * fs));
maxLag = max(1, round(max_lag_s * fs));
lags_s = (-maxLag:maxLag).'/fs;
L = numel(lags_s);

%% =========================
% UI MODE: build R then compute+plot overlay
%% =========================
if isempty(Rin)

    answ = inputdlg('How many files?', 'N files', [1 50], {'2'});
    if isempty(answ), error('Cancelled'); end
    nFiles = str2double(answ{1});
    if isnan(nFiles) || nFiles <= 0, error('Invalid number of files.'); end

    R = repmat(struct( ...
        'file', "", 'fullFile', "", 'recID', NaN, ...
        'cond', "", 'group', "", 'intervals', [], ...
        'TA_rect', [], 'MG_rect', [], 'TA_env', [], 'MG_env', [], ...
        'is_act_TA', [], 'is_act_MG', [] ), nFiles, 1);

    for k = 1:nFiles
        uiwait(msgbox(sprintf('Select file %d/%d', k, nFiles), 'Select experiment file', 'modal'));
        [f,pth] = uigetfile('*.mat', sprintf('Select experiment MAT file (%d/%d)', k, nFiles));
        if isequal(f,0), error('Cancelled'); end
        fullFile = fullfile(pth,f);
    
        [TT, snrV, meta] = preprocess_and_label(fs, ...
            'fullFile', fullFile, ...
            'plot_figures', false, ...
            'save_figures', false, ...
            'use_envelope', use_env);

        tag = sprintf('%s (rec %d)', f, meta.recID);
        [condLabel, intervals] = ask_condition_and_intervals(tag);

        group = grpU;
        if strcmpi(condLabel,'Spastic')
            group = grpS;
        elseif strcmpi(condLabel,'Uninjured')
            group = grpU;
        else
            group = lower(string(condLabel));
        end

        R(k).file = string(f);
        R(k).fullFile = string(fullFile);
        R(k).recID = meta.recID;
        R(k).cond = string(condLabel);
        R(k).group = group;
        R(k).intervals = intervals;

        R(k).TA_rect = TT.TA_rect(:);
        R(k).MG_rect = TT.MG_rect(:);
        R(k).TA_env = TT.TA_env(:);
        R(k).MG_env = TT.MG_env(:);

        R(k).is_act_TA = snrV.is_act(:);
        R(k).is_act_MG = snrV.is_act_MG(:);
    end

    % Compute curves per recording (same math as R-mode)
    RecCurves = compute_curves_from_R(R, fs, maxLag, min_seg_n, use_env, grpU, grpS);

    % Plot overlay (plot-only function)
    fig = figure('Name','TA–MG cross-correlation (per recording)');
    ax = axes(fig); hold(ax,'on');
    colors = lines(numel(RecCurves));
    for i = 1:numel(RecCurves)
        fprintf('%d: finite=%d\n', i, sum(isfinite(RecCurves(i).xc)));
    end
    for i = 1:numel(RecCurves)
        plot_TA_MG_corr_plotonly(RecCurves(i).lags_s, RecCurves(i).xc, ...
        'Axes', ax, 'Color', colors(i,:), 'Label', char(RecCurves(i).label));
    end
    grid(ax,'on');
    box(ax, 'on')
    xlabel(ax,'Lag (s)'); ylabel(ax,'Normalized xcorr');
    title(ax, sprintf('TA–MG cross-correlation | \\pm %.1f s | %s', max_lag_s, ternary(use_env,"env*sign(filt)","filtered")));
    legend(ax,'Location','best');
    fprintf('Rec %d group=%s use_env=%d\n', i,RecCurves(i).group, use_env);

    out = struct();
    out.mode = "ui_overlay";
    out.Rec  = R;
    out.Curves = RecCurves;
    return
end

%% =========================
% R MODE: no UI, compute group mean curves
%% =========================
R = Rin;

RecCurves = compute_curves_from_R(R, fs, maxLag, min_seg_n, use_env, grpU, grpS);

% stack by group
isUninj = lower(string({RecCurves.group})) == grpU;
isSpas  = lower(string({RecCurves.group})) == grpS;

assert(any(isUninj) && any(isSpas), 'Need at least one uninjured and one spastic/injured recording.');

XU = stack_curves(RecCurves(isUninj), L);
XS = stack_curves(RecCurves(isSpas),  L);
Xseg = [];

for i = find(isSpas)
    if isfield(RecCurves(i),'xc_segments') && ~isempty(RecCurves(i).xc_segments)
        Xseg = [Xseg, RecCurves(i).xc_segments]; %#ok<AGROW>
    end
end

fprintf('XS size = %d x %d\n', size(XS,1), size(XS,2));
if isempty(XS)
    fprintf('No spasm curves survived stack_curves.\n');
else
    fprintf('finite meanS = %d / %d\n', sum(isfinite(mean(XS,1,'omitnan'))), size(XS,2));
    fprintf('rows with any finite = %d\n', sum(any(isfinite(XS),2)));
end

out = struct();
out.lags_s = (-maxLag:maxLag).' / fs;

out.meanU = mean(XU, 1, 'omitnan').';      % (L×1)
out.sdU   = std(XU,  0, 1, 'omitnan').';   % (L×1)

out.meanS = mean(XS, 1, 'omitnan').';
out.sdS   = std(XS,  0, 1, 'omitnan').';
out.meanS_seg = mean(Xseg,2,'omitnan');
out.sdS_seg   = std(Xseg,0,2,'omitnan');
out.nSeg      = size(Xseg,2);
out.ciS_within = 1.96 * out.sdS_seg ./ sqrt(max(out.nSeg,1));

out.n_uninj_used = size(XU, 1);            % # recordings used
out.n_spas_used  = size(XS, 1);
out.RecCurves = RecCurves;

out.UseEnvelope = use_env;
out.settings = struct( ...
    'fs', fs, ...
    'max_lag_s', max_lag_s, ...
    'min_seg_s', min_seg_s, ...
    'signal', ternary(use_env, "env", "filtered") );
end

%% ===================== plot-only function =====================

function fig = plot_TA_MG_corr_plotonly(lags_s, xc, options)
arguments
    lags_s (:,1) double
    xc (:,1) double
    options.Axes = []
    options.Color = [0 0 1]
    options.Label (1,:) char = ''
end

if isempty(options.Axes) || ~isvalid(options.Axes)
    fig = figure; ax = axes(fig);
else
    ax = options.Axes; fig = ancestor(ax,'figure');
end
hold(ax,'on');

h = plot(ax, lags_s, xc, 'LineWidth', 1.5);
set(h,'Color',options.Color);
if ~isempty(options.Label)
    set(h,'DisplayName',options.Label);
end
end

%% ===================== computation helpers =====================

function RecCurves = compute_curves_from_R(R, fs, maxLag, min_seg_n, use_env, grpU, grpS)
lags_s = (-maxLag:maxLag).'/fs;
RecCurves = struct('group',"",'lags_s',lags_s,'xc',nan(numel(lags_s),1), 'xc_segments', [],'label',"");
RecCurves = repmat(RecCurves, numel(R), 1);

disp(fieldnames(R))
disp(R(1))
for i = 1:numel(R)
    group = lower(string(R(i).group));
    [xTA, xMG, actMask] = get_x_signals(R(i), use_env);
    
    if group == grpU
        actMask = R(i).is_act_TA | R(i).is_act_MG;
        fprintf('\nRec %d (%s): act=%d (%.2f%%)\n', i, R(i).group, sum(actMask), 100*mean(actMask));
        
        % segment lengths of contiguous active bouts
        d = diff([false; actMask(:); false]);
        i0 = find(d==1); i1 = find(d==-1)-1;
        lens = i1 - i0 + 1;
        fprintf('nBouts=%d, maxBout=%d samples (%.3f s), min_seg_n=%d (%.3f s)\n', ...
            numel(lens), max(lens), max(lens)/fs, min_seg_n, min_seg_n/fs);
        [xc, ok] = xcorr_from_mask(xTA, xMG, actMask, maxLag, min_seg_n);
    elseif group == grpS
        segIdx = intervals_to_index_segments(R(i).intervals, fs, numel(xTA));

        % cut out NaNs and split again (artifact NaNs can break an interval)
        valid = isfinite(xTA) & isfinite(xMG);
        segIdx = restrict_segments_to_mask(segIdx, valid);
        
        [xc, ok, Xseg] = xcorr_avg_over_segments(xTA, xMG, segIdx, maxLag, min_seg_n);
        RecCurves(i).xc_segments = Xseg;   % store for CI later

    else
        [xc, ok] = xcorr_from_mask(xTA, xMG, actMask, maxLag, min_seg_n);
    end

    if ~ok
        xc = nan(2*maxLag+1,1);
    end

    RecCurves(i).group = group;
    RecCurves(i).lags_s = lags_s;
    RecCurves(i).xc = xc(:);

    baseLabel = "";
    if isfield(R(i),'file') && strlength(string(R(i).file))>0
        baseLabel = string(R(i).file);
    elseif isfield(R(i),'fullFile')
        baseLabel = string(R(i).fullFile);
    end
    RecCurves(i).label = sprintf('%s (%s)', baseLabel, group);
end
end

function [xTA, xMG, actMask] = get_x_signals(Rk, use_env)


if use_env
    % unrectified envelope by re-applying sign of filtered signal
    envTA = Rk.TA_env(:);
    envMG = Rk.MG_env(:);
    if isempty(envTA) || isempty(envMG)
        error('R is missing TA_env/MG_env. Store TT.TA_env and TT.MG_env in main.');
    end
    xTA = envTA; %.* sign(TAf);
    xMG = envMG; %.* sign(MGf);
else
    xTA = Rk.TA_rect(:);
    xMG = Rk.MG_rect(:);
    if isempty(xTA) || isempty(xMG)
        error('R is missing TA_f/MG_f. Store TT.TA_f and TT.MG_f in main before calling compare_files_xcorr_avg(...,''R'',R).');
    end

end

actMask = (Rk.is_act_TA(:) | Rk.is_act_MG(:));
end

function [xc_mean, ok] = xcorr_from_mask(x, y, mask, maxLag, min_seg_n)
ok = false;
xc_mean = nan(2*maxLag+1,1);

x = x(:); y = y(:); mask = mask(:);
if numel(x) ~= numel(y) || numel(x) ~= numel(mask) || ~any(mask)
    return;
end

% Also exclude NaNs (from artifact NaN-ing)
valid = mask(:) & isfinite(x(:)) & isfinite(y(:));
if ~any(valid), return; end

segIdx = mask_to_segments(valid);

% Average xcorr over contiguous segments

[xc_mean, ok] = xcorr_avg_over_segments(x, y, segIdx, maxLag, min_seg_n);
end

function segIdx = mask_to_segments(mask)
segIdx = {};
mask = mask(:);
d = diff([false; mask; false]);
iStart = find(d == 1);
iEnd   = find(d == -1) - 1;
for k = 1:numel(iStart)
    segIdx{end+1} = (iStart(k):iEnd(k)).'; %#ok<AGROW>
end
end

function segIdx = intervals_to_index_segments(intervals, fs, N)
segIdx = {};
if isempty(intervals) || size(intervals,2) ~= 2
    return;
end
for k = 1:size(intervals,1)
    t0 = intervals(k,1);
    t1 = intervals(k,2);
    if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0
        continue;
    end
    i0 = max(1, floor(t0*fs) + 1);
    i1 = min(N, floor(t1*fs));
    if i1 >= i0
        segIdx{end+1} = (i0:i1).'; %#ok<AGROW>
    end
end
end

function [xc_mean, ok, X] = xcorr_avg_over_segments(x, y, segIdx, maxLag, min_seg_n)
ok = false;
X = [];   % each column = one segment xcorr

for s = 1:numel(segIdx)
    idx = segIdx{s};
    if numel(idx) < min_seg_n, continue; end

    xz = x(idx); yz = y(idx);
    good = isfinite(xz) & isfinite(yz);
    xz = xz(good); yz = yz(good);
    if numel(xz) < min_seg_n, continue; end
    if std(xz) < eps || std(yz) < eps, continue; end

    
    xc = xcorr(xz, yz, maxLag, 'coeff');
    X(:,end+1) = xc; %#ok<AGROW>
end

if ~isempty(X)
    xc_mean = mean(X,2,'omitnan');
    ok = true;
else
    xc_mean = nan(2*maxLag+1,1);
end
end

function X = stack_curves(curves, L)
X = nan(numel(curves), L);
r = 0;
for i = 1:numel(curves)
    if ~isempty(curves(i).xc) && numel(curves(i).xc) == L && any(isfinite(curves(i).xc))
        r = r + 1;
        X(r,:) = curves(i).xc(:).';
    end
end
X = X(1:r,:);
end

function s = ternary(cond, a, b)
if cond, s = a; else, s = b; end
end

function segIdx2 = restrict_segments_to_mask(segIdx, mask)
segIdx2 = {};
mask = mask(:);
for s = 1:numel(segIdx)
    idx = segIdx{s};
    if isempty(idx), continue; end
    v = false(size(mask));
    v(idx) = true;
    v = v & mask;

    parts = mask_to_segments(v);
    segIdx2 = [segIdx2, parts]; %#ok<AGROW>
end
end