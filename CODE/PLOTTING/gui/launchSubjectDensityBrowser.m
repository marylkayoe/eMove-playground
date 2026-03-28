function H = launchSubjectDensityBrowser(varargin)
% launchSubjectDensityBrowser - Interactive browser for subject-level speed densities.
%
% Usage:
%   launchSubjectDensityBrowser()
%   launchSubjectDensityBrowser('resultsCellPath', '/path/to/resultsCell.mat')
%
% This GUI lets the user choose:
%   - one subject
%   - one or more bodypart marker groups
%   - one or more emotions
%   - full-speed vs micromovement-only regime
%   - baseline-normalized vs absolute values
%   - percentile-based x-axis clipping to suppress very long tails
%   - optional per-panel significance annotation
%
% It then calls plotSubjectSpeedDensityByEmotion using the chosen settings
% and opens the resulting figure.
%
% Browser-specific notes:
%   - left/right groups are collapsed into combined display aliases:
%       Arms   = UPPER_LIMB_L + UPPER_LIMB_R
%       Wrists = WRIST_L + WRIST_R
%       Legs   = LOWER_LIMB_L + LOWER_LIMB_R
%   - the browser can export the current plot as Illustrator-friendly EPS
%     using painters rendering (`print -depsc`).

p = inputParser;
addParameter(p, 'repoRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'dataRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'resultsCellPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'stimCsv', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'defaultUseImmobile', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'defaultBaselineNormalize', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'defaultImmobilityThreshold', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'defaultXLimitQuantile', 0.95, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
parse(p, varargin{:});

repoRoot = char(string(p.Results.repoRoot));
dataRoot = char(string(p.Results.dataRoot));
resultsCellPath = char(string(p.Results.resultsCellPath));
stimCsv = char(string(p.Results.stimCsv));

if isempty(strtrim(repoRoot))
    repoRoot = localInferRepoRoot();
end
if isempty(strtrim(dataRoot))
    dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
end
if isempty(strtrim(stimCsv))
    stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
end
if isempty(strtrim(resultsCellPath))
    analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
    latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
    resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');
end

if ~isfile(resultsCellPath)
    error('launchSubjectDensityBrowser:BadResultsCell', 'resultsCell file not found: %s', resultsCellPath);
end
if ~isfile(stimCsv)
    error('launchSubjectDensityBrowser:BadStimCsv', 'Stim CSV not found: %s', stimCsv);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

Sload = load(resultsCellPath, 'resultsCell');
if ~isfield(Sload, 'resultsCell')
    error('launchSubjectDensityBrowser:MissingResultsCell', 'resultsCell variable missing in %s', resultsCellPath);
end
resultsCell = Sload.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);
[markerGroups, markerGroupAliasMap] = localCollectMarkerGroups(resultsCell);
emotionList = localCollectEmotionList(codingTable);
subjectIDs = localCollectSubjectIDs(resultsCell);

state = struct();
state.resultsCell = resultsCell;
state.codingTable = codingTable;
state.resultsCellPath = resultsCellPath;
state.stimCsv = stimCsv;
state.markerGroups = markerGroups;
state.markerGroupAliasMap = markerGroupAliasMap;
state.emotionList = emotionList;
state.subjectIDs = subjectIDs;
state.subjectIndexMap = localBuildSubjectIndexMap(resultsCell);
state.groupCheckboxes = gobjects(0);
state.emotionCheckboxes = gobjects(0);
state.currentPlotFigure = [];

existingControl = findall(groot, 'Type', 'figure', 'Tag', 'SubjectDensityBrowserControl');
if ~isempty(existingControl)
    figure(existingControl(1));
    if nargout > 0
        H = struct();
        H.controlFigure = existingControl(1);
        H.getState = @() guidata(existingControl(1));
    end
    return;
end

f = figure( ...
    'Name', 'Subject Density Browser', ...
    'Tag', 'SubjectDensityBrowserControl', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Units', 'pixels', ...
    'Position', [120 90 760 840]);

