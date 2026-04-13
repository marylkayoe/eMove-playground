% plot_frontstb_clipmotion_rating_panels.m
%
% Create a visually cleaner 4-panel summary of the within-subject
% front-STb clip-view low-animation motion effect against:
%   - valence
%   - arousal
%   - liking
%   - familiarity
%
% Ratings on 1-9 scales are grouped into three bins (1-3, 4-6, 7-9).
% Familiarity is shown at its native 1-5 levels.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'frontstb_vs_physiology_joined.csv');
statsCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'frontstb_vs_physiology_stats.csv');
outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'styled_panels');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(dataCsv);
S = readtable(statsCsv);

keep = isfinite(T.clipDynamicMedian);
for f = ["valence","arousal","liking","familiarity"]
    keep = keep & isfinite(T.(f));
end
T = T(keep, :);

[G, groupIDs] = findgroups(string(T.participantID)); %#ok<ASGLU>
clipMu = splitapply(@mean, T.clipDynamicMedian, G);
T.clipCentered = T.clipDynamicMedian - clipMu(G);

fig = figure('Color', 'w', 'Position', [80 80 1280 860]);
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

panelDefs = { ...
    struct('field',"valence",     'title',"Valence",     'mode',"triple", 'labels',{{'1-3','4-6','7-9'}}, 'color',[0.18 0.47 0.72]), ...
    struct('field',"arousal",     'title',"Arousal",     'mode',"triple", 'labels',{{'1-3','4-6','7-9'}}, 'color',[0.84 0.39 0.13]), ...
    struct('field',"liking",      'title',"Liking",      'mode',"triple", 'labels',{{'1-3','4-6','7-9'}}, 'color',[0.24 0.62 0.41]), ...
    struct('field',"familiarity", 'title',"Familiarity", 'mode',"native5", 'labels',{{'1','2','3','4','5'}}, 'color',[0.56 0.34 0.67]) ...
    };

allY = T.clipCentered;
yLo = prctile(allY, 1) - 0.15 * range(prctile(allY, [1 99]));
yHi = prctile(allY, 99) + 0.20 * range(prctile(allY, [1 99]));

for i = 1:numel(panelDefs)
    ax = nexttile(tlo, i);
    hold(ax, 'on');
    box(ax, 'off');
    ax.FontName = 'Helvetica';
    ax.FontSize = 11;
    ax.LineWidth = 1.0;
    ax.YGrid = 'on';
    ax.XGrid = 'off';
    ax.GridAlpha = 0.16;
    ax.Layer = 'top';
    ax.Color = [0.995 0.995 0.995];

    d = panelDefs{i};
    x = T.(d.field);
    y = T.clipCentered;

    switch d.mode
        case "triple"
            binIdx = discretize(x, [0 3 6 9], 'IncludedEdge', 'right');
            xLabels = d.labels;
        case "native5"
            binIdx = x;
            xLabels = d.labels;
    end

    good = ~isnan(binIdx) & isfinite(y);
    binIdx = binIdx(good);
    y = y(good);

    b = boxchart(ax, binIdx, y, 'BoxWidth', 0.55, 'MarkerStyle', '.', ...
        'MarkerColor', d.color .* 0.75, 'WhiskerLineColor', d.color .* 0.75);
    b.BoxFaceColor = d.color;
    b.BoxFaceAlpha = 0.30;
    b.LineWidth = 1.5;
    b.JitterOutliers = 'on';
    b.MarkerStyle = '.';
    b.MarkerSize = 5;

    nBins = numel(xLabels);
    med = nan(nBins, 1);
    n = nan(nBins, 1);
    for k = 1:nBins
        med(k) = median(y(binIdx == k), 'omitnan');
        n(k) = nnz(binIdx == k);
    end
    plot(ax, 1:nBins, med, '-o', 'Color', d.color .* 0.7, ...
        'LineWidth', 2.0, 'MarkerFaceColor', d.color, 'MarkerEdgeColor', 'w', 'MarkerSize', 6);

    statRow = S(strcmp(S.metric, 'clipDynamicMedian') & strcmp(S.rating, d.field), :);
    if ~isempty(statRow)
        subtitleText = sprintf('within-subject r = %.3f, p = %.2g', ...
            statRow.withinSubject_r(1), statRow.withinSubject_p(1));
    else
        subtitleText = '';
    end

    title(ax, {char(d.title), subtitleText}, 'FontWeight', 'bold', 'FontSize', 13);
    xlim(ax, [0.5 nBins + 0.5]);
    ylim(ax, [yLo yHi]);
    xticks(ax, 1:nBins);
    xticklabels(ax, xLabels);
    ylabel(ax, 'Centered clip motion');
    yline(ax, 0, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);

    for k = 1:nBins
        text(ax, k, yHi - 0.04 * (yHi - yLo), sprintf('n=%d', n(k)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', 9, 'Color', [0.25 0.25 0.25]);
    end
end

title(tlo, 'Front STb clip-view low-animation motion across clip ratings', ...
    'FontSize', 18, 'FontWeight', 'bold');
xlabel(tlo, 'Rating bins');

exportgraphics(fig, fullfile(outDir, 'frontstb_clipmotion_4panel_ratings.png'), 'Resolution', 220);
savefig(fig, fullfile(outDir, 'frontstb_clipmotion_4panel_ratings.fig'));

