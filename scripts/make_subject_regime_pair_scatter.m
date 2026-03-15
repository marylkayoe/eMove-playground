% make_subject_regime_pair_scatter.m
%
% Subject-level version of the regime-pair scatter:
% one point = one subject x one emotion pair for one bodypart.
% Small multiples by bodypart, color by emotion pair only.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};

latestSubjectDir = localFindLatestStampedDir(figRoot, 'regime_subject_level_');
flipCsv = fullfile(latestSubjectDir, 'subject_pairwise_flips.csv');
if ~isfile(flipCsv)
    error('subject_pairwise_flips.csv not found: %s', flipCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['subject_regime_pair_scatter_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(flipCsv, 'TextType', 'string');
keepPairs = ~contains(T.pairLabel, "FEAR");
T = T(keepPairs & ismember(T.markerGroup, markerGroupsPlot) & T.comparable == 1, :);
pairLabels = unique(T.pairLabel, 'stable');
pairDisplayLabels = cell(size(pairLabels));
for i = 1:numel(pairLabels)
    pairDisplayLabels{i} = localReversePairLabel(pairLabels{i});
end
pairColors = lines(numel(pairLabels));

fprintf('Using subject-level pair table: %s\n', flipCsv);
fprintf('Output dir: %s\n', outDir);

for normIdx = 1:2
    if normIdx == 1
        normLabel = "absolute";
        panelTitle = 'Absolute';
    else
        normLabel = "baseline-normalized";
        panelTitle = 'Baseline-normalized';
    end

    Tn = T(T.normalization == normLabel, :);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 60 1500 980]);
    tl = tiledlayout(f, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Subject-level upper-body regime contrasts (FEAR excluded) | %s', panelTitle), ...
        'FontSize', 22, 'FontWeight', 'bold');

    for g = 1:numel(markerGroupsPlot)
        ax = nexttile(tl, g); hold(ax, 'on');
        mg = markerGroupsPlot{g};
        Tg = Tn(Tn.markerGroup == mg, :);
        [xLims, yLims] = localAxisLimits(Tg.deltaFull, Tg.deltaMicro);
        diagMin = min([xLims(1), yLims(1)]);
        diagMax = max([xLims(2), yLims(2)]);
        localShadeReversalQuadrants(ax, xLims, yLims);
        plot(ax, [diagMin diagMax], [diagMin diagMax], '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.1, 'HandleVisibility', 'off');
        xline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
        yline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');

        for p = 1:numel(pairLabels)
            pairMask = Tg.pairLabel == pairLabels{p};
            Tp = Tg(pairMask, :);
            if isempty(Tp)
                continue;
            end
            scatter(ax, Tp.deltaFull, Tp.deltaMicro, 48, ...
                'MarkerFaceColor', pairColors(p,:), ...
                'MarkerEdgeColor', pairColors(p,:), ...
                'MarkerFaceAlpha', 0.28, ...
                'MarkerEdgeAlpha', 0.55, ...
                'LineWidth', 0.8, ...
                'HandleVisibility', 'off');
        end

        title(ax, strrep(mg, '_', '-'), 'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');
        xlabel(ax, '\Delta full', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel(ax, '\Delta micro', 'FontSize', 12, 'FontWeight', 'bold');
        xlim(ax, xLims);
        ylim(ax, yLims);
        grid(ax, 'on');
        set(ax, 'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
        ax.Toolbar.Visible = 'off';
    end

    axKey = nexttile(tl, 8, [1 2]);
    axis(axKey, 'off');
    hold(axKey, 'on');
    xlim(axKey, [0 1]);
    ylim(axKey, [0 1]);
    axKey.Toolbar.Visible = 'off';
    text(axKey, 0.0, 1.0, 'Emotion-pair colors', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    for i = 1:numel(pairLabels)
        y = 0.88 - (i-1) * 0.12;
        patch(axKey, [0.02 0.08 0.08 0.02], [y-0.025 y-0.025 y+0.025 y+0.025], pairColors(i,:), ...
            'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 0.8);
        text(axKey, 0.12, y, strrep(pairDisplayLabels{i}, '_', '-'), ...
            'FontSize', 12, 'Interpreter', 'none', 'VerticalAlignment', 'middle');
    end
    text(axKey, 0.55, 0.12, sprintf('Points = subject x pair\nNo bodypart encoding inside panels\nEach panel is one bodypart'), ...
        'FontSize', 12, 'Color', [0.25 0.25 0.25], 'VerticalAlignment', 'top');

    baseName = sprintf('subject_regime_pair_scatter_%s', strrep(char(normLabel), '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

fprintf('Saved subject-level pair scatter under:\n%s\n', outDir);

%% Helpers
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

function [xLims, yLims] = localAxisLimits(xVals, yVals)
    xLims = localPaddedLimits(xVals);
    yLims = localPaddedLimits(yVals);
end

function lims = localPaddedLimits(vals)
    vals = vals(isfinite(vals));
    if isempty(vals)
        lims = [-1 1];
        return;
    end
    vMin = min(vals);
    vMax = max(vals);
    if vMin == vMax
        pad = max(0.15 * max(abs(vMin), 1), 0.25);
    else
        pad = max(0.12 * (vMax - vMin), 0.15);
    end
    lims = [vMin - pad, vMax + pad];
end

function localShadeReversalQuadrants(ax, xLims, yLims)
    greenShade = [0.70 0.88 0.72];
    redShade = [0.93 0.72 0.72];
    faceAlpha = 0.14;
    if xLims(2) > 0 && yLims(1) < 0
        patch(ax, [0 xLims(2) xLims(2) 0], [yLims(1) yLims(1) 0 0], redShade, ...
            'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    if xLims(1) < 0 && yLims(2) > 0
        patch(ax, [xLims(1) 0 0 xLims(1)], [0 0 yLims(2) yLims(2)], greenShade, ...
            'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

function out = localReversePairLabel(label)
    parts = split(string(label), "-");
    if numel(parts) == 2
        out = char(parts(2) + "-" + parts(1));
    else
        out = char(label);
    end
end