leftLabelX = 20;
leftFieldX = 140;
leftFieldW = 230;
rightLabelX = 410;
rightFieldX = 590;
rightFieldW = 120;

uicontrol(f, 'Style', 'text', 'String', 'Subject', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [leftLabelX 760 100 20]);
hSubject = uicontrol(f, 'Style', 'popupmenu', ...
    'String', subjectIDs, ...
    'Value', 1, ...
    'Position', [leftFieldX 756 leftFieldW 28], ...
    'Callback', @onControlsChanged);

uicontrol(f, 'Style', 'text', 'String', 'Emotions', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [leftLabelX 724 100 20]);
hEmotionPanel = uipanel(f, ...
    'Units', 'pixels', ...
    'Position', [leftFieldX 610 leftFieldW 112], ...
    'BackgroundColor', 'w', ...
    'BorderType', 'line');
hEmotionAll = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'All', ...
    'Position', [leftLabelX 690 60 26], ...
    'Callback', @onSelectAllEmotions);
hEmotionNone = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'None', ...
    'Position', [leftLabelX 656 60 26], ...
    'Callback', @onSelectNoEmotions);

uicontrol(f, 'Style', 'text', 'String', 'Bodyparts', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [leftLabelX 586 100 20]);
hGroupPanel = uipanel(f, ...
    'Units', 'pixels', ...
    'Position', [leftFieldX 300 leftFieldW 278], ...
    'BackgroundColor', 'w', ...
    'BorderType', 'line');
hGroupAll = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'All', ...
    'Position', [leftLabelX 552 60 26], ...
    'Callback', @onSelectAllGroups);
hGroupNone = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'None', ...
    'Position', [leftLabelX 518 60 26], ...
    'Callback', @onSelectNoGroups);

hImmobile = uicontrol(f, 'Style', 'checkbox', ...
    'String', 'Micromovement only', ...
    'Value', p.Results.defaultUseImmobile, ...
    'BackgroundColor', 'w', ...
    'Position', [rightLabelX 704 180 24], ...
    'Callback', @onControlsChanged);

hNormalize = uicontrol(f, 'Style', 'checkbox', ...
    'String', 'Baseline-normalized', ...
    'Value', p.Results.defaultBaselineNormalize, ...
    'BackgroundColor', 'w', ...
    'Position', [rightLabelX 672 180 24], ...
    'Callback', @onControlsChanged);

hStats = uicontrol(f, 'Style', 'checkbox', ...
    'String', 'Show stats', ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [rightLabelX 640 180 24], ...
    'Callback', @onControlsChanged);

uicontrol(f, 'Style', 'text', 'String', 'X-limit quantile', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [rightLabelX 596 140 20]);
hXLimitQuantile = uicontrol(f, 'Style', 'edit', ...
    'String', num2str(p.Results.defaultXLimitQuantile), ...
    'BackgroundColor', 'w', ...
    'Position', [rightFieldX 592 rightFieldW 28], ...
    'Callback', @onNumericEdited);

    uicontrol(f, 'Style', 'text', 'String', 'Immobility threshold', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [rightLabelX 552 140 20]);
hImmThr = uicontrol(f, 'Style', 'edit', ...
    'String', num2str(p.Results.defaultImmobilityThreshold), ...
    'BackgroundColor', 'w', ...
    'Position', [rightFieldX 548 rightFieldW 28], ...
    'Callback', @onNumericEdited);

hRefresh = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'Plot / Refresh', ...
    'Position', [20 244 170 44], ...
    'Callback', @onRefresh);
hClosePlot = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'Close Plot', ...
    'Position', [200 244 170 44], ...
    'Callback', @onClosePlot);
hExportEps = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'Export EPS', ...
    'Position', [380 244 170 44], ...
    'Callback', @onExportEps);

hStatus = uicontrol(f, 'Style', 'text', ...
    'String', 'Ready', ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.2 0.2 0.2], ...
    'Position', [20 206 700 26]);

