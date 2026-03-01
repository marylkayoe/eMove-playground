function H = launchPosterTrajectoryBrowser(trialData, varargin)
% launchPosterTrajectoryBrowser - Simple GUI to browse poster trajectory plots by videoID.
%
% Usage:
%   launchPosterTrajectoryBrowser(trialData)
%   launchPosterTrajectoryBrowser(trialData, 'defaultMarkers', {'LFHD','RFHD'})
%
% This creates a small control window with:
%   - VideoID dropdown (from trialData.metaData.videoIDs)
%   - Marker list text field (comma-separated)
%   - Dimension dropdown (x/y/z)
%   - Speed panel checkbox
%   - Immobility shading checkbox + threshold (mm/s)
%   - Invert Y-axis checkbox (position panel)
%   - Plot / Refresh button
%   - Static 3D plot button
%
% The actual plot is rendered in a separate figure using
% CODE/PLOTTING/poster/plotPosterMarkerTimeSeries.m.

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addParameter(p, 'defaultMarkers', {}, @(x) ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'defaultDimension', 'x', @(x) ischar(x) || isstring(x));
    addParameter(p, 'defaultShowSpeedPanel', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'defaultSmoothWindowFrames', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'defaultShowImmobileShading', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'defaultImmobileThreshold', 25, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'defaultInvertYAxis', false, @(x) islogical(x) && isscalar(x));
    parse(p, trialData, varargin{:});

    localValidateTrialData(trialData);

    videoIDs = trialData.metaData.videoIDs;
    if isstring(videoIDs)
        videoIDs = cellstr(videoIDs);
    end
    if ~iscell(videoIDs)
        error('launchPosterTrajectoryBrowser:BadVideoIDs', ...
            'trialData.metaData.videoIDs must be a cell array or string array.');
    end
    if isempty(videoIDs)
        error('launchPosterTrajectoryBrowser:NoVideoIDs', ...
            'No videoIDs found in trialData.metaData.videoIDs.');
    end

    defaultMarkers = p.Results.defaultMarkers;
    if isempty(defaultMarkers)
        if ~isempty(trialData.markerNames)
            defaultMarkers = {trialData.markerNames{1}};
        else
            defaultMarkers = {'marker1'};
        end
    end
    defaultMarkers = cellstr(string(defaultMarkers));

    state = struct();
    state.trialData = trialData;
    state.lastPlotFigure = [];
    state.last3DFigure = [];

    f = figure( ...
        'Name', 'Poster Trajectory Browser', ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Units', 'pixels', ...
        'Position', [120 120 430 395]);

    uicontrol(f, 'Style', 'text', 'String', 'VideoID', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [20 220 90 20]);
    hVideo = uicontrol(f, 'Style', 'popupmenu', ...
        'String', videoIDs, ...
        'Value', 1, ...
        'Position', [120 218 280 26], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Markers (comma-separated)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [20 178 170 20]);
    hMarkers = uicontrol(f, 'Style', 'edit', ...
        'String', strjoin(defaultMarkers, ', '), ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'w', ...
        'Position', [20 154 380 26], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Dimension', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [20 130 90 20]);
    hDim = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'x','y','z'}, ...
        'Value', localDimValue(p.Results.defaultDimension), ...
        'Position', [120 128 70 26], ...
        'Callback', @onAutoRefresh);

    hSpeed = uicontrol(f, 'Style', 'checkbox', ...
        'String', 'Show speed panel', ...
        'Value', p.Results.defaultShowSpeedPanel, ...
        'BackgroundColor', 'w', ...
        'Position', [220 130 150 22], ...
        'Callback', @onAutoRefresh);

    hImmobile = uicontrol(f, 'Style', 'checkbox', ...
        'String', 'Shade immobile frames', ...
        'Value', p.Results.defaultShowImmobileShading, ...
        'BackgroundColor', 'w', ...
        'Position', [20 102 170 22], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Threshold (mm/s)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [220 102 110 20]);
    hImmobileThr = uicontrol(f, 'Style', 'edit', ...
        'String', num2str(p.Results.defaultImmobileThreshold), ...
        'BackgroundColor', 'w', ...
        'Position', [335 100 65 24], ...
        'Callback', @onAutoRefresh);

    hInvertY = uicontrol(f, 'Style', 'checkbox', ...
        'String', 'Invert Y-axis (position plot)', ...
        'Value', p.Results.defaultInvertYAxis, ...
        'BackgroundColor', 'w', ...
        'Position', [20 74 220 22], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Smooth (frames)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [260 74 100 20]);
    hSmooth = uicontrol(f, 'Style', 'edit', ...
        'String', num2str(p.Results.defaultSmoothWindowFrames), ...
        'BackgroundColor', 'w', ...
        'Position', [335 72 65 24], ...
        'Callback', @onAutoRefresh);

    hRefresh = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Plot / Refresh', ...
        'Position', [20 28 120 34], ...
        'Callback', @onRefresh);

    hClosePlot = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Close Plot Figure', ...
        'Position', [155 28 120 34], ...
        'Callback', @onClosePlot);

    hPlot3D = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Open Static 3D', ...
        'Position', [290 28 110 34], ...
        'Callback', @onPlot3D);

    hStatus = uicontrol(f, 'Style', 'text', ...
        'String', 'Ready', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'w', ...
        'ForegroundColor', [0.2 0.2 0.2], ...
        'Position', [20 8 390 18]);

    % Store app handles/state in guidata
    S = struct();
    S.state = state;
    S.hVideo = hVideo;
    S.hMarkers = hMarkers;
    S.hDim = hDim;
    S.hSpeed = hSpeed;
    S.hImmobile = hImmobile;
    S.hImmobileThr = hImmobileThr;
    S.hInvertY = hInvertY;
    S.hSmooth = hSmooth;
    S.hRefresh = hRefresh;
    S.hClosePlot = hClosePlot;
    S.hPlot3D = hPlot3D;
    S.hStatus = hStatus;
    guidata(f, S);

    % Initial render
    onRefresh();

    if nargout > 0
        H = struct();
        H.controlFigure = f;
        H.getState = @() guidata(f);
    end

    function onAutoRefresh(~, ~)
        % Auto-refresh for quick browsing; falls back to manual use if errors.
        onRefresh();
    end

    function onRefresh(~, ~)
        S = guidata(f);
        try
            [videoID, markerList, dimStr, showSpeed, smoothFrames, showImmobile, immobileThr, invertYAxis] = localReadControls(S);
            set(S.hStatus, 'String', sprintf('Plotting %s (%s)...', videoID, dimStr), ...
                'ForegroundColor', [0.2 0.2 0.2]);
            drawnow;

            % Close previous plot figure and create a fresh one via the plotter.
            if ~isempty(S.state.lastPlotFigure) && ishandle(S.state.lastPlotFigure)
                close(S.state.lastPlotFigure);
            end

            R = plotPosterMarkerTimeSeries(S.state.trialData, markerList, videoID, ...
                'dimension', dimStr, ...
                'smoothWindowFrames', smoothFrames, ...
                'showSpeedPanel', showSpeed, ...
                'showImmobileShading', showImmobile, ...
                'immobileSpeedThreshold', immobileThr, ...
                'invertYAxis', invertYAxis);
            S.state.lastPlotFigure = R.figure;

            if isfield(S.state.trialData, 'subjectID')
                subjStr = char(string(S.state.trialData.subjectID));
            else
                subjStr = 'trialData';
            end
            set(R.figure, 'Name', sprintf('Poster Trajectory Plot - %s - %s', subjStr, videoID));

            set(S.hStatus, 'String', sprintf('Plotted: %s | markers: %s', videoID, strjoin(markerList, ', ')), ...
                'ForegroundColor', [0.0 0.4 0.0]);
            guidata(f, S);
        catch ME
            set(S.hStatus, 'String', sprintf('Error: %s', ME.message), ...
                'ForegroundColor', [0.75 0.1 0.1]);
            guidata(f, S);
        end
    end

    function onClosePlot(~, ~)
        S = guidata(f);
        if ~isempty(S.state.lastPlotFigure) && ishandle(S.state.lastPlotFigure)
            close(S.state.lastPlotFigure);
        end
        if ~isempty(S.state.last3DFigure) && ishandle(S.state.last3DFigure)
            close(S.state.last3DFigure);
        end
        S.state.lastPlotFigure = [];
        S.state.last3DFigure = [];
        set(S.hStatus, 'String', 'Plot figure closed', 'ForegroundColor', [0.2 0.2 0.2]);
        guidata(f, S);
    end

    function onPlot3D(~, ~)
        S = guidata(f);
        try
            [videoID, markerList, dimStr, ~, ~, ~, ~, invertYAxis] = localReadControls(S); %#ok<ASGLU>

            set(S.hStatus, 'String', sprintf('Opening 3D plot for %s...', videoID), ...
                'ForegroundColor', [0.2 0.2 0.2]);
            drawnow;

            if ~isempty(S.state.last3DFigure) && ishandle(S.state.last3DFigure)
                close(S.state.last3DFigure);
            end

            % Map the 2D "invert Y-axis" toggle onto the selected dimension for 3D convenience.
            invertX = false; invertY = false; invertZ = false;
            switch lower(strtrim(dimStr))
                case 'x'
                    invertX = invertYAxis;
                case 'y'
                    invertY = invertYAxis;
                case 'z'
                    invertZ = invertYAxis;
            end

            R3 = plotPosterMarkerTrajectory3D(S.state.trialData, markerList, videoID, ...
                'invertX', invertX, ...
                'invertY', invertY, ...
                'invertZ', invertZ, ...
                'showStartEnd', true, ...
                'axisEqual', false, ...
                'centerAtStart', false);
            S.state.last3DFigure = R3.figure;

            if isfield(S.state.trialData, 'subjectID')
                subjStr = char(string(S.state.trialData.subjectID));
            else
                subjStr = 'trialData';
            end
            set(R3.figure, 'Name', sprintf('Poster 3D Trajectory - %s - %s', subjStr, videoID));

            set(S.hStatus, 'String', sprintf('Opened 3D plot: %s | markers: %s', videoID, strjoin(markerList, ', ')), ...
                'ForegroundColor', [0.0 0.4 0.0]);
            guidata(f, S);
        catch ME
            set(S.hStatus, 'String', sprintf('Error: %s', ME.message), ...
                'ForegroundColor', [0.75 0.1 0.1]);
            guidata(f, S);
        end
    end
