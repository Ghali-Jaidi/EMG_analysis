function S = generate_synthetic_emg(varargin)
% generate_synthetic_emg
%
% More realistic synthetic 3-channel EMG generator tuned to resemble
% the first 60 s of your real file:
%   - TA quieter than MG at baseline
%   - colored baseline + slow drift + occasional motor-unit spikes
%   - gait is irregular, not perfectly periodic
%   - spasms are burst clusters, not smooth blocks
%   - Ch3 inhibition is smooth and mostly suppresses event drive rather
%     than scaling the entire raw trace abruptly
%   - MG gait bursts are longer, more sustained, lower-amplitude,
%     and the tail of MG overlaps with the onset of TA each cycle
%
% OUTPUT
%   S : struct with fields data__chan_1_rec_1, data__chan_2_rec_1,
%       data__chan_3_rec_1
%
% NAME-VALUE OPTIONS
%   'fs'                  : sampling frequency (default 10000)
%   'DurS'                : total recording duration in seconds (default 120)
%   'PreAcqS'             : silent pre-acquisition period in seconds (default 3)
%   'NoiseAmpTA'          : TA baseline noise scale (default 0.025)
%   'NoiseAmpMG'          : MG baseline noise scale (default 0.045)
%   'DriftAmpTA'          : slow drift amplitude TA (default 0.003)
%   'DriftAmpMG'          : slow drift amplitude MG (default 0.006)
%   'SpikeRateHzTA'       : random MUAP-like spike rate on TA (default 1.5)
%   'SpikeRateHzMG'       : random MUAP-like spike rate on MG (default 3.0)
%   'GaitBurstAmpTA'      : TA gait drive amplitude (default 0.55)
%   'GaitBurstAmpMG'      : MG gait drive amplitude (default 0.75)
%   'SpasmAmpTA'          : TA spasm drive amplitude (default 1.8)
%   'SpasmAmpMG'          : MG spasm drive amplitude (default 2.4)
%   'GaitCycleS'          : nominal gait cycle duration in seconds (default 0.45)
%   'GaitCycleJitter'     : relative cycle jitter (default 0.18)
%   'GaitBurstDutyPrcTA'  : TA active fraction per cycle — short/phasic (default 0.28)
%   'GaitBurstDutyPrcMG'  : MG active fraction per cycle — long/tonic (default 0.52)
%   'GaitMGOverlapFrac'   : fraction of cycle by which MG tail overlaps
%                           with TA onset of the next cycle (default 0.12)
%   'NGaitBouts'          : number of gait bouts (default 6)
%   'GaitBoutDurS'        : duration of each gait bout in seconds (default 5)
%   'NSpasms'             : number of spasms (default 2)
%   'SpasmDurS'           : nominal duration of each spasm in seconds (default 2.5)
%   'Ch3OnDurS'           : duration of each Ch3 ON pulse in seconds (default 2)
%   'Ch3OffDurS'          : duration of Ch3 OFF between pulses in seconds (default 5)
%   'Ch3Amplitude'        : Ch3 signal amplitude when ON (default 5)
%   'Ch3InhibitFrac'      : event-drive reduction during Ch3 ON (default 0.35)
%   'SavePath'            : if provided, saves the .mat file to this path
%   'PlotResult'          : whether to plot the generated signal (default true)
%   'Seed'                : random seed for reproducibility (default 42)

p = inputParser;
p.addParameter('fs',                  10000, @isnumeric);
p.addParameter('DurS',                500,   @isnumeric);
p.addParameter('PreAcqS',             3,     @isnumeric);

p.addParameter('NoiseAmpTA',          0.025, @isnumeric);
p.addParameter('NoiseAmpMG',          0.045, @isnumeric);
p.addParameter('DriftAmpTA',          0.003, @isnumeric);
p.addParameter('DriftAmpMG',          0.006, @isnumeric);
p.addParameter('SpikeRateHzTA',       1.5,   @isnumeric);
p.addParameter('SpikeRateHzMG',       3.0,   @isnumeric);

