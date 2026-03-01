function R = displayBodypartTrajectoriesAcrossStims(markerLists, trialData, varargin)
    % displayBodypartTrajectoriesAcrossStims - Generates subplots for body part trajectories across stimuli.
    %
    % Inputs:
    %   markerLists   - Cell array of cell arrays, each containing marker names for a body part.
    %   trialData     - Struct with fields markerNames, trajectoryData, etc.
    %
    % Optional name-value pairs:
    %   'figureTitle' - Custom figure title (default: 'Body Part Trajectories Across Stimuli').
    %   'panelTitles' - Cell array of strings for subplot titles (default: empty).
    %   'mocapMetaData' - Struct with stimScheduling and videoIDs (default: trialData.metaData).

    % Backward compatibility: allow third positional arg as mocapMetaData
    if ~isempty(varargin) && isstruct(varargin{1})
        varargin = [{'mocapMetaData'}, varargin];
    end

    p = inputParser;
    addRequired(p, 'markerLists', @(x) iscell(x) && all(cellfun(@iscell, x)));
    addRequired(p, 'trialData');
    addParameter(p, 'figureTitle', 'Body Part Trajectories Across Stimuli', @(x) ischar(x) || isstring(x));
    addParameter(p, 'panelTitles', {}, @(x) iscell(x) && all(cellfun(@ischar, x)));
    addParameter(p, 'relativePositions', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'stimVideoEmotionCoding', {}, @(x) istable(x) || iscell(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);

    parse(p, markerLists, trialData, varargin{:});

    figureTitle = p.Results.figureTitle;
    panelTitles = p.Results.panelTitles;
    doRelative = p.Results.relativePositions;
    codingTable = p.Results.stimVideoEmotionCoding;
    metaData = trialData.metaData;

    if isempty(metaData) && isfield(trialData, 'metaData')
        metaData = trialData.metaData;
    end

    % Validate required metadata
    if ~isstruct(metaData) || ~isfield(metaData, 'videoIDs') || ~isfield(metaData, 'stimScheduling')
        error('Metadata must contain videoIDs and stimScheduling (provide mocapMetaData or ensure trialData.metaData has them).');
    end

    nSubplots = numel(markerLists);
    nCols = ceil(sqrt(nSubplots));
    nRows = ceil(nSubplots / nCols);

    % Create figure
    figure;
    subjID = 'subject';
    if isfield(trialData, 'subjectID')
        subjID = char(trialData.subjectID);
    end
    if doRelative
        sgTitleStr = sprintf('%s: %s (relative to baseline)', subjID, figureTitle);
    else
        sgTitleStr = sprintf('%s: %s', subjID, figureTitle);
    end
    sgtitle(sgTitleStr, 'FontSize', 16, 'Color', 'k');

    for i = 1:nSubplots
        markerNames = markerLists{i};
        if isempty(panelTitles)
            panelTitle = sprintf('Panel %d', i); % Default panel title
        else
            panelTitle = panelTitles{i}; % Use provided panel title
        end

        subplot(nRows, nCols, i);
        displayAllStimMarkerTrajectories(trialData, markerNames, ...
            'mocapMetaData', metaData, 'plotWhere', gca, 'figureTitle', '', ...
            'showAverageTrajectory', true, 'relativePositions', doRelative, ...
            'stimVideoEmotionCoding', codingTable);
        title(panelTitle, 'FontSize', 12, 'Color', 'k');
        if i < nSubplots
legend('off');
        end
        % Add legend only for the last panel
 %       if i == nSubplots
 %           legend(gca, metaData.videoIDs, 'Location', 'northeastoutside', 'FontSize', 10);
%        end
    end

    R = gcf;
end
