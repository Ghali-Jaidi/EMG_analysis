% realtime_emg_plotter_full_with_ylabels.m
% Robust EMG-to-video renderer with per-channel y-axis labels and 5 s visible window
% - Parses tab-separated EMG export with header
% - Repairs timestamps by reconstructing from SAMPLE_RATE when inconsistent
% - Per-channel y-axis units and renamed channels (pattern)
% - Zoomed-out time window (default 5 s visible)
% - Safe frame-count computation
% - MP4 preferred; Motion JPEG AVI fallback
% - Ensures figure x-limits update both on-screen and in saved frames

clear; close all; clc;

%% ---------- USER CONFIG ----------
DATA_FILE        = 'Only_Spasms_True.txt';
DATA_START_ROW   = 7;            % first data line in file (1-based)
WINDOW_SEC       = 5;            % nominal visible window (s)
WINDOW_ZOOM      = 1.00;         % set to 1.00 so WINDOW_TOTAL = WINDOW_SEC
RIGHT_MARGIN_FRAC = 0.05;        % fraction of window to pad on right
FPS              = 30;
VIDEO_NAME_MP4   = 'emg_stream.mp4';
VIDEO_NAME_AVI   = 'emg_stream.avi';
USE_AVI_FALLBACK = true;
FIG_POS          = [100 100 1280 900];
MAX_REASONABLE_FRAMES = 5e6;     % safety cap
%% ---------------------------------

fprintf('Reading file: %s\n', DATA_FILE);

try
    raw_lines = readlines(DATA_FILE);
    if isempty(raw_lines)
        error('File appears empty.');
    end

    % --- Parse sampling interval from header (if present)
    interval_val = 0.0001; % fallback seconds
    if numel(raw_lines) >= 1
        line1 = raw_lines(1);
        if contains(line1, 'Interval=')
            s = char(line1);
            tok = regexp(s, 'Interval\s*=\s*([0-9\.,]+)\s*([a-zA-Z]*)', 'tokens', 'once');
            if ~isempty(tok)
                numstr = strrep(tok{1}, ',', '.');
                unit = lower(tok{2});
                v = str2double(numstr);
                if ~isnan(v)
                    switch unit
                        case {'s',''}
                            interval_val = v;
                        case {'ms'}
                            interval_val = v/1000;
                        case {'us'}
                            interval_val = v/1e6;
                        otherwise
                            interval_val = v;
                    end
                end
            end
        end
    end
    SAMPLE_RATE = max(1, round(1/interval_val));
    fprintf('Parsed interval = %.6g s  (≈ %d Hz)\n', interval_val, SAMPLE_RATE);

    % --- Parse channel titles if present (attempt header line 5)
    default_names = string(["left TA rect","left MG rect","left TA filtered + smoothed","left MG Filtered + smoothed", "High-frequency Power (TA)", "Thresholds + Co-contration", "Stimulation output"]);
    channel_names = default_names;
    % DISABLED: Don't override with file header - use defaults instead
    % if numel(raw_lines) >= 5
    %     chline = raw_lines(5);
    %     if contains(chline, 'ChannelTitle=')
    %         chstr = extractAfter(chline, 'ChannelTitle=');
    %         parts = strsplit(string(chstr), char(9));
    %         parts = parts(parts ~= "");
    %         if ~isempty(parts)
    %             channel_names = string(parts);
    %         end
    %     end
    % end

    % --- Read numeric data lines robustly
    n_data_lines = max(0, numel(raw_lines) - DATA_START_ROW + 1);
    if n_data_lines == 0
        error('No data lines found. Check DATA_START_ROW and file contents.');
    end

    % Pre-allocate using detected channel count (assume header gave names)
    NUM_CH = max(1, numel(channel_names));
    t_col = nan(n_data_lines,1);
    ch_mat = zeros(n_data_lines, NUM_CH);

    for r = 1:n_data_lines
        line = raw_lines(DATA_START_ROW + r - 1);
        cols = strsplit(string(line), char(9));
        cols = cols(:);
        if numel(cols) >= 1
            tstr = strrep(string(cols(1)), ',', '.');
            tval = str2double(strtrim(tstr));
            t_col(r) = tval;
        else
            t_col(r) = NaN;
        end
        % fill channels (pad/trim to NUM_CH)
        for c = 1:NUM_CH
            if numel(cols) >= c+1
                vstr = strtrim(string(cols(c+1)));
                if strcmpi(vstr, 'NaN')
                    v = 0;
                else
                    v = str2double(strrep(vstr, ',', '.'));
                    if isnan(v), v = 0; end
                end
            else
                v = 0;
            end
            ch_mat(r,c) = v;
        end
    end

    % Remove rows with non-finite times (for initial cleaning)
    valid_idx = isfinite(t_col);
    t_data = t_col(valid_idx);
    ch_data = ch_mat(valid_idx, :);

    if isempty(t_data)
        error('No valid timestamped rows after parsing.');
    end

    % --- Fix timestamps if inconsistent (robust approach)
    nSamples = numel(t_data);
    span_reported = t_data(end) - t_data(1);
    span_expected = nSamples / SAMPLE_RATE;
    if nSamples > 1
        dt_med = median(diff(t_data));
    else
        dt_med = Inf;
    end
    fprintf('Reported span: %.6f s, Expected span: %.6f s, median dt: %.6e s\n', span_reported, span_expected, dt_med);

    tol = 0.01 * max(1e-12, span_expected); % 1% tolerance
    if ~isfinite(span_reported) || abs(span_reported - span_expected) > tol
        fprintf('Timestamps inconsistent (difference > %.6g). Reconstructing from sample index using SAMPLE_RATE = %d Hz\n', tol, SAMPLE_RATE);
        t0 = t_data(find(isfinite(t_data),1,'first')); % earliest finite time
        if isempty(t0) || ~isfinite(t0)
            t0 = 0;
        end
        t_data = t0 + (0:(nSamples-1))' ./ SAMPLE_RATE;
        span_reported = t_data(end) - t_data(1);
        fprintf('Reconstructed timestamps. New reported span: %.6f s\n', span_reported);
    else
        fprintf('Timestamps appear consistent; keeping original times.\n');
    end

    % Final checks
    if any(~isfinite(t_data))
        error('t_data still contains non-finite values after repairs.');
    end
    nSamples = numel(t_data);
    total_duration = max(0, t_data(end) - t_data(1));
    fprintf('Loaded %d samples. Total duration: %.3f s\n', nSamples, total_duration);

