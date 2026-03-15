% make_reversal_probability_summary_05.m
%
% Show pooled-reversal cells with bootstrap reversal probability down to 0.50,
% including lower limbs for context.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','LOWER_LIMB_L','LOWER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
minProb = 0.50;

latestQcDir = localFindLatestStampedDir(figRoot, 'reversal_stability_qc_');
metricsCsv = fullfile(latestQcDir, 'reversal_stability_metrics.csv');
if ~isfile(metricsCsv)
    error('reversal_stability_metrics.csv not found: %s', metricsCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['reversal_probability_summary_05_' runStamp]);
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
    Tn = T(T.normalization == normLabel & ismember(T.markerGroup, markerGroupsPlot), :);

    M = nan(numel(markerGroupsPlot), numel(pairLabels));
    A = nan(numel(markerGroupsPlot), numel(pairLabels));
    for r = 1:numel(markerGroupsPlot)
        for c = 1:numel(pairLabels)
            row = Tn(Tn.markerGroup == markerGroupsPlot{r} & Tn.pairLabel == pairLabels{c}, :);
            if isempty(row)
                continue;
            end
            if row.pooledFlip(1) == 1 && row.bootstrapFlipProbability(1) >= minProb
                M(r,c) = row.bootstrapFlipProbability(1);
                A(r,c) = row.pooledVsSubjectAgree(1);
            end
        end
    end

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [100 100 1450 780]);
    tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Pooled reversal cells with bootstrap probability >= %.2f | %s', minProb, figureLabel), ...
        'FontSize', 22, 'FontWeight', 'bold');

    ax1 = nexttile(tl, 1);
    imagesc(ax1, M, [minProb 1]);
    colormap(ax1, turbo);
    cb1 = colorbar(ax1);
    ylabel(cb1, 'Bootstrap reversal probability');
    title(ax1, 'Pooled reversals that survive at or above chance', 'FontSize', 14, 'FontWeight', 'bold');
    set(ax1, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax1, 35);
    localAnnotateMatrix(ax1, M, minProb);

    ax2 = nexttile(tl, 2);
    imagesc(ax2, A, [0 1]);
    colormap(ax2, summer);
    cb2 = colorbar(ax2);
    ylabel(cb2, 'Agreement');
    title(ax2, 'Pooled raw vs subject-median aggregation agreement', 'FontSize', 14, 'FontWeight', 'bold');
    set(ax2, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax2, 35);
    localAnnotateAgreement(ax2, A);

    annotation(f, 'textbox', [0.10 0.02 0.82 0.05], ...
        'String', 'This view includes cells down to 0.50 bootstrap probability. Values close to 0.50 should be treated as weak/at-chance rather than persuasive.', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

    baseName = sprintf('reversal_probability_summary_05_%s', strrep(char(normLabel), '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

fprintf('Saved 0.50-threshold reversal summary under:\n%s\n', outDir);

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

function localAnnotateMatrix(ax, M, minProb)
    for r = 1:size(M,1)
        for c = 1:size(M,2)
            if isfinite(M(r,c))
                txtColor = [1 1 1];
                if M(r,c) < (minProb + 0.25*(1-minProb))
                    txtColor = [0 0 0];
                end
                text(ax, c, r, sprintf('%.2f', M(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 10, 'FontWeight', 'bold', 'Color', txtColor);
            end
        end
    end
end

function localAnnotateAgreement(ax, A)
    for r = 1:size(A,1)
        for c = 1:size(A,2)
            if isfinite(A(r,c))
                txtColor = [0 0 0];
                if A(r,c) > 0.5
                    txtColor = [1 1 1];
                end
                text(ax, c, r, sprintf('%.0f', A(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 10, 'FontWeight', 'bold', 'Color', txtColor);
            end
        end
    end
end
