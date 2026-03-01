function H = launchPosterXYTrajectoryScrubber(trialData, markerNames, varargin)
% launchPosterXYTrajectoryScrubber - Interactive XY trajectory scrubber with tail trails.
%
% Usage:
%   launchPosterXYTrajectoryScrubber(trialData, {'Head','LUArm','LElbow'})
%   launchPosterXYTrajectoryScrubber(trialData, {'Head','LUArm'}, 'defaultVideoID', '6611')
%
% Features:
%   - XY-only animated marker view (poster-friendly)
%   - Tail trails behind markers (default 10 frames)
%   - VideoID dropdown to switch stimulus segments
%   - Slider + Play/Pause + Loop
%   - Optional immobility cue (axes background turns gray)
%
% Inputs:
%   trialData   - struct with markerNames, trajectoryData, metaData
%   markerNames - marker or list of markers
%
% Name-value pairs:
%   'mocapMetaData'          - metadata struct (default trialData.metaData)
%   'defaultVideoID'         - initial dropdown selection
%   'tailFrames'             - default tail length in frames (default 10)
%   'clipSec'                - seconds to clip from start of segment (default 0)
%   'relativePositionMarker' - subtract this marker trajectory (default none)
%   'colors'                 - nMarkers x 3 RGB matrix or [] for auto
%   'lineWidth'              - tail line width (default 2.0)
%   'markerSize'             - current point marker size (default 64)
%   'axisEqual'              - logical (default false)
%   'invertX'                - reverse X axis (default false)
%   'invertY'                - reverse Y axis (default false)
%   'figureTitle'            - custom title prefix
%   'showImmobilityCue'      - gray background during immobility bouts (default true)
%   'immobileSpeedThreshold' - threshold in mm/s (default 25)
%   'immobileMinDurationSec' - minimum bout duration in seconds (default 1)
%   'immobileAxisColor'      - axis background RGB for immobility (default [0.92 0.92 0.92])
%
% Output:
%   H struct with figure, axes, slider, and update/load function handles

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addRequired(p, 'markerNames', @(x) ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'defaultVideoID', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'tailFrames', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'clipSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'relativePositionMarker', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'colors', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'lineWidth', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'markerSize', 64, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'axisEqual', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertX', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'invertY', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showImmobilityCue', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'immobileSpeedThreshold', 25, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'immobileMinDurationSec', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'immobileAxisColor', [0.92 0.92 0.92], @(x) isnumeric(x) && numel(x) == 3);
    parse(p, trialData, markerNames, varargin{:});

    markerNames = cellstr(string(markerNames));
    localValidateTrialData(trialData);
    videoIDs = cellstr(string(trialData.metaData.videoIDs));
    if isempty(videoIDs)
        error('launchPosterXYTrajectoryScrubber:NoVideoIDs', 'No videoIDs found in trialData.metaData.videoIDs.');
    end

    defaultVideoID = char(string(p.Results.defaultVideoID));
    if isempty(strtrim(defaultVideoID)) || ~any(strcmp(videoIDs, defaultVideoID))
        defaultVideoID = videoIDs{1};
    end

    nMarkers = numel(markerNames);
    colors = localPosterGradientColors(nMarkers, p.Results.colors);
    tailFrames0 = max(1, round(p.Results.tailFrames));
    normalAxisColor = [1 1 1];

    % Segment-scoped state (reloaded when dropdown changes)
    seg = struct();
    dataXY = [];     % nFrames x 2 x nMarkers
    dataXYZ = [];    % nFrames x 3 x nMarkers (for speed)
    nFrames = 1;
    avgSpeed = [];
    immobileMask = false(1,1);
    curVideoID = defaultVideoID;

    fig = figure('Color', 'w', 'Name', 'Poster XY Trajectory Scrubber', 'NumberTitle', 'off');
    set(fig, 'Units', 'pixels', 'Position', [120 80 1180 780]);

    ax = axes('Parent', fig, 'Position', [0.07 0.20 0.72 0.72]);
    hold(ax, 'on');
    xlabel(ax, 'X (mm)', 'FontWeight', 'bold');
    ylabel(ax, 'Y (mm)', 'FontWeight', 'bold');
    grid(ax, 'on');
    ax.GridAlpha = 0.16;
    set(ax, 'Box', 'off', 'FontSize', 11, 'LineWidth', 1.0, 'Color', normalAxisColor);
    if p.Results.axisEqual
        axis(ax, 'equal');
    end
    set(ax, 'XDir', localDirStr(p.Results.invertX));
    set(ax, 'YDir', localDirStr(p.Results.invertY));

    hTail = gobjects(nMarkers, 1);
    hPoint = gobjects(nMarkers, 1);
    for m = 1:nMarkers
        hTail(m) = plot(ax, NaN, NaN, '-', ...
            'LineWidth', p.Results.lineWidth, ...
            'Color', colors(m,:), ...
            'DisplayName', markerNames{m});
        hPoint(m) = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', max(4, sqrt(p.Results.markerSize)), ...
            'MarkerFaceColor', colors(m,:), ...
            'MarkerEdgeColor', colors(m,:), ...
            'HandleVisibility', 'off');
    end
    lgd = legend(ax, 'show', 'Location', 'northeastoutside', 'Interpreter', 'none');
    set(lgd, 'FontSize', 12);

    % Controls panel
    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.82 0.88 0.13 0.03], 'String', 'Video stimulus', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    hVideo = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
        'Position', [0.82 0.84 0.15 0.04], ...
        'String', videoIDs, ...
        'Value', find(strcmp(videoIDs, defaultVideoID), 1, 'first'), ...
        'Callback', @onVideoChanged);

    hInfo = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.82 0.76 0.15 0.06], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'String', '');

    hImmobileLabel = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.82 0.72 0.15 0.03], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'String', '');

    hTailLabel = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.07 0.14 0.15 0.035], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', ...
        'String', sprintf('Tail: %d frames', tailFrames0));
    hTailEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.18 0.14 0.05 0.04], 'String', num2str(tailFrames0), ...
        'BackgroundColor', 'w', 'Callback', @onTailEdit);

    hPlay = uicontrol(fig, 'Style', 'togglebutton', 'Units', 'normalized', ...
        'Position', [0.25 0.14 0.08 0.04], 'String', 'Play', 'Callback', @onPlayToggle);
    hLoop = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.34 0.14 0.08 0.04], 'String', 'Loop', 'Value', 1, 'BackgroundColor', 'w');

    hFpsText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.43 0.14 0.06 0.035], 'String', 'Play fps', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    defaultPlayFps = localPlaybackFpsFromMeta(trialData.metaData);
    hFpsEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.49 0.14 0.05 0.04], 'String', num2str(defaultPlayFps), ...
        'BackgroundColor', 'w', 'Callback', @onFpsEdit);

    hSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.07 0.08 0.62 0.04], ...
        'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1], ...
        'Callback', @onSlider);
    hFrameLabel = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.70 0.08 0.27 0.04], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'String', '');

    currentState = struct();
    currentState.frameIdx = 1;
    currentState.tailFrames = tailFrames0;
    currentState.playFps = defaultPlayFps;
    currentState.isPlaying = false;

    playTimer = timer('ExecutionMode','fixedSpacing', 'BusyMode','drop', ...
        'Period', 1/max(1, defaultPlayFps), 'TimerFcn', @onTimerTick);
    set(fig, 'CloseRequestFcn', @onCloseFigure);

    loadVideoSegment(defaultVideoID);

    if nargout > 0
        H = struct();
        H.figure = fig;
        H.axes = ax;
        H.slider = hSlider;
        H.videoDropdown = hVideo;
        H.updateFrame = @updateFrame;
        H.loadVideo = @loadVideoSegment;
    end

    function onVideoChanged(~, ~)
        items = get(hVideo, 'String');
        idx = get(hVideo, 'Value');
        if ischar(items)
            vid = strtrim(items(idx, :));
        else
            vid = char(string(items{idx}));
        end
        loadVideoSegment(vid);
    end

    function loadVideoSegment(videoID)
        localSetPlaying(false);
        curVideoID = char(string(videoID));

        seg = extractMarkerTrajectoryForVideo(trialData, markerNames, curVideoID, ...
            'mocapMetaData', p.Results.mocapMetaData, ...
            'clipSec', p.Results.clipSec);
        dataXYZ = seg.trajectories;
        if isempty(dataXYZ)
            error('launchPosterXYTrajectoryScrubber:EmptySegment', 'No frames for videoID %s.', curVideoID);
        end

        % Optional relative positioning
        refMarker = char(string(p.Results.relativePositionMarker));
        if ~isempty(strtrim(refMarker))
            refSeg = extractMarkerTrajectoryForVideo(trialData, refMarker, curVideoID, ...
                'mocapMetaData', p.Results.mocapMetaData, ...
                'clipSec', p.Results.clipSec);
            refTraj = refSeg.trajectories(:, :, 1);
            for m = 1:size(dataXYZ, 3)
                dataXYZ(:, :, m) = dataXYZ(:, :, m) - refTraj;
            end
        end

        dataXY = dataXYZ(:, 1:2, :);
        nFrames = size(dataXY, 1);
        currentState.frameIdx = 1;

        % Immobility classification from average 3D speed across selected markers
        avgSpeed = [];
        immobileMask = false(nFrames, 1);
        if p.Results.showImmobilityCue && ~isempty(seg.frameRate) && isfinite(seg.frameRate) && seg.frameRate > 0
            markerSpeeds = nan(nFrames, size(dataXYZ, 3));
            for m = 1:size(dataXYZ, 3)
                markerSpeeds(:, m) = getTrajectorySpeed(dataXYZ(:, :, m), seg.frameRate, 0.1);
            end
            avgSpeed = mean(markerSpeeds, 2, 'omitnan');
            immobileMask = getImmobileFramesFromSpeed(avgSpeed, seg.frameRate, ...
                'thresholdMmPerSec', p.Results.immobileSpeedThreshold, ...
                'minDurationSec', p.Results.immobileMinDurationSec);
        end

        [xLimData, yLimData] = localXYDataLimits(dataXY);
        if all(isfinite([xLimData yLimData]))
            xlim(ax, xLimData);
            ylim(ax, yLimData);
        else
            axis(ax, 'tight');
        end
        if p.Results.axisEqual
            axis(ax, 'equal');
        end

        localConfigureSlider(nFrames);
        updateFrame(1);

        infoStr = sprintf('Markers: %d\nFrames: %d', size(dataXY,3), nFrames);
        set(hInfo, 'String', infoStr);
    end

    function localConfigureSlider(n)
        if n <= 1
            set(hSlider, 'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1], 'Enable', 'off');
        else
            set(hSlider, 'Min', 1, 'Max', n, 'Value', 1, 'SliderStep', localSliderStep(n), 'Enable', 'on');
        end
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
        localSetPlaying(logical(get(hPlay, 'Value')));
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
            if isa(playTimer, 'timer') && isvalid(playTimer)
                stop(playTimer);
                delete(playTimer);
            end
        catch
        end
        delete(fig);
    end

    function updateFrame(frameIdx)
        if isempty(dataXY)
            return;
        end
        frameIdx = min(max(1, round(frameIdx)), nFrames);
        currentState.frameIdx = frameIdx;
        set(hSlider, 'Value', frameIdx);

        t0 = max(1, frameIdx - currentState.tailFrames + 1);
        for m = 1:nMarkers
            segXY = squeeze(dataXY(t0:frameIdx, :, m));
            if isvector(segXY)
                segXY = reshape(segXY, [], 2);
            end
            validSeg = all(isfinite(segXY), 2);
            if any(validSeg)
                set(hTail(m), 'XData', segXY(validSeg,1), 'YData', segXY(validSeg,2));
            else
                set(hTail(m), 'XData', NaN, 'YData', NaN);
            end

            curXY = squeeze(dataXY(frameIdx, :, m));
            if numel(curXY) == 2 && all(isfinite(curXY))
                set(hPoint(m), 'XData', curXY(1), 'YData', curXY(2));
            else
                set(hPoint(m), 'XData', NaN, 'YData', NaN);
            end
        end

        tSec = seg.timeSec(frameIdx);
        frameGlobal = seg.frameRange(frameIdx);
        set(hFrameLabel, 'String', sprintf('Frame %d/%d (global %d) | t=%.3f s', ...
            frameIdx, nFrames, frameGlobal, tSec));

        isImmobile = frameIdx <= numel(immobileMask) && immobileMask(frameIdx);
        if isImmobile
            set(ax, 'Color', p.Results.immobileAxisColor);
            if ~isempty(avgSpeed) && isfinite(avgSpeed(frameIdx))
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
            titleBase = sprintf('%s | %s | XY scrubber', curVideoID, strjoin(markerNames, ', '));
        end
        title(ax, sprintf('%s | frame %d/%d', titleBase, frameIdx, nFrames), ...
            'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');
        drawnow limitrate;
    end
end

function localValidateTrialData(trialData)
    reqFields = {'markerNames', 'trajectoryData', 'metaData'};
    for i = 1:numel(reqFields)
        if ~isfield(trialData, reqFields{i})
            error('launchPosterXYTrajectoryScrubber:MissingField', ...
                'trialData missing required field "%s".', reqFields{i});
        end
    end
    if ~isfield(trialData.metaData, 'videoIDs')
        error('launchPosterXYTrajectoryScrubber:MissingVideoIDs', ...
            'trialData.metaData.videoIDs is required for dropdown selection.');
    end
end

function fps = localPlaybackFpsFromMeta(metaData)
    fps = 20;
    if isstruct(metaData)
        candidates = {'captureFrameRate','frameRate','samplingRate','fps'};
        for i = 1:numel(candidates)
            f = candidates{i};
            if isfield(metaData, f) && isnumeric(metaData.(f)) && isscalar(metaData.(f)) && isfinite(metaData.(f)) && metaData.(f) > 0
                fps = min(30, max(5, round(double(metaData.(f)))));
                return;
            end
        end
    end
end

function [xLim, yLim] = localXYDataLimits(dataXY)
    X = dataXY(:,1,:); Y = dataXY(:,2,:);
    xLim = localPadLim([min(X(:), [], 'omitnan'), max(X(:), [], 'omitnan')]);
    yLim = localPadLim([min(Y(:), [], 'omitnan'), max(Y(:), [], 'omitnan')]);
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
            error('launchPosterXYTrajectoryScrubber:BadColors', 'colors must be an n x 3 RGB matrix.');
        end
        if size(userColors, 1) == 1 && nLines > 1
            colors = repmat(userColors, nLines, 1);
            return;
        elseif size(userColors, 1) == nLines
            colors = userColors;
            return;
        else
            error('launchPosterXYTrajectoryScrubber:BadColorsCount', ...
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
