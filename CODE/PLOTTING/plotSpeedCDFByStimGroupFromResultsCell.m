function plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, varargin)
% plotSpeedCDFByStimGroupFromResultsCell
% Plot ECDFs of speed metrics grouped by emotion/stimulus code, using resultsCell.
%
% plotMode:
%   'perVideoMedian'  : ECDF of per-video medians (unit = video within subject)
%   'pooledRaw'       : ECDF of pooled raw samples across all subjects (unit = sample)
%   'perSubjectRaw'   : per-subject ECDFs (thin) + median ECDF across subjects (thick)
%
% Baseline normalization (fold baseline) is supported for ALL plot modes.
%
% Optional alias support:
%   Pass 'markerGroupAliases' as a struct or containers.Map to let one
%   plotted group expand to multiple canonical result-cell marker groups.
%   Example:
%       ARMS   -> {'UPPER_LIMB_L','UPPER_LIMB_R'}
%       WRISTS -> {'WRIST_L','WRIST_R'}
%       LEGS   -> {'LOWER_LIMB_L','LOWER_LIMB_R'}

p = inputParser;
addParameter(p, 'markerGroups', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'markerGroupAliases', struct(), @(x) isstruct(x) || isa(x, 'containers.Map'));
addParameter(p, 'emotionInclude', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'emotionExclude', {'0','X','AMUSEMENT',''}, @(x) iscell(x) || isstring(x));
addParameter(p, 'plotMode', 'perVideoMedian', @(x) ischar(x) || isstring(x));
addParameter(p, 'useImmobile', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'immobilityField', 'speedArrayImmobile', @(x) ischar(x) || isstring(x));
addParameter(p, 'summaryField', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
addParameter(p, 'minSamplesPerSubj', 200, @(x) isscalar(x) && x>=0);
addParameter(p, 'tileCols', 3, @(x) isscalar(x) && x>=1);
addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'showStats', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'statsPair', {'NEUTRAL','FEAR'}, @(x) iscell(x) || isstring(x));

addParameter(p, 'doBaselineNormalize', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'baselineEmotion', '0', @(x) ischar(x) || isstring(x));
addParameter(p, 'baselineFromField', '', @(x) ischar(x) || isstring(x)); % default: same as plotted field
addParameter(p, 'minBaselineSamples', 200, @(x) isscalar(x) && x>=0);

parse(p, varargin{:});

markerGroups = cellstr(string(p.Results.markerGroups));
markerGroupAliases = p.Results.markerGroupAliases;
emotionInclude = cellstr(string(p.Results.emotionInclude));
emotionExclude = cellstr(string(p.Results.emotionExclude));
plotMode = char(string(p.Results.plotMode));
useImmobile = p.Results.useImmobile;
immobilityField = char(string(p.Results.immobilityField));
summaryField = char(string(p.Results.summaryField));
outlierQuantile = p.Results.outlierQuantile;
minSamplesPerSubj = p.Results.minSamplesPerSubj;
tileCols = p.Results.tileCols;
figureTitle = char(string(p.Results.figureTitle));
showStats = p.Results.showStats;
statsPair = cellstr(string(p.Results.statsPair));

doBaselineNormalize = p.Results.doBaselineNormalize;
baselineEmotion = char(string(p.Results.baselineEmotion));
baselineFromField = char(string(p.Results.baselineFromField));
minBaselineSamples = p.Results.minBaselineSamples;

% ----- Decide default summaryField based on useImmobile (do this EARLY) -----
if isempty(summaryField)
    if useImmobile
        summaryField = 'medianSpeedImmobile';
    else
        summaryField = 'medianSpeed';
    end
end

% ----- Decide baselineFromField AFTER summaryField exists -----
if isempty(baselineFromField)
    if strcmp(plotMode,'perVideoMedian')
        baselineFromField = summaryField;
    else
        baselineFromField = immobilityField;
    end
end

% Build videoID -> emotion map
[vidToEmotion, allEmotions] = localBuildVideoMap(codingTable);