p.addParameter('GaitBurstAmpTA',      0.55,  @isnumeric);
p.addParameter('GaitBurstAmpMG',      0.75,  @isnumeric);
p.addParameter('SpasmAmpTA',          1.8,   @isnumeric);
p.addParameter('SpasmAmpMG',          2.4,   @isnumeric);

p.addParameter('GaitCycleS',          0.45,  @isnumeric);
p.addParameter('GaitCycleJitter',     0.18,  @isnumeric);
% Separate duty fractions: TA is short/phasic, MG is long/tonic
p.addParameter('GaitBurstDutyPrcTA',  0.28,  @isnumeric);
p.addParameter('GaitBurstDutyPrcMG',  0.52,  @isnumeric);
% Fraction of one cycle that MG tail overlaps into TA of the next cycle
p.addParameter('GaitMGOverlapFrac',   0.12,  @isnumeric);

p.addParameter('NGaitBouts',          20,    @isnumeric);
p.addParameter('GaitBoutDurS',        10,    @isnumeric);
p.addParameter('NSpasms',             12,     @isnumeric);
p.addParameter('SpasmDurS',           2,   @isnumeric);

p.addParameter('Ch3OnDurS',           1,     @isnumeric);
p.addParameter('Ch3OffDurS',          5,     @isnumeric);
p.addParameter('Ch3Amplitude',        5,     @isnumeric);
p.addParameter('Ch3InhibitFrac',      0.6,   @isnumeric);

p.addParameter('SavePath',            '',    @ischar);
p.addParameter('PlotResult',          true, @islogical);
p.addParameter('Seed',                29,    @isnumeric);
p.addParameter('ExtraSpasm',          true, @islogical);
p.parse(varargin{:});
opt = p.Results;

rng(opt.Seed);

fs = opt.fs;
N  = round(opt.DurS * fs);
t  = (0:N-1)' / fs;

fprintf('Generating synthetic EMG: %.0f s at %d Hz (%d samples)\n', opt.DurS, fs, N);

%% ================================================================
%  1. BASELINE: colored EMG hiss + slow drift + sparse MUAP-like spikes
%% ================================================================
Ch3 = zeros(N,1);

TA = make_baseline_channel(N, fs, opt.NoiseAmpTA, opt.DriftAmpTA, opt.SpikeRateHzTA);
MG = make_baseline_channel(N, fs, opt.NoiseAmpMG, opt.DriftAmpMG, opt.SpikeRateHzMG);

TA_base  = TA;
MG_base  = MG;
TA_drive = zeros(N,1);
MG_drive = zeros(N,1);

%% ================================================================
%  2. SCHEDULE EVENTS
%% ================================================================
pre_acq_samples = round(opt.PreAcqS * fs);
available_start = opt.PreAcqS + 1;
available_end   = opt.DurS - 2;

total_event_dur = opt.NGaitBouts * opt.GaitBoutDurS + opt.NSpasms * opt.SpasmDurS;
n_gaps          = opt.NGaitBouts + opt.NSpasms + 1;
available_time  = available_end - available_start;
gap_s           = max(2, (available_time - total_event_dur) / n_gaps);

events = struct('type', {}, 'start_s', {}, 'end_s', {});
cursor = available_start + gap_s;

n_gait   = opt.NGaitBouts;
n_spasms = opt.NSpasms;

event_types = {};
gi = 0; si = 0;
while gi < n_gait || si < n_spasms
    if gi < n_gait
        event_types{end+1} = 'gait'; gi = gi + 1; %#ok<AGROW>
    end
    if gi < n_gait
        event_types{end+1} = 'gait'; gi = gi + 1; %#ok<AGROW>
    end
    if si < n_spasms
        event_types{end+1} = 'spasm'; si = si + 1; %#ok<AGROW>
    end
end

for i = 1:numel(event_types)
    etype = event_types{i};
    if strcmp(etype, 'gait')
        dur = opt.GaitBoutDurS * (0.85 + 0.30*rand);
    else
        dur = opt.SpasmDurS * (0.75 + 0.50*rand);
    end

    if cursor + dur > available_end
        warning('Not enough time for all events. Stopping at event %d.', i);
        break;
    end

    events(end+1).type  = etype; %#ok<AGROW>
    events(end).start_s = cursor;
    events(end).end_s   = cursor + dur;
    cursor = cursor + dur + gap_s * (0.8 + 0.4*rand);
