function [is_valid, meta] = detect_valid_acquisition_start(TA_f, MG_f, ~, ~, fs, opts)

N = numel(TA_f);
t = (0:N-1)'/fs;

% -------- parameters --------
if ~isfield(opts,'rms_win_ms'),      opts.rms_win_ms = 20; end
if ~isfield(opts,'baseline_mult'),   opts.baseline_mult = 5; end
if ~isfield(opts,'window_s'),        opts.window_s = 4; end
if ~isfield(opts,'min_active_ms'),   opts.min_active_ms = 2000; end
if ~isfield(opts,'plot_debug'),      opts.plot_debug = false; end
if ~isfield(opts,'noise_floor_mode'), opts.noise_floor_mode = 'p5'; end
if ~isfield(opts,'noise_floor_value'), opts.noise_floor_value = 0.1; end
if ~isfield(opts,'quiet_prctile'),   opts.quiet_prctile = 20; end
if ~isfield(opts,'quiet_min_s'),     opts.quiet_min_s = 2; end
if ~isfield(opts,'robust_k'),        opts.robust_k = 6; end

% -------- RMS --------
rms_win = max(1, round(opts.rms_win_ms/1000 * fs));
TA_rms = sqrt(movmean(TA_f.^2, rms_win));
MG_rms = sqrt(movmean(MG_f.^2, rms_win));

% combine muscles
R = max(TA_rms, MG_rms);

fprintf('\n=== RMS stats ===\n');
fprintf('min/median/max : %.4f / %.4f / %.4f\n', min(R), median(R), max(R));

% -------- baseline detection --------
quiet_mask = R < prctile(R, opts.quiet_prctile);
quiet_mask = keep_long_runs(quiet_mask, round(opts.quiet_min_s * fs));
baseline_idx = find(quiet_mask);
if isempty(baseline_idx)
    warning('No quiet baseline detected, using first 2 s');
    baseline_idx = 1:min(round(2*fs), N);
end

baseline_rms = median(R(R < prctile(R,20)), 'omitnan');
baseline_mad = mad(R(baseline_idx), 1);

% -------- baseline floor --------
switch lower(opts.noise_floor_mode)
    case 'p5'
        noise_floor_min = prctile(R, 5);
    case 'fixed'
        noise_floor_min = opts.noise_floor_value;
    otherwise
        error('opts.noise_floor_mode must be ''p5'' or ''fixed''.');
end

baseline_eff = max(baseline_rms, noise_floor_min);

fprintf('\n=== Baseline ===\n');
fprintf('baseline_rms = %.4f | baseline_mad = %.4f | noise_floor_min = %.4f | baseline_eff = %.4f\n', ...
    baseline_rms, baseline_mad, noise_floor_min, baseline_eff);

% -------- threshold --------
thr_mult   = opts.baseline_mult * baseline_eff;
thr_robust = baseline_rms + opts.robust_k * baseline_mad;
thr        = max(thr_mult, thr_robust);

fprintf('\n=== Threshold ===\n');
fprintf('thr_mult = %.4f | thr_robust = %.4f | final thr = %.4f\n', ...
    thr_mult, thr_robust, thr);

above_thr = R > thr;

fprintf('\n=== Above-threshold stats ===\n');
fprintf('samples above threshold : %d / %d (%.2f%%)\n', ...
    sum(above_thr), N, 100*sum(above_thr)/N);

% -------- window test --------
win_samples = max(1, round(opts.window_s * fs));
min_active_samples = max(1, round(opts.min_active_ms/1000 * fs));

is_valid = false(N,1);
idx0 = [];

for i = 1:(N - win_samples + 1)
    seg = above_thr(i:i+win_samples-1);
    if sum(seg) >= min_active_samples
        idx0 = i;
        break
    end
end

% -------- result --------
if ~isempty(idx0)
    is_valid(idx0:end) = true;
    
    fprintf('\n=== Start detected ===\n');
    fprintf('t = %.2f s\n', t(idx0));
else
    warning('No acquisition start detected');
end


% -------- print validity intervals --------
d = diff([false; is_valid; false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;

fprintf('\n=== VALID intervals (is_valid = true) ===\n');
for k = 1:numel(starts)
    fprintf('[%.3f  %.3f] s\n', t(starts(k)), t(ends(k)));
end

d = diff([false; ~is_valid; false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;

fprintf('\n=== INVALID intervals (is_valid = false) ===\n');
for k = 1:numel(starts)
    fprintf('[%.3f  %.3f] s\n', t(starts(k)), t(ends(k)));
end

% -------- meta --------
meta = struct();
meta.t = t;
meta.TA_rms = TA_rms;
meta.MG_rms = MG_rms;
meta.R = R;
meta.quiet_mask = quiet_mask;
meta.baseline_idx = baseline_idx;
meta.baseline_rms = baseline_rms;
meta.baseline_mad = baseline_mad;
meta.noise_floor_min = noise_floor_min;
meta.baseline_eff = baseline_eff;
meta.thr_mult = thr_mult;
meta.thr_robust = thr_robust;
meta.threshold = thr;
meta.above_thr = above_thr;
meta.idx0 = idx0;

% -------- debug plot --------
if opts.plot_debug
    figure('Name','Acquisition start detection');

    subplot(3,1,1);
    plot(t, TA_f); hold on;
    plot(t, MG_f);
    title('Filtered EMG');
    xlabel('Time (s)');

    subplot(3,1,2);
    plot(t, R); hold on;
    yline(thr, '--r');
    title('Combined RMS + threshold');
    xlabel('Time (s)');

    subplot(3,1,3);
    plot(t, double(above_thr)); hold on;
    if ~isempty(idx0), xline(t(idx0), '--r'); end
    title('Threshold crossings');
    xlabel('Time (s)');
end

end