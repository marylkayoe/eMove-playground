function H = launchMicromovementExampleBrowser(varargin)
% launchMicromovementExampleBrowser - Browse subjects/videos/bodyparts for collaborator-facing examples.
%
% Usage:
%   launchMicromovementExampleBrowser()
%   launchMicromovementExampleBrowser('matRoot', '/path/to/matlab_from_manifest')
%
% This GUI loads the latest subject MAT from a processed MAT root, lets the
% user choose a subject, video, and bodypart group, and renders a two-panel
% plot:
%   - top: bodypart marker position traces
%   - bottom: instantaneous speed traces
% with optional pre/post stimulus context and explicit stimulus boundary lines.
%
% Notes for standalone packaging:
%   - Pass explicit matRoot / groupCsv / stimCsv paths from a deployment-aware
%     launcher instead of relying on repository-relative defaults.

    p = inputParser;
    addParameter(p, 'repoRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'matRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'groupCsv', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'stimCsv', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'defaultPreStimSec', 10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'defaultPostStimSec', 10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'defaultDimension', 'y', @(x) ischar(x) || isstring(x));
    addParameter(p, 'defaultImmobileThreshold', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, varargin{:});

    repoRoot = char(string(p.Results.repoRoot));
    matRoot = char(string(p.Results.matRoot));
    groupCsv = char(string(p.Results.groupCsv));
    stimCsv = char(string(p.Results.stimCsv));
    if isempty(strtrim(repoRoot))
        repoRoot = localInferRepoRoot();
    end
    if isempty(strtrim(matRoot))
        matRoot = localInferMatRoot(repoRoot);
    end
    if isempty(strtrim(groupCsv))
        groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
    end
    if isempty(strtrim(stimCsv))
        stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
    end

    if ~isfolder(matRoot)
        error('launchMicromovementExampleBrowser:BadMatRoot', 'MAT root not found: %s', matRoot);
    end
    if ~isfile(groupCsv)
        error('launchMicromovementExampleBrowser:BadGroupCsv', 'Grouping CSV not found: %s', groupCsv);
    end

    [groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
    stimInfo = localLoadStimInfoTable(stimCsv);
    subjectMap = localCollectSubjectMats(matRoot);
    if isempty(subjectMap)
        error('launchMicromovementExampleBrowser:NoSubjects', 'No subject MAT files found under %s', matRoot);
    end

    state = struct();
    state.groupedMarkerNames = groupedMarkerNames;
    state.groupedBodypartNames = groupedBodypartNames;
    state.subjectMap = subjectMap;
    state.stimInfo = stimInfo;
    state.currentTrialData = struct();
    state.currentSubjectID = '';
    state.currentPlotFigure = [];
    state.groupCheckboxes = gobjects(0);
    state.pendingNumeric = struct( ...
        'preRaw', num2str(p.Results.defaultPreStimSec), ...
        'postRaw', num2str(p.Results.defaultPostStimSec), ...
        'thrRaw', num2str(p.Results.defaultImmobileThreshold), ...
        'smoothRaw', '1');

    f = figure( ...
        'Name', 'Micromovement Example Browser', ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Units', 'pixels', ...
        'Position', [90 70 620 720]);

    leftLabelX = 20;
    leftFieldX = 125;
    leftFieldW = 220;
    rightLabelX = 365;
    rightFieldX = 490;
    rightFieldW = 90;

    subjectIDs = {subjectMap.subjectID};

    uicontrol(f, 'Style', 'text', 'String', 'Subject', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftLabelX 660 90 20]);
    hSubject = uicontrol(f, 'Style', 'popupmenu', ...
        'String', subjectIDs, ...
        'Value', 1, ...
        'Position', [leftFieldX 656 leftFieldW 28], ...
        'Callback', @onSubjectChanged);

    uicontrol(f, 'Style', 'text', 'String', 'Video', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftLabelX 618 90 20]);
    hVideo = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'(loading...)'}, ...
        'Value', 1, ...
        'Position', [leftFieldX 614 leftFieldW 28], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Bodyparts', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftLabelX 578 90 20]);
    hGroupPanel = uipanel(f, ...
        'Units', 'pixels', ...
        'Position', [leftFieldX 342 leftFieldW 228], ...
        'BackgroundColor', 'w', ...
        'BorderType', 'line');
    hGroupAll = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'All', ...
        'Position', [leftLabelX 544 60 26], ...
        'Callback', @onSelectAllGroups);
    hGroupNone = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'None', ...
        'Position', [leftLabelX 510 60 26], ...
        'Callback', @onSelectNoGroups);

    uicontrol(f, 'Style', 'text', 'String', 'Dimension', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [rightLabelX 660 100 20]);
    hDim = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'x','y','z'}, ...
        'Value', localDimValue(p.Results.defaultDimension), ...
        'Position', [rightFieldX 656 rightFieldW 28], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Pre (s)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [rightLabelX 618 100 20]);
    hPre = uicontrol(f, 'Style', 'edit', ...
        'String', num2str(p.Results.defaultPreStimSec), ...
        'BackgroundColor', 'w', ...
        'Position', [rightFieldX 614 rightFieldW 28], ...
        'Callback', @onNumericEdited);

    uicontrol(f, 'Style', 'text', 'String', 'Post (s)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [rightLabelX 576 100 20]);
    hPost = uicontrol(f, 'Style', 'edit', ...
        'String', num2str(p.Results.defaultPostStimSec), ...
        'BackgroundColor', 'w', ...
        'Position', [rightFieldX 572 rightFieldW 28], ...
        'Callback', @onNumericEdited);

    hSpeed = uicontrol(f, 'Style', 'checkbox', ...
        'String', 'Show speed panel', ...
        'Value', 1, ...
        'BackgroundColor', 'w', ...
        'Position', [rightLabelX 526 180 24], ...
        'Callback', @onAutoRefresh);

    hShade = uicontrol(f, 'Style', 'checkbox', ...
        'String', 'Shade immobile bouts', ...
        'Value', 1, ...
        'BackgroundColor', 'w', ...
        'Position', [rightLabelX 494 180 24], ...
        'Callback', @onAutoRefresh);

    hAvg = uicontrol(f, 'Style', 'checkbox', ...
        'String', 'Average trajectory only', ...
        'Value', 0, ...
        'BackgroundColor', 'w', ...
        'Position', [rightLabelX 462 180 24], ...
        'Callback', @onAutoRefresh);

    uicontrol(f, 'Style', 'text', 'String', 'Immobile threshold (mm/s)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [rightLabelX 416 120 36]);
    hThr = uicontrol(f, 'Style', 'edit', ...
        'String', num2str(p.Results.defaultImmobileThreshold), ...
        'BackgroundColor', 'w', ...
        'Position', [rightFieldX 420 rightFieldW 28], ...
        'Callback', @onNumericEdited);

    uicontrol(f, 'Style', 'text', 'String', 'Smooth (frames)', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [rightLabelX 378 120 20]);
    hSmooth = uicontrol(f, 'Style', 'edit', ...
        'String', '1', ...
        'BackgroundColor', 'w', ...
        'Position', [rightFieldX 374 rightFieldW 28], ...
        'Callback', @onNumericEdited);

    hRefresh = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Plot / Refresh', ...
        'Position', [20 296 160 42], ...
        'Callback', @onRefresh);
    hClosePlot = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Close Plot', ...
        'Position', [190 296 160 42], ...
        'Callback', @onClosePlot);

    hStatus = uicontrol(f, 'Style', 'text', ...
        'String', 'Ready', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'w', ...
        'ForegroundColor', [0.2 0.2 0.2], ...
        'Position', [20 250 570 26]);

    hInfo = uicontrol(f, 'Style', 'text', ...
        'String', '', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'w', ...
        'ForegroundColor', [0.25 0.25 0.25], ...
        'Position', [20 24 570 210]);

    S = struct();
    S.state = state;
    S.hSubject = hSubject;
    S.hVideo = hVideo;
    S.hGroupPanel = hGroupPanel;
    S.hGroupAll = hGroupAll;
    S.hGroupNone = hGroupNone;
    S.hDim = hDim;
    S.hPre = hPre;
    S.hPost = hPost;
    S.hSpeed = hSpeed;
    S.hShade = hShade;
    S.hAvg = hAvg;
    S.hThr = hThr;
    S.hSmooth = hSmooth;
    S.hRefresh = hRefresh;
    S.hClosePlot = hClosePlot;
    S.hStatus = hStatus;
    S.hInfo = hInfo;
    guidata(f, S);

    onSubjectChanged();

    if nargout > 0
        H = struct();
        H.controlFigure = f;
        H.getState = @() guidata(f);
    end

    function onSubjectChanged(~, ~)
        S = guidata(f);
        S = localCaptureNumericFieldState(S);
        previousUi = localCaptureUiSelections(S);
        previousVideoID = localGetSelectedPopupString(S.hVideo);
        items = get(S.hSubject, 'String');
        idx = get(S.hSubject, 'Value');
        subjectID = char(string(items{idx}));
        set(S.hStatus, 'String', sprintf('Loading %s...', subjectID));
        drawnow;

        td = localLoadTrialDataForSubject(S.state.subjectMap, subjectID);
        S.state.currentTrialData = td;
        S.state.currentSubjectID = subjectID;

        videos = localVideoListFromTrialData(td);
        groups = localAvailableGroups(td, S.state.groupedMarkerNames, S.state.groupedBodypartNames);
        if isempty(videos), videos = {'(none)'}; end
        if isempty(groups), groups = {'(none)'}; end

        nextVideoIdx = localFindStringIndex(videos, previousVideoID, 1);
        set(S.hVideo, 'String', videos, 'Value', nextVideoIdx);
        S = localRebuildGroupCheckboxes(S, groups, previousUi.selectedGroups);
        localRestoreUiSelections(S, previousUi);

        selectedVideo = char(string(videos{nextVideoIdx}));
        emotionLabel = localEmotionForVideo(selectedVideo, S.state.stimInfo);
        set(S.hInfo, 'String', sprintf('MAT: %s\nMarkers: %d\nVideos: %d\nSelected emotion: %s', ...
            localCurrentMatPath(S.state.subjectMap, subjectID), numel(td.markerNames), numel(videos), emotionLabel));
        guidata(f, S);
        onRefresh();
    end

    function onAutoRefresh(~, ~)
        onRefresh();
    end

    function onNumericEdited(src, ~)
        S = guidata(f);
        rawValue = strtrim(char(string(get(src, 'String'))));
        if isequal(src, S.hPre)
            S.state.pendingNumeric.preRaw = rawValue;
        elseif isequal(src, S.hPost)
            S.state.pendingNumeric.postRaw = rawValue;
        elseif isequal(src, S.hThr)
            S.state.pendingNumeric.thrRaw = rawValue;
        elseif isequal(src, S.hSmooth)
            S.state.pendingNumeric.smoothRaw = rawValue;
        end
        guidata(f, S);
        if isempty(rawValue)
            fieldLabel = 'Numeric field';
        elseif isequal(src, S.hPre)
            fieldLabel = sprintf('Pre = %s s', rawValue);
        elseif isequal(src, S.hPost)
            fieldLabel = sprintf('Post = %s s', rawValue);
        elseif isequal(src, S.hThr)
            fieldLabel = sprintf('Immobile threshold = %s mm/s', rawValue);
        elseif isequal(src, S.hSmooth)
            fieldLabel = sprintf('Smooth = %s frames', rawValue);
        else
            fieldLabel = 'Controls updated';
        end
        set(S.hStatus, 'String', 'Controls updated. Press Plot / Refresh to apply.', ...
            'ForegroundColor', [0.2 0.2 0.2]);
        if ~isempty(rawValue)
            set(S.hStatus, 'String', sprintf('%s. Press Plot / Refresh to apply.', fieldLabel), ...
                'ForegroundColor', [0.2 0.2 0.2]);
        end
    end

    function onSelectAllGroups(~, ~)
        S = guidata(f);
        for i = 1:numel(S.state.groupCheckboxes)
            if isgraphics(S.state.groupCheckboxes(i))
                set(S.state.groupCheckboxes(i), 'Value', 1);
            end
        end
        guidata(f, S);
        onRefresh();
    end

    function onSelectNoGroups(~, ~)
        S = guidata(f);
        for i = 1:numel(S.state.groupCheckboxes)
            if isgraphics(S.state.groupCheckboxes(i))
                set(S.state.groupCheckboxes(i), 'Value', 0);
            end
        end
        guidata(f, S);
        onRefresh();
    end

    function onRefresh(~, ~)
        S = guidata(f);
        if isempty(fieldnames(S.state.currentTrialData))
            return;
        end
        try
            S = localCaptureNumericFieldState(S);
            guidata(f, S);
            [videoID, groupNames, dimStr, preSec, postSec, showSpeed, showShade, showAverageOnly, thr, smoothFrames] = ...
                localReadControls(S);
            emotionLabel = localEmotionForVideo(videoID, S.state.stimInfo);
            markerNames = localMarkersForGroups(S.state.currentTrialData, groupNames, ...
                S.state.groupedMarkerNames, S.state.groupedBodypartNames);
            if isempty(markerNames)
                error('No markers found for selected groups in subject %s.', S.state.currentSubjectID);
            end
            groupLabel = strjoin(groupNames, ', ');

            if ~isempty(S.state.currentPlotFigure) && ishandle(S.state.currentPlotFigure)
                close(S.state.currentPlotFigure);
            end

            titleText = sprintf('%s | %s (%s) | %s | pre %.1fs / post %.1fs', ...
                S.state.currentSubjectID, videoID, emotionLabel, groupLabel, preSec, postSec);
            R = plotPosterMarkerTimeSeries(S.state.currentTrialData, markerNames, videoID, ...
                'dimension', dimStr, ...
                'preStimSec', preSec, ...
                'postStimSec', postSec, ...
                'showSpeedPanel', showSpeed, ...
                'showImmobileShading', showShade, ...
                'immobileSpeedThreshold', thr, ...
                'showAverageTrajectory', showAverageOnly, ...
                'smoothWindowFrames', smoothFrames, ...
                'layoutPreset', 'stackedWithRightPanels', ...
                'showStimBounds', true, ...
                'figureTitle', titleText);

            set(R.figure, 'Name', sprintf('Micromovement Example - %s - %s - %s', ...
                S.state.currentSubjectID, videoID, groupLabel));
            S.state.currentPlotFigure = R.figure;
            set(S.hStatus, 'String', sprintf('Plotted %s | %s (%s) | %s', ...
                S.state.currentSubjectID, videoID, emotionLabel, groupLabel), ...
                'ForegroundColor', [0.2 0.2 0.2]);
            set(S.hInfo, 'String', sprintf('MAT: %s\nMarkers: %d\nVideos: %d\nSelected emotion: %s', ...
                localCurrentMatPath(S.state.subjectMap, S.state.currentSubjectID), ...
                numel(S.state.currentTrialData.markerNames), ...
                numel(localVideoListFromTrialData(S.state.currentTrialData)), ...
                emotionLabel));
            localPopulateSidePanels(R, groupNames);
            guidata(f, S);
        catch ME
            set(S.hStatus, 'String', sprintf('Error: %s', ME.message), 'ForegroundColor', [0.7 0.1 0.1]);
            guidata(f, S);
        end
    end

    function onClosePlot(~, ~)
        S = guidata(f);
        if ~isempty(S.state.currentPlotFigure) && ishandle(S.state.currentPlotFigure)
            close(S.state.currentPlotFigure);
            S.state.currentPlotFigure = [];
        end
        guidata(f, S);
    end