catch ME
    error('Error parsing data file: %s', ME.message);
end

%% --- Channel renaming per user request
% Use the channel names extracted from file header, or use defaults if not parsed correctly
NUM_CH = size(ch_data,2);

% If channel names from header are not meaningful, you can override them here:
% Uncomment and modify the line below with your actual channel names:
% channel_names = ["Channel 1", "Channel 2", "Channel 3", "Channel 4"];

% Otherwise, use what was parsed from the file header
% (channel_names was already extracted earlier in the parsing section)

%% --- Build label map for y-axis labels (real units are Volts)
labelMap = containers.Map();
labelMap('amplitude') = 'Amplitude (V)';
labelMap('psd') = 'Power (V^2/Hz)';
labelMap('bandpower') = 'Power (V^2)';
labelMap('db') = 'Power (dB re 1 V^2/Hz)';
labelMap('default') = 'Value';


%% --- Figure & plotting setup (tiled)
WINDOW_TOTAL = WINDOW_SEC * WINDOW_ZOOM;
RIGHT_PAD = WINDOW_TOTAL * RIGHT_MARGIN_FRAC;

colors = [
    0.20 0.60 1.00;
    0.10 0.85 0.55;
    1.00 0.55 0.15;
    0.95 0.25 0.35;
    1.00 0.80 0.20;
    0.80 0.40 0.80;
    0.40 0.90 0.80;
    0.65 0.35 0.95];
colors = colors(mod(0:NUM_CH-1, size(colors,1))+1, :);

