function fig = plotPooledSpeedDensityByEmotion(resultsCell, codingTable, varargin)
% plotPooledSpeedDensityByEmotion
% Plot pooled-across-subject speed distributions across emotions.
%
% Usage:
%   fig = plotPooledSpeedDensityByEmotion(resultsCell, codingTable, ...
%       'markerGroups', {'HEAD','UTORSO'}, ...
%       'emotions', {'DISGUST','NEUTRAL','JOY'}, ...
%       'useImmobile', true, ...
%       'doBaselineNormalize', true, ...
%       'plotMode', 'Probability density')
%
% Notes:
%   - This is an exploratory pooled-sample view for browsing and figure design.
%   - It is not identical to the main subject-aggregated batch KS workflow.
%   - Micromovement mode uses the precomputed `speedArrayImmobile` arrays
%     already stored in `resultsCell`.
%   - `plotMode` can be:
%       'Probability density'
%       'CDF'

p = inputParser;
addParameter(p, 'markerGroups', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'markerGroupAliases', struct(), @(x) isstruct(x) || isa(x, 'containers.Map'));
addParameter(p, 'emotions', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'useImmobile', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'doBaselineNormalize', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'baselineEmotion', 'BASELINE', @(x) ischar(x) || isstring(x));
addParameter(p, 'immobilityThreshold', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'minBaselineSamples', 20, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'outlierQuantile', 0.99, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'xLimitQuantile', 0.95, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'tileCols', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'plotMode', 'Probability density', @(x) ischar(x) || isstring(x));
addParameter(p, 'showStats', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'showKs', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

markerGroups = cellstr(string(p.Results.markerGroups));
markerGroupAliases = p.Results.markerGroupAliases;
emotionList = cellstr(string(p.Results.emotions));
useImmobile = p.Results.useImmobile;
doBaselineNormalize = p.Results.doBaselineNormalize;
baselineEmotion = char(string(p.Results.baselineEmotion));
immobilityThreshold = p.Results.immobilityThreshold;
minBaselineSamples = p.Results.minBaselineSamples;
outlierQuantile = p.Results.outlierQuantile;
xLimitQuantile = p.Results.xLimitQuantile;
tileCols = p.Results.tileCols;
figureTitle = char(string(p.Results.figureTitle));
plotMode = char(string(p.Results.plotMode));
showStats = p.Results.showStats;
showKs = p.Results.showKs;

if isempty(markerGroups)
    error('plotPooledSpeedDensityByEmotion:NoMarkerGroups', 'At least one marker group is required.');
end
if isempty(emotionList)
    error('plotPooledSpeedDensityByEmotion:NoEmotions', 'At least one emotion is required.');
end

[vidToEmotion, ~] = localBuildVideoMap(codingTable);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList);

if useImmobile
    speedField = 'speedArrayImmobile';
    regimeLabel = sprintf('micromovement (precomputed <= %g mm/s)', immobilityThreshold);
else
    speedField = 'speedArray';
    regimeLabel = 'full motion';
end

if isempty(tileCols)
    tileCols = min(2, numel(markerGroups));
end
tileRows = ceil(numel(markerGroups) / tileCols);

if isempty(strtrim(figureTitle))
    normLabel = ternary(doBaselineNormalize, 'baseline-normalized', 'absolute');
    figureTitle = sprintf('POOLED | %s | %s | %s', strjoin(emotionList, ', '), normLabel, regimeLabel);
end

fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [100 80 1450 920]);
tl = tiledlayout(fig, tileRows, tileCols, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, figureTitle, 'FontSize', 20, 'FontWeight', 'bold', 'Interpreter', 'none');

legendHandles = gobjects(numel(emotionList), 1);

