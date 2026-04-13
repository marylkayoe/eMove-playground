% plot_frontstb_valence_bins.m
%
% Boxplots of front STb clip-view low-animation motion grouped into
% integer-width valence bins (1..9), with raw and within-subject-centered
% versions.

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
keep = isfinite(T.clipDynamicMedian) & isfinite(T.valence);
T = T(keep, :);

T.valenceBin = min(9, max(1, round(T.valence)));

T.centeredClipDynamic = nan(height(T), 1);
subjectIDs = unique(T.participantID, 'stable');
for i = 1:numel(subjectIDs)
    mask = T.participantID == subjectIDs(i);
    x = T.clipDynamicMedian(mask);
    T.centeredClipDynamic(mask) = x - mean(x, 'omitnan');
end

binLevels = 1:9;
binCats = categorical(T.valenceBin, binLevels, string(binLevels));

outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_regime_surveys_20260413_091305', 'by_valence_integerbins');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fig1 = figure('Color', 'w', 'Position', [100 100 860 600]);
boxchart(binCats, T.clipDynamicMedian, ...
    'BoxFaceColor', [0.30 0.48 0.82], 'WhiskerLineColor', [0.25 0.25 0.25]);
grid on;
xlabel('Valence bin');
ylabel('front STb clipDynamicMedian');
title('front STb clip-view low-animation by valence bin (1-point bins)');
exportgraphics(fig1, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence_integerbins.png'), 'Resolution', 180);
savefig(fig1, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence_integerbins.fig'));

fig2 = figure('Color', 'w', 'Position', [120 120 860 600]);
boxchart(binCats, T.centeredClipDynamic, ...
    'BoxFaceColor', [0.22 0.62 0.42], 'WhiskerLineColor', [0.25 0.25 0.25]);
grid on;
xlabel('Valence bin');
ylabel('front STb clipDynamicMedian (within-subject centered)');
title('front STb clip-view low-animation by valence bin | within-subject centered');
yline(0, ':', 'Color', [0.45 0.45 0.45], 'HandleVisibility', 'off');
exportgraphics(fig2, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence_integerbins_within_subject_centered.png'), 'Resolution', 180);
savefig(fig2, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence_integerbins_within_subject_centered.fig'));

summaryRows = [];
for b = binLevels
    mask = T.valenceBin == b;
    summaryRows = [summaryRows; table(b, nnz(mask), ...
        mean(T.clipDynamicMedian(mask), 'omitnan'), median(T.clipDynamicMedian(mask), 'omitnan'), ...
        mean(T.centeredClipDynamic(mask), 'omitnan'), median(T.centeredClipDynamic(mask), 'omitnan'), ...
        'VariableNames', {'valenceBin','nRows','meanClipDynamic','medianClipDynamic','meanCenteredClipDynamic','medianCenteredClipDynamic'})]; %#ok<AGROW>
end
writetable(summaryRows, fullfile(outDir, 'clipDynamic_by_valence_integerbins_summary.csv'));

disp(summaryRows);
fprintf('Saved outputs to:\n%s\n', outDir);