hInfo = uicontrol(f, 'Style', 'text', ...
    'String', sprintf('resultsCell: %s\nStim coding: %s', resultsCellPath, stimCsv), ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.25 0.25 0.25], ...
    'Position', [20 24 700 164]);

S = struct();
S.state = state;
S.hSubject = hSubject;
S.hEmotionPanel = hEmotionPanel;
S.hEmotionAll = hEmotionAll;
S.hEmotionNone = hEmotionNone;
S.hGroupPanel = hGroupPanel;
S.hGroupAll = hGroupAll;
S.hGroupNone = hGroupNone;
S.hImmobile = hImmobile;
S.hNormalize = hNormalize;
S.hStats = hStats;
S.hXLimitQuantile = hXLimitQuantile;
S.hImmThr = hImmThr;
S.hRefresh = hRefresh;
S.hClosePlot = hClosePlot;
S.hExportEps = hExportEps;
S.hStatus = hStatus;
S.hInfo = hInfo;
guidata(f, S);

S = localRebuildEmotionCheckboxes(S, emotionList, {'DISGUST','NEUTRAL'});
S = localRebuildGroupCheckboxes(S, markerGroups);
guidata(f, S);
onRefresh();

if nargout > 0
    H = struct();
    H.controlFigure = f;
    H.getState = @() guidata(f);
