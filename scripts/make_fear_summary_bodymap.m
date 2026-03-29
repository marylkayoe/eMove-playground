function out = make_fear_summary_bodymap(varargin)
% make_fear_summary_bodymap
% Build a two-panel FEAR summary body map comparing full motion and
% micromovement across all subjects.
%
% The summary value per bodypart is:
%   1. within each subject, median KS D across all FEAR-vs-other pairs
%   2. then aggregated across subjects by median inside the stick-figure plotter
%
% This keeps the view subject-aware while still producing a compact body map.

p = inputParser;
addParameter(p, 'repoRoot', '/Users/yoe/Documents/REPOS/eMove-playground', @(x) ischar(x) || isstring(x));
addParameter(p, 'dataRoot', '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject', @(x) ischar(x) || isstring(x));
addParameter(p, 'resultsCellPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'stimCsv', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'fearLabel', 'FEAR', @(x) ischar(x) || isstring(x));
addParameter(p, 'minSamplesPerCond', 200, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'doBaselineNormalize', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'baselineEmotion', 'BASELINE', @(x) ischar(x) || isstring(x));
addParameter(p, 'minBaselineSamples', 200, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'colormapSpec', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x));
addParameter(p, 'titleText', 'FEAR Distinguishability Across Bodyparts', @(x) ischar(x) || isstring(x));
addParameter(p, 'exportStem', 'fear_summary_bodymap', @(x) ischar(x) || isstring(x));
addParameter(p, 'sharedCLim', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'grayGroups', {'LOWER_LIMB_L','LOWER_LIMB_R'}, @(x) iscell(x) || isstring(x));
parse(p, varargin{:});

repoRoot = char(string(p.Results.repoRoot));
dataRoot = char(string(p.Results.dataRoot));
resultsCellPath = char(string(p.Results.resultsCellPath));
stimCsv = char(string(p.Results.stimCsv));
fearLabel = char(string(p.Results.fearLabel));
minSamplesPerCond = p.Results.minSamplesPerCond;
doBaselineNormalize = p.Results.doBaselineNormalize;
baselineEmotion = char(string(p.Results.baselineEmotion));
minBaselineSamples = p.Results.minBaselineSamples;
colormapSpec = p.Results.colormapSpec;
titleText = char(string(p.Results.titleText));
exportStem = char(string(p.Results.exportStem));
sharedCLimOverride = p.Results.sharedCLim;
grayGroups = cellstr(string(p.Results.grayGroups));

if isempty(strtrim(resultsCellPath))
    analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
    d = dir(analysisRunsRoot);
    d = d([d.isdir]);
    d = d(~ismember({d.name}, {'.','..'}));
    [~, ord] = sort({d.name});
    latestRunDir = fullfile(analysisRunsRoot, d(ord(end)).name);
    resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');
end
if isempty(strtrim(stimCsv))
    stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
fid = fopen(stimCsv, 'r');
assert(fid ~= -1, 'Could not open stim coding CSV: %s', stimCsv);
cleanupObj = onCleanup(@() fclose(fid));
data = textscan(fid, '%s%s%*[^\n]', 'Delimiter', ',', 'HeaderLines', 1);
codingTable = [data{1}, data{2}];

allEmotions = unique(string(codingTable(:,2)), 'stable');
allEmotions = allEmotions(~strcmpi(allEmotions, "BASELINE"));
allEmotions = allEmotions(~strcmpi(allEmotions, "X"));
otherEmotions = allEmotions(~strcmpi(allEmotions, string(fearLabel)));
emotionPairs = cell(numel(otherEmotions), 2);
for i = 1:numel(otherEmotions)
    emotionPairs{i,1} = fearLabel;
    emotionPairs{i,2} = char(otherEmotions(i));
end

ksFull = localComputeFearKsTable(resultsCell, codingTable, fearLabel, otherEmotions, 'speedArray', ...
    minSamplesPerCond, doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples);
ksMicro = localComputeFearKsTable(resultsCell, codingTable, fearLabel, otherEmotions, 'speedArrayImmobile', ...
    minSamplesPerCond, doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples);

