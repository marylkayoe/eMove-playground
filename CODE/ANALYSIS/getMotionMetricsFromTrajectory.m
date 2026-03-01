function R = getMotionMetricsFromTrajectory(trajectory, varargin)
    % return various descriptive metrics from a single 3D trajectory
    % inputs
    %   trajectory - nFrames x 3 matrix of X,Y,Z positions
    % optional name-value pairs:
    %   'FRAMERATE' - sampling rate in frames per second; default, 120
    %   'speedWindow' - time window in seconds for speed calculation; default, 0.1s
    %   'computeFrequencyMetrics' - logical, compute frequency metrics on speed (default: false)
    %   'freqBands' - struct of bands for frequency metrics
    %   'freqMakePlot' - logical, plot PSD/band ratios (default: false)
    %.  'immobilityThreshold' - speed threshold (mm/s) below which is considered immobile (default: 35 mm/s)
    %
    % outputs
    %   metrics - struct with fields:
    %       totalDistance - total distance traveled (mm)
    %       averageSpeed  - average speed (mm/s)
    %       maxSpeed      - maximum speed (mm/s)

    p = inputParser;
    addRequired(p, 'trajectory', @(x) isnumeric(x) && size(x,2) == 3);
    addParameter(p, 'FRAMERATE', 120, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'speedWindow', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'computeFrequencyMetrics', false, @(x) islogical(x) && isscalar(x));
        defaultBands = struct( ...
        'tremor', [6 12], ...
        'low',    [0.5 3], ...
        'mid',    [3 6], ...
        'high',   [12 20]);
    addParameter(p, 'freqBands', defaultBands, @isstruct);

    addParameter(p, 'freqMakePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'immobilityThreshold', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, trajectory, varargin{:});

    FRAMERATE = p.Results.FRAMERATE;
    speedWindow = p.Results.speedWindow; % in seconds
    traj = p.Results.trajectory;
    nFrames = size(traj, 1);
    metrics = struct();
    immobilityThreshold = p.Results.immobilityThreshold;

    % Total distance traveled; sum of Euclidean distances between frames corresponding to the speed window
     speedWindowFrames = max(1, round(speedWindow * FRAMERATE));

     % checking if the trajectory has enough frames to compute metrics
    if nFrames <= speedWindowFrames
        metrics.totalDistance = 0;
        metrics.averageSpeed = 0;
        metrics.maxSpeed = 0;
        R = metrics;
        return;
    end

    % smooth the trajectory first 
    smoothTraj = movmean(traj, [speedWindowFrames 0], 1);
    diffs = sqrt(sum(diff(smoothTraj).^2, 2)); % Euclidean distances between consecutive frames
    totalDistance = sum(diffs);
    metrics.totalDistance = totalDistance;

    % Compute speeds using getTrajectorySpeed function
    speeds = getTrajectorySpeed(smoothTraj, FRAMERATE, speedWindow);
    metrics.averageSpeed = nanmean(speeds);
    metrics.medianSpeed = nanmedian(speeds);
    metrics.maxSpeed = nanmax(speeds);
    metrics.speedArray = speeds;

    % get speed info for periods of immobility
    immobileMask = speeds < immobilityThreshold;
    metrics.speedArrayImmobile = speeds(immobileMask);
    metrics.speedArrayMobile   = speeds(~immobileMask); % optional
  metrics.percentImmobile = 100 * sum(immobileMask) / numel(speeds);
    metrics.avgSpeedImmobile = nanmean(speeds(immobileMask));
    metrics.medianSpeedImmobile = nanmedian(speeds(immobileMask));
    metrics.avgSpeedMobile = nanmean(speeds(~immobileMask));

    % motion smoothness using spectral arc length (SAL) on the speed signal
    % lower SAL indicates smoother motion
    validSpeeds = speeds(~isnan(speeds));
    metrics.spectralArcLength = LF_getSAL(validSpeeds, FRAMERATE);

    % calculate range of motion (max-min in each dimension)
    metrics.rangeOfMotion = max(traj, [], 1) - min(traj, [], 1);

    % calculate MAD (mean absolute deviation) in each dimension
    markerCenterPosition = median(smoothTraj, 1, 'omitnan');
    r = sqrt(sum((smoothTraj - markerCenterPosition).^2, 2));  % nFrames x 1
    mad3d = mad(r, 1);  % scaled by default (multiplicative factor for normality)
    metrics.mad3d = mad3d;

    % optional frequency-domain metrics on the precomputed speed
    if p.Results.computeFrequencyMetrics
        metrics.freqMetrics = getTrajectoryFrequencyMetrics(validSpeeds, FRAMERATE, ...
            'bands', p.Results.freqBands, 'makePlot', p.Results.freqMakePlot);
        metrics.freqSignal = validSpeeds;
    end

    R = metrics;
end

function sal = LF_getSAL(speedSignal, sampleRate)
    % Compute spectral arc length from a precomputed speed signal.
    if numel(speedSignal) < 4 || all(speedSignal == 0)
        sal = NaN;
        return;
    end
    % Detrend
    speedSignal = speedSignal - mean(speedSignal);
    N = numel(speedSignal);
    Y = abs(fft(speedSignal));
    freqs = (0:N-1)' * (sampleRate / N);
    halfIdx = 1:floor(N/2);
    freqs = freqs(halfIdx);
    Y = Y(halfIdx);
    if isempty(freqs) || max(Y) == 0
        sal = NaN;
        return;
    end
    maxFreq = min(10, sampleRate/2);
    mask = freqs <= maxFreq;
    freqs = freqs(mask);
    Y = Y(mask);
    if isempty(freqs) || max(Y)==0
        sal = NaN;
        return;
    end
    fNorm = freqs / maxFreq;
    aNorm = Y / max(Y);
    df = diff(fNorm);
    da = diff(aNorm);
    arcLen = sum(sqrt(df.^2 + da.^2));
    sal = -arcLen; % more negative -> smoother
end