end

% ------------------------------------------------
% EXTRA SPASM: Ch3 turns ON halfway through it
% ------------------------------------------------
if opt.ExtraSpasm == true
    extra_spasm_dur    = opt.SpasmDurS * 1.2;
    extra_ch3_on_start = opt.PreAcqS + opt.Ch3OffDurS;
    extra_spasm_start  = extra_ch3_on_start - extra_spasm_dur/2;
    extra_spasm_end    = extra_spasm_start + extra_spasm_dur;

    if extra_spasm_start > opt.PreAcqS && extra_spasm_end < available_end
        events(end+1).type  = 'spasm';
        events(end).start_s = extra_spasm_start;
        events(end).end_s   = extra_spasm_end;
    end
end

[~, idx_sort] = sort([events.start_s]);
events = events(idx_sort);

fprintf('Scheduled %d events:\n', numel(events));
for i = 1:numel(events)
    fprintf('  [%s]  %.1f - %.1f s\n', events(i).type, events(i).start_s, events(i).end_s);
end

%% ================================================================
%  3. GROUND-TRUTH MASKS
%% ================================================================
is_gait_true  = false(N,1);
is_spasm_true = false(N,1);

%% ================================================================
%  4. INJECT IRREGULAR GAIT
%% ================================================================
for i = 1:numel(events)
    if ~strcmp(events(i).type, 'gait'), continue; end

    s0 = max(pre_acq_samples+1, round(events(i).start_s * fs));
    s1 = min(N, round(events(i).end_s * fs));

    is_gait_true(s0:s1) = true;

    [ta_add, mg_add] = inject_gait_bout( ...
        s1 - s0 + 1, fs, ...
        opt.GaitBurstAmpTA, opt.GaitBurstAmpMG, ...
        opt.GaitCycleS, opt.GaitCycleJitter, ...
        opt.GaitBurstDutyPrcTA, opt.GaitBurstDutyPrcMG, ...
        opt.GaitMGOverlapFrac);

    TA_drive(s0:s1) = TA_drive(s0:s1) + ta_add;
    MG_drive(s0:s1) = MG_drive(s0:s1) + mg_add;
end

%% ================================================================
%  5. INJECT SPASM CLUSTERS
%% ================================================================
for i = 1:numel(events)
    if ~strcmp(events(i).type, 'spasm'), continue; end

    s0 = max(pre_acq_samples+1, round(events(i).start_s * fs));
    s1 = min(N, round(events(i).end_s * fs));
    L  = s1 - s0 + 1;

    is_spasm_true(s0:s1) = true;

    [ta_add, mg_add] = inject_spasm_cluster(L, fs, opt.SpasmAmpTA, opt.SpasmAmpMG);

    TA_drive(s0:s1) = TA_drive(s0:s1) + ta_add;
    MG_drive(s0:s1) = MG_drive(s0:s1) + mg_add;
end

%% ================================================================
%  6. CH3 STIMULATION
%% ================================================================
ch3_on_samples  = round(opt.Ch3OnDurS  * fs);
ch3_off_samples = round(opt.Ch3OffDurS * fs);

is_ch3_on = false(N,1);
pos = pre_acq_samples + ch3_off_samples;

while pos + ch3_on_samples <= N
    on_end = min(N, pos + ch3_on_samples - 1);
    Ch3(pos:on_end) = opt.Ch3Amplitude;
    is_ch3_on(pos:on_end) = true;
    pos = on_end + 1 + ch3_off_samples;
end

gain = ones(N,1);
gain(is_ch3_on) = 1 - opt.Ch3InhibitFrac;

smooth_len = max(3, round(0.050 * fs));
gain = conv(gain, ones(smooth_len,1)/smooth_len, 'same');
gain = min(max(gain, 0), 1);

TA = TA_base + gain .* TA_drive;
MG = MG_base + gain .* MG_drive;

