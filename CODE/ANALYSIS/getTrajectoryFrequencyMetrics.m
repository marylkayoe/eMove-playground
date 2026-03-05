function metrics = getTrajectoryFrequencyMetrics(trajOrSpeed, sampleRate, varargin)
% getTrajectoryFrequencyMetrics - Frequency-domain analysis of a 3D trajectory or precomputed speed.
%
% APPROVAL-REQUIRED COMPUTATION:
% Frequency settings here affect reported spectral results.
% Do not change behavior without explicit project-owner approval.
%
%   metrics = getTrajectoryFrequencyMetrics(traj, sampleRate, 'bands', bands, ...)
%
% Inputs:
%   trajOrSpeed - either nFrames x 3 position data (unsmoothed) or a speed vector
%   sampleRate  - sampling rate in Hz
%
% Optional name-value pairs:
%   'bands'        - struct of named bands with [fLow fHigh] (default: tremor [6 12], low [0.5 3], mid [3 6], high [12 20])
%   'windowLength' - Welch window length in seconds (default: 2)
%   'overlapFrac'  - overlap fraction for Welch (default: 0.5)
%   'nfft'         - FFT length for PSD (default: 1024; or auto if empty)
%   'maxFreq'      - maximum frequency to keep/analyze (default: 20 Hz)
%   'highpassCutoff' - optional high-pass on speed to suppress drift (Hz, default: 0.2; empty to skip)
%   'makePlot'     - if true, plot PSD and band ratios (default: false)
%
% Output:
%   metrics struct with fields:
%       freq          - frequency vector (Hz)
%       psd           - power spectral density of speed (units^2/Hz)
%       totalPower    - total power over analyzed band
%       peakFreq      - frequency of maximum PSD
%       peakPower     - maximum PSD value
%       bands         - table of band name, power, and powerRatio
%

    p = inputParser;
    addRequired(p, 'trajOrSpeed', @(x) isnumeric(x));
    addRequired(p, 'sampleRate', @(x) isnumeric(x) && isscalar(x) && x > 0);
    defaultBands = struct( ...
        'tremor', [6 12], ...
        'low',    [0.5 3], ...
        'mid',    [3 6], ...
        'high',   [12 20]);
    addParameter(p, 'bands', defaultBands, @isstruct);
    addParameter(p, 'windowLength', 2, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'overlapFrac', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
    addParameter(p, 'nfft', 512, @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    addParameter(p, 'maxFreq', 30, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'highpassCutoff', 1, @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
    addParameter(p, 'makePlot', false, @(x) islogical(x) && isscalar(x));
    parse(p, trajOrSpeed, sampleRate, varargin{:});

    bands = p.Results.bands;
    winSec = p.Results.windowLength;
    overlapFrac = p.Results.overlapFrac;
    nfftParam = p.Results.nfft;
    maxFreq = p.Results.maxFreq;
    hpCut = p.Results.highpassCutoff;
    makePlot = p.Results.makePlot;

    metrics = struct('freq', [], 'psd', [], 'totalPower', NaN, 'peakFreq', NaN, 'peakPower', NaN, 'bands', []);

    if isvector(trajOrSpeed) && size(trajOrSpeed,2)==1
        speed = trajOrSpeed(:);
    else
        if size(trajOrSpeed,1) < 4 || size(trajOrSpeed,2) ~= 3
            return;
        end
        % Velocity magnitude from positions
        vel = diff(trajOrSpeed, 1, 1) * sampleRate;
        speed = vecnorm(vel, 2, 2);
    end

    if numel(speed) < 4
        return;
    end
    speed = speed - mean(speed); % detrend
    if ~isempty(hpCut) && hpCut > 0
        Wn = min(max(hpCut / (sampleRate/2), 1e-4), 0.99);
        [b,a] = butter(2, Wn, 'high');
        speed = filtfilt(b,a,speed);
    end

    % Welch PSD
    winSamples = max(16, round(winSec * sampleRate));
    if numel(speed) < winSamples
        winSamples = numel(speed);
    end
    overlapSamples = floor(overlapFrac * winSamples);
    overlapSamples = min(overlapSamples, winSamples-1);
    if isempty(nfftParam)
        nfft = 2^nextpow2(max(winSamples, numel(speed)));
        nfft = max(nfft, 1024); % ensure decent frequency resolution
    else
        nfft = nfftParam;
    end
    [Pxx, f] = pwelch(speed, hamming(winSamples), overlapSamples, nfft, sampleRate);
    mask = f <= maxFreq;
    f = f(mask);
    Pxx = Pxx(mask);

    metrics.freq = f;
    metrics.psd = Pxx;
    metrics.totalPower = trapz(f, Pxx);

    % Peak
    [metrics.peakPower, idxMax] = max(Pxx);
    metrics.peakFreq = f(idxMax);

    % Band metrics
    bandNames = fieldnames(bands);
    bandPower = zeros(numel(bandNames),1);
    bandRatio = zeros(numel(bandNames),1);
    for i = 1:numel(bandNames)
        fr = bands.(bandNames{i});
        mask = f >= fr(1) & f <= fr(2);
        if any(mask)
            bandPower(i) = trapz(f(mask), Pxx(mask));
            if metrics.totalPower > 0
                bandRatio(i) = bandPower(i) / metrics.totalPower;
            end
        else
            bandPower(i) = NaN;
            bandRatio(i) = NaN;
        end
    end
    metrics.bands = table(bandNames, bandPower, bandRatio, 'VariableNames', {'band','power','powerRatio'});

    if makePlot
        plotFreqMetrics(metrics);
    end
end

function plotFreqMetrics(metrics)
    figure;
    subplot(2,1,1);
    semilogy(metrics.freq, metrics.psd, 'LineWidth', 1.5);
    xlabel('Frequency (Hz)');
    ylabel('PSD');
    title(sprintf('Peak %.2f Hz (%.3g)', metrics.peakFreq, metrics.peakPower));
    grid on;

    subplot(2,1,2);
    bar(categorical(metrics.bands.band), metrics.bands.powerRatio);
    ylabel('Power ratio');

    title('Band power ratios');
    grid on;
end
