function R = plotPosterUpperBodyStickFigure3D(trialData, videoID, varargin)
% plotPosterUpperBodyStickFigure3D - Static 3D stick figure for upper-body markers.
%
% Usage:
%   plotPosterUpperBodyStickFigure3D(trialData, '6611')
%   plotPosterUpperBodyStickFigure3D(trialData, '6611', 'frameSelector', 'start')
%
% This function extracts a single frame from a stimulus segment and plots a
% simple stick figure using the following default markers:
%   Head, RShoulder, RUArm, RFArm, RWristIn, RHand,
%   LShoulder, LUArm, LFArm, LWristIn, LHand
%
% Inputs:
%   trialData - struct with markerNames, trajectoryData, metaData
%   videoID   - stimulus/video identifier
%
% Name-value pairs:
%   'mocapMetaData'    - metadata struct (default trialData.metaData)
%   'markerNames'      - marker list to extract (default upper-body list above)
%   'highlightMarkers' - subset to emphasize (default all selected markers)
%   'frameSelector'    - 'start' | 'middle' (default) | 'end' | numeric index within segment
%   'clipSec'          - seconds to clip from start of segment (default 0)
%   'plotWhere'        - axes handle (default new figure)
%   'figureTitle'      - custom title
%   'showLabels'       - show marker name labels (default false)
%   'showLegend'       - show legend for base/highlight markers (default false)
%   'baseColor'        - line/base marker color (default [0.55 0.55 0.60])
%   'highlightColor'   - highlight marker color (default [0 0 0])
%   'segmentLineWidth' - stick segment width (default 2)
%   'baseMarkerSize'   - base marker size (default 36)
%   'highlightSize'    - highlight marker size (default 68)
%   'invertX'          - reverse X axis (default false)
%   'invertY'          - reverse Y axis (default false)
%   'invertZ'          - reverse Z axis (default false)
%   'axisEqual'        - logical (default false for visual clarity)
%   'centerAtShoulders'- center pose at shoulder midpoint (default true)
%
% Output:
%   R struct with figure, axes, markerTable, frameIndexWithinSegment, frameIndexGlobal

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addRequired(p, 'videoID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'markerNames', localDefaultUpperBodyMarkers(), @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'highlightMarkers', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'frameSelector', 'middle');
    addParameter(p, 'clipSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'plotWhere', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showLabels', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showLegend', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'baseColor', [0.55 0.55 0.60], @(x) isnumeric(x) && numel(x) == 3);
    addParameter(p, 'highlightColor', [0 0 0], @(x) isnumeric(x) && numel(x) == 3);
    addParameter(p, 'segmentLineWidth', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'baseMarkerSize', 36, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'highlightSize', 68, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'invertX', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertY', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertZ', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'axisEqual', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'centerAtShoulders', true, @(x) islogical(x) && isscalar(x));
    parse(p, trialData, videoID, varargin{:});

    videoID = char(string(videoID));
    markerNames = cellstr(string(p.Results.markerNames));
    if isempty(p.Results.highlightMarkers)
        highlightMarkers = markerNames;
    else
        highlightMarkers = cellstr(string(p.Results.highlightMarkers));
    end

    S = extractMarkerTrajectoryForVideo(trialData, markerNames, videoID, ...
        'mocapMetaData', p.Results.mocapMetaData, ...
        'clipSec', p.Results.clipSec);

    nFrames = size(S.trajectories, 1);
    if nFrames == 0
        error('plotPosterUpperBodyStickFigure3D:NoFrames', 'No frames available after extraction.');
    end

    frameIdx = localResolveFrameSelector(p.Results.frameSelector, nFrames);
    xyz = squeeze(S.trajectories(frameIdx, :, :))'; % nMarkers x 3
    if size(xyz, 2) ~= 3
        xyz = reshape(xyz, [], 3);
    end

    markerTbl = table(markerNames(:), xyz(:,1), xyz(:,2), xyz(:,3), ...
        'VariableNames', {'markerName','X','Y','Z'});

    if p.Results.centerAtShoulders
        centerPoint = localShoulderMidpoint(markerTbl);
        if all(isfinite(centerPoint))
            markerTbl.X = markerTbl.X - centerPoint(1);
            markerTbl.Y = markerTbl.Y - centerPoint(2);
            markerTbl.Z = markerTbl.Z - centerPoint(3);
        end
    end

    ax = p.Results.plotWhere;
    if isempty(ax)
        fig = figure('Color', 'w');
        ax = axes('Parent', fig);
    else
        fig = ancestor(ax, 'figure');
    end
    hold(ax, 'on');

    conn = localUpperBodyConnections();
    hSegments = gobjects(0);
    for i = 1:size(conn, 1)
        p1 = localMarkerPoint(markerTbl, conn{i,1});
        p2 = localMarkerPoint(markerTbl, conn{i,2});
        if any(~isfinite([p1 p2]))
            continue;
        end
        hSegments(end+1,1) = plot3(ax, [p1(1) p2(1)], [p1(2) p2(2)], [p1(3) p2(3)], ... %#ok<AGROW>
            '-', 'Color', p.Results.baseColor, 'LineWidth', p.Results.segmentLineWidth, ...
            'HandleVisibility', 'off');
    end

    validBase = isfinite(markerTbl.X) & isfinite(markerTbl.Y) & isfinite(markerTbl.Z);
    hBase = scatter3(ax, markerTbl.X(validBase), markerTbl.Y(validBase), markerTbl.Z(validBase), ...
        p.Results.baseMarkerSize, 'o', ...
        'MarkerEdgeColor', p.Results.baseColor, ...
        'MarkerFaceColor', p.Results.baseColor, ...
        'MarkerFaceAlpha', 0.65, 'MarkerEdgeAlpha', 0.85, ...
        'DisplayName', 'Markers');

    isHighlight = ismember(markerTbl.markerName, highlightMarkers) & validBase;
    hHighlight = scatter3(ax, markerTbl.X(isHighlight), markerTbl.Y(isHighlight), markerTbl.Z(isHighlight), ...
        p.Results.highlightSize, 'o', ...
        'MarkerEdgeColor', p.Results.highlightColor, ...
        'MarkerFaceColor', p.Results.highlightColor, ...
        'DisplayName', 'Highlighted markers');

    if p.Results.showLabels
        idxLab = find(isHighlight);
        for i = 1:numel(idxLab)
            k = idxLab(i);
            text(ax, markerTbl.X(k), markerTbl.Y(k), markerTbl.Z(k), ['  ' markerTbl.markerName{k}], ...
                'FontSize', 10, 'Color', [0.15 0.15 0.15], 'Interpreter', 'none');
        end
    end

    xlabel(ax, 'X (mm)', 'FontWeight', 'bold');
    ylabel(ax, 'Y (mm)', 'FontWeight', 'bold');
    zlabel(ax, 'Z (mm)', 'FontWeight', 'bold');
    grid(ax, 'on');
    ax.GridAlpha = 0.16;
    set(ax, 'Box', 'off', 'FontSize', 11, 'LineWidth', 1.0, 'Color', 'none');

    if p.Results.axisEqual
        axis(ax, 'equal');
    end
    axis(ax, 'tight');
    view(ax, 3);
    rotate3d(fig, 'on');

    set(ax, 'XDir', localDirStr(p.Results.invertX));
    set(ax, 'YDir', localDirStr(p.Results.invertY));
    set(ax, 'ZDir', localDirStr(p.Results.invertZ));

    titleStr = char(string(p.Results.figureTitle));
    if isempty(strtrim(titleStr))
        titleStr = sprintf('%s | Upper-body stick figure | frame %d/%d', videoID, frameIdx, nFrames);
    end
    title(ax, titleStr, 'Interpreter', 'none', 'FontWeight', 'bold');

    if p.Results.showLegend
        legend(ax, [hBase hHighlight], {'Markers','Highlighted markers'}, 'Location', 'best');
    end

    R = struct();
    R.figure = fig;
    R.axes = ax;
    R.segmentHandles = hSegments;
    R.baseHandle = hBase;
    R.highlightHandle = hHighlight;
    R.markerTable = markerTbl;
    R.frameIndexWithinSegment = frameIdx;
    R.frameIndexGlobal = S.frameRange(frameIdx);
    R.extracted = S;
end

function markerNames = localDefaultUpperBodyMarkers()
    markerNames = { ...
        'Head', 'RShoulder', 'RUArm', 'RFArm', 'RWristIn', 'RHand', ...
        'LShoulder', 'LUArm', 'LFArm', 'LWristIn', 'LHand'};
end

function conn = localUpperBodyConnections()
    conn = { ...
        'Head', 'RShoulder'; ...
        'Head', 'LShoulder'; ...
        'RShoulder', 'LShoulder'; ...
        'RShoulder', 'RUArm'; ...
        'RUArm', 'RFArm'; ...
        'RFArm', 'RWristIn'; ...
        'RWristIn', 'RHand'; ...
        'LShoulder', 'LUArm'; ...
        'LUArm', 'LFArm'; ...
        'LFArm', 'LWristIn'; ...
        'LWristIn', 'LHand'};
end

function idx = localResolveFrameSelector(frameSelector, nFrames)
    if isnumeric(frameSelector) && isscalar(frameSelector)
        idx = min(max(1, round(frameSelector)), nFrames);
        return;
    end

    s = lower(strtrim(char(string(frameSelector))));
    switch s
        case 'start'
            idx = 1;
        case 'middle'
            idx = round((nFrames + 1) / 2);
        case 'end'
            idx = nFrames;
        otherwise
            error('plotPosterUpperBodyStickFigure3D:BadFrameSelector', ...
                'frameSelector must be ''start'', ''middle'', ''end'', or a numeric index.');
    end
end

function p = localMarkerPoint(markerTbl, markerName)
    p = [NaN NaN NaN];
    idx = find(strcmp(markerTbl.markerName, markerName), 1, 'first');
    if isempty(idx)
        return;
    end
    p = [markerTbl.X(idx), markerTbl.Y(idx), markerTbl.Z(idx)];
end

function c = localShoulderMidpoint(markerTbl)
    pR = localMarkerPoint(markerTbl, 'RShoulder');
    pL = localMarkerPoint(markerTbl, 'LShoulder');
    if all(isfinite(pR)) && all(isfinite(pL))
        c = (pR + pL) ./ 2;
    else
        c = [NaN NaN NaN];
    end
end

function s = localDirStr(doInvert)
    if doInvert
        s = 'reverse';
    else
        s = 'normal';
    end
end