end

    function onControlsChanged(~, ~)
        S = guidata(f);
        set(S.hStatus, 'String', 'Controls updated. Press Plot / Refresh to apply.', ...
            'ForegroundColor', [0.2 0.2 0.2]);
        guidata(f, S);
    end

    function onNumericEdited(~, ~)
        onControlsChanged();
    end

    function onSelectAllGroups(~, ~)
        S = guidata(f);
        for i = 1:numel(S.state.groupCheckboxes)
            if isgraphics(S.state.groupCheckboxes(i))
                set(S.state.groupCheckboxes(i), 'Value', 1);
            end
        end
        guidata(f, S);
        onControlsChanged();
    end

    function onSelectNoGroups(~, ~)
        S = guidata(f);
        for i = 1:numel(S.state.groupCheckboxes)
            if isgraphics(S.state.groupCheckboxes(i))
                set(S.state.groupCheckboxes(i), 'Value', 0);
            end
        end
        guidata(f, S);
        onControlsChanged();
    end

    function onSelectAllEmotions(~, ~)
        S = guidata(f);
        for i = 1:numel(S.state.emotionCheckboxes)
            if isgraphics(S.state.emotionCheckboxes(i))
                set(S.state.emotionCheckboxes(i), 'Value', 1);
            end
        end
        guidata(f, S);
        onControlsChanged();
    end

    function onSelectNoEmotions(~, ~)
        S = guidata(f);
        for i = 1:numel(S.state.emotionCheckboxes)
            if isgraphics(S.state.emotionCheckboxes(i))
                set(S.state.emotionCheckboxes(i), 'Value', 0);
            end
        end
        guidata(f, S);
        onControlsChanged();
    end

    function onRefresh(~, ~)
        S = guidata(f);
        try
            settings = localReadControls(S);
            if isempty(settings.markerGroups)
                error('Select at least one bodypart.');
            end
            if isempty(settings.emotions)
                error('Choose at least one emotion.');
            end

            staleFigs = findall(groot, 'Type', 'figure', 'Tag', 'SubjectDensityBrowserPlot');
            for k = 1:numel(staleFigs)
                if ishandle(staleFigs(k))
                    close(staleFigs(k));
                end
            end
            if ~isempty(S.state.currentPlotFigure) && ishandle(S.state.currentPlotFigure)
                close(S.state.currentPlotFigure);
            end

            subjectPopupIdx = get(S.hSubject, 'Value');
            subjectID = char(string(subjectIDs{subjectPopupIdx}));
            rcIdx = S.state.subjectIndexMap(subjectID);
            rc = S.state.resultsCell{rcIdx};
            regimeLabel = ternary(settings.useImmobile, ...
                sprintf('micromovement (<= %g mm/s)', settings.immobilityThreshold), ...
                'full motion');
            figTitle = sprintf('%s | %s | %s', ...
                subjectID, ...
                strjoin(settings.emotions, ', '), ...
                regimeLabel);

            plotFig = plotSubjectSpeedDensityByEmotion(rc, S.state.codingTable, ...
                'markerGroups', settings.markerGroups, ...
                'markerGroupAliases', S.state.markerGroupAliasMap, ...
                'emotions', settings.emotions, ...
                'useImmobile', settings.useImmobile, ...
                'doBaselineNormalize', settings.doBaselineNormalize, ...
                'baselineEmotion', 'BASELINE', ...
                'immobilityThreshold', settings.immobilityThreshold, ...
                'minBaselineSamples', 20, ...
                'xLimitQuantile', settings.xLimitQuantile, ...
                'figureTitle', figTitle, ...
                'showStats', settings.showStats);

            set(plotFig, 'Name', sprintf('Subject Density - %s', subjectID));
            set(plotFig, 'Tag', 'SubjectDensityBrowserPlot');
            S.state.currentPlotFigure = plotFig;
            set(S.hStatus, 'String', sprintf('Plotted %s | %s', subjectID, regimeLabel), ...
                'ForegroundColor', [0.2 0.2 0.2]);
            guidata(f, S);
        catch ME
            set(S.hStatus, 'String', sprintf('Error: %s', ME.message), ...
                'ForegroundColor', [0.7 0.1 0.1]);
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

    function onExportEps(~, ~)
        S = guidata(f);
        if isempty(S.state.currentPlotFigure) || ~ishandle(S.state.currentPlotFigure)
            set(S.hStatus, 'String', 'No plot is open to export.', ...
                'ForegroundColor', [0.7 0.1 0.1]);
            guidata(f, S);
            return;
        end
        try
            settings = localReadControls(S);
            subjectLabel = char(string(subjectIDs{get(S.hSubject, 'Value')}));
            groupLabel = strjoin(settings.markerGroups, '_');
            emotionLabel = strjoin(settings.emotions, '_');
            if isempty(groupLabel), groupLabel = 'no_groups'; end
            if isempty(emotionLabel), emotionLabel = 'no_emotions'; end
            regimeLabel = ternary(settings.useImmobile, 'micro', 'full');
            normLabel = ternary(settings.doBaselineNormalize, 'baseline_normalized', 'absolute');
            defaultName = sprintf('subject_density_%s_%s_%s_%s.eps', ...
                subjectLabel, emotionLabel, groupLabel, [regimeLabel '_' normLabel]);
            defaultName = regexprep(defaultName, '[^\w.-]+', '_');
            [fileName, filePath] = uiputfile('*.eps', 'Export subject density plot as EPS', defaultName);
            if isequal(fileName, 0) || isequal(filePath, 0)
                set(S.hStatus, 'String', 'EPS export canceled.', ...
                    'ForegroundColor', [0.2 0.2 0.2]);
                guidata(f, S);
                return;
            end
            fig = S.state.currentPlotFigure;
            oldRendererMode = get(fig, 'RendererMode');
            oldRenderer = get(fig, 'Renderer');
            set(fig, 'Renderer', 'painters');
            drawnow;
            saveFileName = fullfile(filePath, fileName);
            print(fig, '-depsc', saveFileName);
            if strcmpi(oldRendererMode, 'manual')
                set(fig, 'Renderer', oldRenderer);
            else
                set(fig, 'RendererMode', oldRendererMode);
            end
            set(S.hStatus, 'String', sprintf('Exported EPS: %s', saveFileName), ...
                'ForegroundColor', [0.2 0.2 0.2]);
            guidata(f, S);
        catch ME
            set(S.hStatus, 'String', sprintf('EPS export failed: %s', ME.message), ...
                'ForegroundColor', [0.7 0.1 0.1]);
            guidata(f, S);
        end
    end
