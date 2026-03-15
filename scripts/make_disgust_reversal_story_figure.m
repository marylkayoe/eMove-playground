% make_disgust_reversal_story_figure.m
%
% Build a compact story figure:
%   1. One individual subject with clear disgust-centered reversals.
%   2. Pooled stable disgust-centered reversal summary.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
exampleSubject = "SC3001";
bootstrapThreshold = 0.60;

latestSubjectDir = localFindLatestStampedDir(figRoot, 'regime_subject_level_');
latestQcDir = localFindLatestStampedDir(figRoot, 'reversal_stability_qc_');
subjectCsv = fullfile(latestSubjectDir, 'subject_pairwise_flips.csv');
metricsCsv = fullfile(latestQcDir, 'reversal_stability_metrics.csv');

if ~isfile(subjectCsv), error('Missing subject pairwise CSV: %s', subjectCsv); end
if ~isfile(metricsCsv), error('Missing QC metrics CSV: %s', metricsCsv); end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['disgust_reversal_story_' runStamp]);
if ~exist(outDir, 'dir'), mkdir(outDir); end

subjTbl = readtable(subjectCsv, 'TextType', 'string');
metricsTbl = readtable(metricsCsv, 'TextType', 'string');

subjTbl = subjTbl(subjTbl.subjectID == exampleSubject & subjTbl.comparable == 1, :);
subjTbl = subjTbl(contains(subjTbl.pairLabel, "DISGUST") & ismember(subjTbl.markerGroup, markerGroupsPlot), :);
metricsTbl = metricsTbl(contains(metricsTbl.pairLabel, "DISGUST") & ismember(metricsTbl.markerGroup, markerGroupsPlot), :);

pairLabels = unique(metricsTbl.pairLabel, 'stable');
pairDisplayLabels = cell(size(pairLabels));
for i = 1:numel(pairLabels)
    pairDisplayLabels{i} = localReversePairLabel(pairLabels{i});
end
pairColors = lines(numel(pairLabels));

fprintf('Example subject: %s\n', exampleSubject);
fprintf('Output dir: %s\n', outDir);

f = figure('Color', 'w', 'Units', 'pixels', 'Position', [60 60 1680 980]);
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Disgust-centered regime reversals | subject example first, pooled stability second | %s', exampleSubject), ...
    'FontSize', 22, 'FontWeight', 'bold');

