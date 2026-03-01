function H = launchPoster3DTrajectoryScrubber(trialData, markerNames, videoID, varargin)
% launchPoster3DTrajectoryScrubber - Interactive 3D marker scrubber with tail trails.
%
% Usage:
%   launchPoster3DTrajectoryScrubber(trialData, {'Head','LUArm','LElbow'}, '6611')
%
% Features:
%   - 3D plot of current marker positions
%   - Tail trajectory behind each marker (default 10 frames)
%   - Slider to scrub through the selected stimulus segment
%   - Play/Pause button for animation
%   - Optional immobility-state visual cue (axis background shading)
%   - Rotatable / zoomable 3D axes
%
% Inputs:
%   trialData   - struct with markerNames, trajectoryData, metaData
%   markerNames - marker or list of markers
%   videoID     - stimulus/video identifier
%
% Name-value pairs:
%   'mocapMetaData'          - metadata struct (default trialData.metaData)
%   'tailFrames'             - number of trailing frames to show (default 10)
%   'clipSec'                - clip seconds from start of segment (default 0)
%   'relativePositionMarker' - subtract this marker trajectory (default none)
%   'colors'                 - nMarkers x 3 RGB matrix or [] for auto
%   'lineWidth'              - tail line width (default 2.0)
%   'markerSize'             - current point marker size (default 64)
%   'axisEqual'              - logical (default false)
%   'invertX'                - reverse X axis (default false)
%   'invertY'                - reverse Y axis (default false)
%   'invertZ'                - reverse Z axis (default false)
%   'figureTitle'            - custom title prefix
%   'showImmobilityCue'      - gray background during immobility bouts (default true)
%   'immobileSpeedThreshold' - threshold in mm/s (default 25)
%   'immobileMinDurationSec' - minimum bout duration in seconds (default 1)
%   'immobileAxisColor'      - axis background RGB for immobility (default [0.92 0.92 0.92])
%
% Output:
%   H struct with figure, axes, slider, extracted, and an update function handle

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addRequired(p, 'markerNames', @(x) ischar(x) || isstring(x) || iscell(x));
    addRequired(p, 'videoID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'tailFrames', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'clipSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'relativePositionMarker', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'colors', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'lineWidth', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'markerSize', 64, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'axisEqual', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertX', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertY', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertZ', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showImmobilityCue', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'immobileSpeedThreshold', 25, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'immobileMinDurationSec', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'immobileAxisColor', [0.92 0.92 0.92], @(x) isnumeric(x) && numel(x) == 3);
    parse(p, trialData, markerNames, videoID, varargin{:});

    markerNames = cellstr(string(markerNames));
    videoID = char(string(videoID));
    tailFrames = max(1, round(p.Results.tailFrames));

    S = extractMarkerTrajectoryForVideo(trialData, markerNames, videoID, ...
        'mocapMetaData', p.Results.mocapMetaData, ...
        'clipSec', p.Results.clipSec);
    data = S.trajectories; % nFrames x 3 x nMarkers
    nFrames = size(data, 1);
    nMarkers = size(data, 3);
    if nFrames < 1 || nMarkers < 1
        error('launchPoster3DTrajectoryScrubber:EmptyData', 'No data available to plot.');
    end

    refMarker = char(string(p.Results.relativePositionMarker));
    if ~isempty(strtrim(refMarker))
        refS = extractMarkerTrajectoryForVideo(trialData, refMarker, videoID, ...
            'mocapMetaData', p.Results.mocapMetaData, ...
            'clipSec', p.Results.clipSec);
        refTraj = refS.trajectories(:, :, 1);
        for m = 1:nMarkers
            data(:, :, m) = data(:, :, m) - refTraj;
        end
    end

    colors = localPosterGradientColors(nMarkers, p.Results.colors);

    % Compute immobility state from average speed across selected markers.
    avgSpeed = [];
    immobileMask = false(nFrames, 1);
    if p.Results.showImmobilityCue
        if isempty(S.frameRate) || ~isfinite(S.frameRate) || S.frameRate <= 0
            warning('launchPoster3DTrajectoryScrubber:MissingFrameRate', ...
                'Frame rate missing; immobility cue disabled.');
        else
            markerSpeeds = nan(nFrames, nMarkers);
            for m = 1:nMarkers
                markerSpeeds(:, m) = getTrajectorySpeed(data(:, :, m), S.frameRate, 0.1);
            end
            avgSpeed = mean(markerSpeeds, 2, 'omitnan');
            immobileMask = getImmobileFramesFromSpeed(avgSpeed, S.frameRate, ...
                'thresholdMmPerSec', p.Results.immobileSpeedThreshold, ...
                'minDurationSec', p.Results.immobileMinDurationSec);
        end
    end

    fig = figure('Color', 'w', 'Name', 'Poster 3D Trajectory Scrubber', 'NumberTitle', 'off');
    set(fig, 'Units', 'pixels', 'Position', [120 80 1100 760]);

    ax = axes('Parent', fig, 'Position', [0.07 0.20 0.88 0.74]);
    hold(ax, 'on');

    hTail = gobjects(nMarkers, 1);
    hPoint = gobjects(nMarkers, 1);
    for m = 1:nMarkers
        hTail(m) = plot3(ax, NaN, NaN, NaN, '-', ...
            'LineWidth', p.Results.lineWidth, ...
            'Color', colors(m,:), ...
            'DisplayName', markerNames{m});
        hPoint(m) = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', max(4, sqrt(p.Results.markerSize)), ...
            'MarkerFaceColor', colors(m,:), ...
            'MarkerEdgeColor', colors(m,:), ...
            'HandleVisibility', 'off');
    end

    xlabel(ax, 'X (mm)', 'FontWeight', 'bold');
    ylabel(ax, 'Y (mm)', 'FontWeight', 'bold');
    zlabel(ax, 'Z (mm)', 'FontWeight', 'bold');
    grid(ax, 'on');
    ax.GridAlpha = 0.16;
    normalAxisColor = [1 1 1];
    set(ax, 'Box', 'off', 'FontSize', 11, 'LineWidth', 1.0, 'Color', normalAxisColor);
    if p.Results.axisEqual
        axis(ax, 'equal');
    end
    view(ax, 3);
    rotate3d(fig, 'on');
    set(ax, 'XDir', localDirStr(p.Results.invertX));
    set(ax, 'YDir', localDirStr(p.Results.invertY));
    set(ax, 'ZDir', localDirStr(p.Results.invertZ));

    % Stable axis limits from all finite data for smoother scrubbing.
    [xLim, yLim, zLim] = localDataLimits(data);
    if all(isfinite([xLim yLim zLim]))
        xlim(ax, xLim); ylim(ax, yLim); zlim(ax, zLim);
    else
        axis(ax, 'tight');
    end

    lgd = legend(ax, 'show', 'Location', 'northeastoutside', 'Interpreter', 'none');
    set(lgd, 'FontSize', 12);

    hSlider = uicontrol(fig, 'Style', 'slider', ...
        'Units', 'normalized', ...
        'Position', [0.10 0.09 0.66 0.04], ...
        'Min', 1, 'Max', nFrames, 'Value', 1, ...
        'SliderStep', localSliderStep(nFrames), ...
        'Callback', @onSlider);

    hFrameLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.78 0.09 0.17 0.04], ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'String', '');

    hImmobileLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.78 0.14 0.17 0.035], ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'String', '');

    hTailLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.10 0.14 0.30 0.035], ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'String', sprintf('Tail: %d frames', tailFrames));

    hTailEdit = uicontrol(fig, 'Style', 'edit', ...
        'Units', 'normalized', ...
        'Position', [0.36 0.14 0.06 0.04], ...
        'String', num2str(tailFrames), ...
        'BackgroundColor', 'w', ...
        'Callback', @onTailEdit);

    hPlay = uicontrol(fig, 'Style', 'togglebutton', ...
        'Units', 'normalized', ...
        'Position', [0.44 0.14 0.09 0.04], ...
        'String', 'Play', ...
        'Callback', @onPlayToggle);

    hLoop = uicontrol(fig, 'Style', 'checkbox', ...
        'Units', 'normalized', ...
        'Position', [0.54 0.14 0.10 0.04], ...
        'String', 'Loop', ...
        'Value', 1, ...
        'BackgroundColor', 'w');

    defaultFps = localPlaybackFps(S);
    hFpsLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.66 0.14 0.08 0.035], ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'String', 'Play fps');

    hFpsEdit = uicontrol(fig, 'Style', 'edit', ...
        'Units', 'normalized', ...
        'Position', [0.73 0.14 0.05 0.04], ...
        'String', num2str(defaultFps), ...
        'BackgroundColor', 'w', ...
        'Callback', @onFpsEdit);

    currentState = struct();
    currentState.tailFrames = tailFrames;
    currentState.frameIdx = 1;
    currentState.playFps = defaultFps;
    currentState.isPlaying = false;

    playTimer = timer( ...
        'ExecutionMode', 'fixedSpacing', ...
        'BusyMode', 'drop', ...
        'Period', 1 / max(1, defaultFps), ...
        'TimerFcn', @onTimerTick);

    set(fig, 'CloseRequestFcn', @onCloseFigure);

    updateFrame(1);

    if nargout > 0
        H = struct();
        H.figure = fig;
        H.axes = ax;
        H.slider = hSlider;
        H.extracted = S;
        H.updateFrame = @updateFrame;
        H.playButton = hPlay;
        H.immobileMask = immobileMask;
        H.avgSpeed = avgSpeed;
    end

    function onSlider(~, ~)
        frameIdx = round(get(hSlider, 'Value'));
        updateFrame(frameIdx);
    end

    function onTailEdit(~, ~)
        v = str2double(char(string(get(hTailEdit, 'String'))));
        if ~isfinite(v) || v < 1
            set(hTailEdit, 'String', num2str(currentState.tailFrames));
            return;
        end
        currentState.tailFrames = max(1, round(v));
        set(hTailEdit, 'String', num2str(currentState.tailFrames));
        set(hTailLabel, 'String', sprintf('Tail: %d frames', currentState.tailFrames));
        updateFrame(currentState.frameIdx);
    end

    function onPlayToggle(~, ~)
        wantPlay = logical(get(hPlay, 'Value'));
        if wantPlay
            localSetPlaying(true);
        else
            localSetPlaying(false);
        end
    end

    function onFpsEdit(~, ~)
        v = str2double(char(string(get(hFpsEdit, 'String'))));
        if ~isfinite(v) || v <= 0
            set(hFpsEdit, 'String', num2str(currentState.playFps));
            return;
        end
        currentState.playFps = max(0.1, v);
        set(hFpsEdit, 'String', num2str(currentState.playFps));
        if isvalid(playTimer)
            stop(playTimer);
            playTimer.Period = 1 / currentState.playFps;
            if currentState.isPlaying
                start(playTimer);
            end
        end
    end

    function onTimerTick(~, ~)
        if ~ishandle(fig)
            return;
        end
        nextFrame = currentState.frameIdx + 1;
        if nextFrame > nFrames
            if logical(get(hLoop, 'Value'))
                nextFrame = 1;
            else
                localSetPlaying(false);
                return;
            end
        end
        updateFrame(nextFrame);
    end

    function localSetPlaying(tf)
        currentState.isPlaying = logical(tf);
        if ~ishandle(hPlay)
            return;
        end
        if currentState.isPlaying
            set(hPlay, 'Value', 1, 'String', 'Pause');
            if currentState.frameIdx >= nFrames
                updateFrame(1);
            end
            if isvalid(playTimer)
                stop(playTimer);
                playTimer.Period = 1 / max(0.1, currentState.playFps);
                start(playTimer);
            end
        else
            set(hPlay, 'Value', 0, 'String', 'Play');
            if isvalid(playTimer)
                stop(playTimer);
            end
        end
    end

    function onCloseFigure(~, ~)
        try
            localSetPlaying(false);
        catch
        end
        try
            if exist('playTimer', 'var') && isa(playTimer, 'timer') && isvalid(playTimer)
                stop(playTimer);
                delete(playTimer);
            end
        catch
        end
        delete(fig);
    end

    function updateFrame(frameIdx)
        frameIdx = min(max(1, round(frameIdx)), nFrames);
        currentState.frameIdx = frameIdx;
        set(hSlider, 'Value', frameIdx);

        t0 = max(1, frameIdx - currentState.tailFrames + 1);
        for m = 1:nMarkers
            seg = squeeze(data(t0:frameIdx, :, m));
            if isvector(seg)
                seg = reshape(seg, [], 3);
            end

            validSeg = all(isfinite(seg), 2);
            if any(validSeg)
                set(hTail(m), 'XData', seg(validSeg,1), 'YData', seg(validSeg,2), 'ZData', seg(validSeg,3));
            else
                set(hTail(m), 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            end

            cur = squeeze(data(frameIdx, :, m));
            if numel(cur) == 3 && all(isfinite(cur))
                set(hPoint(m), 'XData', cur(1), 'YData', cur(2), 'ZData', cur(3));
            else
                set(hPoint(m), 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            end
        end

        tSec = S.timeSec(frameIdx);
        frameGlobal = S.frameRange(frameIdx);
        set(hFrameLabel, 'String', sprintf('Frame %d/%d (global %d) | t=%.3f s', ...
            frameIdx, nFrames, frameGlobal, tSec));

        isImmobile = ~isempty(immobileMask) && frameIdx <= numel(immobileMask) && immobileMask(frameIdx);
        if isImmobile
            set(ax, 'Color', p.Results.immobileAxisColor);
            if ~isempty(avgSpeed) && frameIdx <= numel(avgSpeed) && isfinite(avgSpeed(frameIdx))
                set(hImmobileLabel, 'String', sprintf('IMMOBILE (%.1f mm/s)', avgSpeed(frameIdx)), ...
                    'ForegroundColor', [0.25 0.25 0.25], 'BackgroundColor', p.Results.immobileAxisColor);
            else
                set(hImmobileLabel, 'String', 'IMMOBILE', ...
                    'ForegroundColor', [0.25 0.25 0.25], 'BackgroundColor', p.Results.immobileAxisColor);
            end
        else
            set(ax, 'Color', normalAxisColor);
            if ~isempty(avgSpeed) && frameIdx <= numel(avgSpeed) && isfinite(avgSpeed(frameIdx))
                set(hImmobileLabel, 'String', sprintf('Moving (%.1f mm/s)', avgSpeed(frameIdx)), ...
                    'ForegroundColor', [0.15 0.45 0.15], 'BackgroundColor', 'w');
            else
                set(hImmobileLabel, 'String', 'Moving', ...
                    'ForegroundColor', [0.15 0.45 0.15], 'BackgroundColor', 'w');
            end
        end

        titleBase = char(string(p.Results.figureTitle));
        if isempty(strtrim(titleBase))
            titleBase = sprintf('%s | %s | 3D scrubber', videoID, strjoin(markerNames, ', '));
        end
        title(ax, sprintf('%s | frame %d/%d', titleBase, frameIdx, nFrames), ...
            'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');
        drawnow limitrate;
    end
end

function fps = localPlaybackFps(S)
    fps = 20;
    if isfield(S, 'frameRate') && ~isempty(S.frameRate) && isfinite(S.frameRate) && S.frameRate > 0
        fps = min(30, max(5, round(S.frameRate)));
    end
end

function [xLim, yLim, zLim] = localDataLimits(data)
    X = data(:,1,:); Y = data(:,2,:); Z = data(:,3,:);
    xLim = localPadLim([min(X(:), [], 'omitnan'), max(X(:), [], 'omitnan')]);
    yLim = localPadLim([min(Y(:), [], 'omitnan'), max(Y(:), [], 'omitnan')]);
    zLim = localPadLim([min(Z(:), [], 'omitnan'), max(Z(:), [], 'omitnan')]);
end

function lim = localPadLim(lim)
    if any(~isfinite(lim))
        lim = [NaN NaN];
        return;
    end
    if lim(1) == lim(2)
        d = max(1, abs(lim(1))*0.05);
        lim = lim + [-d d];
        return;
    end
    pad = 0.05 * (lim(2) - lim(1));
    lim = lim + [-pad pad];
end

function step = localSliderStep(nFrames)
    if nFrames <= 1
        step = [1 1];
        return;
    end
    smallStep = 1 / (nFrames - 1);
    largeStep = min(1, max(smallStep, 10 / (nFrames - 1)));
    step = [smallStep largeStep];
end

function colors = localPosterGradientColors(nLines, userColors)
    if ~isempty(userColors)
        if size(userColors, 2) ~= 3
            error('launchPoster3DTrajectoryScrubber:BadColors', 'colors must be an n x 3 RGB matrix.');
        end
        if size(userColors, 1) == 1 && nLines > 1
            colors = repmat(userColors, nLines, 1);
            return;
        elseif size(userColors, 1) == nLines
            colors = userColors;
            return;
        else
            error('launchPoster3DTrajectoryScrubber:BadColorsCount', ...
                'colors must have either 1 row or %d rows.', nLines);
        end
    end

    nBase = max(64, nLines);
    cmap = parula(nBase);
    idx = round(linspace(8, nBase - 6, nLines));
    colors = cmap(idx, :);
end

function s = localDirStr(doInvert)
    if doInvert
        s = 'reverse';
    else
        s = 'normal';
    end
end