fig = figure('Name','EMG Real-Time Monitor','Color',[0.08 0.08 0.12], ...
    'NumberTitle','off','Position',FIG_POS, 'Visible', 'on');

tl = tiledlayout(NUM_CH,1,'TileSpacing','compact','Padding','compact');
ax = gobjects(NUM_CH,1);
ln = gobjects(NUM_CH,1);
cursorLine = gobjects(NUM_CH,1);

for ch = 1:NUM_CH
    ax(ch) = nexttile;
    ln(ch) = plot(ax(ch), nan, nan, 'Color', colors(ch,:), 'LineWidth', 1.25);
    set(ax(ch), 'Color', [0.10 0.10 0.15], ...
        'XColor', [0.55 0.55 0.65], 'YColor', [0.55 0.55 0.65], ...
        'GridColor', [0.25 0.25 0.35], 'XGrid','on','YGrid','on', 'FontSize',9);

    title(ax(ch), char(channel_names(ch)), 'Color', colors(ch,:), ...
        'FontWeight','normal','FontSize',10,'Interpreter','none');

    % Apply y-label using getUnitLabel to parse channel name
    lbl = getUnitLabel(channel_names(ch));
    ylabel(ax(ch), lbl, 'Color', [0.85 0.85 0.9]);

    if ch < NUM_CH
        set(ax(ch), 'XTickLabel', []);
    else
        xlabel(ax(ch), 'Time (s)', 'Color', [0.7 0.7 0.8]);
    end

    % Use full-data y-limits so video is consistent
    ch_vals = ch_data(:,ch);
    y_min = min(ch_vals);
    y_max = max(ch_vals);
    y_margin = (y_max - y_min) * 0.15;
    if y_margin == 0, y_margin = 0.5; end
    ylim(ax(ch), [y_min - y_margin, y_max + y_margin]);

    % Precreate a vertical cursor line (store handle)
    hold(ax(ch), 'on');
    cursorLine(ch) = plot(ax(ch), [t_data(1) t_data(1)], ylim(ax(ch)), 'r', 'LineWidth', 1);
    hold(ax(ch), 'off');
end

sgtitle(tl, 'EMG Real-Time Stream', 'Color', [0.90 0.90 0.95], 'FontSize', 13, 'FontWeight', 'bold');
drawnow;

%% --- Prepare VideoWriter safely
useAVI = false;
try
    vw = VideoWriter(VIDEO_NAME_MP4, 'MPEG-4');
    vw.FrameRate = FPS;
    open(vw);
    fprintf('Writing MP4: %s  (FPS=%d)\n', VIDEO_NAME_MP4, FPS);
catch
    if USE_AVI_FALLBACK
        warning('MP4 writer unavailable. Falling back to Motion JPEG AVI.');
        vw = VideoWriter(VIDEO_NAME_AVI, 'Motion JPEG AVI');
        vw.FrameRate = FPS;
        open(vw);
        useAVI = true;
        fprintf('Writing AVI: %s  (FPS=%d)\n', VIDEO_NAME_AVI, FPS);
    else
        rethrow(lasterror);
    end
end

%% --- Compute safe frame count
t0 = t_data(1);
tend = t_data(end);

if ~isfinite(t0) || ~isfinite(tend)
    close(vw);
    error('t_data start/end are not finite.');
end
total_duration = max(0, tend - t0);
nFrames = max(1, floor(total_duration * FPS) + 1);

if ~isfinite(nFrames) || nFrames < 1
    close(vw);
    error('Computed invalid frame count.');
end

if nFrames > MAX_REASONABLE_FRAMES
    warning('Computed frame count (%d) exceeds safety cap (%d). Capping frames.', nFrames, MAX_REASONABLE_FRAMES);
    nFrames = MAX_REASONABLE_FRAMES;
end

fprintf('Total duration: %.3f s, Frames to render: %d\n', total_duration, nFrames);

%% --- Validate figure handle
if ~ishandle(fig) || ~strcmp(get(fig,'Type'),'figure')
    close(vw);
    error('Figure handle is invalid. Cannot capture frames.');
end
set(fig, 'Visible', 'on');
drawnow;

