% make_regime_order_boxscatter_panels.m
%
% Presentation-oriented figure for comparing emotion ordering between
% full-motion and micromovement regimes without forcing them onto the same
% y-scale. Uses subject-level medians (box + jitter) and excludes FEAR and
% lower-limb groups for readability.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
subjectRunsRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
emotionOrder = {'NEUTRAL','DISGUST','JOY','SAD'};

addpath(genpath(fullfile(repoRoot, 'CODE')));

latestSubjectDir = localFindLatestStampedDir(subjectRunsRoot, 'regime_subject_level_');
vectorsCsv = fullfile(latestSubjectDir, 'subject_regime_vectors.csv');
if ~isfile(vectorsCsv)
    error('subject_regime_vectors.csv not found: %s', vectorsCsv);
end
if ~isfile(stimCsv)
    error('Stim coding CSV not found: %s', stimCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['regime_order_boxscatter_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

vectorsTbl = readtable(vectorsCsv, 'TextType', 'string');
codingTable = localLoadStimCodingTable(stimCsv);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionOrder);

vectorsTbl = vectorsTbl(ismember(vectorsTbl.markerGroup, markerGroupsPlot) & ...
    ismember(vectorsTbl.emotion, emotionOrder), :);

fprintf('Using subject-level vectors: %s\n', vectorsCsv);
fprintf('Output dir: %s\n', outDir);

for normIdx = 1:2
    if normIdx == 1
        normLabel = "absolute";
        yLabel = 'Median speed (mm/s)';
    else
        normLabel = "baseline-normalized";
        yLabel = 'Median speed (fold baseline)';
    end

    Tnorm = vectorsTbl(vectorsTbl.normalization == normLabel, :);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 50 1650 2200]);
    tl = tiledlayout(f, numel(markerGroupsPlot), 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, sprintf('Emotion ordering by regime (FEAR excluded) | %s | subject medians', char(normLabel)), ...
        'Interpreter', 'none', 'FontSize', 24, 'FontWeight', 'bold');

    for g = 1:numel(markerGroupsPlot)
        mg = markerGroupsPlot{g};
        Tmg = Tnorm(Tnorm.markerGroup == mg, :);

        localDrawRegimePanel(nexttile(tl, (g-1)*2 + 1), Tmg, emotionOrder, emotionColorMap, ...
            'fullMedian', sprintf('%s | Full', strrep(mg, '_', '-')), yLabel);
        localDrawRegimePanel(nexttile(tl, (g-1)*2 + 2), Tmg, emotionOrder, emotionColorMap, ...
            'microMedian', sprintf('%s | Micro', strrep(mg, '_', '-')), yLabel);
    end

    exportgraphics(f, fullfile(outDir, sprintf('regime_order_boxscatter_%s.png', strrep(char(normLabel), '-', '_'))), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, sprintf('regime_order_boxscatter_%s.pdf', strrep(char(normLabel), '-', '_'))), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, sprintf('regime_order_boxscatter_%s.fig', strrep(char(normLabel), '-', '_'))));
end

fprintf('Saved order-comparison figures under:\n%s\n', outDir);

%% Helpers
function localDrawRegimePanel(ax, Tmg, emotionOrder, emotionColorMap, valueField, panelTitle, yLabel)
    hold(ax, 'on');
    nE = numel(emotionOrder);
    xPos = 1:nE;
    allVals = [];

    for e = 1:nE
        emo = emotionOrder{e};
        vals = Tmg.(valueField)(Tmg.emotion == emo);
        vals = vals(isfinite(vals));
        if isempty(vals)
            continue;
        end
        allVals = [allVals; vals(:)]; %#ok<AGROW>

        bc = boxchart(ax, repmat(xPos(e), size(vals)), vals, ...
            'BoxFaceColor', emotionColorMap(emo), ...
            'BoxEdgeColor', emotionColorMap(emo), ...
            'MarkerStyle', 'none', ...
            'WhiskerLineColor', emotionColorMap(emo), ...
            'LineWidth', 1.2);
        bc.BoxFaceAlpha = 0.22;

        jitter = (rand(size(vals)) - 0.5) * 0.26;
        scatter(ax, xPos(e) + jitter, vals, 18, ...
            'MarkerFaceColor', emotionColorMap(emo), ...
            'MarkerEdgeColor', 'w', ...
            'LineWidth', 0.4, ...
            'MarkerFaceAlpha', 0.60, ...
            'MarkerEdgeAlpha', 0.45);

        medVal = median(vals, 'omitnan');
        plot(ax, xPos(e), medVal, 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', emotionColorMap(emo), ...
            'MarkerEdgeColor', [0 0 0], ...
            'LineWidth', 1.0, ...
            'HandleVisibility', 'off');
    end

    set(ax, 'XTick', xPos, 'XTickLabel', strrep(emotionOrder, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax, 25);
    grid(ax, 'on');
    title(ax, panelTitle, 'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');
    ylabel(ax, yLabel, 'FontSize', 11, 'FontWeight', 'bold');

    if isempty(allVals)
        ylim(ax, [0 1]);
    else
        ylim(ax, localPaddedLimits(allVals));
    end
end

function lims = localPaddedLimits(vals)
    vals = vals(isfinite(vals));
    if isempty(vals)
        lims = [0 1];
        return;
    end
    vMin = min(vals);
    vMax = max(vals);
    if vMin == vMax
        pad = max(0.1 * max(abs(vMin), 1), 0.15);
    else
        pad = max(0.10 * (vMax - vMin), 0.10);
    end
    lims = [vMin - pad, vMax + pad];
    if lims(1) > 0 && vMin >= 0
        lims(1) = max(0, vMin - pad);
    end
end

function latestDir = localFindLatestStampedDir(rootDir, prefix)
    d = dir(rootDir);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    isMatch = startsWith(names, prefix);
    names = sort(names(isMatch));
    if isempty(names)
        error('No directories starting with %s found under %s', prefix, rootDir);
    end
    latestDir = fullfile(rootDir, char(names(end)));
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