end

function subjectMap = localCollectSubjectMats(matRoot)
    subjDirs = dir(matRoot);
    subjDirs = subjDirs([subjDirs.isdir]);
    subjectMap = struct('subjectID', {}, 'matPath', {});
    for i = 1:numel(subjDirs)
        name = subjDirs(i).name;
        if strcmp(name, '.') || strcmp(name, '..')
            continue;
        end
        mats = dir(fullfile(matRoot, name, '*.mat'));
        if isempty(mats)
            continue;
        end
        pickIdx = localPickLatestMat(mats);
        subjectMap(end+1).subjectID = name; %#ok<AGROW>
        subjectMap(end).matPath = fullfile(mats(pickIdx).folder, mats(pickIdx).name);
    end
    [~, ord] = sort({subjectMap.subjectID});
    subjectMap = subjectMap(ord);
end

function pickIdx = localPickLatestMat(mats)
    timestamps = NaT(numel(mats), 1);
    for i = 1:numel(mats)
        timestamps(i) = localParseTakeTimestamp(mats(i).name);
    end
    if any(~isnat(timestamps))
        ts = timestamps;
        ts(isnat(ts)) = datetime(1,1,1);
        [~, pickIdx] = max(ts);
    else
        [~, pickIdx] = max([mats.datenum]);
    end
