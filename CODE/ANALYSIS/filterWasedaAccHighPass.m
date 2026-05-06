function [seriesOut, info] = filterWasedaAccHighPass(seriesIn, cutoffHz, filterOrder)
%FILTERWASEDAACCHIGHPASS Zero-phase high-pass filter on raw Waseda ACC axes.
%
% This is intended as a preprocessing comparison step before dynamic-envelope
% construction. It preserves the original time base and metadata.

if nargin < 2 || isempty(cutoffHz) || cutoffHz <= 0
    seriesOut = seriesIn;
    info = struct('applied', false, 'cutoff_hz', NaN, 'order', NaN);
    return;
end
if nargin < 3 || isempty(filterOrder)
    filterOrder = 2;
end
if ~isfield(seriesIn, 'sample_rate_hz') || isempty(seriesIn.sample_rate_hz) || seriesIn.sample_rate_hz <= 0
    error('filterWasedaAccHighPass requires a positive sample_rate_hz field.');
end
if cutoffHz >= 0.5 * seriesIn.sample_rate_hz
    error('High-pass cutoff %.3f Hz must be below Nyquist for sample rate %.3f Hz.', ...
        cutoffHz, seriesIn.sample_rate_hz);
end

Wn = cutoffHz / (seriesIn.sample_rate_hz / 2);
[b, a] = butter(filterOrder, Wn, 'high');

seriesOut = seriesIn;
seriesOut.ax = filtfilt(b, a, seriesIn.ax);
seriesOut.ay = filtfilt(b, a, seriesIn.ay);
seriesOut.az = filtfilt(b, a, seriesIn.az);
seriesOut.raw_highpass_cutoff_hz = cutoffHz;
seriesOut.raw_highpass_order = filterOrder;

info = struct('applied', true, 'cutoff_hz', cutoffHz, 'order', filterOrder);
end