for g = 1:numel(markerGroups)
    mg = markerGroups{g};
    mgSpec = localResolveMarkerGroupSpec(mg, markerGroupAliases);

    pooledVals = cell(numel(emotionList), 1);
    for e = 1:numel(emotionList)
        pooledVals{e} = localApplyOutlierCut(localCollectRawSamplesAcrossSubjectsNormalized( ...
            resultsCell, vidToEmotion, mgSpec, emotionList{e}, speedField, ...
            doBaselineNormalize, baselineEmotion, minBaselineSamples), outlierQuantile);
    end

    ax = nexttile(tl, g);
    hold(ax, 'on');
    maxY = 0;
    xLims = localPaddedLimits(cat(1, pooledVals{:}), xLimitQuantile);
    for e = 1:numel(emotionList)
        [h, peakY] = localPlotCurveWithMedian(ax, pooledVals{e}, emotionColorMap(emotionList{e}), xLims, plotMode);
        maxY = max(maxY, peakY);
        if g == 1
            legendHandles(e) = h;
        end
    end

    xlim(ax, xLims);
    if strcmpi(plotMode, 'CDF')
        ylim(ax, [0, 1]);
    else
        ylim(ax, [0, max(0.05, maxY * 1.12)]);
    end
    grid(ax, 'on');
    set(ax, 'Box', 'off', 'LineWidth', 1.0, 'FontSize', 11);
    ax.Toolbar.Visible = 'off';
    title(ax, localPrettyMarkerGroupLabel(mg), 'FontSize', 15, 'FontWeight', 'bold');
    if g > (tileRows - 1) * tileCols
        xlabel(ax, localXAxisLabel(doBaselineNormalize), 'FontSize', 12, 'FontWeight', 'bold');
    end
    if mod(g - 1, tileCols) == 0
        ylabel(ax, localYAxisLabel(plotMode), 'FontSize', 12, 'FontWeight', 'bold');
    end
    if ~any(cellfun(@(v) ~isempty(v), pooledVals))
        text(ax, 0.5, 0.5, 'No samples for current selection', ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 12, ...
            'Color', [0.45 0.45 0.45]);
    end
    if showStats || showKs
        localAnnotatePanelStats(ax, pooledVals, showStats, showKs);
    end
end

lgd = legend(legendHandles, emotionList, ...
    'Location', 'southoutside', ...
    'Orientation', 'horizontal', ...
    'Box', 'off');
set(lgd, 'FontSize', 12);

caption = sprintf('Pooled-across-subject %s %s. Thin vertical lines mark pooled medians.', lower(plotMode), regimeLabel);
annotation(fig, 'textbox', [0.12 0.02 0.76 0.04], ...
    'String', caption, ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 11, ...
    'Color', [0.25 0.25 0.25]);
end

function vals = localCollectRawSamplesAcrossSubjectsNormalized(resultsCell, vidToEmotion, markerGroupSpec, emotion, speedField, doBaselineNormalize, baselineEmotion, minBaselineSamples)
vals = [];
for i = 1:numel(resultsCell)
    rc = resultsCell{i};
    if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
        continue;
    end
    thisVals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroupSpec, emotion, speedField, doBaselineNormalize, baselineEmotion, speedField, minBaselineSamples);
    if isempty(thisVals)
        continue;
    end
    vals = [vals; thisVals(:)]; %#ok<AGROW>
end
vals = vals(~isnan(vals) & isfinite(vals));
end

function [vidToEmotion, emotions] = localBuildVideoMap(codingTable)
vidToEmotion = containers.Map;
emotions = {};
vids = cellstr(string(codingTable{:,1}));
emos = cellstr(string(codingTable{:,2}));
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

function emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList)
emotionColorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
vids = cellstr(string(codingTable{:,1}));
grps = cellstr(string(codingTable{:,2}));
codingCell = [vids, grps];
[~, ~, uniqueGroups, groupColorMap] = resolveStimVideoColors(vids, codingCell);
for i = 1:numel(uniqueGroups)
    g = char(string(uniqueGroups{i}));
    if isKey(groupColorMap, g)
        emotionColorMap(g) = groupColorMap(g);
    end
end
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

function vals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroupSpec, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
vals = [];
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
    thisVals = thisVals(~isnan(thisVals) & isfinite(thisVals));
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

function baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples)
baseVal = NaN;
if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
    return;
end
st = rc.summaryTable;
if ~ismember(baselineFromField, st.Properties.VariableNames)
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
pooled = [];
rows = find(idx);
for r = rows(:)'
    vals = st.(baselineFromField){r};
    pooled = [pooled; vals(:)]; %#ok<AGROW>
end
pooled = pooled(~isnan(pooled) & isfinite(pooled));
if numel(pooled) < minBaselineSamples
    return;
end
baseVal = median(pooled, 'omitnan');
if ~(isfinite(baseVal) && baseVal > 0)
    baseVal = NaN;
end
end

function emoCol = localEmotionColumn(st, vidToEmotion)
emoCol = [];
if ~ismember('videoID', st.Properties.VariableNames)
    return;
end
vids = cellstr(string(st.videoID));
emoCol = repmat({''}, size(vids));
for i = 1:numel(vids)
    if isKey(vidToEmotion, vids{i})
        emoCol{i} = vidToEmotion(vids{i});
    end
end
end

function vals = localApplyOutlierCut(vals, q)
vals = vals(:);
vals = vals(~isnan(vals) & isfinite(vals));
if isempty(vals) || q >= 1
    return;