end

function dt = localParseTakeTimestamp(fileName)
    dt = NaT;
    tok = regexp(fileName, 'Take_(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}_[AP]M)\.mat$', 'tokens', 'once');
    if isempty(tok)
        return;
    end
    try
        dt = datetime(strrep(tok{1}, '_', ' '), 'InputFormat', 'yyyy MM dd hh mm ss a');
    catch
        dt = NaT;
    end
end

function td = localLoadTrialDataForSubject(subjectMap, subjectID)
    idx = find(strcmp({subjectMap.subjectID}, subjectID), 1, 'first');
    if isempty(idx)
        error('Subject %s not found in subject map.', subjectID);
    end
    S = load(subjectMap(idx).matPath);
    if isfield(S, 'trialData')
        td = S.trialData;
    else
        error('trialData variable missing in %s', subjectMap(idx).matPath);
    end
end

function pathOut = localCurrentMatPath(subjectMap, subjectID)
    idx = find(strcmp({subjectMap.subjectID}, subjectID), 1, 'first');
    if isempty(idx)
        pathOut = '';
    else
        pathOut = subjectMap(idx).matPath;
    end
end

function videos = localVideoListFromTrialData(td)
    videos = {};
    if isfield(td, 'metaData') && isfield(td.metaData, 'videoIDs')
        vids = cellstr(string(td.metaData.videoIDs));
        vids = vids(~cellfun(@isempty, vids));
        vids = vids(~strcmpi(vids, '0'));
        videos = unique(vids, 'stable');
    end
