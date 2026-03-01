function sal = computeSpectralArcLength(traj, sampleRate, varargin)
% computeSpectralArcLength - Spectral arc length smoothness metric for 2D/3D trajectories.
%   sal = computeSpectralArcLength(traj, sampleRate) computes the spectral arc
%   length (more negative = smoother) from the velocity magnitude spectrum.
%
% Inputs:
%   traj        - nFrames x 2 or nFrames x 3 matrix of positions
%   sampleRate  - sampling rate in Hz
%
% Optional name-value:
%   'maxFreq'   - upper frequency (Hz) for arc length (default: min(10, Nyquist))
%
% Output:
%   sal         - spectral arc length (negative; more negative -> smoother)
%
% Notes:
%   Follows common SAL usage: compute speed, take magnitude spectrum,
%   normalize amplitude to [0,1], normalize frequency axis, and compute
%   arc length; return its negative so smoother motion yields smaller (more negative) values.

    p = inputParser;
    addParameter(p, 'maxFreq', [], @(x) isempty(x) || (isscalar(x) && x>0));
    parse(p, varargin{:});
    maxFreq = p.Results.maxFreq;

    if size(traj,1) < 4
        sal = NaN;
        return;
    end

    % velocity magnitude
    vel = diff(traj,1,1) * sampleRate;
    speed = vecnorm(vel,2,2);

    % detrend to reduce DC dominance
    speed = speed - mean(speed);

    N = numel(speed);
    if N < 2 || all(speed==0)
        sal = NaN;
        return;
    end

    % FFT magnitude
    Y = abs(fft(speed));
    freqs = (0:N-1)' * (sampleRate / N);

    % keep positive freqs up to Nyquist
    halfIdx = 1:floor(N/2);
    freqs = freqs(halfIdx);
    Y = Y(halfIdx);

    % limit frequency band
    nyq = sampleRate/2;
    if isempty(maxFreq)
        maxFreq = min(10, nyq);
    else
        maxFreq = min(maxFreq, nyq);
    end
    bandMask = freqs <= maxFreq;
    freqs = freqs(bandMask);
    Y = Y(bandMask);

    if isempty(freqs) || max(Y)==0
        sal = NaN;
        return;
    end

    % normalize frequency to [0,1], amplitude to [0,1]
    fNorm = freqs / maxFreq;
    aNorm = Y / max(Y);

    % arc length
    df = diff(fNorm);
    da = diff(aNorm);
    arcLen = sum(sqrt(df.^2 + da.^2));

    % more negative = smoother (convention in SAL literature)
    sal = -arcLen;
end