TA(is_ch3_on) = TA(is_ch3_on) * 0.97;
MG(is_ch3_on) = MG(is_ch3_on) * 0.95;

%% ================================================================
%  7. PRE-ACQUISITION SILENCE
%% ================================================================
TA(1:pre_acq_samples)  = opt.NoiseAmpTA * 0.02 * randn(pre_acq_samples,1);
MG(1:pre_acq_samples)  = opt.NoiseAmpMG * 0.02 * randn(pre_acq_samples,1);
Ch3(1:pre_acq_samples) = 0;

%% ================================================================
%  8. PACKAGE
%% ================================================================
S.data__chan_1_rec_1 = TA;
S.data__chan_2_rec_1 = MG;
S.data__chan_3_rec_1 = Ch3;

%% ================================================================
%  9. SAVE
%% ================================================================
if ~isempty(opt.SavePath)
    save(opt.SavePath, '-struct', 'S');
    fprintf('Saved synthetic recording to: %s\n', opt.SavePath);
end

%% ================================================================
% 10. GROUND TRUTH SUMMARY
%% ================================================================
fprintf('\n--- Ground truth ---\n');
fprintf('  Pre-acquisition : 0 - %.1f s\n', opt.PreAcqS);
fprintf('  Gait samples    : %d (%.1f s)\n', sum(is_gait_true),  sum(is_gait_true)/fs);
fprintf('  Spasm samples   : %d (%.1f s)\n', sum(is_spasm_true), sum(is_spasm_true)/fs);
fprintf('  Ch3 ON samples  : %d (%.1f s)\n', sum(is_ch3_on),     sum(is_ch3_on)/fs);
fprintf('  Ch3 ON x Gait  : %.1f s\n', sum(is_ch3_on & is_gait_true)/fs);
fprintf('  Ch3 ON x Spasm : %.1f s\n', sum(is_ch3_on & is_spasm_true)/fs);
fprintf('  Ch3 inhibition  : %.0f%% event-drive reduction\n', opt.Ch3InhibitFrac*100);

S.ground_truth.is_gait_true  = is_gait_true;
S.ground_truth.is_spasm_true = is_spasm_true;
S.ground_truth.is_ch3_on     = is_ch3_on;
S.ground_truth.t             = t;
S.ground_truth.events        = events;
S.ground_truth.gain          = gain;

%% ================================================================
% 11. PLOT
%% ================================================================
if opt.PlotResult
    figure('Color','k','Name','Synthetic EMG','Position',[50 50 1400 650]);

    ax1 = subplot(3,1,1);
    hold(ax1,'on');
    set(ax1,'Color','k','XColor','w','YColor','w');
    plot(ax1, t, TA, 'Color',[0.4 0.8 1],'LineWidth',0.5);
    shade_regions(ax1, t, is_gait_true,  [0.2 1 0.4], 0.22);
    shade_regions(ax1, t, is_spasm_true, [1 0.2 0.2], 0.30);
    shade_regions(ax1, t, is_ch3_on,     [0 1 1],     0.12);
    ylabel(ax1,'TA','Color','w');
    title(ax1,'Synthetic EMG','Color','w');
    xlim(ax1,[0 opt.DurS]);

    ax2 = subplot(3,1,2);
    hold(ax2,'on');
    set(ax2,'Color','k','XColor','w','YColor','w');
    plot(ax2, t, MG, 'Color',[0.8 0.5 1],'LineWidth',0.5);
    shade_regions(ax2, t, is_gait_true,  [0.2 1 0.4], 0.22);
    shade_regions(ax2, t, is_spasm_true, [1 0.2 0.2], 0.30);
    shade_regions(ax2, t, is_ch3_on,     [0 1 1],     0.12);
    ylabel(ax2,'MG','Color','w');
    xlim(ax2,[0 opt.DurS]);

    ax3 = subplot(3,1,3);
    hold(ax3,'on');
    set(ax3,'Color','k','XColor','w','YColor','w');
    plot(ax3, t, Ch3, 'Color',[0 1 1],'LineWidth',1);
    ylabel(ax3,'Ch3','Color','w');
    xlabel(ax3,'Time (s)','Color','w');
    xlim(ax3,[0 opt.DurS]);

    linkaxes([ax1 ax2 ax3],'x');