% Apply include/exclude to emotion list (these are non-baseline target emotions)
allEmotions = setdiff(allEmotions, emotionExclude, 'stable');
if ~isempty(emotionInclude)
    allEmotions = intersect(allEmotions, emotionInclude, 'stable');
end
if numel(allEmotions) < 1
    warning('No emotions left after include/exclude.');
    return;
end

% Collect markerGroups if not provided
if isempty(markerGroups)
    markerGroups = localCollectAllMarkerGroups(resultsCell);
end
if isempty(markerGroups)
    warning('No marker groups found in resultsCell.');
    return;
end

% Layout
nGroups = numel(markerGroups);
nCols = min(tileCols, nGroups);
nRows = ceil(nGroups / nCols);
figure;
tl = tiledlayout(nRows, nCols, 'Padding', 'compact', 'TileSpacing', 'compact');
if isempty(figureTitle)
    figureTitle = sprintf('CDF by marker group | %s', plotMode);
end
title(tl, figureTitle, 'Interpreter', 'none');

emotionList = allEmotions(:);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList);
axHandles = gobjects(nGroups, 1);
legendHandlesMaster = gobjects(0);
legendLabelsMaster = {};

    for g = 1:nGroups
        mg = markerGroups{g};
        mgLabel = localPrettyMarkerGroupLabel(mg);
        mgSpec = localResolveMarkerGroupSpec(mg, markerGroupAliases);
        nexttile; hold on;
        axHandles(g) = gca;

    switch plotMode
        case 'perVideoMedian'
            pooled = cell(numel(emotionList), 1);
            for e = 1:numel(emotionList)
                emo = emotionList{e};
                pooled{e} = localCollectSummaryValuesNormalized( ...
                    resultsCell, vidToEmotion, mgSpec, emo, summaryField, ...
                    doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);

                pooled{e} = localApplyOutlierCut(pooled{e}, outlierQuantile);
            end
            [hLegend, labelsLegend] = localPlotPooledEcdfs(pooled, emotionList, emotionColorMap);
            if isempty(legendHandlesMaster) && ~isempty(hLegend)
                legendHandlesMaster = hLegend;
                legendLabelsMaster = labelsLegend;
            end
            localAnnotateStats(gca, pooled, emotionList, showStats, statsPair);

            if doBaselineNormalize
                xlabel("Median speed (fold baseline)");
            else
                xlabel(localXLabelFromField(summaryField));
            end
            ylabel('CDF');
            title(mgLabel, 'Interpreter', 'none');
            grid on;

        case 'pooledRaw'
            % IMPORTANT: baseline-normalize each subject BEFORE pooling
            pooled = cell(numel(emotionList), 1);
            for e = 1:numel(emotionList)
                emo = emotionList{e};
                valsAll = [];

                for s = 1:numel(resultsCell)
                    rc = resultsCell{s};
                    vals = localCollectRawSamplesForSubjectNormalized( ...
                        rc, vidToEmotion, mgSpec, emo, immobilityField, ...
                        doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);

                    vals = localApplyOutlierCut(vals, outlierQuantile);
                    valsAll = [valsAll; vals(:)]; %#ok<AGROW>
                end
                pooled{e} = valsAll;
            end

            [hLegend, labelsLegend] = localPlotPooledEcdfs(pooled, emotionList, emotionColorMap);
            if isempty(legendHandlesMaster) && ~isempty(hLegend)
                legendHandlesMaster = hLegend;
                legendLabelsMaster = labelsLegend;
            end
            localAnnotateStats(gca, pooled, emotionList, showStats, statsPair);

            if doBaselineNormalize
                xlabel("Speed samples (fold baseline)");
            else
                xlabel(localXLabelFromField(immobilityField));
            end
            ylabel('CDF');
            title(mgLabel, 'Interpreter', 'none');
            grid on;

        case 'perSubjectRaw'
            % One axis per markerGroup; within it, draw each emotion's subject-ECDFs
            subjIDs = localCollectSubjectIDs(resultsCell);

            for e = 1:numel(emotionList)
                emo = emotionList{e};

                ecdfX = cell(numel(subjIDs), 1);
                ecdfF = cell(numel(subjIDs), 1);

                for s = 1:numel(subjIDs)
                    rc = resultsCell{s};
                    vals = localCollectRawSamplesForSubjectNormalized( ...
                        rc, vidToEmotion, mgSpec, emo, immobilityField, ...
                        doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);

                    vals = vals(~isnan(vals));
                    if numel(vals) < minSamplesPerSubj
                        continue;
                    end
                    vals = localApplyOutlierCut(vals, outlierQuantile);

                    [f, x] = ecdf(vals);
                    ecdfX{s} = x;
                    ecdfF{s} = f;

                    stairs(x, f, 'LineWidth', 0.5);
                end

                [xGrid, fMedian] = localMedianEcdfAcrossSubjects(ecdfX, ecdfF);
                if ~isempty(xGrid)
                    stairs(xGrid, fMedian, 'LineWidth', 2.0);
                end
            end

            if doBaselineNormalize
                xlabel("Speed samples (fold baseline)");
            else
                xlabel(localXLabelFromField(immobilityField));
            end
            ylabel('CDF');
            title(mgLabel, 'Interpreter', 'none');
            grid on;

        otherwise
            error('Unknown plotMode: %s', plotMode);
    end
