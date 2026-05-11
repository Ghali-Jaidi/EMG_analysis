function ticks = compute_logical_ticks(minVal, maxVal)
% compute_logical_ticks
% Generates logical tick locations at sensible voltage intervals
% 
% Inputs:
%   minVal : minimum voltage value
%   maxVal : maximum voltage value
%
% Outputs:
%   ticks  : vector of tick positions at logical voltage intervals
%            (e.g., 0V, 0.5V, 1V or 0V, 0.1V, 0.2V depending on range)

range = maxVal - minVal;

% Determine tick spacing based on range
if range == 0
    ticks = minVal;
    return;
end

% Find a nice tick interval (0.1, 0.2, 0.5, 1.0, 2.0, 5.0, etc.)
magnitude = 10^floor(log10(range));
normalized_range = range / magnitude;

if normalized_range < 1.5
    tick_interval = 0.2 * magnitude;
elseif normalized_range < 3
    tick_interval = 0.5 * magnitude;
elseif normalized_range < 7
    tick_interval = 1 * magnitude;
else
    tick_interval = 2 * magnitude;
end

% Generate ticks from minVal to maxVal
tick_start = ceil(minVal / tick_interval) * tick_interval;
tick_end = floor(maxVal / tick_interval) * tick_interval;

ticks = tick_start : tick_interval : tick_end;

% Ensure we always have at least 2 ticks
if numel(ticks) < 2
    ticks = [minVal, maxVal];
end

end