end

end

%% ================================================================
% LOCAL HELPERS
%% ================================================================

function x = make_baseline_channel(N, fs, noise_amp, drift_amp, spike_rate_hz)
raw1 = randn(N,1);
[b1,a1] = butter(4, [70 900]/(fs/2), 'bandpass');
hiss = filtfilt(b1, a1, raw1);
hiss = hiss / (std(hiss) + eps);

raw2 = randn(N,1);
[b2,a2] = butter(2, [5 40]/(fs/2), 'bandpass');
drift = filtfilt(b2, a2, raw2);
drift = drift / (std(drift) + eps);

x = noise_amp * hiss + drift_amp * drift;

n_spikes = poissrnd(spike_rate_hz * (N/fs));
for k = 1:n_spikes
    c  = randi([1 N]);
    L  = max(8, round(fs*(0.002 + 0.004*rand)));
    s0 = max(1, c-floor(L/2));
    s1 = min(N, s0+L-1);
    wav = motor_unit_waveform(s1-s0+1);
    amp = noise_amp * (2 + 6*rand);
    x(s0:s1) = x(s0:s1) + amp * wav;
end
end

% ----------------------------------------------------------------
function [ta, mg] = inject_gait_bout(L, fs, amp_ta, amp_mg, cycle_s, cycle_jitter, duty_ta, duty_mg, overlap_frac)

ta = zeros(L,1);
mg = zeros(L,1);

mod_t     = linspace(0,1,L)';
bout_gain = 0.8 + 0.3*sin(2*pi*(0.4 + 0.3*rand)*mod_t + 2*pi*rand);
bout_gain = max(0.5, bout_gain);

pos = 1;
while pos < L
    % --- cycle timing ---
    cyc  = cycle_s * (1 + cycle_jitter*randn);
    cyc  = max(0.28, min(0.75, cyc));
    cycN = max(1, round(cyc * fs));

    % MG: stance phase — long tonic burst, flat-top envelope, tight amplitude
    dur_mg = max(10, round(cycN * duty_mg * (0.90 + 0.20*rand)));

    % TA: swing phase — starts near end of MG with a short overlap
    ta_offset = max(5, round(dur_mg - cycN * overlap_frac * (0.8 + 0.4*rand)));
    dur_ta    = max(10, round(cycN * duty_ta * (0.8 + 0.4*rand)));

    mg_s = pos;
    mg_e = min(L, mg_s + dur_mg - 1);

    ta_s = min(L, pos + ta_offset);
    ta_e = min(L, ta_s + dur_ta - 1);

    % --- MG burst: flat-top sustained envelope, tight amplitude ---
    if mg_s <= L
        env = sustained_envelope(mg_e - mg_s + 1);
        nse = emg_packet_noise(mg_e - mg_s + 1, fs);
        a   = amp_mg * (0.85 + 0.25*rand);
        mg(mg_s:mg_e) = mg(mg_s:mg_e) + a * env .* nse;
    end

    % --- TA burst: peaked envelope, wider amplitude swing ---
    if ta_s <= L
        env = packet_envelope(ta_e - ta_s + 1);
        nse = emg_packet_noise(ta_e - ta_s + 1, fs);
        a   = amp_ta * (0.7 + 0.8*rand);
        ta(ta_s:ta_e) = ta(ta_s:ta_e) + a * env .* nse;
    end

    % occasional co-contraction packet
    if rand < 0.22
        cc_s = min(L, pos + round(0.15*cycN));
        cc_e = min(L, cc_s + round((0.05 + 0.06*rand)*fs));
        if cc_s < cc_e
            env = packet_envelope(cc_e - cc_s + 1);
            ta(cc_s:cc_e) = ta(cc_s:cc_e) + 0.25*amp_ta * env .* emg_packet_noise(cc_e-cc_s+1, fs);
            mg(cc_s:cc_e) = mg(cc_s:cc_e) + 0.25*amp_mg * env .* emg_packet_noise(cc_e-cc_s+1, fs);
        end
    end

    pos = pos + cycN;