end

% Legend: in perSubjectRaw it's meaningless (many repeated lines)
if ~strcmp(plotMode, 'perSubjectRaw') && ~isempty(legendHandlesMaster)
    legend(axHandles(end), legendHandlesMaster, legendLabelsMaster, ...
        'Location', 'eastoutside', 'Interpreter', 'none');
end

end

function s = localPrettyMarkerGroupLabel(raw)
% Render marker-group labels for plots without underscores.
    s = char(string(raw));
    switch upper(s)
        case 'HEAD'
            s = 'Head';
        case 'UTORSO'
            s = 'Upper torso';
        case 'LTORSO'
            s = 'Lower torso';
        case 'ARMS'
            s = 'Arms';
        case 'WRISTS'
            s = 'Wrists';
        case 'LEGS'
            s = 'Legs';
        otherwise
            s = strrep(s, '_', '-');
    end
end

%% ---------- helpers ----------

function markerGroups = localCollectAllMarkerGroups(resultsCell)
markerGroups = {};
for s = 1:numel(resultsCell)
    if ~isfield(resultsCell{s}, 'summaryTable') || isempty(resultsCell{s}.summaryTable)
        continue;
    end
    st = resultsCell{s}.summaryTable;
    if ismember('markerGroup', st.Properties.VariableNames)
        markerGroups = [markerGroups; unique(st.markerGroup, 'stable')]; %#ok<AGROW>
    end
end
markerGroups = unique(markerGroups, 'stable');
end

function subjIDs = localCollectSubjectIDs(resultsCell)
subjIDs = cell(numel(resultsCell),1);
for s = 1:numel(resultsCell)
    if isfield(resultsCell{s}, 'subjectID') && ~isempty(resultsCell{s}.subjectID)
        subjIDs{s} = char(string(resultsCell{s}.subjectID));
    else
        subjIDs{s} = sprintf('subj%d', s);
    end
end
end

function emoCol = localEmotionColumn(st, vidToEmotion)
if ~ismember('videoID', st.Properties.VariableNames)
    emoCol = {};
    return;
end
emoCol = repmat({''}, height(st), 1);
for r = 1:height(st)
    vid = st.videoID{r};
    if isKey(vidToEmotion, vid)
        emoCol{r} = vidToEmotion(vid);
    else
        emoCol{r} = '';
    end
end
end

function markerGroupSpec = localResolveMarkerGroupSpec(markerGroupKey, markerGroupAliases)
    key = char(string(markerGroupKey));
    if isa(markerGroupAliases, 'containers.Map')
        if isKey(markerGroupAliases, key)
            markerGroupSpec = cellstr(string(markerGroupAliases(key)));
        else
            markerGroupSpec = {key};
        end
        return;
    end

    if isstruct(markerGroupAliases) && isfield(markerGroupAliases, key)
        markerGroupSpec = cellstr(string(markerGroupAliases.(key)));
    else
        markerGroupSpec = {key};
    end