end

function groups = localAvailableGroups(td, groupedMarkerNames, groupedBodypartNames)
    groups = {};
    markerNames = cellstr(string(td.markerNames));
    for i = 1:numel(groupedBodypartNames)
        markers = groupedMarkerNames{i};
        if any(ismember(markers, markerNames))
            groups{end+1} = groupedBodypartNames{i}; %#ok<AGROW>
        end
    end
end

function S = localRebuildGroupCheckboxes(S, groups, selectedGroups)
    if nargin < 3
        selectedGroups = {};
    end
    oldBoxes = S.state.groupCheckboxes;
    for i = 1:numel(oldBoxes)
        if isgraphics(oldBoxes(i))
            delete(oldBoxes(i));
        end
    end

    n = numel(groups);
    boxes = gobjects(n, 1);
    panelPos = get(S.hGroupPanel, 'Position');
    startY = panelPos(4) - 28;
    stepY = 21;
    for i = 1:n
        y = startY - (i - 1) * stepY;
        if y < 2
            y = 2;
        end
        defaultValue = i == 1;
        if ~isempty(selectedGroups)
            defaultValue = any(strcmp(groups{i}, selectedGroups));
        end
        boxes(i) = uicontrol(S.hGroupPanel, ...
            'Style', 'checkbox', ...
            'String', groups{i}, ...
            'Value', defaultValue, ...
            'BackgroundColor', 'w', ...
            'HorizontalAlignment', 'left', ...
            'Position', [8 y 180 20], ...
            'Callback', @onBrowserCheckboxChanged);
    end
    if ~isempty(boxes) && ~any(arrayfun(@(h) logical(get(h, 'Value')), boxes))
        set(boxes(1), 'Value', 1);
    end
    S.state.groupCheckboxes = boxes;