%% --- Render frames (on-the-fly times, moving pointer for indices)
ptr = 1;
for frameIdx = 0:(nFrames-1)
    ft = t0 + frameIdx / FPS;  % absolute time for this frame
    if ft > tend + 1e-12
        break;
    end

    t_start = ft - WINDOW_TOTAL;
    t_end   = ft + RIGHT_PAD;

    % Move pointer to first index >= t_start
    while ptr < nSamples && t_data(ptr) < t_start
        ptr = ptr + 1;
    end
    i0 = max(1, ptr);

    % Move end pointer forward to include values <= t_end
    i1 = i0;
    while i1 <= nSamples && t_data(i1) <= t_end
        i1 = i1 + 1;
    end
    i1 = min(i1, nSamples);
    if i1 > i0 && t_data(i1) > t_end
        i1 = i1 - 1;
    end

    if i1 < i0
        % No data in window: draw small flat line
        t_plot = [t_start, t_end];
        for ch = 1:NUM_CH
            set(ln(ch), 'XData', t_plot, 'YData', [0 0]);
            set(cursorLine(ch), 'XData', [ft ft], 'YData', ylim(ax(ch)));
            xlim(ax(ch), [t_start t_end]);
        end
    else
        t_plot = t_data(i0:i1);  % absolute times
        for ch = 1:NUM_CH
            set(ln(ch), 'XData', t_plot, 'YData', ch_data(i0:i1, ch));
            % Update cursor line position and ensure it spans current ylim
            set(cursorLine(ch), 'XData', [ft ft], 'YData', ylim(ax(ch)));
            xlim(ax(ch), [t_start t_end]);
        end
    end

    % Update the first title line with elapsed time (keeps per-frame info)
    elapsed = ft - t0;
    % Update only the top axis title (others retain their channel name)
    title(ax(1), sprintf('%s    t = %.3f s', char(channel_names(1)), elapsed), ...
        'Color', [0.9 0.9 0.95], 'FontSize', 9);

    drawnow;                     % ensure rendering
    % Capture frame from figure explicitly
    try
        frame = getframe(fig);
    catch
        try
            frame = getframe(ax(end));
        catch ME
            close(vw);
            error('Failed to capture frame: %s', ME.message);
        end
    end

    % Resize frame to standard size (1280x720) for consistency
    frame_resized.cdata = imresize(frame.cdata, [720 1280]);
    frame_resized.colormap = frame.colormap;
    
    try
        writeVideo(vw, frame_resized);
    catch ME
        % If resize doesn't help, try writing original frame
        try
            writeVideo(vw, frame);
        catch
            close(vw);
            error('Failed to write video frame: %s', ME.message);
        end
    end

    % Progress every 10%
    if mod(frameIdx+1, max(1, round(nFrames/10))) == 0
        fprintf('%.0f%% ', 100*(frameIdx+1)/nFrames);
    end
end
fprintf('\n');

close(vw);
if useAVI
    fprintf('Video saved (%s).\n', VIDEO_NAME_AVI);
else
    fprintf('Video saved (%s).\n', VIDEO_NAME_MP4);
end

%% ========== HELPER FUNCTIONS ==========