end

function mask = localMarkerGroupMask(st, markerGroupSpec)
    mgCol = string(st.markerGroup);
    spec = cellstr(string(markerGroupSpec));
    mask = ismember(mgCol, string(spec));
end

function [hOut, labelsOut] = localPlotPooledEcdfs(pooledVals, emotionList, emotionColorMap)
hOut = gobjects(0);
labelsOut = {};
for i = 1:numel(pooledVals)
    v = pooledVals{i};
    if isempty(v), continue; end
    [f, x] = ecdf(v);
    emo = char(string(emotionList{i}));
    if isKey(emotionColorMap, emo)
        c = emotionColorMap(emo);
        h = stairs(x, f, 'LineWidth', 1.4, 'Color', c);
    else
        h = stairs(x, f, 'LineWidth', 1.4);
    end
    hOut(end+1,1) = h; %#ok<AGROW>
    labelsOut{end+1,1} = emo; %#ok<AGROW>
end
end

function emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList)
    emotionColorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    if isempty(codingTable)
        return;
    end

    if istable(codingTable)
        if width(codingTable) < 2
            return;
        end
        vids = cellstr(string(codingTable{:,1}));
        grps = cellstr(string(codingTable{:,2}));
        codingCell = [vids, grps];
    elseif iscell(codingTable) && size(codingTable,2) >= 2
        codingCell = codingTable(:,1:2);
        vids = cellstr(string(codingCell(:,1)));
    else
        return;
    end

    [~, ~, uniqueGroups, groupColorMap] = resolveStimVideoColors(vids, codingCell);
    for i = 1:numel(uniqueGroups)
        g = char(string(uniqueGroups{i}));
        if isKey(groupColorMap, g)
            emotionColorMap(g) = groupColorMap(g);
        end
    end

    % Ensure requested emotions have deterministic fallback colors.
    missing = {};
    for i = 1:numel(emotionList)
        e = char(string(emotionList{i}));
        if ~isKey(emotionColorMap, e)
            missing{end+1,1} = e; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        cmap = lines(numel(missing));
        for i = 1:numel(missing)
            emotionColorMap(missing{i}) = cmap(i,:);
        end
    end
end

function localAnnotateStats(ax, pooledVals, emotionList, showStats, statsPair)
    if ~showStats
        return;
    end

    dataAll = [];
    groupAll = {};
    for i = 1:numel(pooledVals)
        v = pooledVals{i};
        if isempty(v), continue; end
        dataAll = [dataAll; v(:)]; %#ok<AGROW>
        groupAll = [groupAll; repmat(emotionList(i), numel(v), 1)]; %#ok<AGROW>
    end
    if isempty(dataAll) || numel(unique(groupAll)) < 2
        return;
    end

    pKW = kruskalwallis(dataAll, groupAll, 'off');
    if pKW < 0.001
        starStr = '***';
    elseif pKW < 0.01
        starStr = '**';
    elseif pKW < 0.05
        starStr = '*';
    else
        starStr = 'n.s.';
    end

    text(ax, 0.02, 0.96, sprintf('%s  KW p=%.2g', starStr, pKW), ...
        'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold');

    if numel(statsPair) ~= 2
        return;
    end
    a = upper(strtrim(string(statsPair{1})));
    b = upper(strtrim(string(statsPair{2})));
    ia = find(upper(string(emotionList)) == a, 1);
    ib = find(upper(string(emotionList)) == b, 1);
    if isempty(ia) || isempty(ib)
        return;
    end
    va = pooledVals{ia};
    vb = pooledVals{ib};
    if isempty(va) || isempty(vb)
        return;
    end
    [~, pPair] = kstest2(va, vb);
    text(ax, 0.02, 0.89, sprintf('%s vs %s p=%.2g', a, b, pPair), ...
        'Units', 'normalized', 'FontSize', 9, 'Color', [0.25 0.25 0.25]);