end

function ui = localCaptureUiSelections(S)
    dims = get(S.hDim, 'String');
    ui = struct();
    ui.dimensionValue = get(S.hDim, 'Value');
    ui.dimensionString = char(string(dims{ui.dimensionValue}));
    ui.showSpeed = logical(get(S.hSpeed, 'Value'));
    ui.showShade = logical(get(S.hShade, 'Value'));
    ui.showAverageOnly = logical(get(S.hAvg, 'Value'));
    ui.selectedGroups = {};
    for i = 1:numel(S.state.groupCheckboxes)
        h = S.state.groupCheckboxes(i);
        if isgraphics(h) && logical(get(h, 'Value'))
            ui.selectedGroups{end+1} = char(string(get(h, 'String'))); %#ok<AGROW>
        end
    end
end

function localRestoreUiSelections(S, ui)
    if isempty(ui)
        return;
    end
    dims = get(S.hDim, 'String');
    dimIdx = localFindStringIndex(cellstr(string(dims)), ui.dimensionString, ui.dimensionValue);
    set(S.hDim, 'Value', dimIdx);
    set(S.hSpeed, 'Value', ui.showSpeed);
    set(S.hShade, 'Value', ui.showShade);
    set(S.hAvg, 'Value', ui.showAverageOnly);
    set(S.hPre, 'String', S.state.pendingNumeric.preRaw);
    set(S.hPost, 'String', S.state.pendingNumeric.postRaw);
    set(S.hThr, 'String', S.state.pendingNumeric.thrRaw);
    set(S.hSmooth, 'String', S.state.pendingNumeric.smoothRaw);