fearFullTbl = localBuildFearSummaryTable(ksFull, fearLabel);
fearMicroTbl = localBuildFearSummaryTable(ksMicro, fearLabel);
fearFullDisplayTbl = localApplyGrayGroups(fearFullTbl, grayGroups);
fearMicroDisplayTbl = localApplyGrayGroups(fearMicroTbl, grayGroups);

if isempty(fearFullDisplayTbl)
    error('make_fear_summary_bodymap:EmptyFull', ...
        'FEAR full-summary table is empty. ksFull rows=%d', height(ksFull));
end
if isempty(fearMicroDisplayTbl)
    error('make_fear_summary_bodymap:EmptyMicro', ...
        'FEAR micro-summary table is empty. ksMicro rows=%d', height(ksMicro));
end

aggFull = localAggregateDisplayedValues(fearFullDisplayTbl);
aggMicro = localAggregateDisplayedValues(fearMicroDisplayTbl);
allVals = [aggFull; aggMicro];
allVals = allVals(isfinite(allVals));
if isempty(sharedCLimOverride)
    if isempty(allVals)
        sharedCLim = [0 0.4];
    else
        vmin = min(allVals);
        vmax = max(allVals);
        if vmax <= vmin
            pad = max(0.01, 0.05 * max(vmax, 1));
            sharedCLim = [max(0, vmin - pad), vmax + pad];
        else
            sharedCLim = [vmin vmax];
        end
    end
else
    sharedCLim = sharedCLimOverride(:)';
end

if isempty(colormapSpec)
    cmapSpec = [ones(256,1), linspace(1, 0, 256)', linspace(1, 0, 256)'];
else
    cmapSpec = colormapSpec;
end

outDir = fullfile(repoRoot, 'outputs', 'figures', [exportStem '_' datestr(now, 'yyyymmdd_HHMMSS')]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 120 1200 640]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, titleText, 'FontSize', 22, 'FontWeight', 'bold');

ax1 = nexttile(tl, 1);
R1 = plotKsBodyPartStickFigure(fearFullDisplayTbl, {fearLabel, 'SUMMARY'}, ...
    'plotWhere', ax1, ...
    'valueField', 'fearSummary', ...
    'aggFcn', 'median', ...
    'showValues', false, ...
    'showGroupLabels', true, ...
    'showColorbar', false, ...
    'cLim', sharedCLim, ...
    'colormapName', cmapSpec, ...
    'baseLineWidth', 10, ...
    'groupLineWidthScale', 1.18, ...
    'nodeMarkerSize', 5, ...
    'labelFontSize', 10, ...
    'titleFontSize', 16, ...
    'missingColor', [0.82 0.82 0.82], ...
    'missingAlpha', 1.0, ...
    'titleText', 'Full motion');

ax2 = nexttile(tl, 2);
R2 = plotKsBodyPartStickFigure(fearMicroDisplayTbl, {fearLabel, 'SUMMARY'}, ...
    'plotWhere', ax2, ...
    'valueField', 'fearSummary', ...
    'aggFcn', 'median', ...
    'showValues', false, ...
    'showGroupLabels', true, ...
    'showColorbar', false, ...
    'cLim', sharedCLim, ...
    'colormapName', cmapSpec, ...
    'baseLineWidth', 10, ...
    'groupLineWidthScale', 1.18, ...
    'nodeMarkerSize', 5, ...
    'labelFontSize', 10, ...
    'titleFontSize', 16, ...
    'missingColor', [0.82 0.82 0.82], ...
    'missingAlpha', 1.0, ...
    'titleText', 'Micromovement');

cb = colorbar(ax2, 'eastoutside');
if ischar(cmapSpec) || isstring(cmapSpec)
    colormap(fig, char(string(cmapSpec)));
else
    colormap(fig, cmapSpec);
end
caxis(ax2, sharedCLim);
clim(ax1, sharedCLim);
clim(ax2, sharedCLim);
if strcmpi(fearLabel, 'FEAR')
    labelStem = 'other';
else
    labelStem = 'other non-target';
end
cb.Label.String = sprintf('Median KS D across %s-vs-%s pairs', upper(fearLabel), labelStem);
cb.FontSize = 12;
cb.Label.FontSize = 14;