end

function localValidateTrialData(trialData)
    reqFields = {'markerNames', 'trajectoryData', 'metaData'};
    for i = 1:numel(reqFields)
        if ~isfield(trialData, reqFields{i})
            error('launchPosterTrajectoryBrowser:MissingTrialField', ...
                'trialData is missing required field "%s".', reqFields{i});
        end
    end
    if ~isfield(trialData.metaData, 'videoIDs')
        error('launchPosterTrajectoryBrowser:MissingVideoIDs', ...
            'trialData.metaData.videoIDs is required for the dropdown.');
    end
end

function [videoID, markerList, dimStr, showSpeed, smoothFrames, showImmobile, immobileThr, invertYAxis] = localReadControls(S)
    videoItems = get(S.hVideo, 'String');
    videoIdx = get(S.hVideo, 'Value');
    if ischar(videoItems)
        videoID = strtrim(videoItems(videoIdx, :));
    else
        videoID = char(string(videoItems{videoIdx}));
    end

    rawMarkers = char(string(get(S.hMarkers, 'String')));
    markerList = regexp(rawMarkers, ',', 'split');
    markerList = cellfun(@strtrim, markerList, 'UniformOutput', false);
    markerList = markerList(~cellfun(@isempty, markerList));
    if isempty(markerList)
        error('Please enter at least one marker name.');
    end

    dimItems = get(S.hDim, 'String');
    dimIdx = get(S.hDim, 'Value');
    if ischar(dimItems)
        dimStr = strtrim(dimItems(dimIdx, :));
    else
        dimStr = char(string(dimItems{dimIdx}));
    end

    showSpeed = logical(get(S.hSpeed, 'Value'));
    showImmobile = logical(get(S.hImmobile, 'Value'));
    invertYAxis = logical(get(S.hInvertY, 'Value'));

    immobileThr = str2double(char(string(get(S.hImmobileThr, 'String'))));
    if ~isfinite(immobileThr) || immobileThr < 0
        error('Immobile threshold must be a number >= 0.');
    end

    smoothFrames = str2double(char(string(get(S.hSmooth, 'String'))));
    if ~isfinite(smoothFrames) || smoothFrames < 1
        error('Smooth (frames) must be a number >= 1.');
    end
    smoothFrames = round(smoothFrames);
end

function v = localDimValue(dimStr)
    switch lower(strtrim(char(string(dimStr))))
        case 'x'
            v = 1;
        case 'y'
            v = 2;
        case 'z'
            v = 3;
        otherwise
            v = 1;
    end
end
