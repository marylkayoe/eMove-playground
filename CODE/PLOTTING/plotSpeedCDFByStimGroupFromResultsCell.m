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

p = inputParser;
addParameter(p, 'markerGroups', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'emotionInclude', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'emotionExclude', {'0','X','AMUSEMENT',''}, @(x) iscell(x) || isstring(x));
addParameter(p, 'plotMode', 'perVideoMedian', @(x) ischar(x) || isstring(x));
addParameter(p, 'useImmobile', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'immobilityField', 'speedArrayImmobile', @(x) ischar(x) || isstring(x));
addParameter(p, 'summaryField', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
addParameter(p, 'minSamplesPerSubj', 200, @(x) isscalar(x) && x>=0);
addParameter(p, 'tileCols', 3, @(x) isscalar(x) && x>=1);

addParameter(p, 'doBaselineNormalize', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'baselineEmotion', '0', @(x) ischar(x) || isstring(x));
addParameter(p, 'baselineFromField', '', @(x) ischar(x) || isstring(x)); % default: same as plotted field
addParameter(p, 'minBaselineSamples', 200, @(x) isscalar(x) && x>=0);

parse(p, varargin{:});

markerGroups = cellstr(string(p.Results.markerGroups));
emotionInclude = cellstr(string(p.Results.emotionInclude));
emotionExclude = cellstr(string(p.Results.emotionExclude));
plotMode = char(string(p.Results.plotMode));
useImmobile = p.Results.useImmobile;
immobilityField = char(string(p.Results.immobilityField));
summaryField = char(string(p.Results.summaryField));
outlierQuantile = p.Results.outlierQuantile;
minSamplesPerSubj = p.Results.minSamplesPerSubj;
tileCols = p.Results.tileCols;

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

emotionList = allEmotions(:);

for g = 1:nGroups
    mg = markerGroups{g};
    nexttile; hold on;

    switch plotMode
        case 'perVideoMedian'
            pooled = cell(numel(emotionList), 1);
            for e = 1:numel(emotionList)
                emo = emotionList{e};
                pooled{e} = localCollectSummaryValuesNormalized( ...
                    resultsCell, vidToEmotion, mg, emo, summaryField, ...
                    doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);

                pooled{e} = localApplyOutlierCut(pooled{e}, outlierQuantile);
            end
            localPlotPooledEcdfs(pooled);

            if doBaselineNormalize
                xlabel("Median speed (fold baseline)");
            else
                xlabel(localXLabelFromField(summaryField));
            end
            ylabel('CDF');
            title(sprintf('%s | perVideoMedian', mg));
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
                        rc, vidToEmotion, mg, emo, immobilityField, ...
                        doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);

                    vals = localApplyOutlierCut(vals, outlierQuantile);
                    valsAll = [valsAll; vals(:)]; %#ok<AGROW>
                end
                pooled{e} = valsAll;
            end

            localPlotPooledEcdfs(pooled);

            if doBaselineNormalize
                xlabel("Speed samples (fold baseline)");
            else
                xlabel(localXLabelFromField(immobilityField));
            end
            ylabel('CDF');
            title(sprintf('%s | pooledRaw', mg));
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
                        rc, vidToEmotion, mg, emo, immobilityField, ...
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
            title(sprintf('%s | perSubjectRaw (thin=subj, thick=median)', mg));
            grid on;

        otherwise
            error('Unknown plotMode: %s', plotMode);
    end
end

% Legend: in perSubjectRaw it's meaningless (many repeated lines)
if ~strcmp(plotMode, 'perSubjectRaw')
    legend(emotionList, 'Location', 'southeast');
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

function localPlotPooledEcdfs(pooledVals)
for i = 1:numel(pooledVals)
    v = pooledVals{i};
    if isempty(v), continue; end
    [f, x] = ecdf(v);
    stairs(x, f, 'LineWidth', 1.4);
end
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

idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, baselineEmotion);
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

function vals = localCollectSummaryValuesNormalized(resultsCell, vidToEmotion, markerGroup, emotion, summaryField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
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

    baseVal = 1;
    if doBaselineNormalize
        baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples);
        if ~isfinite(baseVal)
            continue;
        end
    end

    emoCol = localEmotionColumn(st, vidToEmotion);
    if isempty(emoCol)
        continue;
    end

    idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, emotion);
    v = st.(summaryField)(idx);
    v = v(~isnan(v));
    if isempty(v), continue; end

    vals = [vals; (v(:) ./ baseVal)]; %#ok<AGROW>
end
end

function vals = localCollectRawSamplesForSubject(rc, vidToEmotion, markerGroup, emotion, speedField)
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

idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, emotion);
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

function vals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
vals = localCollectRawSamplesForSubject(rc, vidToEmotion, markerGroup, emotion, speedField);

if ~doBaselineNormalize
    return;
end

baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples);
if ~isfinite(baseVal)
    vals = [];
    return;
end

vals = vals ./ baseVal;
end