function stitch_video_intervals(input_video, interval1_start, interval1_end, interval2_start, interval2_end, output_video)
    % STITCH_VIDEO_INTERVALS Extract two time intervals from a video and stitch them together
    %
    % Usage:
    %   stitch_video_intervals('emg_stream.mp4', 5, 12, 20, 28, 'emg_spasms.mp4')
    %   Extracts frames from 5-12s and 20-28s, stitches them into output video
    %
    % Inputs:
    %   input_video    : Path to input MP4 file (string)
    %   interval1_start: Start time of first interval in seconds
    %   interval1_end  : End time of first interval in seconds
    %   interval2_start: Start time of second interval in seconds
    %   interval2_end  : End time of second interval in seconds
    %   output_video   : Path to output MP4 file (string)
    
    fprintf('Stitching video intervals from %s...\n', input_video);
    
    % Read input video
    vidReader = VideoReader(input_video);
    fps = vidReader.FrameRate;
    
    % Create output video writer
    vidWriter = VideoWriter(output_video, 'MPEG-4');
    vidWriter.FrameRate = fps;
    open(vidWriter);
    
    try
        % Convert time intervals to frame indices
        frame1_start = max(1, floor(interval1_start * fps) + 1);
        frame1_end = floor(interval1_end * fps);
        frame2_start = max(1, floor(interval2_start * fps) + 1);
        frame2_end = floor(interval2_end * fps);
        
        fprintf('  Extracting interval 1: %.2f-%.2f s (frames %d-%d)\n', ...
            interval1_start, interval1_end, frame1_start, frame1_end);
        fprintf('  Extracting interval 2: %.2f-%.2f s (frames %d-%d)\n', ...
            interval2_start, interval2_end, frame2_start, frame2_end);
        
        % Extract and write first interval
        vidReader.CurrentTime = interval1_start;
        frameCount = 0;
        while hasFrame(vidReader) && vidReader.CurrentTime < interval1_end
            frame = readFrame(vidReader);
            writeVideo(vidWriter, frame);
            frameCount = frameCount + 1;
        end
        fprintf('  Wrote %d frames from interval 1\n', frameCount);
        
        % Extract and write second interval
        vidReader.CurrentTime = interval2_start;
        frameCount = 0;
        while hasFrame(vidReader) && vidReader.CurrentTime < interval2_end
            frame = readFrame(vidReader);
            writeVideo(vidWriter, frame);
            frameCount = frameCount + 1;
        end
        fprintf('  Wrote %d frames from interval 2\n', frameCount);
        
        close(vidWriter);
        fprintf('✓ Stitched video saved to: %s\n', output_video);
        
    catch ME
        close(vidWriter);
        error('Error stitching video: %s', ME.message);
    end
end

function unitType = unitType(chIdx)
    % Determine unit type based on channel index
    % Maps channel index to unit category: 'amplitude', 'psd', 'bandpower', 'db', or 'default'
    % All EMG channels use amplitude (Volts) as the default unit
    
    unitType = 'amplitude';  % All channels in this script are amplitude-based (rectified or filtered EMG)
end

function lbl = getUnitLabel(channelName)
    % GETUNITLABEL Return a y-axis label string inferred from channelName.
    % Input can be a char vector or string scalar.
    % Returns a y-axis label based on keywords found in channelName.
    % Real units are in Volts (V).
    
    if nargin < 1
        lbl = "Value";
        return;
    end
    
    s = string(channelName);
    if isempty(s)
        lbl = "Value";
        return;
    end
    
    % Normalize to lower-case for searching
    s_lower = lower(s);
    
    % Look for PSD / spectral indicators
    if contains(s_lower, "psd") || contains(s_lower, "power spectral") || contains(s_lower, "spectral")
        lbl = "Power (V^2/Hz)";
        return;
    end
    
    % Band-power variants
    if contains(s_lower, "bandpower") || contains(s_lower, "band power") || contains(s_lower, "band_pow") ...
            || contains(s_lower, " bp ") || startsWith(s_lower, "bp_") || contains(s_lower, "bp-")
        lbl = "Power (V^2)";
        return;
    end
    
    % dB mentions
    if contains(s_lower, "db")
        lbl = "Power (dB re 1 V^2/Hz)";
        return;
    end
    
    % Generic 'power' but exclude common interference labels like 'powerline'
    if contains(s_lower, "power") && ~contains(s_lower, "powerline") && ~contains(s_lower, "mains")
        lbl = "Power (V^2)";
        return;
    end
    
    % Amplitude / voltage / rectified / filtered / emg indicators
    if contains(s_lower, "rect") || contains(s_lower, "filtered") || contains(s_lower, "emg") ...
            || contains(s_lower, "raw") || contains(s_lower, "amp") || contains(s_lower, "volt") ...
            || contains(s_lower, "v")
        lbl = "Amplitude (V)";
        return;
    end
    
    % Fallback label
    lbl = "Value";
end
