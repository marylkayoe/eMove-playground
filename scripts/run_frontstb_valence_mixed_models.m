% run_frontstb_valence_mixed_models.m
%
% Mixed-effects follow-up for clip-view front-STb motion and physiology.
% Uses a within-/between-subject decomposition of valence:
%   outcome_z ~ valenceWS_z + valenceBS_z + (1 + valenceWS_z | participantID)
%
% For front STb clip motion, also compares a quadratic within-subject term.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'frontstb_vs_physiology_joined.csv');

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    ['emowear_frontstb_valence_mixed_models_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(dataCsv);
T.participantID = categorical(string(T.participantID));
T = T(isfinite(T.valence), :);

metrics = { ...
    'clipDynamicMedian', ...
    'bh3_hr_mean', ...
    'e4_eda_std', ...
    'bh3_br_mean', ...
    'e4_hr_mean', ...
    'e4_eda_mean', ...
    'e4_skt_mean' ...
    };

results = table();
models = struct();

for i = 1:numel(metrics)
    metric = metrics{i};
    D = T(:, {'participantID','valence', metric});
    D.Properties.VariableNames{3} = 'outcome';
    D = D(isfinite(D.outcome), :);
    if height(D) < 40
        continue;
    end

    [G, subjIDs] = findgroups(D.participantID); %#ok<ASGLU>
    subjMeanVal = splitapply(@mean, D.valence, G);
    D.valenceBS = subjMeanVal(G);
    D.valenceWS = D.valence - D.valenceBS;
    D.valenceBS = D.valenceBS - mean(D.valenceBS, 'omitnan');

    D.outcomeZ = localZ(D.outcome);
    D.valenceWSZ = localZ(D.valenceWS);
    D.valenceBSZ = localZ(D.valenceBS);

    linFormula = 'outcomeZ ~ 1 + valenceWSZ + valenceBSZ + (1 + valenceWSZ | participantID)';
    [lmeLin, linSpec] = localFitLME(D, linFormula);
    linCoef = lmeLin.Coefficients;
    wsRow = strcmp(linCoef.Name, 'valenceWSZ');
    bsRow = strcmp(linCoef.Name, 'valenceBSZ');

    resRow = table();
    resRow.metric = string(metric);
    resRow.nRows = height(D);
    resRow.nSubjects = numel(categories(removecats(D.participantID)));
    resRow.modelSpec = string(linSpec);
    resRow.linear_AIC = lmeLin.ModelCriterion.AIC;
    resRow.linear_BIC = lmeLin.ModelCriterion.BIC;
    resRow.within_beta = linCoef.Estimate(wsRow);
    resRow.within_SE = linCoef.SE(wsRow);
    resRow.within_t = linCoef.tStat(wsRow);
    resRow.within_p = linCoef.pValue(wsRow);
    resRow.within_CI_lo = linCoef.Lower(wsRow);
    resRow.within_CI_hi = linCoef.Upper(wsRow);
    resRow.between_beta = linCoef.Estimate(bsRow);
    resRow.between_p = linCoef.pValue(bsRow);
    resRow.quadModelSpec = missing;
    resRow.quad_AIC = NaN;
    resRow.quad_BIC = NaN;
    resRow.quad_beta = NaN;
    resRow.quad_p = NaN;
    resRow.deltaAIC_quad_minus_linear = NaN;
    resRow.compare_p = NaN;

    if strcmp(metric, 'clipDynamicMedian')
        D.valenceWSZ2 = D.valenceWSZ .^ 2;
        quadFormula = 'outcomeZ ~ 1 + valenceWSZ + valenceWSZ2 + valenceBSZ + (1 + valenceWSZ | participantID)';
        [lmeQuad, quadSpec] = localFitLME(D, quadFormula);
        quadCoef = lmeQuad.Coefficients;
        qRow = strcmp(quadCoef.Name, 'valenceWSZ2');
        resRow.quadModelSpec = string(quadSpec);
        resRow.quad_AIC = lmeQuad.ModelCriterion.AIC;
        resRow.quad_BIC = lmeQuad.ModelCriterion.BIC;
        resRow.quad_beta = quadCoef.Estimate(qRow);
        resRow.quad_p = quadCoef.pValue(qRow);
        resRow.deltaAIC_quad_minus_linear = lmeQuad.ModelCriterion.AIC - lmeLin.ModelCriterion.AIC;
        try
            cmp = compare(lmeLin, lmeQuad);
            resRow.compare_p = cmp.pValue(2);
        catch
            resRow.compare_p = NaN;
        end
        models.clipLinear = lmeLin;
        models.clipQuadratic = lmeQuad;
    end

    results = [results; resRow]; %#ok<AGROW>
    models.(metric) = lmeLin;
end

writetable(results, fullfile(outDir, 'valence_mixed_model_summary.csv'));
save(fullfile(outDir, 'valence_mixed_models.mat'), 'models');

[~, ord] = sort(abs(results.within_beta), 'descend');
R = results(ord, :);
writetable(R, fullfile(outDir, 'valence_mixed_model_ranked.csv'));

fig = figure('Color', 'w', 'Position', [120 120 980 620]);
ax = axes(fig); hold(ax, 'on');
ax.FontName = 'Helvetica';
ax.FontSize = 11;
ax.LineWidth = 1.0;
ax.YGrid = 'on';
ax.GridAlpha = 0.15;
ax.Color = [0.995 0.995 0.995];

x = 1:height(R);
y = R.within_beta;
errLo = y - R.within_CI_lo;
errHi = R.within_CI_hi - y;
eb = errorbar(ax, x, y, errLo, errHi, 'o', ...
    'Color', [0.20 0.20 0.20], 'MarkerFaceColor', [0.19 0.47 0.73], ...
    'MarkerEdgeColor', 'w', 'LineWidth', 1.4, 'CapSize', 8, 'MarkerSize', 8);
bar(ax, x, y, 0.62, 'FaceColor', [0.19 0.47 0.73], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
yline(ax, 0, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
xlim(ax, [0.4 height(R)+0.6]);
xticks(ax, x);
xticklabels(localPrettyMetricLabels(R.metric));
xtickangle(ax, 25);
ylabel(ax, 'Within-subject valence beta (standardized)');
title(ax, 'Valence mixed-effects comparison: motion vs physiology', 'FontWeight', 'bold');
subtitle(ax, 'Outcome z-scored; valence decomposed into within- and between-subject components');

for i = 1:height(R)
    text(ax, x(i), R.within_CI_hi(i) + 0.04, sprintf('p=%.2g', R.within_p(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 8, 'Color', [0.25 0.25 0.25], 'Rotation', 0);
end

exportgraphics(fig, fullfile(outDir, 'valence_mixed_model_comparison.png'), 'Resolution', 220);
savefig(fig, fullfile(outDir, 'valence_mixed_model_comparison.fig'));

disp(R);
fprintf('Saved outputs to:\n%s\n', outDir);

function z = localZ(x)
x = double(x);
mu = mean(x, 'omitnan');
sd = std(x, 0, 'omitnan');
if ~isfinite(sd) || sd <= 0
    z = x - mu;
else
    z = (x - mu) ./ sd;
end
end

function [mdl, spec] = localFitLME(T, formula)
try
    mdl = fitlme(T, formula, 'FitMethod', 'REML');
    spec = formula;
catch
    simpler = regexprep(formula, '\(1 \+ valenceWSZ \| participantID\)', '(1 | participantID)');
    mdl = fitlme(T, simpler, 'FitMethod', 'REML');
    spec = simpler;
end
end

function labels = localPrettyMetricLabels(metrics)
labels = strings(size(metrics));
for i = 1:numel(metrics)
    switch string(metrics(i))
        case "clipDynamicMedian"
            labels(i) = "Front STb clip motion";
        case "bh3_hr_mean"
            labels(i) = "BH3 heart rate";
        case "e4_eda_std"
            labels(i) = "E4 EDA variability";
        case "bh3_br_mean"
            labels(i) = "BH3 breathing rate";
        case "e4_hr_mean"
            labels(i) = "E4 heart rate";
        case "e4_eda_mean"
            labels(i) = "E4 EDA mean";
        case "e4_skt_mean"
            labels(i) = "E4 skin temperature";
        otherwise
            labels(i) = replace(string(metrics(i)), "_", " ");
    end
end
end
