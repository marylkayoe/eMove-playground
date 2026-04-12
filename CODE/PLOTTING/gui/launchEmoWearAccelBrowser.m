function H = launchEmoWearAccelBrowser(varargin)
% launchEmoWearAccelBrowser - Interactive browser for EmoWear accelerometry and markers.
%
% Purpose:
%   Make the inferred dataset structure explicit and inspectable.
%   The browser lets the user:
%   - choose a participant
%   - choose a device and signal table
%   - inspect survey and marker tables
%   - plot signal traces with walking-related marker overlays
%   - compare candidate pre-walk standing windows

    p = inputParser;
    addParameter(p, 'repoRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'dataRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'visible', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});

    repoRoot = char(string(p.Results.repoRoot));
    dataRoot = char(string(p.Results.dataRoot));
    if isempty(strtrim(repoRoot))
        repoRoot = localInferRepoRoot();
    end
    if isempty(strtrim(dataRoot))
        dataRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279';
    end

    matRoot = fullfile(dataRoot, 'mat_extracted', 'mat');
    metaCsv = fullfile(dataRoot, 'meta.csv');
    questionnaireCsv = fullfile(dataRoot, 'questionnaire.csv');

    if ~isfolder(matRoot)
        error('launchEmoWearAccelBrowser:BadMatRoot', 'MAT root not found: %s', matRoot);
    end
    if ~isfile(metaCsv)
        error('launchEmoWearAccelBrowser:BadMetaCsv', 'meta.csv not found: %s', metaCsv);
    end
    if ~isfile(questionnaireCsv)
        error('launchEmoWearAccelBrowser:BadQuestionnaireCsv', ...
            'questionnaire.csv not found: %s', questionnaireCsv);
    end

    participants = localCollectParticipants(matRoot);
    metaTable = readtable(metaCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    questionnaireTable = readtable(questionnaireCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');

    existingControl = findall(groot, 'Type', 'figure', 'Tag', 'EmoWearAccelBrowser');
    if ~isempty(existingControl) && p.Results.visible
        figure(existingControl(1));
        if nargout > 0
            H = struct('figure', existingControl(1), 'getState', @() guidata(existingControl(1)));
        end
        return;
    end

    figVisible = ternary(p.Results.visible, 'on', 'off');
    f = figure( ...
        'Name', 'EmoWear Accelerometer Browser', ...
        'Tag', 'EmoWearAccelBrowser', ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'MenuBar', 'figure', ...
        'ToolBar', 'figure', ...
        'Units', 'pixels', ...
        'Visible', figVisible, ...
        'Position', [80 60 1380 920]);

    ax = axes('Parent', f, 'Units', 'pixels', 'Position', [330 420 1020 470], ...
        'Box', 'on', 'FontSize', 10);
    title(ax, 'Signal Trace');
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Signal');

    leftX = 18;
    fieldX = 150;
    fieldW = 150;
    rowY = 874;
    rowGap = 38;

    uicontrol(f, 'Style', 'text', 'String', 'Participant', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hParticipant = uicontrol(f, 'Style', 'popupmenu', ...
        'String', participants, 'Value', 1, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onParticipantChanged);

    rowY = rowY - rowGap;
    uicontrol(f, 'Style', 'text', 'String', 'Device', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hDevice = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {' '}, 'Value', 1, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onDeviceChanged);

    rowY = rowY - rowGap;
    uicontrol(f, 'Style', 'text', 'String', 'Signal table', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hSignal = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {' '}, 'Value', 1, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onControlsChanged);

    rowY = rowY - rowGap;
    uicontrol(f, 'Style', 'text', 'String', 'Sequence', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hSequence = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'ALL'}, 'Value', 1, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onControlsChanged);

    rowY = rowY - rowGap;
    uicontrol(f, 'Style', 'text', 'String', 'Plot mode', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hPlotMode = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'Raw magnitude','Dynamic magnitude','Axes'}, 'Value', 1, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onControlsChanged);

    rowY = rowY - rowGap;
    uicontrol(f, 'Style', 'text', 'String', 'Window', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hWindow = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'Full session','Selected sequence'}, 'Value', 2, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onControlsChanged);

    rowY = rowY - rowGap;
    uicontrol(f, 'Style', 'text', 'String', 'Pre-walk view', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [leftX rowY 120 20]);
    hPrewalk = uicontrol(f, 'Style', 'popupmenu', ...
        'String', {'preB -> walkB','preB -> walkDetect','5 s before walkB','5 s before walkDetect'}, ...
        'Value', 1, ...
        'Position', [fieldX rowY-4 fieldW 28], ...
        'Callback', @onControlsChanged);

    rowY = rowY - rowGap - 4;
    hRefresh = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Refresh', ...
        'Position', [leftX rowY 90 28], ...
        'Callback', @onRefresh);
    hShowPrewalk = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Pre-walk', ...
        'Position', [leftX+98 rowY 90 28], ...
        'Callback', @onShowPrewalkOnly);
    hShowWalking = uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Walk', ...
        'Position', [leftX+196 rowY 90 28], ...
        'Callback', @onShowWalkingOnly);

    hStatus = uicontrol(f, 'Style', 'text', ...
        'String', 'Ready', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'w', ...
        'ForegroundColor', [0.2 0.2 0.2], ...
        'Position', [18 540 290 26]);

    hInfo = uicontrol(f, 'Style', 'edit', ...
        'Min', 0, 'Max', 2, ...
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.985 0.985 0.985], ...
        'Position', [18 382 290 150], ...
        'String', '');

    uicontrol(f, 'Style', 'text', 'String', 'Phase 2 markers', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [18 390 120 18]);
    hPhase2 = uitable(f, ...
        'Units', 'pixels', ...
        'Position', [18 175 620 210], ...
        'ColumnName', {}, ...
        'Data', {});

    uicontrol(f, 'Style', 'text', 'String', 'Surveys', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [660 390 120 18]);
    hSurveys = uitable(f, ...
        'Units', 'pixels', ...
        'Position', [660 175 690 210], ...
        'ColumnName', {}, ...
        'Data', {});

    uicontrol(f, 'Style', 'text', 'String', 'Questionnaire / device availability', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [18 145 220 18]);
    hMeta = uitable(f, ...
        'Units', 'pixels', ...
        'Position', [18 18 1332 120], ...
        'ColumnName', {}, ...
        'Data', {});

    S = struct();
    S.repoRoot = repoRoot;
    S.dataRoot = dataRoot;
    S.matRoot = matRoot;
    S.metaTable = metaTable;
    S.questionnaireTable = questionnaireTable;
    S.participants = participants;
    S.cache = struct();
    S.ax = ax;
    S.hParticipant = hParticipant;
    S.hDevice = hDevice;
    S.hSignal = hSignal;
    S.hSequence = hSequence;
    S.hPlotMode = hPlotMode;
    S.hWindow = hWindow;
    S.hPrewalk = hPrewalk;
    S.hRefresh = hRefresh;
    S.hShowPrewalk = hShowPrewalk;
    S.hShowWalking = hShowWalking;
    S.hStatus = hStatus;
    S.hInfo = hInfo;
    S.hPhase2 = hPhase2;
    S.hSurveys = hSurveys;
    S.hMeta = hMeta;
    S.lastAxisLimits = [];
    guidata(f, S);

    onParticipantChanged();

    if nargout > 0
        H = struct('figure', f, 'getState', @() guidata(f));
    end

    function onParticipantChanged(~, ~)
        S = guidata(f);
        prevDevice = localSelectedStringSafe(S.hDevice);
        prevSignal = localSelectedStringSafe(S.hSignal);
        prevSeq = localSelectedStringSafe(S.hSequence);
        participantID = localSelectedString(S.hParticipant);
        participant = localLoadParticipant(S.matRoot, participantID);
        S.cache.currentParticipant = participant;

        devices = fieldnames(participant.signals);
        if isempty(devices)
            devices = {' '};
        end
        set(S.hDevice, 'String', devices, ...
            'Value', localResolvePopupValue(devices, prevDevice, 1));

        phase2 = participant.markers.phase2;
        if istable(phase2) && ismember('seq', phase2.Properties.VariableNames)
            seqLabels = [{'ALL'}; cellstr(string(phase2.seq))];
        else
            seqLabels = {'ALL'};
        end
        defaultSeqValue = min(2, numel(seqLabels));
        set(S.hSequence, 'String', seqLabels, ...
            'Value', localResolvePopupValue(seqLabels, prevSeq, defaultSeqValue));

        S = localRefreshDeviceControls(S, prevSignal);
        guidata(f, S);
        onRefresh();
    end

    function onDeviceChanged(~, ~)
        S = guidata(f);
        prevSignal = localSelectedStringSafe(S.hSignal);
        S = localRefreshDeviceControls(S, prevSignal);
        guidata(f, S);
        onControlsChanged();
    end

    function onControlsChanged(~, ~)
        S = guidata(f);
        set(S.hStatus, 'String', 'Controls updated. Press Plot / Refresh to apply.', ...
            'ForegroundColor', [0.2 0.2 0.2]);
        guidata(f, S);
    end

    function onRefresh(~, ~)
        S = guidata(f);
        participant = S.cache.currentParticipant;
        deviceName = localSelectedString(S.hDevice);
        signalName = localSelectedString(S.hSignal);
        seqLabel = localSelectedString(S.hSequence);
        plotMode = localSelectedString(S.hPlotMode);
        windowMode = localSelectedString(S.hWindow);

        localPrepareAxes(S.ax);

        signalStruct = participant.signals.(deviceName);
        T = signalStruct.(signalName);
        if ~istable(T) || ~ismember('timestamp', T.Properties.VariableNames)
            text(S.ax, 0.5, 0.5, 'Selected signal is not a plottable time table.', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center');
            return;
        end

        phase2 = participant.markers.phase2;
        row = localResolvePhase2Row(phase2, seqLabel);
        infoText = localBuildInfoText(participant, deviceName, signalName, T, row);
        set(S.hInfo, 'String', infoText);

        [timeVec, yData, seriesNames, primaryLabel, regimeMeta] = localBuildPlotData(T, plotMode);
        hold(S.ax, 'on');
        colors = lines(size(yData, 2));
        for iLine = 1:size(yData, 2)
            plot(S.ax, timeVec, yData(:, iLine), 'LineWidth', 1.0, ...
                'Color', colors(iLine, :), 'DisplayName', seriesNames{iLine});
        end

        if strcmpi(windowMode, 'Selected sequence') && ~isempty(row)
            xlim(S.ax, localSequenceXLim(row));
        else
            xlim(S.ax, [min(timeVec) max(timeVec)]);
        end

        ylabel(S.ax, primaryLabel);
        xlabel(S.ax, 'Time (s)');
        title(S.ax, sprintf('%s | %s.%s', participant.id, deviceName, signalName), ...
            'Interpreter', 'none');
        grid(S.ax, 'on');
        localOverlayRegimes(S.ax, timeVec, regimeMeta);

        localOverlayMarkers(S.ax, participant.markers, row, seqLabel);

        if size(yData, 2) > 1
            legend(S.ax, 'Location', 'best');
        end
        hold(S.ax, 'off');

        localPopulateTables(S, participant);
        S.lastAxisLimits = axis(S.ax);
        set(S.hStatus, 'String', sprintf('Showing %s | %s.%s', participant.id, deviceName, signalName), ...
            'ForegroundColor', [0.2 0.2 0.2]);
        guidata(f, S);
    end

    function onShowPrewalkOnly(~, ~)
        S = guidata(f);
        participant = S.cache.currentParticipant;
        deviceName = localSelectedString(S.hDevice);
        signalName = localSelectedString(S.hSignal);
        seqLabel = localSelectedString(S.hSequence);
        plotMode = localSelectedString(S.hPlotMode);
        phase2 = participant.markers.phase2;
        row = localResolvePhase2Row(phase2, seqLabel);
        if isempty(row)
            set(S.hStatus, 'String', 'Select one sequence to show a pre-walk window.', ...
                'ForegroundColor', [0.75 0.25 0.2]);
            return;
        end

        signalStruct = participant.signals.(deviceName);
        T = signalStruct.(signalName);
        [timeVec, yData, seriesNames, primaryLabel, regimeMeta] = localBuildPlotData(T, plotMode);
        [tStart, tEnd, windowLabel] = localResolvePrewalkWindow(row, localSelectedString(S.hPrewalk));
        keep = timeVec >= tStart & timeVec <= tEnd;
        if ~any(keep)
            set(S.hStatus, 'String', 'No samples fell inside the selected pre-walk window.', ...
                'ForegroundColor', [0.75 0.25 0.2]);
            return;
        end

        localPrepareAxes(S.ax);
        hold(S.ax, 'on');
        colors = lines(size(yData, 2));
        for iLine = 1:size(yData, 2)
            plot(S.ax, timeVec(keep), yData(keep, iLine), 'LineWidth', 1.1, ...
                'Color', colors(iLine, :), 'DisplayName', seriesNames{iLine});
        end
        xlim(S.ax, [tStart tEnd]);
        ylabel(S.ax, primaryLabel);
        xlabel(S.ax, 'Time (s)');
        title(S.ax, sprintf('%s | %s.%s | %s', participant.id, deviceName, signalName, windowLabel), ...
            'Interpreter', 'none');
        grid(S.ax, 'on');
        regimeSubset = localSubsetRegimeMeta(regimeMeta, keep);
        localOverlayRegimes(S.ax, timeVec(keep), regimeSubset);
        localOverlayMarkers(S.ax, participant.markers, row, seqLabel);
        if size(yData, 2) > 1
            legend(S.ax, 'Location', 'best');
        end
        hold(S.ax, 'off');
        S.lastAxisLimits = axis(S.ax);
        set(S.hStatus, 'String', sprintf('Showing %s for seq %s', windowLabel, seqLabel), ...
            'ForegroundColor', [0.2 0.2 0.2]);
        guidata(f, S);
    end

    function onShowWalkingOnly(~, ~)
        S = guidata(f);
        participant = S.cache.currentParticipant;
        deviceName = localSelectedString(S.hDevice);
        signalName = localSelectedString(S.hSignal);
        seqLabel = localSelectedString(S.hSequence);
        plotMode = localSelectedString(S.hPlotMode);
        phase2 = participant.markers.phase2;
        row = localResolvePhase2Row(phase2, seqLabel);
        if isempty(row)
            set(S.hStatus, 'String', 'Select one sequence to show walking.', ...
                'ForegroundColor', [0.75 0.25 0.2]);
            return;
        end

        signalStruct = participant.signals.(deviceName);
        T = signalStruct.(signalName);
        [timeVec, yData, seriesNames, primaryLabel, regimeMeta] = localBuildPlotData(T, plotMode);
        tStart = double(row.walkB);
        tEnd = double(row.walkFinish);
        if ~isfinite(tStart) || ~isfinite(tEnd) || tEnd <= tStart
            set(S.hStatus, 'String', 'walkB / walkFinish markers are not usable for this sequence.', ...
                'ForegroundColor', [0.75 0.25 0.2]);
            return;
        end

        keep = timeVec >= tStart & timeVec <= tEnd;
        if ~any(keep)
            set(S.hStatus, 'String', 'No samples fell inside walkB to walkFinish.', ...
                'ForegroundColor', [0.75 0.25 0.2]);
            return;
        end

        localPrepareAxes(S.ax);
        hold(S.ax, 'on');
        colors = lines(size(yData, 2));
        for iLine = 1:size(yData, 2)
            plot(S.ax, timeVec(keep), yData(keep, iLine), 'LineWidth', 1.1, ...
                'Color', colors(iLine, :), 'DisplayName', seriesNames{iLine});
        end
        xlim(S.ax, [tStart tEnd]);
        ylabel(S.ax, primaryLabel);
        xlabel(S.ax, 'Time (s)');
        title(S.ax, sprintf('%s | %s.%s | walkB to walkFinish', participant.id, deviceName, signalName), ...
            'Interpreter', 'none');
        grid(S.ax, 'on');
        regimeSubset = localSubsetRegimeMeta(regimeMeta, keep);
        localOverlayRegimes(S.ax, timeVec(keep), regimeSubset);
        localOverlayMarkers(S.ax, participant.markers, row, seqLabel);
        if size(yData, 2) > 1
            legend(S.ax, 'Location', 'best');
        end
        hold(S.ax, 'off');
        S.lastAxisLimits = axis(S.ax);
        set(S.hStatus, 'String', sprintf('Showing walking for seq %s', seqLabel), ...
            'ForegroundColor', [0.2 0.2 0.2]);
        guidata(f, S);
    end
end

function S = localRefreshDeviceControls(S, preferredSignal)
    if nargin < 2
        preferredSignal = '';
    end
    participant = S.cache.currentParticipant;
    deviceName = localSelectedString(S.hDevice);
    if ~isfield(participant.signals, deviceName)
        deviceNames = fieldnames(participant.signals);
        deviceName = deviceNames{1};
        set(S.hDevice, 'String', deviceNames, 'Value', 1);
    end

    signalFields = fieldnames(participant.signals.(deviceName));
    plottable = {};
    for i = 1:numel(signalFields)
        value = participant.signals.(deviceName).(signalFields{i});
        if istable(value) && ismember('timestamp', value.Properties.VariableNames)
            plottable{end+1,1} = signalFields{i}; %#ok<AGROW>
        end
    end
    if isempty(plottable)
        plottable = {' '};
    end
    set(S.hSignal, 'String', plottable, ...
        'Value', localResolvePopupValue(plottable, preferredSignal, 1));
end

function localPopulateTables(S, participant)
    phase2 = participant.markers.phase2;
    if istable(phase2)
        set(S.hPhase2, 'Data', localTableToUiCell(phase2), 'ColumnName', phase2.Properties.VariableNames);
    else
        set(S.hPhase2, 'Data', cell(0, 0), 'ColumnName', {});
    end

    surveys = participant.surveys;
    if istable(surveys)
        set(S.hSurveys, 'Data', localTableToUiCell(surveys), 'ColumnName', surveys.Properties.VariableNames);
    else
        set(S.hSurveys, 'Data', cell(0, 0), 'ColumnName', {});
    end

    qRow = localSelectQuestionnaireRow(S.questionnaireTable, participant.idShort);
    mRows = localSelectMetaRows(S.metaTable, participant.idShort);
    infoTable = localCombineMetaTables(qRow, mRows);
    if isempty(infoTable)
        set(S.hMeta, 'Data', cell(0, 0), 'ColumnName', {});
    else
        set(S.hMeta, 'Data', localTableToUiCell(infoTable), 'ColumnName', infoTable.Properties.VariableNames);
    end
end

function participant = localLoadParticipant(matRoot, participantID)
    baseDir = fullfile(matRoot, participantID);
    if ~isfolder(baseDir)
        error('Participant folder not found: %s', baseDir);
    end

    signals = load(fullfile(baseDir, 'signals.mat'));
    markers = load(fullfile(baseDir, 'markers.mat'));
    surveys = load(fullfile(baseDir, 'surveys.mat'));
    params = load(fullfile(baseDir, 'params.mat'));

    participant = struct();
    participant.id = participantID;
    toks = regexp(participantID, '^\d+\-(.+)$', 'tokens', 'once');
    if isempty(toks)
        participant.idShort = participantID;
    else
        participant.idShort = string(toks{1});
    end
    participant.signals = signals.signals;
    participant.markers = markers.markers;
    participant.surveys = surveys.surveys;
    participant.params = params.params;
end

function participants = localCollectParticipants(matRoot)
    d = dir(matRoot);
    d = d([d.isdir]);
    participants = string({d.name});
    participants = participants(participants ~= "." & participants ~= "..");
    participants = sort(cellstr(participants));
end

function row = localResolvePhase2Row(phase2, seqLabel)
    row = [];
    if ~istable(phase2) || strcmpi(seqLabel, 'ALL') || ~ismember('seq', phase2.Properties.VariableNames)
        return;
    end
    seqNum = str2double(seqLabel);
    idx = find(double(phase2.seq) == seqNum, 1, 'first');
    if ~isempty(idx)
        row = phase2(idx, :);
    end
end

function [timeVec, yData, seriesNames, yLabel, regimeMeta] = localBuildPlotData(T, plotMode)
    timeVec = double(T.timestamp);
    vars = T.Properties.VariableNames;
    numericVars = setdiff(vars, {'timestamp'}, 'stable');
    numericVars = numericVars(varfun(@isnumeric, T(:, numericVars), 'OutputFormat', 'uniform'));
    regimeMeta = struct( ...
        'hasLowAnimation', false, ...
        'lowThreshold', NaN, ...
        'lowMask', [], ...
        'hasWalking', false, ...
        'walkThreshold', NaN, ...
        'walkMask', []);

    xyzTriplet = localPickTriplet(numericVars);
    if strcmpi(plotMode, 'Raw magnitude') && ~isempty(xyzTriplet)
        X = double(T.(xyzTriplet{1}));
        Y = double(T.(xyzTriplet{2}));
        Z = double(T.(xyzTriplet{3}));
        yData = sqrt(X.^2 + Y.^2 + Z.^2);
        seriesNames = {sprintf('|%s %s %s|', xyzTriplet{1}, xyzTriplet{2}, xyzTriplet{3})};
        yLabel = 'Raw magnitude';
        return;
    end

    if strcmpi(plotMode, 'Dynamic magnitude') && ~isempty(xyzTriplet)
        X = double(T.(xyzTriplet{1}));
        Y = double(T.(xyzTriplet{2}));
        Z = double(T.(xyzTriplet{3}));
        % Browser-side local motion-energy proxy:
        % use rolling per-axis standard deviation so orientation/posture
        % shifts do not appear as sustained dynamic offsets.
        motionMag = localRollingMotionMagnitude(timeVec, X, Y, Z);
        [lowMask, ~] = getLowAnimationFramesFromMotionMagnitude(motionMag, timeVec, ...
            'threshold', 40, 'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1);
        [walkMask, ~] = getContinuousWalkingFramesFromMotionMagnitude(motionMag, timeVec, ...
            'threshold', 100, 'minWalkDurationSec', 1.0, 'maxLowGapSec', 0.25);
        yData = motionMag;
        seriesNames = {sprintf('|rolling std %s %s %s|', xyzTriplet{1}, xyzTriplet{2}, xyzTriplet{3})};
        yLabel = 'Rolling motion magnitude';
        regimeMeta.hasLowAnimation = true;
        regimeMeta.lowThreshold = 40;
        regimeMeta.lowMask = lowMask;
        regimeMeta.hasWalking = true;
        regimeMeta.walkThreshold = 100;
        regimeMeta.walkMask = walkMask;
        return;
    end

    if ~isempty(xyzTriplet)
        yData = [double(T.(xyzTriplet{1})), double(T.(xyzTriplet{2})), double(T.(xyzTriplet{3}))];
        seriesNames = xyzTriplet(:)';
        yLabel = 'Axis value';
        return;
    end

    firstN = min(3, numel(numericVars));
    pick = numericVars(1:firstN);
    yData = zeros(height(T), firstN);
    for i = 1:firstN
        yData(:, i) = double(T.(pick{i}));
    end
    seriesNames = pick(:)';
    yLabel = 'Value';
end

function localOverlayRegimes(ax, timeVec, regimeMeta)
    if ~isstruct(regimeMeta) || isempty(timeVec)
        return;
    end

    yl = ylim(ax);
    hold(ax, 'on');

    if isfield(regimeMeta, 'hasLowAnimation') && regimeMeta.hasLowAnimation && isfield(regimeMeta, 'lowMask')
        lowMask = logical(regimeMeta.lowMask(:));
        if numel(lowMask) == numel(timeVec)
            bouts = localMaskToTimeBouts(timeVec, lowMask);
            for i = 1:size(bouts, 1)
                patch(ax, ...
                    [bouts(i, 1) bouts(i, 2) bouts(i, 2) bouts(i, 1)], ...
                    [yl(1) yl(1) yl(2) yl(2)], ...
                    [0.65 0.86 0.65], ...
                    'FaceAlpha', 0.14, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            end
            yline(ax, regimeMeta.lowThreshold, '--', sprintf('low-animation threshold (%.0f)', regimeMeta.lowThreshold), ...
                'Color', [0.15 0.55 0.15], ...
                'HandleVisibility', 'off');
        end
    end

    if isfield(regimeMeta, 'hasWalking') && regimeMeta.hasWalking && isfield(regimeMeta, 'walkMask')
        walkMask = logical(regimeMeta.walkMask(:));
        if numel(walkMask) == numel(timeVec)
            bouts = localMaskToTimeBouts(timeVec, walkMask);
            for i = 1:size(bouts, 1)
                patch(ax, ...
                    [bouts(i, 1) bouts(i, 2) bouts(i, 2) bouts(i, 1)], ...
                    [yl(1) yl(1) yl(2) yl(2)], ...
                    [0.97 0.82 0.58], ...
                    'FaceAlpha', 0.12, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            end
            yline(ax, regimeMeta.walkThreshold, ':', sprintf('walking threshold (%.0f)', regimeMeta.walkThreshold), ...
                'Color', [0.82 0.45 0.05], ...
                'HandleVisibility', 'off');
        end
    end

    localBringPrimaryTraceToFront(ax);
    hold(ax, 'off');
end

function regimeSubset = localSubsetRegimeMeta(regimeMeta, keep)
    regimeSubset = regimeMeta;
    if isfield(regimeMeta, 'hasLowAnimation') && regimeMeta.hasLowAnimation && isfield(regimeMeta, 'lowMask')
        regimeSubset.lowMask = regimeMeta.lowMask(keep);
    end
    if isfield(regimeMeta, 'hasWalking') && regimeMeta.hasWalking && isfield(regimeMeta, 'walkMask')
        regimeSubset.walkMask = regimeMeta.walkMask(keep);
    end
end

function localBringPrimaryTraceToFront(ax)
    lines = findobj(ax, 'Type', 'line');
    if isempty(lines)
        return;
    end
    uistack(lines, 'top');
end

function localPrepareAxes(ax)
    hold(ax, 'off');
    delete(findall(ax, 'Type', 'patch'));
    delete(findall(ax, 'Type', 'ConstantLine'));
    delete(findall(ax, 'Type', 'line'));
    cla(ax);
end

function bouts = localMaskToTimeBouts(timeVec, mask)
    bouts = zeros(0, 2);
    d = diff([false; mask(:); false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    if isempty(starts)
        return;
    end

    dt = diff(timeVec);
    dt = dt(isfinite(dt) & dt > 0);
    if isempty(dt)
        halfStep = 0;
    else
        halfStep = 0.5 * median(dt, 'omitnan');
    end

    bouts = zeros(numel(starts), 2);
    for i = 1:numel(starts)
        t1 = timeVec(starts(i)) - halfStep;
        t2 = timeVec(ends(i)) + halfStep;
        bouts(i, :) = [t1, t2];
    end
end

function triplet = localPickTriplet(varNames)
    triplet = {};
    if all(ismember({'x','y','z'}, varNames))
        triplet = {'x','y','z'};
        return;
    end

    prefixes = {'1_lis2dw12','2_lis3dhh','3_lsm6dsox'};
    for i = 1:numel(prefixes)
        cand = {['x' prefixes{i}], ['y' prefixes{i}], ['z' prefixes{i}]};
        if all(ismember(cand, varNames))
            triplet = cand;
            return;
        end
    end
end

function motionMag = localRollingMotionMagnitude(timeVec, X, Y, Z)
    if numel(timeVec) < 5
        motionMag = nan(size(timeVec));
        return;
    end

    dt = diff(timeVec);
    dt = dt(isfinite(dt) & dt > 0);
    if isempty(dt)
        motionMag = nan(size(timeVec));
        return;
    end

    sampleRate = 1 / median(dt, 'omitnan');
    if ~isfinite(sampleRate) || sampleRate <= 0
        motionMag = nan(size(timeVec));
        return;
    end

    winSec = 0.5;
    winSamples = max(5, round(winSec * sampleRate));
    if mod(winSamples, 2) == 0
        winSamples = winSamples + 1;
    end

    xStd = localMovStdNanSafe(X, winSamples);
    yStd = localMovStdNanSafe(Y, winSamples);
    zStd = localMovStdNanSafe(Z, winSamples);
    motionMag = sqrt(xStd.^2 + yStd.^2 + zStd.^2);
end

function out = localMovStdNanSafe(x, winSamples)
    x = double(x);
    finiteMask = isfinite(x);
    if ~any(finiteMask)
        out = nan(size(x));
        return;
    end

    xFilled = x;
    xFilled(~finiteMask) = interp1(find(finiteMask), x(finiteMask), find(~finiteMask), 'linear', 'extrap');
    out = movstd(xFilled, winSamples, 0, 'omitnan', 'Endpoints', 'shrink');
    out(~finiteMask) = nan;
end

function localOverlayMarkers(ax, markers, row, seqLabel)
    colors = struct( ...
        'preB', [0.45 0.45 0.45], ...
        'vidB', [0.15 0.45 0.95], ...
        'surveyB', [0.8 0.25 0.6], ...
        'walkB', [0.1 0.7 0.2], ...
        'walkDetect', [0.95 0.45 0.1], ...
        'walkE', [0.8 0.1 0.1], ...
        'walkFinish', [0.55 0.15 0.15]);

    if ~isempty(row)
        markerNames = {'preB','vidB','surveyB','walkB','walkDetect','walkE','walkFinish'};
        for i = 1:numel(markerNames)
            name = markerNames{i};
            if ismember(name, row.Properties.VariableNames) && ~ismissing(row.(name)) && ~isnan(row.(name))
                    xline(ax, double(row.(name)), '-', name, ...
                    'Color', colors.(name), 'LabelOrientation', 'horizontal', ...
                    'LabelVerticalAlignment', 'middle');
            end
        end
        return;
    end

    if strcmpi(seqLabel, 'ALL') && isfield(markers, 'phase2') && istable(markers.phase2)
        phase2 = markers.phase2;
        thinNames = {'walkB','walkE'};
        for i = 1:numel(thinNames)
            name = thinNames{i};
            if ismember(name, phase2.Properties.VariableNames)
                vals = double(phase2.(name));
                vals = vals(~isnan(vals));
                for j = 1:numel(vals)
                    xline(ax, vals(j), ':', 'Color', colors.(name), 'HandleVisibility', 'off');
                end
            end
        end
    end
end

function xlimVals = localSequenceXLim(row)
    xStart = min([double(row.preB), double(row.vidB), double(row.walkB)]) - 10;
    xEnd = max([double(row.walkFinish), double(row.walkE), double(row.surveyB)]) + 10;
    xlimVals = [xStart xEnd];
end

function [tStart, tEnd, label] = localResolvePrewalkWindow(row, modeName)
    walkB = double(row.walkB);
    walkDetect = double(row.walkDetect);
    preB = double(row.preB);

    switch modeName
        case 'preB -> walkB'
            tStart = preB;
            tEnd = walkB;
            label = 'preB to walkB';
        case 'preB -> walkDetect'
            tStart = preB;
            tEnd = walkDetect;
            label = 'preB to walkDetect';
        case '5 s before walkB'
            tStart = walkB - 5;
            tEnd = walkB;
            label = '5 s before walkB';
        case '5 s before walkDetect'
            tStart = walkDetect - 5;
            tEnd = walkDetect;
            label = '5 s before walkDetect';
        otherwise
            tStart = preB;
            tEnd = walkB;
            label = modeName;
    end
end

function txt = localBuildInfoText(participant, deviceName, signalName, T, row)
    signalFields = strjoin(fieldnames(participant.signals)', ', ');
    currentVars = strjoin(T.Properties.VariableNames, ', ');
    markerSummary = 'No sequence selected';
    if ~isempty(row)
        markerSummary = sprintf('seq=%g exp=%g | preB=%.2f | walkB=%.2f | walkDetect=%.2f | walkE=%.2f', ...
            double(row.seq), double(row.exp), double(row.preB), double(row.walkB), ...
            double(row.walkDetect), double(row.walkE));
    end
    txt = sprintf([ ...
        'Participant: %s\n' ...
        'Short ID: %s\n' ...
        'Available devices: %s\n' ...
        'Current view: %s.%s\n' ...
        'Rows x cols: %d x %d\n' ...
        'Columns: %s\n' ...
        'Marker summary: %s'], ...
        participant.id, char(string(participant.idShort)), signalFields, deviceName, signalName, ...
        height(T), width(T), currentVars, markerSummary);
end

function qRow = localSelectQuestionnaireRow(questionnaireTable, idShort)
    qRow = table();
    if ismember('ID', questionnaireTable.Properties.VariableNames)
        mask = string(questionnaireTable.ID) == string(idShort);
        qRow = questionnaireTable(mask, :);
    end
end

function mRows = localSelectMetaRows(metaTable, idShort)
    mRows = table();
    if ismember('ID', metaTable.Properties.VariableNames)
        mask = string(metaTable.ID) == string(idShort);
        mRows = metaTable(mask, :);
    end
end

function out = localCombineMetaTables(qRow, mRows)
    if isempty(qRow) && isempty(mRows)
        out = table();
        return;
    end

    fieldCol = strings(0, 1);
    valueCol = strings(0, 1);
    sourceCol = strings(0, 1);

    if ~isempty(qRow)
        keep = intersect({'ID','Age','Gender','Handedness','Level of Alertness'}, ...
            qRow.Properties.VariableNames, 'stable');
        for i = 1:numel(keep)
            fieldCol(end+1, 1) = string(keep{i}); %#ok<AGROW>
            valueCol(end+1, 1) = string(qRow.(keep{i})(1)); %#ok<AGROW>
            sourceCol(end+1, 1) = "questionnaire"; %#ok<AGROW>
        end
    end

    if ~isempty(mRows)
        keep = intersect({'Sequence','Experiment','Empatica E4','Zephyr BioHarness 3','Front STb','Back STb','Water STb','Notes'}, ...
            mRows.Properties.VariableNames, 'stable');
        firstRow = mRows(1, :);
        for i = 1:numel(keep)
            fieldCol(end+1, 1) = "meta." + string(keep{i}); %#ok<AGROW>
            valueCol(end+1, 1) = string(firstRow.(keep{i})(1)); %#ok<AGROW>
            sourceCol(end+1, 1) = "meta"; %#ok<AGROW>
        end
    end

    out = table(sourceCol, fieldCol, valueCol, ...
        'VariableNames', {'Source','Field','Value'});
end

function C = localTableToUiCell(T)
    C = table2cell(T);
    for i = 1:numel(C)
        v = C{i};
        if isstring(v)
            if any(ismissing(v))
                C{i} = '';
            elseif isscalar(v)
                C{i} = char(v);
            else
                C{i} = char(strjoin(v, ", "));
            end
        elseif (isnumeric(v) || islogical(v)) && isscalar(v) && ismissing(v)
            C{i} = '';
        end
    end
end

function s = localSelectedString(h)
    items = cellstr(string(get(h, 'String')));
    idx = get(h, 'Value');
    idx = min(max(1, idx), numel(items));
    s = items{idx};
end

function s = localSelectedStringSafe(h)
    if isempty(h) || ~isgraphics(h)
        s = '';
        return;
    end
    items = get(h, 'String');
    if isempty(items)
        s = '';
        return;
    end
    s = localSelectedString(h);
end

function idx = localResolvePopupValue(options, preferred, fallback)
    opts = cellstr(string(options));
    idx = find(strcmp(opts, char(string(preferred))), 1, 'first');
    if isempty(idx)
        idx = min(max(1, fallback), numel(opts));
    end
end

function repoRoot = localInferRepoRoot()
    thisFile = mfilename('fullpath');
    repoRoot = fileparts(fileparts(fileparts(fileparts(thisFile))));
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
