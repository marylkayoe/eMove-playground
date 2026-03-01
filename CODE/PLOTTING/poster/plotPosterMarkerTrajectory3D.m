function R = plotPosterMarkerTrajectory3D(trialData, markerNames, videoID, varargin)
% plotPosterMarkerTrajectory3D - Static 3D marker trajectory plot for a stimulus segment.
%
% Usage:
%   plotPosterMarkerTrajectory3D(trialData, 'LFHD', 'vid01')
%   plotPosterMarkerTrajectory3D(trialData, {'LFHD','RFHD'}, 'vid01', 'showStartEnd', true)
%
% Inputs:
%   trialData   - struct with markerNames, trajectoryData, and metaData (or pass mocapMetaData)
%   markerNames - marker name or list of marker names
%   videoID     - stimulus/video identifier
%
% Name-value pairs:
%   'mocapMetaData'          - metadata struct (default trialData.metaData)
%   'plotWhere'              - axes handle (default new figure/axes)
%   'figureTitle'            - custom title
%   'relativePositionMarker' - subtract this marker trajectory (default none)
%   'showAverageTrajectory'  - plot average across selected markers only (default false)
%   'clipSec'                - clip from start of extracted segment (default 0)
%   'centerAtStart'          - subtract each trace's first valid XYZ point (default false)
%   'lineWidth'              - line width (default 2.0)
%   'colors'                 - nMarkers x 3 RGB matrix or [] for auto
%   'showLegend'             - logical (default true if multiple traces)
%   'legendLocation'         - legend location (default 'best')
%   'showStartEnd'           - mark start/end points for each trace (default true)
%   'startMarkerStyle'       - marker symbol for starts (default 'o')
%   'endMarkerStyle'         - marker symbol for ends (default 's')
%   'gridOn'                 - logical (default true)
%   'axisEqual'              - logical (default true)
%   'invertX'                - reverse X axis (default false)
%   'invertY'                - reverse Y axis (default false)
%   'invertZ'                - reverse Z axis (default false)
%   'savePath'               - optional export file path
%
% Output:
%   R - struct with figure, axes, lineHandles, startHandles, endHandles, extracted

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addRequired(p, 'markerNames', @(x) ischar(x) || isstring(x) || iscell(x));
    addRequired(p, 'videoID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'plotWhere', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'relativePositionMarker', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showAverageTrajectory', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'clipSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'centerAtStart', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'lineWidth', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'colors', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'showLegend', [], @(x) isempty(x) || (islogical(x) && isscalar(x)));
    addParameter(p, 'legendLocation', 'best', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showStartEnd', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'startMarkerStyle', 'o', @(x) ischar(x) || isstring(x));
    addParameter(p, 'endMarkerStyle', 's', @(x) ischar(x) || isstring(x));
    addParameter(p, 'gridOn', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'axisEqual', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertX', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertY', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertZ', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
    parse(p, trialData, markerNames, videoID, varargin{:});

    markerNames = cellstr(string(markerNames));
    videoID = char(string(videoID));

    extracted = extractMarkerTrajectoryForVideo( ...
        trialData, markerNames, videoID, ...
        'mocapMetaData', p.Results.mocapMetaData, ...
        'clipSec', p.Results.clipSec);
    data = extracted.trajectories;
    labels = extracted.markerNames;

    refMarker = char(string(p.Results.relativePositionMarker));
    if ~isempty(strtrim(refMarker))
        refExtracted = extractMarkerTrajectoryForVideo( ...
            trialData, refMarker, videoID, ...
            'mocapMetaData', p.Results.mocapMetaData, ...
            'clipSec', p.Results.clipSec);
        refTraj = refExtracted.trajectories(:, :, 1);
        for m = 1:size(data, 3)
            data(:, :, m) = data(:, :, m) - refTraj;
        end
    end

    if p.Results.showAverageTrajectory && size(data, 3) > 1
        data = reshape(mean(data, 3, 'omitnan'), size(data, 1), 3, 1);
        labels = {'Average trajectory'};
    elseif p.Results.showAverageTrajectory
        labels = {'Average trajectory'};
    end

    ax = p.Results.plotWhere;
    if isempty(ax)
        fig = figure('Color', 'w');
        ax = axes('Parent', fig);
    else
        fig = ancestor(ax, 'figure');
    end

    hold(ax, 'on');
    nLines = size(data, 3);
    colors = localResolveColors(nLines, p.Results.colors);
    hLines = gobjects(nLines, 1);
    hStart = gobjects(0);
    hEnd = gobjects(0);

    for m = 1:nLines
        traj = squeeze(data(:, :, m));
        valid = all(isfinite(traj), 2);
        trajValid = traj(valid, :);
        if isempty(trajValid)
            continue;
        end
        if p.Results.centerAtStart
            trajValid = trajValid - trajValid(1, :);
        end

        hLines(m) = plot3(ax, trajValid(:,1), trajValid(:,2), trajValid(:,3), ...
            'LineWidth', p.Results.lineWidth, ...
            'Color', colors(m,:), ...
            'DisplayName', labels{m});

        if p.Results.showStartEnd
            hStart(end+1,1) = plot3(ax, trajValid(1,1), trajValid(1,2), trajValid(1,3), ... %#ok<AGROW>
                char(string(p.Results.startMarkerStyle)), ...
                'Color', colors(m,:), 'MarkerFaceColor', colors(m,:), ...
                'HandleVisibility', 'off');
            hEnd(end+1,1) = plot3(ax, trajValid(end,1), trajValid(end,2), trajValid(end,3), ... %#ok<AGROW>
                char(string(p.Results.endMarkerStyle)), ...
                'Color', colors(m,:), 'MarkerFaceColor', 'w', ...
                'LineWidth', 1.0, 'HandleVisibility', 'off');
        end
    end

    xlabel(ax, 'X', 'FontWeight', 'bold');
    ylabel(ax, 'Y', 'FontWeight', 'bold');
    zlabel(ax, 'Z', 'FontWeight', 'bold');

    if p.Results.gridOn
        grid(ax, 'on');
        ax.GridAlpha = 0.18;
    else
        grid(ax, 'off');
    end

    if p.Results.axisEqual
        axis(ax, 'equal');
    end
    axis(ax, 'tight');
    view(ax, 3);
    rotate3d(fig, 'on');

    set(ax, 'Box', 'off', 'FontSize', 11, 'LineWidth', 1.0, 'Color', 'none');
    set(ax, 'XDir', ternDir(p.Results.invertX));
    set(ax, 'YDir', ternDir(p.Results.invertY));
    set(ax, 'ZDir', ternDir(p.Results.invertZ));

    titleStr = char(string(p.Results.figureTitle));
    if isempty(strtrim(titleStr))
        labelStr = strjoin(markerNames, ', ');
        if p.Results.showAverageTrajectory && numel(markerNames) > 1
            labelStr = sprintf('Average of %d markers', numel(markerNames));
        end
        titleStr = sprintf('%s | %s | 3D trajectories', videoID, labelStr);
        if ~isempty(strtrim(refMarker))
            titleStr = sprintf('%s (relative to %s)', titleStr, refMarker);
        end
    end
    title(ax, titleStr, 'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');

    showLegend = p.Results.showLegend;
    if isempty(showLegend)
        showLegend = (nLines > 1);
    end
    if showLegend
        legend(ax, 'show', 'Location', char(string(p.Results.legendLocation)), 'Interpreter', 'none');
    end

    if ~isempty(strtrim(char(string(p.Results.savePath))))
        exportgraphics(fig, char(string(p.Results.savePath)));
    end

    R = struct();
    R.figure = fig;
    R.axes = ax;
    R.lineHandles = hLines;
    R.startHandles = hStart;
    R.endHandles = hEnd;
    R.extracted = extracted;
    R.markerLabelsPlotted = labels;
end

function colors = localResolveColors(nLines, userColors)
    if isempty(userColors)
        colors = localPosterGradientColors(nLines);
        return;
    end
    if size(userColors, 2) ~= 3
        error('plotPosterMarkerTrajectory3D:BadColors', 'colors must be an n x 3 RGB matrix.');
    end
    if size(userColors, 1) == 1 && nLines > 1
        colors = repmat(userColors, nLines, 1);
    elseif size(userColors, 1) == nLines
        colors = userColors;
    else
        error('plotPosterMarkerTrajectory3D:BadColorsCount', ...
            'colors must have either 1 row or %d rows.', nLines);
    end
end

function colors = localPosterGradientColors(nLines)
    if nLines <= 0
        colors = zeros(0, 3);
        return;
    end

    % Smooth sequential palette for poster overlays (less categorical than lines()).
    nBase = max(64, nLines);
    cmap = parula(nBase);
    idx = round(linspace(8, nBase - 6, nLines)); % avoid extreme endpoints
    colors = cmap(idx, :);
end

function dirStr = ternDir(doInvert)
    if doInvert
        dirStr = 'reverse';
    else
        dirStr = 'normal';
    end
end
