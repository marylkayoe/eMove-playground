% run_frontstb_multirating_mixed_models.m
%
% Mixed-effects comparison of front STb clip motion and physiology across
% multiple clip ratings:
%   valence, arousal, liking, familiarity
%
% For each rating, use a within-/between-subject decomposition:
%   outcomeZ ~ ratingWSZ + ratingBSZ + (1 + ratingWSZ | participantID)
%
% Outputs:
%   - summary CSV of standardized within-subject betas
%   - one rose/petal plot per rating comparing modalities
%   - one rose plot for front STb clip motion across the four ratings

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'frontstb_vs_physiology_joined.csv');

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    ['emowear_frontstb_multirating_mixed_models_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(dataCsv);
T.participantID = categorical(string(T.participantID));

metrics = { ...
    'clipDynamicMedian', ...
    'bh3_hr_mean', ...
    'e4_eda_std', ...
    'bh3_br_mean', ...
    'e4_hr_mean', ...
    'e4_eda_mean', ...
    'e4_skt_mean' ...
    };
ratings = {'valence','arousal','liking','familiarity'};

results = table();
models = struct();

for rIdx = 1:numel(ratings)
    rating = ratings{rIdx};
    TR = T(isfinite(T.(rating)), :);
    for mIdx = 1:numel(metrics)
        metric = metrics{mIdx};
        D = TR(:, {'participantID', rating, metric});
        D.Properties.VariableNames{2} = 'ratingValue';
        D.Properties.VariableNames{3} = 'outcome';
        D = D(isfinite(D.outcome), :);
        if height(D) < 40
            continue;
        end

        [G, ~] = findgroups(D.participantID);
        subjMeanRating = splitapply(@mean, D.ratingValue, G);
        D.ratingBS = subjMeanRating(G);
        D.ratingWS = D.ratingValue - D.ratingBS;
        D.ratingBS = D.ratingBS - mean(D.ratingBS, 'omitnan');

        D.outcomeZ = localZ(D.outcome);
        D.ratingWSZ = localZ(D.ratingWS);
        D.ratingBSZ = localZ(D.ratingBS);

        linFormula = 'outcomeZ ~ 1 + ratingWSZ + ratingBSZ + (1 + ratingWSZ | participantID)';
        [lmeLin, linSpec] = localFitLME(D, linFormula);
        coef = lmeLin.Coefficients;
        wsRow = strcmp(coef.Name, 'ratingWSZ');
        bsRow = strcmp(coef.Name, 'ratingBSZ');

        row = table();
        row.rating = string(rating);
        row.metric = string(metric);
        row.nRows = height(D);
        row.nSubjects = numel(categories(removecats(D.participantID)));
        row.modelSpec = string(linSpec);
        row.AIC = lmeLin.ModelCriterion.AIC;
        row.BIC = lmeLin.ModelCriterion.BIC;
        row.within_beta = coef.Estimate(wsRow);
        row.within_SE = coef.SE(wsRow);
        row.within_t = coef.tStat(wsRow);
        row.within_p = coef.pValue(wsRow);
        row.within_CI_lo = coef.Lower(wsRow);
        row.within_CI_hi = coef.Upper(wsRow);
        row.between_beta = coef.Estimate(bsRow);
        row.between_p = coef.pValue(bsRow);
        results = [results; row]; %#ok<AGROW>

        safeModelName = matlab.lang.makeValidName(sprintf('%s_%s', rating, metric));
        models.(safeModelName) = lmeLin;
    end
end

writetable(results, fullfile(outDir, 'multirating_mixed_model_summary.csv'));
save(fullfile(outDir, 'multirating_mixed_models.mat'), 'models');

% Rose-style plot per rating comparing modalities.
for rIdx = 1:numel(ratings)
    rating = ratings{rIdx};
    R = results(results.rating == string(rating), :);
    [~, ord] = sort(abs(R.within_beta), 'descend');
    R = R(ord, :);
    makeRoseForRating(R, rating, outDir);
end

% Rose-style plot for front STb across ratings.
Rstb = results(results.metric == "clipDynamicMedian", :);
ratingOrder = ["valence","arousal","liking","familiarity"];
[~, ord] = ismember(Rstb.rating, ratingOrder);
Rstb = sortrows(addvars(Rstb, ord, 'Before', 1, 'NewVariableNames', 'ord'), 'ord');
makeRoseForFrontSTb(Rstb, outDir);

disp(results);
fprintf('Saved outputs to:\n%s\n', outDir);

function makeRoseForRating(R, rating, outDir)
fig = figure('Color', 'w', 'Position', [120 120 760 760]);
pax = polaraxes(fig);
hold(pax, 'on');
pax.ThetaZeroLocation = 'top';
pax.ThetaDir = 'clockwise';
pax.FontName = 'Helvetica';
pax.FontSize = 11;
pax.RGrid = 'on';
pax.ThetaGrid = 'on';
pax.GridAlpha = 0.18;
pax.LineWidth = 1.0;

n = height(R);
theta = linspace(0, 2*pi, n+1);
r = [R.within_beta; R.within_beta(1)];
rHi = [R.within_CI_hi; R.within_CI_hi(1)];
rLo = [R.within_CI_lo; R.within_CI_lo(1)];

rMin = min(min(R.within_CI_lo)-0.02, -0.08);
rMax = max(max(R.within_CI_hi)+0.03, 0.16);
pax.RLim = [rMin rMax];
rl = unique(round(linspace(rMin, rMax, 5), 2));
pax.RTick = rl;

polarplot(pax, theta, rLo, '-', 'LineWidth', 1.0, 'Color', [0.63 0.71 0.82]);
polarplot(pax, theta, rHi, '-', 'LineWidth', 1.0, 'Color', [0.63 0.71 0.82]);
polarplot(pax, theta, r, '-o', 'LineWidth', 2.4, ...
    'Color', [0.18 0.47 0.72], 'MarkerFaceColor', [0.18 0.47 0.72], ...
    'MarkerEdgeColor', 'w', 'MarkerSize', 7);
polarplot(pax, linspace(0, 2*pi, 300), zeros(1,300), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);

anglesDeg = rad2deg(theta(1:end-1));
pax.ThetaTick = anglesDeg;
pax.ThetaTickLabel = cellstr(localPrettyMetricLabels(R.metric));

title(pax, sprintf('%s: motion vs physiology', localPrettyRatingLabel(rating)), ...
    'FontWeight', 'bold', 'FontSize', 16);

exportgraphics(fig, fullfile(outDir, sprintf('rose_%s_modalities.png', rating)), 'Resolution', 220);
savefig(fig, fullfile(outDir, sprintf('rose_%s_modalities.fig', rating)));
end

function makeRoseForFrontSTb(R, outDir)
fig = figure('Color', 'w', 'Position', [140 140 720 720]);
pax = polaraxes(fig);
hold(pax, 'on');
pax.ThetaZeroLocation = 'top';
pax.ThetaDir = 'clockwise';
pax.FontName = 'Helvetica';
pax.FontSize = 11;
pax.GridAlpha = 0.18;

n = height(R);
theta = linspace(0, 2*pi, n+1);
r = [R.within_beta; R.within_beta(1)];
rHi = [R.within_CI_hi; R.within_CI_hi(1)];
rLo = [R.within_CI_lo; R.within_CI_lo(1)];

rMin = min(min(R.within_CI_lo)-0.02, -0.08);
rMax = max(max(R.within_CI_hi)+0.03, 0.24);
pax.RLim = [rMin rMax];
rl = unique(round(linspace(rMin, rMax, 5), 2));
pax.RTick = rl;

polarplot(pax, theta, rLo, '-', 'LineWidth', 1.0, 'Color', [0.67 0.82 0.71]);
polarplot(pax, theta, rHi, '-', 'LineWidth', 1.0, 'Color', [0.67 0.82 0.71]);
polarplot(pax, theta, r, '-o', 'LineWidth', 2.8, ...
    'Color', [0.22 0.58 0.37], 'MarkerFaceColor', [0.22 0.58 0.37], ...
    'MarkerEdgeColor', 'w', 'MarkerSize', 8);
polarplot(pax, linspace(0, 2*pi, 300), zeros(1,300), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);

anglesDeg = rad2deg(theta(1:end-1));
pax.ThetaTick = anglesDeg;
pax.ThetaTickLabel = cellstr(localPrettyRatingLabel(R.rating));

title(pax, 'Front STb clip motion across clip ratings', ...
    'FontWeight', 'bold', 'FontSize', 16);

exportgraphics(fig, fullfile(outDir, 'rose_frontstb_across_ratings.png'), 'Resolution', 220);
savefig(fig, fullfile(outDir, 'rose_frontstb_across_ratings.fig'));
end

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
    simpler = regexprep(formula, '\(1 \+ ratingWSZ \| participantID\)', '(1 | participantID)');
    mdl = fitlme(T, simpler, 'FitMethod', 'REML');
    spec = simpler;
end
end

function labels = localPrettyMetricLabels(metrics)
labels = strings(size(metrics));
for i = 1:numel(metrics)
    switch string(metrics(i))
        case "clipDynamicMedian"
            labels(i) = "Front STb";
        case "bh3_hr_mean"
            labels(i) = "BH3 HR";
        case "e4_eda_std"
            labels(i) = "E4 EDA var";
        case "bh3_br_mean"
            labels(i) = "BH3 BR";
        case "e4_hr_mean"
            labels(i) = "E4 HR";
        case "e4_eda_mean"
            labels(i) = "E4 EDA";
        case "e4_skt_mean"
            labels(i) = "E4 skin temp";
        otherwise
            labels(i) = replace(string(metrics(i)), "_", " ");
    end
end
end

function labels = localPrettyRatingLabel(ratings)
labels = strings(size(ratings));
for i = 1:numel(ratings)
    switch string(ratings(i))
        case "valence"
            labels(i) = "Valence";
        case "arousal"
            labels(i) = "Arousal";
        case "liking"
            labels(i) = "Liking";
        case "familiarity"
            labels(i) = "Familiarity";
        otherwise
            labels(i) = replace(string(ratings(i)), "_", " ");
    end
end
end
