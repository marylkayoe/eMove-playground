function valuesStd = rollingStdCentered(values, windowSamples)
%ROLLINGSTDCENTERED Centered rolling population SD with shrinking endpoints.
if mod(windowSamples, 2) == 0
    error('windowSamples must be odd.');
end
halfWindow = floor(windowSamples / 2);
valuesStd = movstd(values, [halfWindow, halfWindow], 1, 'Endpoints', 'shrink');
end
