% plot_emowear_frontstb_clipDynamic_by_valence_boxplot.m
%
% Show front STb clip-view low-animation motion grouped by discrete
% valence ratings as boxplots, plus participant-centered version.

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

valenceLevels = unique(T.valence);
valenceLevels = valenceLevels(isfinite(valenceLevels));
valenceLevels = sort(valenceLevels);

outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_regime_surveys_20260413_091305', 'by_valence');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fig1 = figure('Color', 'w', 'Position', [100 100 920 620]);
boxchart(categorical(T.valence, valenceLevels, string(valenceLevels)), T.clipDynamicMedian, ...
    'BoxFaceColor', [0.30 0.48 0.82], 'WhiskerLineColor', [0.25 0.25 0.25]);
grid on;
xlabel('Valence rating');
ylabel('front STb clipDynamicMedian');
title('front STb clip-view low-animation by valence');
exportgraphics(fig1, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence.png'), 'Resolution', 180);
savefig(fig1, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence.fig'));

T.centeredClipDynamic = nan(height(T), 1);
subjectIDs = unique(T.participantID, 'stable');
for i = 1:numel(subjectIDs)
    mask = T.participantID == subjectIDs(i);
    x = T.clipDynamicMedian(mask);
    T.centeredClipDynamic(mask) = x - mean(x, 'omitnan');
end

fig2 = figure('Color', 'w', 'Position', [120 120 920 620]);
boxchart(categorical(T.valence, valenceLevels, string(valenceLevels)), T.centeredClipDynamic, ...
    'BoxFaceColor', [0.22 0.62 0.42], 'WhiskerLineColor', [0.25 0.25 0.25]);
grid on;
xlabel('Valence rating');
ylabel('front STb clipDynamicMedian (within-subject centered)');
title('front STb clip-view low-animation by valence | within-subject centered');
yline(0, ':', 'Color', [0.45 0.45 0.45], 'HandleVisibility', 'off');
exportgraphics(fig2, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence_within_subject_centered.png'), 'Resolution', 180);
savefig(fig2, fullfile(outDir, 'boxplot_clipDynamicMedian_by_valence_within_subject_centered.fig'));

summaryRows = [];
for i = 1:numel(valenceLevels)
    v = valenceLevels(i);
    mask = T.valence == v;
    summaryRows = [summaryRows; table(v, nnz(mask), ...
        mean(T.clipDynamicMedian(mask), 'omitnan'), median(T.clipDynamicMedian(mask), 'omitnan'), ...
        mean(T.centeredClipDynamic(mask), 'omitnan'), median(T.centeredClipDynamic(mask), 'omitnan'), ...
        'VariableNames', {'valence','nRows','meanClipDynamic','medianClipDynamic','meanCenteredClipDynamic','medianCenteredClipDynamic'})]; %#ok<AGROW>
end
writetable(summaryRows, fullfile(outDir, 'clipDynamic_by_valence_summary.csv'));

disp(summaryRows);
fprintf('Saved outputs to:\n%s\n', outDir);
