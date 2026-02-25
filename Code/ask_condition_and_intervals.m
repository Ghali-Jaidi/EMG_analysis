function [condLabel, intervals, groupLabel] = ask_condition_and_intervals(fileTag)
% Ask for condition and optional spasm intervals
% Returns:
%   condLabel  : raw condition label
%   intervals  : Nx2 interval matrix in seconds (empty if none)
%   groupLabel : normalized group label for analysis

choice = questdlg(sprintf('%s: condition?', fileTag), ...
                  'Condition', 'Spastic', 'Uninjured', 'Uninjured');

if isempty(choice)
    error('Condition selection canceled.');
end

condLabel = choice;

switch lower(choice)
    case 'spastic'
        groupLabel = "injured";
    case 'uninjured'
        groupLabel = "uninjured";
    otherwise
        groupLabel = string(choice);
end

if strcmpi(choice,'Spastic')
    prompt = ['Enter spasm intervals as Nx2 matrix in seconds, e.g.:' newline ...
              '[12.5 14.0; 33.2 35.1]' newline ...
              'Leave empty to use FULL recording.'];

    answ = inputdlg(prompt,'Spasm intervals',[6 60],{''});

    if isempty(answ)
        error('Interval input canceled.');
    end

    if isempty(strtrim(answ{1}))
        intervals = [];
    else
        intervals = str2num(answ{1}); %#ok<ST2NM>
        if isempty(intervals) || size(intervals,2) ~= 2
            error('Intervals must be an Nx2 numeric matrix [t_start t_end].');
        end
    end
else
    intervals = [];
end
end

function mask = build_interval_mask(N, fs, intervals)
% intervals Nx2 [t0 t1] in seconds
% if empty => mask all true
mask = true(N,1);
if isempty(intervals)
    return;
end

mask(:) = false;
for k = 1:size(intervals,1)
    t0 = intervals(k,1);
    t1 = intervals(k,2);
    if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0
        continue;
    end
    i0 = max(1, floor(t0*fs) + 1);
    i1 = min(N, floor(t1*fs));
    if i1 > i0
        mask(i0:i1) = true;
    end
end
end