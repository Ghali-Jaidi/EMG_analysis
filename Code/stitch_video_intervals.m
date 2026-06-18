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
    
    % Validate inputs
    if ~isfile(input_video)
        error('Input video file not found: %s', input_video);
    end
    
    if interval1_start >= interval1_end || interval2_start >= interval2_end
        error('Invalid intervals: start time must be less than end time');
    end
    
    fprintf('Stitching video intervals from %s...\n', input_video);
    
    % Read input video properties
    vidReader = VideoReader(input_video);
    fps = vidReader.FrameRate;
    total_duration = vidReader.Duration;
    
    % Validate intervals don't exceed video duration
    if interval1_end > total_duration || interval2_end > total_duration
        warning('Intervals exceed video duration (%.2f s). Clamping to available range.', total_duration);
        interval1_end = min(interval1_end, total_duration);
        interval2_end = min(interval2_end, total_duration);
    end
    
    % Create output video writer
    vidWriter = VideoWriter(output_video, 'MPEG-4');
    vidWriter.FrameRate = fps;
    open(vidWriter);
    
    try
        fprintf('  FPS: %.1f\n', fps);
        fprintf('  Total input duration: %.2f s\n', total_duration);
        fprintf('  Extracting interval 1: %.2f-%.2f s (duration: %.2f s)\n', ...
            interval1_start, interval1_end, interval1_end - interval1_start);
        fprintf('  Extracting interval 2: %.2f-%.2f s (duration: %.2f s)\n', ...
            interval2_start, interval2_end, interval2_end - interval2_start);
        
        % Extract and write first interval
        fprintf('Processing interval 1...\n');
        vidReader.CurrentTime = interval1_start;
        frameCount1 = 0;
        while hasFrame(vidReader) && vidReader.CurrentTime < interval1_end
            frame = readFrame(vidReader);
            writeVideo(vidWriter, frame);
            frameCount1 = frameCount1 + 1;
        end
        fprintf('  ✓ Wrote %d frames from interval 1\n', frameCount1);
        
        % Extract and write second interval
        fprintf('Processing interval 2...\n');
        vidReader.CurrentTime = interval2_start;
        frameCount2 = 0;
        while hasFrame(vidReader) && vidReader.CurrentTime < interval2_end
            frame = readFrame(vidReader);
            writeVideo(vidWriter, frame);
            frameCount2 = frameCount2 + 1;
        end
        fprintf('  ✓ Wrote %d frames from interval 2\n', frameCount2);
        
        close(vidWriter);
        
        % Calculate output duration
        total_frames = frameCount1 + frameCount2;
        output_duration = total_frames / fps;
        
        fprintf('\n✓ Stitched video successfully created:\n');
        fprintf('  Output file: %s\n', output_video);
        fprintf('  Total frames: %d\n', total_frames);
        fprintf('  Output duration: %.2f s\n', output_duration);
        
    catch ME
        try
            close(vidWriter);
        catch
        end
        error('Error stitching video: %s', ME.message);
    end
end
