function R = displayMarkerTrajectoryDuringStimulus(trialData, markerNames, mocapMetaData, videoID, varargin)
    % Plot trajectories for selected markers during a specific stimulus/video ID.
    % Supports optional figure/legend customization via name-value pairs.
    %
    % Required inputs:
    %   trialData      - struct containing motion capture data
    %   markerNames    - cell array or char of marker names to plot
    %   mocapMetaData  - struct with metadata for the mocap trial
    %   videoID        - identifier of the stimulus/video segment
    %
    % Optional name-value pairs:
    %   'plotWhere'              - axes handle to plot into (default: new figure)
    %   'figureTitle'            - custom title (default uses marker names + videoID)
    %   'relativePositionMarker' - marker name to use as reference (default: none)
    %   'groupColor'             - color for the group (default: auto colors)
    %   'groupLabel'             - legend label for the group (default: videoID)

    p = inputParser;
    addRequired(p, 'trialData');
    addRequired(p, 'markerNames', @(x) iscell(x) || ischar(x) || isstring(x));
    addRequired(p, 'mocapMetaData', @isstruct);
    addRequired(p, 'videoID', @(x) ischar(x) || isstring(x));

    addParameter(p, 'plotWhere', [], @(x) isempty(x) || ishandle(x));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'relativePositionMarker', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'groupColor', [], @(x) isempty(x) || ischar(x) || isnumeric(x));
   

    parse(p, trialData, markerNames, mocapMetaData, videoID, varargin{:});

    plotWhere = p.Results.plotWhere;
    figureTitle = p.Results.figureTitle;
    relativePositionMarker = p.Results.relativePositionMarker;
    groupColor = p.Results.groupColor;

    if strlength(string(figureTitle)) == 0
        figureTitle = sprintf('Trajectories of %s during stimulus %s', strjoin(cellstr(markerNames), ', '), videoID);
    end

    markerTrajectories = getMarkerTrajectory(trialData, markerNames, ...
        'videoID', videoID, 'mocapMetaData', mocapMetaData);

    R = plot3Dtrajectories(markerTrajectories, ...
        'markerNames', markerNames, ...
        'figureTitle', figureTitle, ...
        'relativePositionMarker', relativePositionMarker, ...
        'plotWhere', plotWhere, ...
        'groupColor', groupColor, ...
        'groupLabel', videoID);
end