end

function S = localRebuildEmotionCheckboxes(S, emotions, selectedEmotions)
oldBoxes = S.state.emotionCheckboxes;
for i = 1:numel(oldBoxes)
    if isgraphics(oldBoxes(i))
        delete(oldBoxes(i));
    end
end
n = numel(emotions);
boxes = gobjects(n, 1);
panelPos = get(S.hEmotionPanel, 'Position');
startY = panelPos(4) - 28;
stepY = 21;
for i = 1:n
    y = startY - (i - 1) * stepY;
    boxes(i) = uicontrol(S.hEmotionPanel, ...
        'Style', 'checkbox', ...
        'String', emotions{i}, ...
        'Value', any(strcmp(emotions{i}, selectedEmotions)), ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'Position', [8 max(2, y) 190 20], ...
        'Callback', @onBrowserCheckboxChanged);
end
S.state.emotionCheckboxes = boxes;
end

function S = localRebuildGroupCheckboxes(S, groups)
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
stepY = 23;
for i = 1:n
    y = startY - (i - 1) * stepY;
    boxes(i) = uicontrol(S.hGroupPanel, ...
        'Style', 'checkbox', ...
        'String', groups{i}, ...
        'Value', i <= min(3, n), ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'Position', [8 max(2, y) 190 20], ...
        'Callback', @onBrowserCheckboxChanged);
end
S.state.groupCheckboxes = boxes;
end

function onBrowserCheckboxChanged(src, ~)
f = ancestor(src, 'figure');
if isempty(f) || ~ishandle(f)
    return;
end
refreshBtn = findobj(f, 'Style', 'pushbutton', 'String', 'Plot / Refresh');
if isempty(refreshBtn)
    return;
end
    S = guidata(f);
    set(S.hStatus, 'String', 'Controls updated. Press Plot / Refresh to apply.', ...
        'ForegroundColor', [0.2 0.2 0.2]);
    guidata(f, S);
end

function settings = localReadControls(S)
subjectItems = get(S.hSubject, 'String');
settings = struct();
settings.subjectID = char(string(subjectItems{get(S.hSubject, 'Value')}));
settings.useImmobile = logical(get(S.hImmobile, 'Value'));
settings.doBaselineNormalize = logical(get(S.hNormalize, 'Value'));
settings.showStats = logical(get(S.hStats, 'Value'));
settings.xLimitQuantile = min(1, max(0.5, localParseNumericEdit(S.hXLimitQuantile, 0.95)));
settings.immobilityThreshold = max(0, localParseNumericEdit(S.hImmThr, 35));
settings.emotions = {};
for i = 1:numel(S.state.emotionCheckboxes)
    h = S.state.emotionCheckboxes(i);
    if isgraphics(h) && logical(get(h, 'Value'))
        settings.emotions{end+1} = char(string(get(h, 'String'))); %#ok<AGROW>
    end
end
markerGroups = {};
for i = 1:numel(S.state.groupCheckboxes)
    h = S.state.groupCheckboxes(i);
    if isgraphics(h) && logical(get(h, 'Value'))
        markerGroups{end+1} = char(string(get(h, 'String'))); %#ok<AGROW>
    end
end
settings.markerGroups = markerGroups;
end

function val = localParseNumericEdit(h, fallback)
val = str2double(string(get(h, 'String')));
if ~isfinite(val)
    val = fallback;
    set(h, 'String', num2str(val));
end
end

function [markerGroups, aliasMap] = localCollectMarkerGroups(resultsCell)
markerGroups = {};
for s = 1:numel(resultsCell)
    rc = resultsCell{s};
    if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
        continue;
    end
    st = rc.summaryTable;
    if ismember('markerGroup', st.Properties.VariableNames)
        markerGroups = [markerGroups; unique(cellstr(string(st.markerGroup)), 'stable')]; %#ok<AGROW>
    end
