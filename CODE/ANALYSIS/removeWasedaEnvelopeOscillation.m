function [signalOut, info] = removeWasedaEnvelopeOscillation(timesSec, signalIn, varargin)
%REMOVEWASEDAENVELOPEOSCILLATION Fit and subtract a dominant narrowband oscillation.
%
% This is intended for the cleaned dynamic-envelope signal, not the raw ACC.

p = inputParser;
p.addParameter('searchBandHz', [0.10 0.80]);
p.addParameter('harmonicCount', 3, @isscalar);
p.addParameter('minPeakRelPower', 3.0, @isscalar);
p.parse(varargin{:});
opts = p.Results;

signalOut = signalIn;
info = struct('applied', false, 'dominant_freq_hz', NaN, ...
    'peak_rel_power', NaN, 'harmonic_count', opts.harmonicCount);

validMask = ~isnan(signalIn);
if nnz(validMask) < 32
    return;
end

t = timesSec(validMask);
y = signalIn(validMask);
yCentered = y - median(y);
dt = diff(t);
dt = dt(dt > 0);
if isempty(dt)
    return;
end
fs = 1 / median(dt);

[pxx, f] = pwelch(yCentered, [], [], [], fs);
bandMask = f >= opts.searchBandHz(1) & f <= opts.searchBandHz(2);
if ~any(bandMask)
    return;
end

fBand = f(bandMask);
pBand = pxx(bandMask);
[peakPower, idx] = max(pBand);
dominantFreq = fBand(idx);
bandMedian = median(pBand);
if bandMedian <= 0
    bandMedian = eps;
end
peakRelPower = peakPower / bandMedian;

info.dominant_freq_hz = dominantFreq;
info.peak_rel_power = peakRelPower;
if peakRelPower < opts.minPeakRelPower
    return;
end

tRel = t - t(1);
X = ones(numel(tRel), 1);
for k = 1:opts.harmonicCount
    X = [X, sin(2 * pi * k * dominantFreq * tRel), cos(2 * pi * k * dominantFreq * tRel)]; %#ok<AGROW>
end
beta = X \ y;
oscPart = X(:, 2:end) * beta(2:end);

signalOut(validMask) = y - oscPart;
info.applied = true;
end