end
hi = quantile(vals, q);
vals = vals(vals <= hi);
end

function [h, peakY] = localPlotCurveWithMedian(ax, vals, colorVal, xLims, plotMode)
vals = vals(:);
vals = vals(~isnan(vals) & isfinite(vals));
if numel(vals) < 2
    h = plot(ax, nan, nan, 'Color', colorVal, 'LineWidth', 2.2);
    peakY = 0;
    return;
end
vals = vals(vals >= xLims(1) & vals <= xLims(2));
if numel(vals) < 2
    h = plot(ax, nan, nan, 'Color', colorVal, 'LineWidth', 2.2);
    peakY = 0;
    return;
end
medVal = median(vals, 'omitnan');
xGrid = linspace(xLims(1), xLims(2), 256);
if strcmpi(plotMode, 'CDF')
    [f, x] = ksdensity(vals, xGrid, 'Function', 'cdf');
else
    [f, x] = ksdensity(vals, xGrid, 'Function', 'pdf');
end
h = plot(ax, x, f, 'Color', colorVal, 'LineWidth', 2.2);
peakY = max(f);
if medVal >= xLims(1) && medVal <= xLims(2)
    plot(ax, [medVal medVal], [0 peakY], ':', 'Color', colorVal, 'LineWidth', 2.0);
end
end

function lims = localPaddedLimits(vals, xLimitQuantile)
vals = vals(:);
vals = vals(~isnan(vals) & isfinite(vals));
if isempty(vals)
    lims = [0 1];
    return;
end
if xLimitQuantile >= 1
    vmax = max(vals);
    vmin = min(vals);
else
    vmax = quantile(vals, xLimitQuantile);
    valsInRange = vals(vals <= vmax);
    if isempty(valsInRange)
        vmin = min(vals);
    else
        vmin = min(valsInRange);
    end
end
if vmin == vmax
    pad = max(0.1, abs(vmin) * 0.1 + 0.1);
else
    pad = (vmax - vmin) * 0.08;
end
lims = [vmin - pad, vmax + pad];
end

function xlab = localXAxisLabel(doBaselineNormalize)
if doBaselineNormalize
    xlab = 'Speed (fold baseline)';
else
    xlab = 'Speed (mm/s)';
end
end

function ylab = localYAxisLabel(plotMode)
if strcmpi(plotMode, 'CDF')
    ylab = 'CDF';
else
    ylab = 'Probability density';
end
end

function s = localPrettyMarkerGroupLabel(raw)
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

function localAnnotatePanelStats(ax, pooledVals, showStats, showKs)
vals = [];
grp = [];
for i = 1:numel(pooledVals)
    v = pooledVals{i};
    v = v(:);
    v = v(~isnan(v) & isfinite(v));
    if isempty(v)
        continue;
    end
    vals = [vals; v]; %#ok<AGROW>
    grp = [grp; repmat(i, numel(v), 1)]; %#ok<AGROW>
end
if isempty(vals) || numel(unique(grp)) < 2
    return;
end
txtLines = {};
if numel(unique(grp)) == 2
    groupA = pooledVals{1}; groupA = groupA(:); groupA = groupA(~isnan(groupA) & isfinite(groupA));
    groupB = pooledVals{2}; groupB = groupB(:); groupB = groupB(~isnan(groupB) & isfinite(groupB));
    if showStats
        pVal = ranksum(groupA, groupB);
        txtLines{end+1} = sprintf('%s RS p=%s', localPStars(pVal), localFormatPValue(pVal)); %#ok<AGROW>
    end
    if showKs
        [~, ~, ksD] = kstest2(groupA, groupB);
        txtLines{end+1} = sprintf('KS D=%.2f', ksD); %#ok<AGROW>
    end
else
    if showStats
        pVal = kruskalwallis(vals, grp, 'off');
        txtLines{end+1} = sprintf('%s KW p=%s', localPStars(pVal), localFormatPValue(pVal)); %#ok<AGROW>
    end
end
if isempty(txtLines)
    return;
end
text(ax, 0.02, 0.98, strjoin(txtLines, '\n'), ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'Color', [0.1 0.1 0.1], ...
    'BackgroundColor', 'none');
end

function s = localPStars(pVal)
if ~isfinite(pVal)
    s = 'n/a';
elseif pVal < 0.001
    s = '***';
elseif pVal < 0.01
    s = '**';
elseif pVal < 0.05
    s = '*';
else
    s = 'n.s.';
end
end

function txt = localFormatPValue(pVal)
if pVal < 1e-3
    txt = sprintf('%.1e', pVal);
else
    txt = sprintf('%.3f', pVal);
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
