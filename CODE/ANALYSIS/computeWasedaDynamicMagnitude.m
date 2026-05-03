function dynMag = computeWasedaDynamicMagnitude(series, rollingWindowSec)
%COMPUTEWASEDADYNAMICMAGNITUDE Magnitude of rolling per-axis SD.
if nargin < 2 || isempty(rollingWindowSec)
    rollingWindowSec = 0.5;
end
windowSamples = max(5, round(rollingWindowSec * series.sample_rate_hz));
if mod(windowSamples, 2) == 0
    windowSamples = windowSamples + 1;
end
xStd = rollingStdCentered(series.ax, windowSamples);
yStd = rollingStdCentered(series.ay, windowSamples);
zStd = rollingStdCentered(series.az, windowSamples);
dynMag = sqrt(xStd .^ 2 + yStd .^ 2 + zStd .^ 2);
end