end

function v = localApplyOutlierCut(v, outlierQuantile)
v = v(~isnan(v));
if isempty(v) || isempty(outlierQuantile)
    return;
end
cutoff = quantile(v, outlierQuantile);
v(v > cutoff) = [];
end

function [xGrid, fMedian] = localMedianEcdfAcrossSubjects(ecdfX, ecdfF)
allX = [];
for i = 1:numel(ecdfX)
    x = ecdfX{i};
    if ~isempty(x)
        allX = [allX; x(:)]; %#ok<AGROW>
    end
end
allX = allX(~isnan(allX));
allX = unique(allX, 'sorted');

if numel(allX) < 10
    xGrid = [];
    fMedian = [];
    return;
end

F = nan(numel(allX), numel(ecdfX));
for i = 1:numel(ecdfX)
    x = ecdfX{i};
    f = ecdfF{i};
    if isempty(x) || isempty(f)
        continue;
    end

    x = x(:); f = f(:);
    goodMask = ~isnan(x) & ~isnan(f);
    x = x(goodMask);
    f = f(goodMask);

    if numel(x) < 2
        continue;
    end

    [xUnique, lastIndex] = unique(x, 'last');
    fUnique = f(lastIndex);

    if numel(xUnique) < 2
        continue;
    end

    F(:, i) = interp1(xUnique, fUnique, allX, 'previous', 'extrap');
end

fMedian = median(F, 2, 'omitnan');
xGrid = allX;
end

function [vidToEmotion, emotions] = localBuildVideoMap(codingTable)
vidToEmotion = containers.Map;
emotions = {};

if istable(codingTable)
    vids = codingTable{:,1};
    emos = codingTable{:,2};
elseif iscell(codingTable)
    vids = codingTable(:,1);
    emos = codingTable(:,2);
else
    error('codingTable must be a table or cell array.');
end

if isstring(vids), vids = cellstr(vids); end
if isstring(emos), emos = cellstr(emos); end

for i = 1:numel(vids)
    vid = char(string(vids{i}));
    emo = char(string(emos{i}));
    if isempty(strtrim(vid)) || isempty(strtrim(emo))
        continue;
    end
    vidToEmotion(vid) = emo;
    emotions{end+1,1} = emo; %#ok<AGROW>
end
emotions = unique(emotions, 'stable');
end

function label = localXLabelFromField(fieldName)
switch fieldName
    case {'medianSpeedImmobile'}
        label = 'Median speed while "immobile" (mm/s)';
    case {'medianSpeed'}
        label = 'Median speed (mm/s)';
    case {'speedArrayImmobile'}
        label = 'Speed samples while "immobile" (mm/s)';
    case {'speedArray'}
        label = 'Speed samples (mm/s)';
    otherwise
        label = fieldName;
end
end

function baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples)
baseVal = NaN;
if ~isfield(rc,'summaryTable') || isempty(rc.summaryTable)
    return;
end
st = rc.summaryTable;

if ~ismember('markerGroup', st.Properties.VariableNames) || ~ismember('videoID', st.Properties.VariableNames)
    return;
end

emoCol = localEmotionColumn(st, vidToEmotion);
if isempty(emoCol)
    return;
end

idx = strcmp(string(st.markerGroup), string(markerGroup)) & strcmp(emoCol, baselineEmotion);
if ~any(idx)
    return;
end

if ~ismember(baselineFromField, st.Properties.VariableNames)
    return;
end

v = st.(baselineFromField)(idx);

if iscell(v)
    vv = [];
    for i = 1:numel(v)
        if ~isempty(v{i})
            vv = [vv; v{i}(:)]; %#ok<AGROW>
        end
    end
    vv = vv(~isnan(vv));
    if numel(vv) < minBaselineSamples
        return;
    end
    baseVal = median(vv, 'omitnan');
else
    v = v(~isnan(v));
    if isempty(v)
        return;
    end
    baseVal = median(v, 'omitnan');
end