end
markerGroups = unique(markerGroups, 'stable');
aliasMap = struct();
aliasMap.HEAD = {'HEAD'};
aliasMap.UTORSO = {'UTORSO'};
aliasMap.LTORSO = {'LTORSO'};
aliasMap.ARMS = {'UPPER_LIMB_L','UPPER_LIMB_R'};
aliasMap.WRISTS = {'WRIST_L','WRIST_R'};
aliasMap.LEGS = {'LOWER_LIMB_L','LOWER_LIMB_R'};
collapsedGroups = {};
if any(strcmp(markerGroups, 'HEAD')), collapsedGroups{end+1} = 'HEAD'; end %#ok<AGROW>
if any(strcmp(markerGroups, 'UTORSO')), collapsedGroups{end+1} = 'UTORSO'; end %#ok<AGROW>
if any(strcmp(markerGroups, 'LTORSO')), collapsedGroups{end+1} = 'LTORSO'; end %#ok<AGROW>
if any(ismember(markerGroups, {'UPPER_LIMB_L','UPPER_LIMB_R'})), collapsedGroups{end+1} = 'ARMS'; end %#ok<AGROW>
if any(ismember(markerGroups, {'WRIST_L','WRIST_R'})), collapsedGroups{end+1} = 'WRISTS'; end %#ok<AGROW>
if any(ismember(markerGroups, {'LOWER_LIMB_L','LOWER_LIMB_R'})), collapsedGroups{end+1} = 'LEGS'; end %#ok<AGROW>
markerGroups = collapsedGroups;
end

function emotionList = localCollectEmotionList(codingTable)
emotionList = unique(cellstr(string(codingTable{:,2})), 'stable');
emotionList = setdiff(emotionList, {'BASELINE','0','X','AMUSEMENT',''}, 'stable');
end

function subjectIDs = localCollectSubjectIDs(resultsCell)
subjectIDs = {};
for i = 1:numel(resultsCell)
    if isfield(resultsCell{i}, 'subjectID') && ~isempty(resultsCell{i}.subjectID)
        subjectIDs{end+1,1} = char(string(resultsCell{i}.subjectID)); %#ok<AGROW>
    end
end
subjectIDs = unique(subjectIDs, 'stable');
end

function subjectIndexMap = localBuildSubjectIndexMap(resultsCell)
subjectIndexMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:numel(resultsCell)
    if isfield(resultsCell{i}, 'subjectID') && ~isempty(resultsCell{i}.subjectID)
        subjectID = char(string(resultsCell{i}.subjectID));
        if ~isKey(subjectIndexMap, subjectID)
            subjectIndexMap(subjectID) = i;
        end
    end
end
end

function latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot)
d = dir(analysisRunsRoot);
d = d([d.isdir]);
names = string({d.name});
names = names(names ~= "." & names ~= "..");
isRun = ~cellfun('isempty', regexp(cellstr(names), '^\d{8}_\d{6}$', 'once'));
names = sort(names(isRun));
if isempty(names)
    error('No timestamped analysis runs found under %s', analysisRunsRoot);
end
latestRunDir = fullfile(analysisRunsRoot, char(names(end)));
end

function codingTable = localLoadStimCodingTable(stimCsv)
opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
strCols = {'videoID','emotionTag','groupCode'};
strCols = intersect(strCols, opts.VariableNames, 'stable');
if ~isempty(strCols)
    opts = setvartype(opts, strCols, 'string');
end
T = readtable(stimCsv, opts);
if ismember('groupCode', T.Properties.VariableNames)
    emo = string(T.groupCode);
elseif ismember('emotionTag', T.Properties.VariableNames)
    emo = string(T.emotionTag);
else
    error('Stim CSV requires groupCode or emotionTag.');
end
vid = upper(strtrim(string(T.videoID)));
isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
vid(isNum) = compose('%04d', str2double(vid(isNum)));
emo = upper(strtrim(emo));
keep = vid ~= "" & emo ~= "";
codingTable = table(vid(keep), emo(keep), 'VariableNames', {'videoID','emotion'});
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
