% make_stable_reversal_summary_allbody.m
%
% Variant of the stable reversal summary that includes lower limbs as a brief
% negative-control view.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','LOWER_LIMB_L','LOWER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
bootstrapThreshold = 0.60;

latestQcDir = localFindLatestStampedDir(figRoot, 'reversal_stability_qc_');
metricsCsv = fullfile(latestQcDir, 'reversal_stability_metrics.csv');
if ~isfile(metricsCsv)
    error('reversal_stability_metrics.csv not found: %s', metricsCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['stable_reversal_summary_allbody_' runStamp]);
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

    stableMask = Tn.pooledFlip == 1 & Tn.bootstrapFlipProbability >= bootstrapThreshold;
    M = nan(numel(markerGroupsPlot), numel(pairLabels));
    for r = 1:numel(markerGroupsPlot)
        for c = 1:numel(pairLabels)
            row = Tn(Tn.markerGroup == markerGroupsPlot{r} & Tn.pairLabel == pairLabels{c}, :);
            if isempty(row)
                continue;
            end
            idx = find(strcmp(Tn.markerGroup, markerGroupsPlot{r}) & strcmp(Tn.pairLabel, pairLabels{c}), 1);
            if stableMask(idx)
                M(r,c) = row.bootstrapFlipProbability(1);
            end
        end
    end

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 100 980 820]);
    ax = axes('Parent', f);
    imagesc(ax, M, [bootstrapThreshold 1]);
    colormap(ax, turbo);
    cb = colorbar(ax);
    ylabel(cb, 'Bootstrap reversal probability');
    title(ax, sprintf('Stable reversal cells | %s | all-body context | bootstrap >= %.2f', figureLabel, bootstrapThreshold), ...
        'FontSize', 18, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax, 35);
    for r = 1:size(M,1)
        for c = 1:size(M,2)
            if isfinite(M(r,c))
                txtColor = [1 1 1];
                if M(r,c) < 0.72
                    txtColor = [0 0 0];
                end
                text(ax, c, r, sprintf('%.2f', M(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 10, 'FontWeight', 'bold', 'Color', txtColor);
            end
        end
    end

    annotation(f, 'textbox', [0.10 0.01 0.82 0.05], ...
        'String', 'Including lower limbs here acts as a negative control: if they stay blank while upper-body cells survive, the effect is not whole-body and indiscriminate.', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

    baseName = sprintf('stable_reversal_summary_allbody_%s', strrep(char(normLabel), '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

fprintf('Saved all-body stable-reversal summary under:\n%s\n', outDir);

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