end

ta = ta .* bout_gain;
mg = mg .* bout_gain;
end
% ----------------------------------------------------------------
function [ta, mg] = inject_spasm_cluster(L, fs, amp_ta, amp_mg)
ta = zeros(L,1);
mg = zeros(L,1);

n_packets = randi([6 10]);
centers = round(linspace(round(0.12*L), round(0.88*L), n_packets)' + 0.05*L*randn(n_packets,1));
centers = min(max(centers,1),L);
centers = sort(centers);

for i = 1:n_packets
    dur  = round(fs * (0.25 + 0.45*rand));
    s0   = max(1, centers(i) - floor(dur/2));
    s1   = min(L, s0 + dur - 1);
    dur2 = s1 - s0 + 1;
    env  = spasm_packet_envelope(dur2);
    ta(s0:s1) = ta(s0:s1) + amp_ta * (0.7 + 0.8*rand) * env .* emg_packet_noise(dur2, fs);
    mg(s0:s1) = mg(s0:s1) + amp_mg * (0.7 + 0.8*rand) * env .* emg_packet_noise(dur2, fs);
end

global_env = spasm_packet_envelope(L);
ta = ta + 0.35 * amp_ta * global_env .* emg_packet_noise(L, fs);
mg = mg + 0.35 * amp_mg * global_env .* emg_packet_noise(L, fs);

lf = randn(L,1);
[b,a] = butter(2, [2 12]/(fs/2), 'bandpass');
lf  = filtfilt(b,a,lf);
lf  = lf / (std(lf)+eps);
mod = max(0.4, 1 + 0.20*lf);
ta  = ta .* mod;
mg  = mg .* mod;
end

% ----------------------------------------------------------------
function env = packet_envelope(L)
% Sinusoidal (phasic) — TA gait bursts and short events
x = linspace(0,1,L)';
env = sin(pi*x).^1.2;
end

% ----------------------------------------------------------------
function env = sustained_envelope(L)
% Trapezoidal (tonic) — MG gait bursts.
% Fast rise, sustained plateau with mild ripple, slow fall whose tail
% bleeds into the next TA onset to create realistic overlap.
rise_frac = 0.12;   % quick ramp up
fall_frac  = 0.25;  % slow taper (this is the overlap tail)
r = max(2, round(rise_frac * L));
f = max(2, round(fall_frac * L));
p = max(1, L - r - f);

plateau = ones(p,1);
% Subtle amplitude ripple on the plateau
plateau = plateau + 0.08 * sin(linspace(0, 2*pi*(1+rand), p)');

env = [linspace(0, 1, r)'; plateau; linspace(1, 0, f)'];
env = max(0, env(1:L));
end

% ----------------------------------------------------------------
function env = spasm_packet_envelope(L)
r = max(2, round(0.15*L));
f = max(2, round(0.20*L));
p = max(1, L-r-f);
env = [linspace(0,1,r)'; ones(p,1); linspace(1,0,f)'];
env = env(1:L);
end


% ----------------------------------------------------------------
function n = emg_packet_noise(L, fs)
raw = randn(L,1);
if L < 25
    n = raw / (std(raw) + eps);
    return;
end
[b,a] = butter(4, [80 700]/(fs/2), 'bandpass');
n = filtfilt(b,a,raw);
n = n / (std(n) + eps);
end

% ----------------------------------------------------------------
function w = motor_unit_waveform(L)
x = linspace(-1,1,L)';
w = exp(-18*x.^2) .* sin(2*pi*(1.2 + 0.8*rand)*x);
w = w / (std(w)+eps);
end

function shade_regions(ax, t, mask, color, alpha)
if ~any(mask), return; end
d = diff([false; mask(:); false]);
starts = find(d ==  1);
ends   = find(d == -1) - 1;
yl = ylim(ax);
for k = 1:numel(starts)
    x0 = t(starts(k));
    x1 = t(ends(k));
    patch(ax, [x0 x1 x1 x0], [yl(1) yl(1) yl(2) yl(2)], ...
        color, 'FaceAlpha', alpha, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
end
end