% plot_emowear_dynamic_to_dynamic_by_subject.m
%
% Visualize the regime-defined dynamic->dynamic episode scatter with
% subject-colored points and subject centroids.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
baseDir = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/emowear_regime_scatter_comparison_20260412_194949';
inFile = fullfile(baseDir, 'regime_features.csv');
outDir = fullfile(baseDir, 'subject_colored');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(inFile, 'TextType', 'string');

subjectIDs = unique(string(T.participantID), 'stable');
nSubjects = numel(subjectIDs);
cmap = lines(max(nSubjects, 7));

fig = figure('Color', 'w', 'Position', [80 80 1100 780]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');

centroidX = nan(nSubjects, 1);
centroidY = nan(nSubjects, 1);

for i = 1:nSubjects
    mask = string(T.participantID) == subjectIDs(i);
    x = T.preDynamicMedian(mask);
    y = T.walkDynamicMedian(mask);
    c = cmap(mod(i-1, size(cmap, 1)) + 1, :);
    scatter(ax, x, y, 18, 'filled', ...
        'MarkerFaceColor', c, ...
        'MarkerFaceAlpha', 0.35, ...
        'MarkerEdgeAlpha', 0.35, ...
        'HandleVisibility', 'off');
    centroidX(i) = mean(x, 'omitnan');
    centroidY(i) = mean(y, 'omitnan');
end

scatter(ax, centroidX, centroidY, 55, 'k', 'filled', 'MarkerFaceAlpha', 0.85);
text(ax, centroidX, centroidY, cellstr(subjectIDs), ...
    'FontSize', 7, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left', ...
    'Color', [0.1 0.1 0.1]);

[rPearson, pPearson] = corr(T.preDynamicMedian, T.walkDynamicMedian, 'Rows', 'complete', 'Type', 'Pearson');
localAddLeastSquaresLine(ax, T.preDynamicMedian, T.walkDynamicMedian);

xlabel(ax, 'Pre-walk low-animation dynamic median');
ylabel(ax, 'Walking dynamic median');
title(ax, sprintf('dynamic to dynamic | subject-colored pooled episodes (r = %.3f, p = %.3g, n = %d, subjects = %d)', ...
    rPearson, pPearson, height(T), nSubjects), 'Interpreter', 'none');

exportgraphics(fig, fullfile(outDir, 'pooled_scatter_dynamic_to_dynamic_subject_colored.png'), 'Resolution', 180);
savefig(fig, fullfile(outDir, 'pooled_scatter_dynamic_to_dynamic_subject_colored.fig'));

function localAddLeastSquaresLine(ax, x, y)
mask = ~isnan(x) & ~isnan(y);
x = x(mask);
y = y(mask);
if numel(x) < 2
    return;
end
p = polyfit(x, y, 1);
xx = linspace(min(x), max(x), 200);
yy = polyval(p, xx);
plot(ax, xx, yy, 'k-', 'LineWidth', 1.5);
end
