% make_combined_regime_pair_scatter.m
%
% Combine all upper-body pooled pairwise regime contrasts into one scatter
% per normalization. Bodypart is encoded by color; emotion pair is encoded by
% point number with a compact decoding key.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};

latestRegimeDir = localFindLatestStampedDir(figRoot, 'regime_distinctness_');
pairwiseCsv = fullfile(latestRegimeDir, 'pairwise_regime_contrasts.csv');
if ~isfile(pairwiseCsv)
    error('pairwise_regime_contrasts.csv not found: %s', pairwiseCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['combined_regime_pair_scatter_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(pairwiseCsv, 'TextType', 'string');
T = T(ismember(T.markerGroup, markerGroupsPlot), :);
T = localCanonicalizeDisgustPairs(T);
pairLabels = unique(T.pairLabel, 'stable');
pairDisplayLabels = cellstr(strrep(pairLabels, '_', '-'));
pairColors = lines(numel(pairLabels));

fprintf('Using pairwise table: %s\n', pairwiseCsv);
fprintf('Output dir: %s\n', outDir);

f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 100 1800 760]);
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Upper-body pooled pairwise regime contrasts (FEAR excluded, disgust-centered)', ...
    'FontSize', 22, 'FontWeight', 'bold');

for normIdx = 1:2
    if normIdx == 1
        normLabel = "absolute";
        panelTitle = 'Absolute';
    else
        normLabel = "baseline-normalized";
        panelTitle = 'Baseline-normalized';
    end
    ax = nexttile(tl, normIdx); hold(ax, 'on');
    Tn = T(T.normalization == normLabel, :);
    [xLims, yLims] = localAxisLimits(Tn.deltaFull, Tn.deltaMicro);
    diagMin = min([xLims(1), yLims(1)]);
    diagMax = max([xLims(2), yLims(2)]);
    localShadeReversalQuadrants(ax, xLims, yLims);
    plot(ax, [diagMin diagMax], [diagMin diagMax], '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.2, 'HandleVisibility', 'off');
    xline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
    yline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
    localAnnotateReversalQuadrants(ax, xLims, yLims);

        for g = 1:numel(markerGroupsPlot)
            mg = markerGroupsPlot{g};
            Tg = Tn(Tn.markerGroup == mg, :);
            for p = 1:height(Tg)
                pairIdx = find(pairLabels == Tg.pairLabel(p), 1);
                isFlip = logical(Tg.signFlip(p));
                bodypartIdx = g;
                scatter(ax, Tg.deltaFull(p), Tg.deltaMicro(p), 560, ...
                    'MarkerFaceColor', pairColors(pairIdx,:), ...
                    'MarkerEdgeColor', [0.1 0.1 0.1], ...
                    'LineWidth', 1.1, ...
                    'MarkerFaceAlpha', ternary(isFlip, 0.95, 0.25), ...
                    'MarkerEdgeAlpha', 0.95, ...
                    'HandleVisibility', 'off');
                text(ax, Tg.deltaFull(p), Tg.deltaMicro(p), sprintf('%d', bodypartIdx), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 12, ...
                    'FontWeight', 'bold', ...
                    'Color', ternaryColor(isFlip));
            end
        end

    title(ax, panelTitle, 'FontSize', 16, 'FontWeight', 'bold');
    xlabel(ax, '\Delta full', 'FontSize', 13, 'FontWeight', 'bold');
    ylabel(ax, '\Delta micro', 'FontSize', 13, 'FontWeight', 'bold');
    xlim(ax, xLims);
    ylim(ax, yLims);
    grid(ax, 'on');
    set(ax, 'FontSize', 12, 'LineWidth', 1.0, 'Box', 'off');
    ax.Toolbar.Visible = 'off';
end

axKey = nexttile(tl, 3);
axis(axKey, 'off');
hold(axKey, 'on');
xlim(axKey, [0 1]);
ylim(axKey, [0 1]);
axKey.Toolbar.Visible = 'off';
text(axKey, 0.0, 1.0, 'Emotion-pair colors', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
for i = 1:numel(pairLabels)
    y = 0.93 - (i-1) * 0.085;
    patch(axKey, [0.02 0.10 0.10 0.02], [y-0.02 y-0.02 y+0.02 y+0.02], pairColors(i,:), ...
        'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 0.8);
    text(axKey, 0.14, y, strrep(pairDisplayLabels{i}, '_', '-'), 'FontSize', 12, 'Interpreter', 'none', 'VerticalAlignment', 'middle');
end
text(axKey, 0.0, 0.34, 'Bodypart numbers', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
localDrawBodypartKeyStickFigure(axKey);
text(axKey, 0.0, 0.02, 'Filled points: sign flip between regimes', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

exportgraphics(f, fullfile(outDir, 'combined_regime_pair_scatter.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'combined_regime_pair_scatter.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'combined_regime_pair_scatter.fig'));

fprintf('Saved combined pair scatter under:\n%s\n', outDir);

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

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function c = ternaryColor(isFlip)
    if isFlip
        c = [1 1 1];
    else
        c = [0.1 0.1 0.1];
    end
end

function localShadeReversalQuadrants(ax, xLims, yLims)
    greenShade = [0.70 0.88 0.72];
    redShade = [0.93 0.72 0.72];
    faceAlpha = 0.18;

    if xLims(2) > 0 && yLims(1) < 0
        patch(ax, [0 xLims(2) xLims(2) 0], [yLims(1) yLims(1) 0 0], redShade, ...
            'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    if xLims(1) < 0 && yLims(2) > 0
        patch(ax, [xLims(1) 0 0 xLims(1)], [0 0 yLims(2) yLims(2)], greenShade, ...
            'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

function localAnnotateReversalQuadrants(ax, xLims, yLims)
    xSpan = xLims(2) - xLims(1);
    ySpan = yLims(2) - yLims(1);

    if xLims(1) < 0 && yLims(2) > 0
        text(ax, xLims(1) + 0.04*xSpan, 0.5 * yLims(2), ...
            'micro contrast becomes more positive', ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.18 0.40 0.18], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Rotation', 90);
    end
    if xLims(2) > 0 && yLims(1) < 0
        text(ax, xLims(2) - 0.04*xSpan, 0.5 * yLims(1), ...
            'micro contrast becomes more negative', ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.55 0.18 0.18], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Rotation', 90);
    end
end

function T = localCanonicalizeDisgustPairs(T)
    for i = 1:height(T)
        parts = split(string(T.pairLabel(i)), "-");
        if numel(parts) ~= 2
            continue;
        end
        a = parts(1);
        b = parts(2);
        if a == "DISGUST"
            continue;
        end
        if b == "DISGUST"
            T.pairLabel(i) = "DISGUST-" + a;
            T.deltaFull(i) = -T.deltaFull(i);
            T.deltaMicro(i) = -T.deltaMicro(i);
        end
    end
    T.signFlip = sign(T.deltaFull) ~= 0 & sign(T.deltaMicro) ~= 0 & sign(T.deltaFull) ~= sign(T.deltaMicro);
end

function localDrawBodypartKeyStickFigure(ax)
    % Canonical key geometry in axis-key coordinates.
    P.headTop   = [0.55 0.29];
    P.neck      = [0.55 0.25];
    P.lShoulder = [0.42 0.23];
    P.rShoulder = [0.68 0.23];
    P.chest     = [0.55 0.19];
    P.lElbow    = [0.34 0.17];
    P.rElbow    = [0.76 0.17];
    P.lWrist    = [0.28 0.12];
    P.rWrist    = [0.82 0.12];
    P.waist     = [0.55 0.11];

    baseColor = [0.82 0.82 0.82];
    lw = 6;
    plot(ax, [P.neck(1) P.headTop(1)], [P.neck(2) P.headTop(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.lShoulder(1) P.neck(1) P.rShoulder(1)], [P.lShoulder(2) P.neck(2) P.rShoulder(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.chest(1) P.waist(1)], [P.chest(2) P.waist(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.lShoulder(1) P.lElbow(1) P.lWrist(1)], [P.lShoulder(2) P.lElbow(2) P.lWrist(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.rShoulder(1) P.rElbow(1) P.rWrist(1)], [P.rShoulder(2) P.rElbow(2) P.rWrist(2)], '-', 'Color', baseColor, 'LineWidth', lw);
    plot(ax, [P.neck(1) P.chest(1)], [P.neck(2) P.chest(2)], '-', 'Color', baseColor, 'LineWidth', lw);

    nodeNames = {'headTop','neck','lShoulder','rShoulder','chest','lElbow','rElbow','lWrist','rWrist','waist'};
    for i = 1:numel(nodeNames)
        pt = P.(nodeNames{i});
        plot(ax, pt(1), pt(2), 'o', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.35 0.35 0.35], 'MarkerSize', 8, 'LineWidth', 1);
    end

    labels = {
        1, [0.55 0.315];  % HEAD
        2, [0.55 0.20];   % UTORSO
        3, [0.23 0.18];   % UPPER_LIMB_L
        4, [0.87 0.18];   % UPPER_LIMB_R
        5, [0.18 0.11];   % WRIST_L
        6, [0.90 0.11];   % WRIST_R
        7, [0.55 0.09];   % LTORSO
    };
    for i = 1:size(labels,1)
        text(ax, labels{i,2}(1), labels{i,2}(2), sprintf('%d', labels{i,1}), ...
            'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    end
end
