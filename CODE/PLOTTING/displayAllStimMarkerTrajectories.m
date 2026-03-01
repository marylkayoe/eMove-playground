function R = displayAllStimMarkerTrajectories(trialData, markerNames, varargin)
    % Plot trajectories of selected markers for all stimulus videos on a single 3D plot.
    %
    % Inputs:
    %   trialData     - struct with fields markerNames, trajectoryData, etc.
    %   markerNames   - cell array/char/string of markers to plot
    %
    % Optional name-value pairs:
    %   'plotWhere'              - axes handle to plot into (default: new figure)
    %   'figureTitle'            - custom figure title (default constructed)
    %   'relativePositionMarker' - marker name for relative positioning (default: none)
    %   'colors'                 - nVideos x 3 colormap (default: cool gradient)
    %.  'showAverageTrajectory'   - boolean to plot average trajectory across markers (default: false)
    %   'mocapMetaData'          - struct with stimScheduling and videoIDs (default: trialData.metaData)
    %   'relativePositions'      - logical, show trajectories relative to baseline mean XY (default: true)

    % Backward compatibility: allow third positional arg as mocapMetaData
    if ~isempty(varargin) && isstruct(varargin{1})
        varargin = [{'mocapMetaData'}, varargin];
    end

    p = inputParser;
    addRequired(p, 'trialData');
    addRequired(p, 'markerNames', @(x) iscell(x) || ischar(x) || isstring(x));

    addParameter(p, 'plotWhere', [], @(x) isempty(x) || ishandle(x));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'relativePositionMarker', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'colors', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'showAverageTrajectory', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'relativePositions', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'stimVideoEmotionCoding', {}, @(x) istable(x) || iscell(x));

    parse(p, trialData, markerNames, varargin{:});

    plotWhere = p.Results.plotWhere;
    figureTitle = p.Results.figureTitle;
    relativePositionMarker = p.Results.relativePositionMarker;
    customColors = p.Results.colors;
    showAverageTrajectory = p.Results.showAverageTrajectory;
    metaData = p.Results.mocapMetaData;
    doRelative = p.Results.relativePositions;
    codingTable = p.Results.stimVideoEmotionCoding;
    if isempty(codingTable) && isfield(trialData, 'stimVideoEmotionCoding')
        codingTable = trialData.stimVideoEmotionCoding;
    end

    if isempty(metaData) && isfield(trialData, 'metaData')
        metaData = trialData.metaData;
    end

    % Validate required metadata
    if ~isstruct(metaData) || ~isfield(metaData, 'videoIDs') || ~isfield(metaData, 'stimScheduling')
        error('Metadata must contain videoIDs and stimScheduling (provide mocapMetaData or ensure trialData.metaData has them).');
    end

    videoIDs = metaData.videoIDs;
    if isrow(videoIDs); videoIDs = videoIDs(:); end
    nVideos = numel(videoIDs);

    newFigCreated = false;
    if isempty(plotWhere)
        figure;
        ax = gca;
        newFigCreated = true;
    else
        ax = plotWhere;
        axes(ax); %#ok<LAXES>
    end
    hold(ax, 'on');

    subjID = 'subject';
    if isfield(trialData, 'subjectID')
        subjID = char(trialData.subjectID);
    end

    if isempty(figureTitle)
        figureTitle = sprintf('%s: trajectories of %s across %d stimuli', subjID, strjoin(cellstr(markerNames), ', '), nVideos);
        if doRelative
            figureTitle = [figureTitle ' (relative to baseline)'];
        end
    else
        if doRelative && ~contains(figureTitle, 'relative', 'IgnoreCase', true)
            figureTitle = [figureTitle ' (relative)'];
        end
    end

    [colors, groupCodes, uniqueGroups, groupColorMap] = resolveColors(videoIDs, customColors, codingTable);

    % Precompute baseline mean XY per marker if requested
    baselineMeanXY = [];
    if doRelative
        baseIdx = find(contains(lower(videoIDs), 'baseline'), 1);
        if ~isempty(baseIdx)
            baseID = videoIDs{baseIdx};
            baseTraj = getMarkerTrajectory(trialData, markerNames, 'videoID', baseID, 'mocapMetaData', metaData);
            baselineMeanXY = squeeze(nanmean(baseTraj(:, 1:2, :), 1)); % 2 x nMarkers
        else
            doRelative = false; % fall back if no baseline found
        end
    end

    for i = 1:nVideos
        vid = videoIDs{i};
        grpCode = groupCodes{i};
        markerTrajectories = getMarkerTrajectory(trialData, markerNames, ...
            'videoID', vid, 'mocapMetaData', metaData);

        if doRelative && ~isempty(baselineMeanXY)
            % subtract baseline mean XY per marker
            markerTrajectories(:, 1, :) = markerTrajectories(:, 1, :) - reshape(baselineMeanXY(1, :), 1, 1, []);
            markerTrajectories(:, 2, :) = markerTrajectories(:, 2, :) - reshape(baselineMeanXY(2, :), 1, 1, []);
        end

        thisLabel = vid;
        if ~isempty(codingTable)
            thisLabel = grpCode;
        end

        plot3Dtrajectories(markerTrajectories, ...
            'markerNames', markerNames, ...
            'figureTitle', figureTitle, ...
            'relativePositionMarker', relativePositionMarker, ...
            'plotWhere', ax, ...
            'groupColor', colors(i, :), ...
            'groupLabel', thisLabel, 'showAverageTrajectory', showAverageTrajectory);
    end

    R = gcf;
    % make backgrounf gray
    set(ax, 'Color', [0.5 0.5 0.5]);
    % make axes tight in XYZ
    axis(ax, 'tight');
    % legend outside plot, bigger font
    if isempty(uniqueGroups)
        lgd = legend(ax, 'Location', 'northeastoutside', 'FontSize', 12);
    else
        % hide individual trajectories from legend
        set(findobj(ax, 'Type', 'line'), 'HandleVisibility', 'off');
        grpKeys = uniqueGroups;
        % counts per group
        grpCounts = zeros(numel(grpKeys), 1);
        for k = 1:numel(grpKeys)
            grpCounts(k) = sum(strcmp(groupCodes, grpKeys{k}));
        end
        grpHandles = gobjects(numel(grpKeys),1);
        hold(ax, 'on');
        for g = 1:numel(grpKeys)
            grpColor = groupColorMap(grpKeys{g});
            grpHandles(g) = plot3(ax, NaN, NaN, NaN, '-', 'Color', grpColor, 'LineWidth', 2);
        end
        grpLabels = arrayfun(@(k) sprintf('%s (N=%d)', grpKeys{k}, grpCounts(k)), (1:numel(grpKeys))', 'UniformOutput', false);
        lgd = legend(ax, grpHandles, grpLabels, 'Location', 'northeastoutside', 'FontSize', 12);
    end
    % background of legend to gray, text to white
    if ~isempty(lgd) && isvalid(lgd)
        lgd.Color = [0.5 0.5 0.5];
        lgd.TextColor = 'w';
    end

    title(ax, figureTitle, 'Color', 'k', 'FontSize', 14);
    if newFigCreated
        sgtitle(figureTitle);
    end
    xlabel(ax, 'X', 'Color', 'w', 'FontSize', 12);
    ylabel(ax, 'Y', 'Color', 'w', 'FontSize', 12);
    zlabel(ax, 'Z', 'Color', 'w', 'FontSize',   12);

end

function [colors, groupCodes, uniqueGroups, groupColorMap] = resolveColors(videoIDs, customColors, codingTable)
    % Determine colors for each video ID based on coding table or custom colors.
    % the group color for "0" is black
    
    n = numel(videoIDs);
    groupCodes = videoIDs; % default: each video is its own group
    uniqueGroups = {};
    groupColorMap = containers.Map;

    if ~isempty(customColors)
        colors = customColors;
        if size(colors, 1) < n
            warning('Provided colors must have at least one row per video ID.');
            colors = repmat(colors, ceil(n/size(colors,1)), 1);
        end
        colors = colors(1:n, :);
        return;
    end

    % If codingTable provided, map groups to colors
    if ~isempty(codingTable)
        % extract mappings
        if istable(codingTable)
            vids = codingTable{:,1};
            grps = codingTable{:,2};
        else
            vids = codingTable(:,1);
            grps = codingTable(:,2);
        end
        vids = cellstr(vids);
        grps = cellstr(grps);
        uniqueGrps = unique(grps);
        uniqueGroups = uniqueGrps;
        cmap = lines(numel(uniqueGrps));
        colors = zeros(n, 3);
        for i = 1:n
            vid = videoIDs{i};
            idx = find(strcmp(vids, vid), 1);
            if isempty(idx)
                colors(i, :) = [0.5 0.5 0.5]; % default gray if missing
            else
                grp = grps{idx};
                groupCodes{i} = grp;
                gIdx = find(strcmp(uniqueGrps, grp), 1);
                colors(i, :) = cmap(gIdx, :);
                if strcmp(grp, '0')
                    colors(i, :) = [0 0 0];
                end
            end
        end
        for j = 1:numel(uniqueGrps)
            if strcmp(uniqueGrps{j}, '0')
                groupColorMap(uniqueGrps{j}) = [0 0 0];
            else
                groupColorMap(uniqueGrps{j}) = cmap(j, :);
            end
        end
        return;
    end

    % fallback
    colors = hot(n);
end