for normIdx = 1:2
    if normIdx == 1
        normLabel = "absolute";
        label = 'Absolute';
    else
        normLabel = "baseline-normalized";
        label = 'Baseline-normalized';
    end

    % Subject example scatter
    ax = nexttile(tl, normIdx);
    hold(ax, 'on');
    Tsub = subjTbl(subjTbl.normalization == normLabel, :);
    [xLims, yLims] = localAxisLimits(Tsub.deltaFull, Tsub.deltaMicro);
    diagMin = min([xLims(1), yLims(1)]);
    diagMax = max([xLims(2), yLims(2)]);
    localShadeReversalQuadrants(ax, xLims, yLims);
    plot(ax, [diagMin diagMax], [diagMin diagMax], '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.1);
    xline(ax, 0, ':', 'Color', [0.65 0.65 0.65]);
    yline(ax, 0, ':', 'Color', [0.65 0.65 0.65]);
    localAnnotateReversalQuadrants(ax, xLims, yLims);

    for g = 1:numel(markerGroupsPlot)
        mg = markerGroupsPlot{g};
        Tg = Tsub(Tsub.markerGroup == mg, :);
        for p = 1:height(Tg)
            pairIdx = find(strcmp(cellstr(pairLabels), char(Tg.pairLabel(p))), 1);
            if isempty(pairIdx)
                continue;
            end
            scatter(ax, Tg.deltaFull(p), Tg.deltaMicro(p), 420, ...
                'MarkerFaceColor', pairColors(pairIdx,:), ...
                'MarkerEdgeColor', [0.1 0.1 0.1], ...
                'LineWidth', 1.0, ...
                'MarkerFaceAlpha', ternary(logical(Tg.signFlip(p)), 0.95, 0.25), ...
                'MarkerEdgeAlpha', 0.95);
            text(ax, Tg.deltaFull(p), Tg.deltaMicro(p), sprintf('%d', g), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 13, 'FontWeight', 'bold', 'Color', ternaryColor(logical(Tg.signFlip(p))));
        end
    end
    title(ax, sprintf('%s | %s subject example', label, exampleSubject), 'Interpreter', 'none', 'FontSize', 15, 'FontWeight', 'bold');
    xlabel(ax, '\Delta full', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax, '\Delta micro', 'FontSize', 12, 'FontWeight', 'bold');
    xlim(ax, xLims); ylim(ax, yLims); grid(ax, 'on');
    set(ax, 'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    ax.Toolbar.Visible = 'off';

    % Pooled stable heatmap
    axH = nexttile(tl, normIdx + 3);
    Tm = metricsTbl(metricsTbl.normalization == normLabel, :);
    M = nan(numel(markerGroupsPlot), numel(pairLabels));
    for r = 1:numel(markerGroupsPlot)
        for c = 1:numel(pairLabels)
            row = Tm(Tm.markerGroup == markerGroupsPlot{r} & Tm.pairLabel == pairLabels{c}, :);
            if isempty(row), continue; end
            if row.pooledFlip(1) == 1 && row.bootstrapFlipProbability(1) >= bootstrapThreshold
                M(r,c) = row.bootstrapFlipProbability(1);
            end
        end
    end
    imagesc(axH, M, [bootstrapThreshold 1]);
    colormap(axH, turbo);
    colorbar(axH);
    title(axH, sprintf('%s | pooled stable disgust cells', label), 'FontSize', 15, 'FontWeight', 'bold');
    set(axH, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(axH, 35);
    localAnnotateMatrix(axH, M);
    axH.Toolbar.Visible = 'off';
end

% Key panel
axKey = nexttile(tl, 3);
axis(axKey, 'off'); hold(axKey, 'on');
xlim(axKey, [0 1]); ylim(axKey, [0 1]); axKey.Toolbar.Visible = 'off';
text(axKey, 0.0, 1.0, 'Disgust-pair colors', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
for i = 1:numel(pairLabels)
    y = 0.88 - (i-1) * 0.12;
    patch(axKey, [0.02 0.10 0.10 0.02], [y-0.025 y-0.025 y+0.025 y+0.025], pairColors(i,:), ...
        'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 0.8);
    text(axKey, 0.14, y, strrep(pairDisplayLabels{i}, '_', '-'), 'FontSize', 12, 'Interpreter', 'none', 'VerticalAlignment', 'middle');
end
text(axKey, 0.0, 0.40, 'Bodypart numbers', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
localDrawBodypartKeyStickFigure(axKey);
text(axKey, 0.0, 0.02, sprintf('Subject panel: one %s point per bodypart x pair\nHeatmaps: only pooled reversals with bootstrap >= %.2f', exampleSubject, bootstrapThreshold), ...
    'FontSize', 11, 'Color', [0.25 0.25 0.25]);

exportgraphics(f, fullfile(outDir, 'disgust_reversal_story.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'disgust_reversal_story.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'disgust_reversal_story.fig'));

fprintf('Saved disgust reversal story figure under:\n%s\n', outDir);

%% Helpers
function latestDir = localFindLatestStampedDir(rootDir, prefix)
    d = dir(rootDir);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    isMatch = startsWith(names, prefix);
    names = sort(names(isMatch));
    if isempty(names), error('No directories starting with %s under %s', prefix, rootDir); end
    latestDir = fullfile(rootDir, char(names(end)));
end

function out = localReversePairLabel(label)
    parts = split(string(label), "-");
    if numel(parts) == 2
        out = char(parts(2) + "-" + parts(1));
    else
        out = char(label);
    end
end

function [xLims, yLims] = localAxisLimits(xVals, yVals)
    xLims = localPaddedLimits(xVals);
    yLims = localPaddedLimits(yVals);
end

function lims = localPaddedLimits(vals)
    vals = vals(isfinite(vals));
    if isempty(vals), lims = [-1 1]; return; end
    vMin = min(vals); vMax = max(vals);
    if vMin == vMax
        pad = max(0.15 * max(abs(vMin), 1), 0.25);
    else
        pad = max(0.12 * (vMax - vMin), 0.15);
    end
    lims = [vMin - pad, vMax + pad];
end

function localShadeReversalQuadrants(ax, xLims, yLims)
    patch(ax, [xLims(1) 0 0 xLims(1)], [0 0 yLims(2) yLims(2)], [0.70 0.88 0.72], ...
        'FaceAlpha', 0.16, 'EdgeColor', 'none');
    patch(ax, [0 xLims(2) xLims(2) 0], [yLims(1) yLims(1) 0 0], [0.93 0.72 0.72], ...
        'FaceAlpha', 0.16, 'EdgeColor', 'none');
end

function localAnnotateReversalQuadrants(ax, xLims, yLims)
    xSpan = xLims(2) - xLims(1);
    if xLims(1) < 0 && yLims(2) > 0
        text(ax, xLims(1) + 0.04*xSpan, 0.5 * yLims(2), 'micro contrast becomes more positive', ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.18 0.40 0.18], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
    end
    if xLims(2) > 0 && yLims(1) < 0
        text(ax, xLims(2) - 0.04*xSpan, 0.5 * yLims(1), 'micro contrast becomes more negative', ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.55 0.18 0.18], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function c = ternaryColor(isFlip)
    if isFlip, c = [1 1 1]; else, c = [0.1 0.1 0.1]; end
end

function localAnnotateMatrix(ax, M)
    for r = 1:size(M,1)
        for c = 1:size(M,2)
            if isfinite(M(r,c))
                txtColor = [1 1 1];
                if M(r,c) < 0.72, txtColor = [0 0 0]; end
                text(ax, c, r, sprintf('%.2f', M(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 10, 'FontWeight', 'bold', 'Color', txtColor);
            end
        end
    end
end

function localDrawBodypartKeyStickFigure(ax)
    P.headTop   = [0.55 0.28];
    P.neck      = [0.55 0.24];
    P.lShoulder = [0.42 0.22];
    P.rShoulder = [0.68 0.22];
    P.chest     = [0.55 0.18];
    P.lElbow    = [0.34 0.16];
    P.rElbow    = [0.76 0.16];
    P.lWrist    = [0.28 0.11];
    P.rWrist    = [0.82 0.11];
    P.waist     = [0.55 0.10];
    baseColor = [0.82 0.82 0.82]; lw = 6;
    plot(ax, [P.neck(1) P.headTop(1)], [P.neck(2) P.headTop(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.lShoulder(1) P.neck(1) P.rShoulder(1)], [P.lShoulder(2) P.neck(2) P.rShoulder(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.chest(1) P.waist(1)], [P.chest(2) P.waist(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.lShoulder(1) P.lElbow(1) P.lWrist(1)], [P.lShoulder(2) P.lElbow(2) P.lWrist(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.rShoulder(1) P.rElbow(1) P.rWrist(1)], [P.rShoulder(2) P.rElbow(2) P.rWrist(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.neck(1) P.chest(1)], [P.neck(2) P.chest(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    labels = {1,[0.55 0.305];2,[0.55 0.19];3,[0.23 0.17];4,[0.87 0.17];5,[0.18 0.10];6,[0.90 0.10];7,[0.55 0.08]};
    for i = 1:size(labels,1)
        text(ax, labels{i,2}(1), labels{i,2}(2), sprintf('%d', labels{i,1}), ...
            'FontSize', 18, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    end
end