end

function markers = localMarkersForGroups(td, groupNames, groupedMarkerNames, groupedBodypartNames)
    markerNames = cellstr(string(td.markerNames));
    markers = {};
    for i = 1:numel(groupNames)
        idx = find(strcmp(groupedBodypartNames, groupNames{i}), 1, 'first');
        if isempty(idx)
            continue;
        end
        thisMarkers = groupedMarkerNames{idx};
        thisMarkers = thisMarkers(ismember(thisMarkers, markerNames));
        markers = [markers(:); thisMarkers(:)]; %#ok<AGROW>
    end
    markers = unique(markers, 'stable');
end

function onBrowserCheckboxChanged(src, ~)
    f = ancestor(src, 'figure');
    if isempty(f) || ~ishandle(f)
        return;
    end
    S = guidata(f);
    if isempty(S)
        return;
    end
    localRefreshFromCheckbox(f);
end

function localRefreshFromCheckbox(f)
    if isempty(f) || ~ishandle(f)
        return;
    end
    refreshBtn = findobj(f, 'Style', 'pushbutton', 'String', 'Plot / Refresh');
    if isempty(refreshBtn)
        return;
    end
    cb = get(refreshBtn(1), 'Callback');
    if isa(cb, 'function_handle')
        cb(refreshBtn(1), []);
    end
end

function selectedValue = localGetSelectedPopupString(hPopup)
    selectedValue = '';
    if isempty(hPopup) || ~ishandle(hPopup)
        return;
    end
    items = get(hPopup, 'String');
    if isempty(items)
        return;
    end
    idx = get(hPopup, 'Value');
    idx = max(1, min(idx, numel(items)));
    selectedValue = char(string(items{idx}));
end

function idx = localFindStringIndex(items, targetValue, fallbackIdx)
    idx = fallbackIdx;
    if isempty(items)
        return;
    end
    if nargin < 3 || isempty(fallbackIdx)
        fallbackIdx = 1;
    end
    idx = max(1, min(fallbackIdx, numel(items)));
    if isempty(targetValue)
        return;
    end
    matchIdx = find(strcmp(cellstr(string(items)), char(string(targetValue))), 1, 'first');
    if ~isempty(matchIdx)
        idx = matchIdx;
    end
end

function val = localDimValue(dimStr)
    switch lower(char(string(dimStr)))
        case 'x'
            val = 1;
        case 'y'
            val = 2;
        otherwise
            val = 3;
    end
end

