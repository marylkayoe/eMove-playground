% make_stable_reversal_summary_figure.m
%
% Presentation-oriented summary of reversal cells that remain stable under
% subject-aware bootstrap QC.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
bootstrapThreshold = 0.60;

latestQcDir = localFindLatestStampedDir(figRoot, 'reversal_stability_qc_');
metricsCsv = fullfile(latestQcDir, 'reversal_stability_metrics.csv');
if ~isfile(metricsCsv)
    error('reversal_stability_metrics.csv not found: %s', metricsCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['stable_reversal_summary_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(metricsCsv, 'TextType', 'string');
pairLabels = unique(T.pairLabel, 'stable');
pairDisplayLabels = cell(size(pairLabels));
for i = 1:numel(pairLabels)
    pairDisplayLabels{i} = localReversePairLabel(pairLabels{i});
end

fprintf('Using reversal-stability metrics: %s\n', metricsCsv);
fprintf('Output dir: %s\n', outDir);

for normIdx = 1:2
    if normIdx == 1
        normLabel = "absolute";
        figureLabel = 'Absolute';
    else
        normLabel = "baseline-normalized";
        figureLabel = 'Baseline-normalized';
    end
    Tn = T(T.normalization == normLabel, :);

    stableMask = Tn.pooledFlip == 1 & Tn.bootstrapFlipProbability >= bootstrapThreshold;

    M = nan(numel(markerGroupsPlot), numel(pairLabels));
    A = nan(numel(markerGroupsPlot), numel(pairLabels));
    for r = 1:numel(markerGroupsPlot)
        for c = 1:numel(pairLabels)
            row = Tn(Tn.markerGroup == markerGroupsPlot{r} & Tn.pairLabel == pairLabels{c}, :);
            if isempty(row)
                continue;
            end
            if stableMask(find(strcmp(Tn.markerGroup, markerGroupsPlot{r}) & strcmp(Tn.pairLabel, pairLabels{c}), 1))
                M(r,c) = row.bootstrapFlipProbability(1);
                A(r,c) = row.pooledVsSubjectAgree(1);
            end
        end
    end

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [100 100 1450 760]);
    tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Stable pooled reversal cells | %s | bootstrap >= %.2f', figureLabel, bootstrapThreshold), ...
        'FontSize', 22, 'FontWeight', 'bold');

    ax1 = nexttile(tl, 1);
    imagesc(ax1, M, [bootstrapThreshold 1]);
    colormap(ax1, turbo);
    cb1 = colorbar(ax1);
    ylabel(cb1, 'Bootstrap reversal probability');
    title(ax1, 'Only pooled reversals that survive subject resampling', 'FontSize', 14, 'FontWeight', 'bold');
    set(ax1, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax1, 35);
    localAnnotateMatrix(ax1, M, '%.2f');

    ax2 = nexttile(tl, 2);
    imagesc(ax2, A, [0 1]);
    colormap(ax2, summer);
    cb2 = colorbar(ax2);
    ylabel(cb2, 'Agreement');
    title(ax2, 'Do pooled raw and subject-median aggregation agree?', 'FontSize', 14, 'FontWeight', 'bold');
    set(ax2, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax2, 35);
    localAnnotateMatrix(ax2, A, '%.0f');

    annotation(f, 'textbox', [0.14 0.02 0.78 0.05], ...
        'String', 'Blank cells = pooled reversal did not meet the stability threshold. Stable cells are selective, not ubiquitous.', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.25 0.25 0.25]);

    baseName = sprintf('stable_reversal_summary_%s', strrep(char(normLabel), '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

fprintf('Saved stable-reversal summary figure under:\n%s\n', outDir);

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

function out = localReversePairLabel(label)
    parts = split(string(label), "-");
    if numel(parts) == 2
        out = char(parts(2) + "-" + parts(1));
    else
        out = char(label);
    end
end

function localAnnotateMatrix(ax, M, fmt)
    for r = 1:size(M,1)
        for c = 1:size(M,2)
            if isfinite(M(r,c))
                txtColor = [1 1 1];
                if M(r,c) < 0.72
                    txtColor = [0 0 0];
                end
                text(ax, c, r, sprintf(fmt, M(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 10, 'FontWeight', 'bold', 'Color', txtColor);
            end
        end
    end
end