if ~(isfinite(baseVal) && baseVal > 0)
    baseVal = NaN;
end
end

function vals = localCollectSummaryValuesNormalized(resultsCell, vidToEmotion, markerGroupSpec, emotion, summaryField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
vals = [];
for s = 1:numel(resultsCell)
    rc = resultsCell{s};
    if ~isfield(rc,'summaryTable') || isempty(rc.summaryTable)
        continue;
    end
    st = rc.summaryTable;
    if ~ismember(summaryField, st.Properties.VariableNames)
        continue;
    end

    emoCol = localEmotionColumn(st, vidToEmotion);
    if isempty(emoCol)
        continue;
    end

    idx = localMarkerGroupMask(st, markerGroupSpec) & strcmp(emoCol, emotion);
    if ~any(idx), continue; end

    rowIdx = find(idx);
            rowVideoIDs = string(st.videoID(rowIdx));
            uniqueVideoIDs = unique(rowVideoIDs, 'stable');

    for vIdx = 1:numel(uniqueVideoIDs)
        vid = uniqueVideoIDs(vIdx);
        thisRows = rowIdx(rowVideoIDs == vid);
        rowVals = nan(numel(thisRows), 1);
        keepCount = 0;
        for j = 1:numel(thisRows)
            r = thisRows(j);
            thisVal = st.(summaryField)(r);
            if ~isfinite(thisVal)
                continue;
            end
            if doBaselineNormalize
                thisGroup = char(string(st.markerGroup{r}));
                baseVal = localBaselineScalarForSubject(rc, vidToEmotion, thisGroup, baselineEmotion, baselineFromField, minBaselineSamples);
                if ~isfinite(baseVal)
                    continue;
                end
                thisVal = thisVal ./ baseVal;
            end
            keepCount = keepCount + 1;
            rowVals(keepCount) = thisVal;
        end
        rowVals = rowVals(1:keepCount);
        rowVals = rowVals(~isnan(rowVals));
        if isempty(rowVals)
            continue;
        end
        vals = [vals; mean(rowVals, 'omitnan')]; %#ok<AGROW>
    end
end
end

function vals = localCollectRawSamplesForSubject(rc, vidToEmotion, markerGroupSpec, emotion, speedField)
vals = [];
if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
    return;
end
st = rc.summaryTable;

if ~ismember(speedField, st.Properties.VariableNames)
    return;
end

emoCol = localEmotionColumn(st, vidToEmotion);
if isempty(emoCol)
    return;
end

idx = localMarkerGroupMask(st, markerGroupSpec) & strcmp(emoCol, emotion);
if ~any(idx)
    return;
end

cellVals = st.(speedField)(idx);
for i = 1:numel(cellVals)
    v = cellVals{i};
    if isempty(v), continue; end
    vals = [vals; v(:)]; %#ok<AGROW>
end
vals = vals(~isnan(vals));
end

function vals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroupSpec, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
vals = [];
if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
    return;
end
st = rc.summaryTable;

if ~ismember(speedField, st.Properties.VariableNames)
    return;
end

emoCol = localEmotionColumn(st, vidToEmotion);
if isempty(emoCol)
    return;
end

idx = localMarkerGroupMask(st, markerGroupSpec) & strcmp(emoCol, emotion);
if ~any(idx)
    return;
end

rowIdx = find(idx);
for j = 1:numel(rowIdx)
    r = rowIdx(j);
    cellVal = st.(speedField){r};
    if isempty(cellVal)
        continue;
    end
    thisVals = cellVal(:);
    thisVals = thisVals(~isnan(thisVals));
    if isempty(thisVals)
        continue;
    end

    if doBaselineNormalize
        thisGroup = char(string(st.markerGroup{r}));
        baseVal = localBaselineScalarForSubject(rc, vidToEmotion, thisGroup, baselineEmotion, baselineFromField, minBaselineSamples);
        if ~isfinite(baseVal)
            continue;
        end
        thisVals = thisVals ./ baseVal;
    end

    vals = [vals; thisVals]; %#ok<AGROW>
end
end
