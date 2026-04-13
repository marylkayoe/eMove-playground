% run_emowear_clip_rating_survey.m
%
% Aggregate participant survey ratings by stimulus exp and cluster clips by
% perceived profile.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_clip_rating_survey_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

d = dir(dataRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

rows = [];
for i = 1:numel(ids)
    participantID = char(ids(i));
    S = load(fullfile(dataRoot, participantID, 'surveys.mat'));
    if ~isfield(S, 'surveys') || ~istable(S.surveys)
        continue;
    end
    T = S.surveys;
    need = {'seq','exp','valence','arousal','dominance','liking','familiarity'};
    if ~all(ismember(need, T.Properties.VariableNames))
        continue;
    end
    T = T(:, need);
    T.participantID = repmat(string(participantID), height(T), 1);
    rows = [rows; T]; %#ok<AGROW>
end

writetable(rows, fullfile(outDir, 'all_subject_surveys.csv'));

expList = unique(rows.exp);
aggRows = [];
for i = 1:numel(expList)
    mask = rows.exp == expList(i);
    TT = rows(mask, :);
    aggRows = [aggRows; table( ...
        expList(i), height(TT), ...
        mean(TT.valence, 'omitnan'), std(TT.valence, 'omitnan'), ...
        mean(TT.arousal, 'omitnan'), std(TT.arousal, 'omitnan'), ...
        mean(TT.dominance, 'omitnan'), std(TT.dominance, 'omitnan'), ...
        mean(TT.liking, 'omitnan'), std(TT.liking, 'omitnan'), ...
        mean(TT.familiarity, 'omitnan'), std(TT.familiarity, 'omitnan'), ...
        'VariableNames', {'exp','nRatings', ...
        'valence_mean','valence_sd', ...
        'arousal_mean','arousal_sd', ...
        'dominance_mean','dominance_sd', ...
        'liking_mean','liking_sd', ...
        'familiarity_mean','familiarity_sd'})]; %#ok<AGROW>
end
writetable(aggRows, fullfile(outDir, 'clip_rating_summary_by_exp.csv'));

featNames = {'valence_mean','arousal_mean','dominance_mean','liking_mean','familiarity_mean'};
X = aggRows{:, featNames};
Xz = zscore(X, 0, 1);
Z = linkage(Xz, 'ward');
leafOrder = optimalleaforder(Z, pdist(Xz));

fig1 = figure('Color', 'w', 'Position', [80 80 980 760]);
tiledlayout(fig1, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
[H,Tout,outPerm] = dendrogram(Z, 0, 'Reorder', leafOrder, 'Orientation', 'left'); %#ok<ASGLU>
set(gca, 'YDir', 'reverse');
title('Clip clustering by perceived profile');
xlabel('Ward linkage distance');
ylabel('exp');

nexttile;
imagesc(Xz(leafOrder, :));
colormap(parula);
colorbar;
xticks(1:numel(featNames));
xticklabels(strrep(featNames, '_mean', ''));
yticks(1:numel(leafOrder));
yticklabels("exp " + string(aggRows.exp(leafOrder)));
title('Z-scored perceived clip profile');

exportgraphics(fig1, fullfile(outDir, 'clip_rating_cluster_heatmap.png'), 'Resolution', 180);
savefig(fig1, fullfile(outDir, 'clip_rating_cluster_heatmap.fig'));

fig2 = figure('Color', 'w', 'Position', [100 100 980 680]);
tiledlayout(fig2, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
sdPairs = {'valence_sd','Valence SD'; 'arousal_sd','Arousal SD'; 'dominance_sd','Dominance SD'; 'liking_sd','Liking SD'; 'familiarity_sd','Familiarity SD'};
for i = 1:size(sdPairs, 1)
    nexttile;
    vals = aggRows.(sdPairs{i,1});
    histogram(vals, 12, 'FaceColor', [0.25 0.45 0.8], 'EdgeColor', 'none');
    grid on;
    title(sdPairs{i,2});
    xlabel('Across-subject SD');
    ylabel('Clip count');
end
nexttile;
scatter(aggRows.valence_mean, aggRows.dominance_mean, 35, [0.8 0.35 0.2], 'filled');
grid on;
xlabel('Mean valence');
ylabel('Mean dominance');
title('Clip means');
text(aggRows.valence_mean, aggRows.dominance_mean, "exp " + string(aggRows.exp), ...
    'FontSize', 7, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
exportgraphics(fig2, fullfile(outDir, 'clip_rating_agreement_summary.png'), 'Resolution', 180);
savefig(fig2, fullfile(outDir, 'clip_rating_agreement_summary.fig'));

disp(aggRows(1:min(10,height(aggRows)), :));
fprintf('Saved outputs to:\n%s\n', outDir);
