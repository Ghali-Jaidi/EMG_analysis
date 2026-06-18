% getUnitLabel.m
% Return a sensible y-axis label based on a channel name.
%
% Usage:
%   lbl = getUnitLabel(channelName)
%   lbl = getUnitLabel("Left TA rect")
%
% Returns one of:
%   "Amplitude (µV)"
%   "Power (µV^2/Hz)"
%   "Power (µV^2)"
%   "Power (dB re 1 µV^2/Hz)"
%   "Value"
%
% Detection rules (case-insensitive):
% - 'psd' | 'spectral' -> Power (µV^2/Hz)
% - 'bandpower' | 'band power' | 'bp' -> Power (µV^2)
% - 'db' -> Power (dB re 1 µV^2/Hz)
% - 'rect' | 'filtered' | 'emg' | 'raw' | 'amp' | 'volt' | 'µv' | 'uv' -> Amplitude (µV)
% - 'power' (but not 'powerline') -> Power (µV^2)
% - otherwise -> Value

function lbl = getUnitLabel(channelName)
%GETUNITLABEL Return a y-axis label string inferred from channelName.
%   lbl = GETUNITLABEL(channelName) returns a plain string suitable for a
%   y-axis label based on keywords found in channelName. Input can be a
%   char vector or string scalar.

if nargin < 1
    error('getUnitLabel requires a channel name input.');
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
    lbl = "Power (µV^2/Hz)";
    return;
end

% Band-power variants
if contains(s_lower, "power") || contains(s_lower, "band power") || contains(s_lower, "band_pow") ...
        || contains(s_lower, " bp ") || startsWith(s_lower, "bp_") || contains(s_lower, "bp-")
    lbl = "Power (V^2)";
    return;
end

% dB mentions
if contains(s_lower, "db")
    lbl = "Power (dB re 1 µV^2/Hz)";
    return;
end

% Generic 'power' but exclude common interference labels like 'powerline'
if contains(s_lower, "power") && ~contains(s_lower, "powerline") && ~contains(s_lower, "mains")
    lbl = "Power (µV^2)";
    return;
end

% Amplitude / voltage / rectified / filtered / emg indicators
if contains(s_lower, "rect") || contains(s_lower, "filtered") || contains(s_lower, "emg") ...
        || contains(s_lower, "raw") || contains(s_lower, "amp") || contains(s_lower, "volt") ...
        || contains(s_lower, "µv") || contains(s_lower, "uv")
    lbl = "Amplitude (µV)";
    return;
end

% Fallback label
lbl = "Value";
end