annotation(fig, 'textbox', [0.12 0.03 0.76 0.05], ...
    'String', 'Each bodypart color summarizes, within each subject, the median baseline-normalized KS D across FEAR vs every other emotion; colors are then aggregated across subjects with the median. Shared scale across full and micromovement.', ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 11, ...
    'Color', [0.25 0.25 0.25]);

pngPath = fullfile(outDir, [exportStem '.png']);
pdfPath = fullfile(outDir, [exportStem '.pdf']);
figPath = fullfile(outDir, [exportStem '.fig']);
epsPath = fullfile(outDir, [exportStem '.eps']);
exportgraphics(fig, pngPath, 'Resolution', 200);
exportgraphics(fig, pdfPath, 'ContentType', 'vector');
savefig(fig, figPath);
set(fig, 'Renderer', 'painters');
print(fig, '-depsc', epsPath);

targetStem = lower(regexprep(fearLabel, '\s+', '_'));
writetable(fearFullTbl, fullfile(outDir, sprintf('%s_summary_full.csv', targetStem)));
writetable(fearMicroTbl, fullfile(outDir, sprintf('%s_summary_micro.csv', targetStem)));

out = struct();
out.figure = fig;
out.outputDir = outDir;
out.pngPath = pngPath;
out.pdfPath = pdfPath;
out.figPath = figPath;
out.epsPath = epsPath;
out.fearFullTbl = fearFullTbl;
out.fearMicroTbl = fearMicroTbl;
out.sharedCLim = sharedCLim;
out.handles = struct('full', R1, 'micro', R2);
end

function outTbl = localBuildFearSummaryTable(ksTbl, fearLabel)
if isempty(ksTbl)
    outTbl = localEmptyFearSummaryTable();
    return;
end

keep = strcmp(string(ksTbl.emotionA), string(fearLabel)) | strcmp(string(ksTbl.emotionB), string(fearLabel));
T = ksTbl(keep, :);

rows = struct('subjectID', {}, 'markerGroup', {}, 'emotionA', {}, 'emotionB', {}, 'fearSummary', {});
pairLabel = "FEAR-SUMMARY";
subjects = unique(string(T.subjectID), 'stable');
groups = unique(string(T.markerGroup), 'stable');
idx = 1;
for s = 1:numel(subjects)
    Ts = T(string(T.subjectID) == subjects(s), :);
    for g = 1:numel(groups)
        Tg = Ts(string(Ts.markerGroup) == groups(g), :);
        if isempty(Tg)
            continue;
        end
        vals = Tg.ksD;
        vals = vals(isfinite(vals));
        if isempty(vals)
            continue;
        end
        rows(idx).subjectID = char(subjects(s)); %#ok<AGROW>
        rows(idx).markerGroup = char(groups(g)); %#ok<AGROW>
        rows(idx).emotionA = fearLabel; %#ok<AGROW>
        rows(idx).emotionB = 'SUMMARY'; %#ok<AGROW>
        rows(idx).fearSummary = median(vals, 'omitnan'); %#ok<AGROW>
        idx = idx + 1;
    end
end

if isempty(rows)
    outTbl = localEmptyFearSummaryTable();
else
    outTbl = struct2table(rows);
end
end

function T = localEmptyFearSummaryTable()
T = table(cell(0,1), cell(0,1), cell(0,1), cell(0,1), zeros(0,1), ...
    'VariableNames', {'subjectID','markerGroup','emotionA','emotionB','fearSummary'});
end

