function fig = plotPooledPairwiseStatsHeatmap(resultsCell, codingTable, varargin)
% plotPooledPairwiseStatsHeatmap
% Plot pooled-across-subject pairwise KS/ranksum heatmaps for selected bodyparts.
%
% Display convention:
%   Off-diagonal cells:
%       cell color = KS distance D
%       cell text  = ranksum significance stars only
%   Diagonal:
%       blank separator
%
% Notes:
%   - The KS color scale is shared across all bodypart panels in the figure.
%   - This is an exploratory pooled-sample view, not the same aggregation
%     route used by computeKsDistancesFromResultsCell + plotKsHeatmap.

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
addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
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
figureTitle = char(string(p.Results.figureTitle));

if isempty(markerGroups)
    error('plotPooledPairwiseStatsHeatmap:NoMarkerGroups', 'At least one marker group is required.');
end
if numel(emotionList) < 2
    error('plotPooledPairwiseStatsHeatmap:TooFewEmotions', 'At least two emotions are required.');
end

[vidToEmotion, ~] = localBuildVideoMap(codingTable);
if useImmobile
    speedField = 'speedArrayImmobile';
    regimeLabel = sprintf('micromovement (precomputed <= %g mm/s)', immobilityThreshold);
else
    speedField = 'speedArray';
    regimeLabel = 'full motion';
end

if isempty(strtrim(figureTitle))
    normLabel = ternary(doBaselineNormalize, 'baseline-normalized', 'absolute');
    figureTitle = sprintf('POOLED | pairwise stats | %s | %s', normLabel, regimeLabel);
end

nGroups = numel(markerGroups);
tileCols = min(3, nGroups);
tileRows = ceil(nGroups / tileCols);
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 100 1500 880]);
tl = tiledlayout(fig, tileRows, tileCols, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, figureTitle, 'FontSize', 20, 'FontWeight', 'bold', 'Interpreter', 'none');

allD = [];
cacheD = cell(nGroups, 1);
cacheP = cell(nGroups, 1);

for g = 1:nGroups
    mgSpec = localResolveMarkerGroupSpec(markerGroups{g}, markerGroupAliases);
    nE = numel(emotionList);
    D = NaN(nE, nE);
    P = NaN(nE, nE);
    sampleMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for e = 1:nE
        vals = localApplyOutlierCut(localCollectRawSamplesAcrossSubjectsNormalized( ...
            resultsCell, vidToEmotion, mgSpec, emotionList{e}, speedField, doBaselineNormalize, baselineEmotion, minBaselineSamples), outlierQuantile);
        sampleMap(emotionList{e}) = vals;
    end
    for i = 1:nE
        valsI = sampleMap(emotionList{i});
        for j = i+1:nE
            valsJ = sampleMap(emotionList{j});
            if numel(valsI) < 2 || numel(valsJ) < 2
                continue;
            end
            [~, pRS, ksD] = kstest2(valsI, valsJ);
            D(i,j) = ksD; D(j,i) = ksD;
            P(i,j) = pRS; P(j,i) = pRS;
        end
    end
    cacheD{g} = D;
    cacheP{g} = P;
    allD = [allD; D(~isnan(D) & isfinite(D))]; %#ok<AGROW>
end

if isempty(allD)
    colorHi = 0.2;
else
    colorHi = max(0.1, ceil(max(allD) * 100) / 100);
end

for g = 1:nGroups
    D = cacheD{g};
    P = cacheP{g};
    nE = size(D,1);
    ax = nexttile(tl, g);
    imagesc(ax, D, [0 colorHi]);
    axis(ax, 'image');
    set(ax, 'YDir', 'normal', 'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    ax.Toolbar.Visible = 'off';
    colormap(ax, parula(256));
    cb = colorbar(ax);
    cb.Label.String = 'KS D';
    xticks(ax, 1:nE); yticks(ax, 1:nE);
    xticklabels(ax, emotionList); yticklabels(ax, emotionList);
    xtickangle(ax, 40);
    grid(ax, 'on'); ax.GridColor = [1 1 1]; ax.GridAlpha = 0.25;
    title(ax, localPrettyMarkerGroupLabel(markerGroups{g}), 'FontSize', 15, 'FontWeight', 'bold');
    for i = 1:nE
        rectangle(ax, 'Position', [i-0.5, i-0.5, 1, 1], 'FaceColor', [0.96 0.96 0.96], 'EdgeColor', [1 1 1], 'LineWidth', 0.5);
        for j = 1:nE
            if i == j
                continue;
            end
            if isnan(D(i,j))
                txt = 'n/a';
            else
                txt = sprintf('D=%.2f\n%s', D(i,j), localPStars(P(i,j)));
            end
            text(ax, j, i, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 10, 'FontWeight', 'bold', 'Color', localTextColorForValue(D(i,j), colorHi));
        end
    end
end

caption = 'All off-diagonal cells show pooled KS distance D (color and text) plus ranksum significance stars. Color scale is shared across bodyparts in this figure.';
annotation(fig, 'textbox', [0.12 0.02 0.76 0.04], 'String', caption, 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);
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

function c = localTextColorForValue(v, colorHi)
if isnan(v)
    c = [0.25 0.25 0.25];
elseif colorHi > 0 && v >= 0.75 * colorHi
    c = [1 1 1];
else
    c = [0.1 0.1 0.1];
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