function [videoID, groupNames, dimStr, preSec, postSec, showSpeed, showShade, showAverageOnly, thr, smoothFrames] = localReadControls(S)
    videos = get(S.hVideo, 'String');
    videoID = char(string(videos{get(S.hVideo, 'Value')}));
    groupNames = {};
    for i = 1:numel(S.state.groupCheckboxes)
        h = S.state.groupCheckboxes(i);
        if isgraphics(h) && logical(get(h, 'Value'))
            groupNames{end+1} = char(string(get(h, 'String'))); %#ok<AGROW>
        end
    end
    dims = get(S.hDim, 'String');
    dimStr = char(string(dims{get(S.hDim, 'Value')}));
    preSec = localParseMinString(S.state.pendingNumeric.preRaw, 10, 10);
    postSec = localParseMinString(S.state.pendingNumeric.postRaw, 10, 10);
    thr = localParseMinString(S.state.pendingNumeric.thrRaw, 35, 0);
    smoothFrames = max(1, round(localParseNonnegativeString(S.state.pendingNumeric.smoothRaw, 1)));
    set(S.hPre, 'String', num2str(preSec));
    set(S.hPost, 'String', num2str(postSec));
    set(S.hThr, 'String', num2str(thr));
    set(S.hSmooth, 'String', num2str(smoothFrames));
    showSpeed = logical(get(S.hSpeed, 'Value'));
    showShade = logical(get(S.hShade, 'Value'));
    showAverageOnly = logical(get(S.hAvg, 'Value'));
end

function S = localCaptureNumericFieldState(S)
    S.state.pendingNumeric.preRaw = char(string(get(S.hPre, 'String')));
    S.state.pendingNumeric.postRaw = char(string(get(S.hPost, 'String')));
    S.state.pendingNumeric.thrRaw = char(string(get(S.hThr, 'String')));
    S.state.pendingNumeric.smoothRaw = char(string(get(S.hSmooth, 'String')));
end

function val = localParseNonnegativeEdit(h, fallback)
    val = str2double(string(get(h, 'String')));
    if ~isfinite(val) || val < 0
        val = fallback;
        set(h, 'String', num2str(val));
    end
end

function val = localParseNonnegativeString(rawValue, fallback)
    val = str2double(string(rawValue));
    if ~isfinite(val) || val < 0
        val = fallback;
    end
end

function val = localParseMinString(rawValue, fallback, minVal)
    val = str2double(string(rawValue));
    if ~isfinite(val)
        val = fallback;
    end
    val = max(minVal, val);
end

function val = localParseMinEdit(h, fallback, minVal)
    val = str2double(string(get(h, 'String')));
    if ~isfinite(val)
        val = fallback;
    end
    val = max(minVal, val);
    set(h, 'String', num2str(val));
end

function T = localLoadStimInfoTable(stimCsv)
    if ~isfile(stimCsv)
        T = table(strings(0,1), strings(0,1), 'VariableNames', {'videoID','emotion'});
        return;
    end
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    strCols = intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable');
    if ~isempty(strCols)
        opts = setvartype(opts, strCols, 'string');
    end
    T = readtable(stimCsv, opts);
    if ~ismember('videoID', T.Properties.VariableNames)
        T = table(strings(0,1), strings(0,1), 'VariableNames', {'videoID','emotion'});
        return;
    end
    if ismember('groupCode', T.Properties.VariableNames)
        emo = string(T.groupCode);
    elseif ismember('emotionTag', T.Properties.VariableNames)
        emo = string(T.emotionTag);
    else
        emo = strings(height(T), 1);
    end
    vid = upper(strtrim(string(T.videoID)));
    emo = upper(strtrim(emo));
    keep = vid ~= "";
    T = table(vid(keep), emo(keep), 'VariableNames', {'videoID','emotion'});
end

function emotionLabel = localEmotionForVideo(videoID, stimInfo)
    emotionLabel = 'UNLABELED';
    if isempty(stimInfo) || height(stimInfo) == 0
        return;
    end
    vid = upper(strtrim(string(videoID)));
    idx = find(stimInfo.videoID == vid, 1, 'first');
    if isempty(idx)
        return;
    end
    emo = char(string(stimInfo.emotion(idx)));
    if isempty(strtrim(emo))
        return;
    end
    emotionLabel = emo;
end

function localPopulateSidePanels(R, groupNames)
    if isempty(groupNames)
        return;
    end
    if isempty(R.rightTopAxes) || ~ishandle(R.rightTopAxes)
        return;
    end
    cla(R.rightTopAxes);
    cla(R.rightBottomAxes);
    hold(R.rightTopAxes, 'on');
    axis(R.rightTopAxes, 'equal');
    axis(R.rightTopAxes, 'off');
    localDrawGroupOverview(R.rightTopAxes, groupNames);

    axis(R.rightBottomAxes, 'off');
end

