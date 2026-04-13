% plot_emowear_frontstb_within_subject_centered_valence.m
%
% Create a within-subject-centered scatter plot for the front STb
% clip-view low-animation motion versus valence.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
inputCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_regime_surveys_20260413_091305', 'frontstb_regime_joined.csv');

if ~isfile(inputCsv)
    error('Input CSV not found: %s', inputCsv);
end

T = readtable(inputCsv, 'TextType', 'string');
T.participantID = string(T.participantID);

subjectIDs = unique(T.participantID, 'stable');
xCentered = nan(height(T), 1);
yCentered = nan(height(T), 1);

for i = 1:numel(subjectIDs)
    mask = T.participantID == subjectIDs(i);
    x = T.clipDynamicMedian(mask);
    y = T.valence(mask);
    keep = isfinite(x) & isfinite(y);
    if nnz(keep) < 2
        continue;
    end
    xCentered(mask) = x - mean(x(keep), 'omitnan');
    yCentered(mask) = y - mean(y(keep), 'omitnan');
end

keep = isfinite(xCentered) & isfinite(yCentered);
xCentered = xCentered(keep);
yCentered = yCentered(keep);

[rPearson, pPearson] = corr(xCentered, yCentered, 'Rows', 'complete', 'Type', 'Pearson');
[rSpearman, pSpearman] = corr(xCentered, yCentered, 'Rows', 'complete', 'Type', 'Spearman');

outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_regime_surveys_20260413_091305', 'within_subject');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fig = figure('Color', 'w', 'Position', [120 120 860 680]);
scatter(xCentered, yCentered, 18, [0.25 0.45 0.8], 'filled', ...
    'MarkerFaceAlpha', 0.35, 'MarkerEdgeAlpha', 0.35);
grid on;
xlabel('clipDynamicMedian (within-subject centered)');
ylabel('valence (within-subject centered)');
title(sprintf('front STb clipDynamicMedian vs valence | within-subject centered (r = %.3f, p = %.3g, rho = %.3f, p = %.3g, n = %d)', ...
    rPearson, pPearson, rSpearman, pSpearman, numel(xCentered)), ...
    'Interpreter', 'none');
hold on;
localAddLeastSquaresLine(xCentered, yCentered);
xline(0, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(0, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
hold off;

exportgraphics(fig, fullfile(outDir, 'scatter_clipDynamicMedian_vs_valence_within_subject_centered.png'), 'Resolution', 180);
savefig(fig, fullfile(outDir, 'scatter_clipDynamicMedian_vs_valence_within_subject_centered.fig'));

statsTbl = table(rPearson, pPearson, rSpearman, pSpearman, numel(xCentered), ...
    'VariableNames', {'pearson_r','pearson_p','spearman_rho','spearman_p','nRows'});
writetable(statsTbl, fullfile(outDir, 'scatter_clipDynamicMedian_vs_valence_within_subject_centered_stats.csv'));

disp(statsTbl);
fprintf('Saved outputs to:\n%s\n', outDir);

function localAddLeastSquaresLine(x, y)
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);
if numel(x) < 2
    return;
end
p = polyfit(x, y, 1);
xx = linspace(min(x), max(x), 200);
yy = polyval(p, xx);
plot(xx, yy, 'k-', 'LineWidth', 1.5);
end