function ksTbl = localComputeFearKsTable(resultsCell, codingTable, fearLabel, otherEmotions, speedField, minSamplesPerCond, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
vids = string(codingTable(:,1));
emos = string(codingTable(:,2));
vidToEmotion = containers.Map('KeyType','char','ValueType','char');
for i = 1:numel(vids)
    vidToEmotion(char(vids(i))) = char(emos(i));
end

rows = struct('subjectID', {}, 'markerGroup', {}, 'emotionA', {}, 'emotionB', {}, 'ksD', {});
idxRow = 1;
for s = 1:numel(resultsCell)
    rc = resultsCell{s};
    if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
        continue;
    end
    st = rc.summaryTable;
    if ~ismember(speedField, st.Properties.VariableNames)
        continue;
    end
    subjectID = '';
    if isfield(rc, 'subjectID') && ~isempty(rc.subjectID)
        subjectID = char(string(rc.subjectID));
    else
        subjectID = sprintf('subj%d', s);
    end

    stEmotion = repmat({''}, height(st), 1);
    for r = 1:height(st)
        vid = char(string(st.videoID{r}));
        if isKey(vidToEmotion, vid)
            stEmotion{r} = vidToEmotion(vid);
        end
    end

    groups = unique(string(st.markerGroup), 'stable');
    for g = 1:numel(groups)
        gMask = strcmp(string(st.markerGroup), groups(g));
        fearVals = localConcatCells(st.(speedField)(gMask & strcmp(string(stEmotion), string(fearLabel))));
        fearVals = fearVals(:);
        fearVals = fearVals(isfinite(fearVals));
        if doBaselineNormalize
            baseVal = localBaselineScalarForSubject(st, stEmotion, char(groups(g)), baselineEmotion, baselineFromField, minBaselineSamples);
            if ~(isfinite(baseVal) && baseVal > 0)
                continue;
            end
            fearVals = fearVals ./ baseVal;
        end
        if numel(fearVals) < minSamplesPerCond
            continue;
        end
        for e = 1:numel(otherEmotions)
            other = string(otherEmotions(e));
            otherVals = localConcatCells(st.(speedField)(gMask & strcmp(string(stEmotion), other)));
            otherVals = otherVals(:);
            otherVals = otherVals(isfinite(otherVals));
            if doBaselineNormalize
                otherVals = otherVals ./ baseVal;
            end
            if numel(otherVals) < minSamplesPerCond
                continue;
            end
            [~, ~, ksD] = kstest2(fearVals, otherVals);
            rows(idxRow).subjectID = subjectID; %#ok<AGROW>
            rows(idxRow).markerGroup = char(groups(g)); %#ok<AGROW>
            rows(idxRow).emotionA = fearLabel; %#ok<AGROW>
            rows(idxRow).emotionB = char(other); %#ok<AGROW>
            rows(idxRow).ksD = ksD; %#ok<AGROW>
            idxRow = idxRow + 1;
        end
    end
end

if isempty(rows)
    ksTbl = table(cell(0,1), cell(0,1), cell(0,1), cell(0,1), zeros(0,1), ...
        'VariableNames', {'subjectID','markerGroup','emotionA','emotionB','ksD'});
else
    ksTbl = struct2table(rows);
end
end

function vals = localConcatCells(cellVals)
vals = [];
for i = 1:numel(cellVals)
    v = cellVals{i};
    if ~isempty(v)
        vals = [vals; v(:)]; %#ok<AGROW>
    end
end
end

function baseVal = localBaselineScalarForSubject(st, stEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples)
baseVal = NaN;
if ~ismember(baselineFromField, st.Properties.VariableNames)
    return;
end
idx = strcmp(string(st.markerGroup), string(markerGroup)) & strcmp(string(stEmotion), string(baselineEmotion));
if ~any(idx)
    return;
end
vv = localConcatCells(st.(baselineFromField)(idx));
vv = vv(isfinite(vv));
if numel(vv) < minBaselineSamples
    return;
end
baseVal = median(vv, 'omitnan');
if ~(isfinite(baseVal) && baseVal > 0)
    baseVal = NaN;
end
end

function vals = localAggregateDisplayedValues(T)
vals = [];
if isempty(T)
    return;
end
groups = unique(string(T.markerGroup), 'stable');
for i = 1:numel(groups)
    gvals = T.fearSummary(string(T.markerGroup) == groups(i));
    gvals = gvals(isfinite(gvals));
    if isempty(gvals)
        continue;
    end
    vals(end+1,1) = median(gvals, 'omitnan'); %#ok<AGROW>
end
end

function T = localApplyGrayGroups(T, grayGroups)
if isempty(T)
    return;
end
mask = ismember(string(T.markerGroup), string(grayGroups));
T.fearSummary(mask) = NaN;
end
