function [avgSpeed, markerSpeeds] = getAverageTrajectorySpeed(trialData, markerNames, FRAMERATE, varargin)
    % Compute per-frame average speed across a set of markers.
    %
    % Inputs:
    %   trialData   - struct with markerNames, trajectoryData, etc.
    %   markerNames - cell/char/string list of markers to include
    %   FRAMERATE   - sampling rate in frames per second (required positional)
    %
    % Optional name-value pairs:
    %   'speedWindow' - window (seconds) for speed calculation (default: 0.1)
    %   'frameRange'  - explicit frame indices to use
    %   'videoID'     - video ID to derive frame range from mocapMetaData
    %   'mocapMetaData' - struct with stimScheduling/videoIDs (needed if using videoID)
    %. 'speedWindow'  - time window in seconds for speed calculation (default: 0.1)
    %
    % Outputs:
    %   avgSpeed     - column vector of average speed across requested markers (NaN for frames without data)
    %   markerSpeeds - matrix nFrames x nMarkers of individual marker speeds

    p = inputParser;
    addRequired(p, 'trialData');
    addRequired(p, 'markerNames', @(x) ischar(x) || isstring(x) || ...
        (iscell(x) && all(cellfun(@(c) ischar(c) || isstring(c), x(:)))));
    addRequired(p, 'FRAMERATE', @(x) isnumeric(x) && isscalar(x) && x > 0);

    addParameter(p, 'speedWindow', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'frameRange', [], @(x) isnumeric(x) && isvector(x));
    addParameter(p, 'videoID', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);



    parse(p, trialData, markerNames, FRAMERATE, varargin{:});

    speedWindow = p.Results.speedWindow;
    frameRange = p.Results.frameRange;
    videoID = p.Results.videoID;
    mocapMetaData = p.Results.mocapMetaData;
    FRAMERATE = p.Results.FRAMERATE;

    if isempty(videoID) && isempty(frameRange)
        % use all frames
        frameRange = [];
    else
        % get the frame range from videoID if provided
        if ~isempty(videoID)
            if isfield(mocapMetaData, 'stimScheduling') && isfield(mocapMetaData, 'videoIDs')
                [startFrame, endFrame] = getFramesForStimVideo(mocapMetaData, videoID);
                frameRange = startFrame:endFrame;
            else
                warning('mocapMetaData does not contain stimScheduling or videoIDs fields. Cannot get frame range for videoID: %s', videoID);
            end
    
        end
    end

    % Pull trajectories for the requested markers (handles frameRange/videoID internally)
    trajectories = getMarkerTrajectory(trialData, markerNames, ...
        'frameRange', frameRange, 'videoID', videoID, 'mocapMetaData', mocapMetaData);

    if ischar(markerNames)
        markerNames = {markerNames};
    end
    nMarkers = numel(markerNames);
    nFrames = size(trajectories, 1);

    markerSpeeds = NaN(nFrames, nMarkers);
    for m = 1:nMarkers
        markerSpeeds(:, m) = getTrajectorySpeed(trajectories(:, :, m), FRAMERATE, speedWindow);
    end

    % Average across markers per frame, ignoring NaNs (common at window edges)
    avgSpeed = mean(markerSpeeds, 2, 'omitnan');

end