function localDrawGroupOverview(ax, groupNames)
    nodes = localBodyNodes();
    segments = localBodySegments();
    highlightMap = localGroupNodeMap();
    allSegColor = [0.83 0.83 0.83];
    hiColor = [0 0 0];

    for i = 1:size(segments, 1)
        p1 = nodes.(segments{i,1});
        p2 = nodes.(segments{i,2});
        plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', 'Color', allSegColor, 'LineWidth', 6, ...
            'HandleVisibility', 'off');
    end

    for g = 1:numel(groupNames)
        groupName = groupNames{g};
        if isfield(highlightMap, groupName)
            segs = highlightMap.(groupName);
            for i = 1:size(segs, 1)
                p1 = nodes.(segs{i,1});
                p2 = nodes.(segs{i,2});
                plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', 'Color', hiColor, 'LineWidth', 8, ...
                    'HandleVisibility', 'off');
            end
        end
    end

    nodeNames = fieldnames(nodes);
    xy = zeros(numel(nodeNames), 2);
    for i = 1:numel(nodeNames)
        xy(i, :) = nodes.(nodeNames{i});
    end
    plot(ax, xy(:,1), xy(:,2), 'o', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.2 0.2 0.2], ...
        'MarkerSize', 5, 'HandleVisibility', 'off');
    xlim(ax, [-1.3 1.3]);
    ylim(ax, [-2.2 1.4]);
end

function nodes = localBodyNodes()
    nodes = struct();
    nodes.headTop = [0, 1.10];
    nodes.neck = [0, 0.65];
    nodes.shoulderL = [-0.55, 0.55];
    nodes.shoulderR = [0.55, 0.55];
    nodes.elbowL = [-0.85, 0.10];
    nodes.elbowR = [0.85, 0.10];
    nodes.wristL = [-1.02, -0.35];
    nodes.wristR = [1.02, -0.35];
    nodes.chest = [0, 0.20];
    nodes.waist = [0, -0.35];
    nodes.hipL = [-0.30, -0.45];
    nodes.hipR = [0.30, -0.45];
    nodes.kneeL = [-0.42, -1.10];
    nodes.kneeR = [0.42, -1.10];
    nodes.ankleL = [-0.48, -1.85];
    nodes.ankleR = [0.48, -1.85];
end

function segments = localBodySegments()
    segments = {
        'headTop','neck';
        'shoulderL','neck';
        'shoulderR','neck';
        'neck','chest';
        'chest','waist';
        'shoulderL','elbowL';
        'elbowL','wristL';
        'shoulderR','elbowR';
        'elbowR','wristR';
        'waist','hipL';
        'waist','hipR';
        'hipL','kneeL';
        'kneeL','ankleL';
        'hipR','kneeR';
        'kneeR','ankleR'};
end

function m = localGroupNodeMap()
    m = struct();
    m.HEAD = {'headTop','neck'};
    m.UTORSO = {'shoulderL','neck'; 'neck','shoulderR'; 'neck','chest'};
    m.LTORSO = {'chest','waist'; 'waist','hipL'; 'waist','hipR'};
    m.UPPER_LIMB_L = {'shoulderL','elbowL'; 'neck','shoulderL'};
    m.UPPER_LIMB_R = {'shoulderR','elbowR'; 'neck','shoulderR'};
    m.WRIST_L = {'elbowL','wristL'};
    m.WRIST_R = {'elbowR','wristR'};
    m.LOWER_LIMB_L = {'hipL','kneeL'; 'kneeL','ankleL'};
    m.LOWER_LIMB_R = {'hipR','kneeR'; 'kneeR','ankleR'};
end

function repoRoot = localInferRepoRoot()
    here = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(here, '..', '..', '..', '..');
    repoRoot = char(java.io.File(repoRoot).getCanonicalPath());
end

function matRoot = localInferMatRoot(repoRoot)
    candidate = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
    if isfolder(candidate)
        matRoot = candidate;
        return;
    end
    candidate = fullfile(repoRoot, 'data', 'matlab_from_manifest');
    if isfolder(candidate)
        matRoot = candidate;
        return;
    end
    error('launchMicromovementExampleBrowser:MatRootMissing', ...
        'matRoot was not provided and no default dataset folder could be resolved.');
end
