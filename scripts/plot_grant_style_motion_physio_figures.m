% plot_grant_style_motion_physio_figures.m
%
% Produce two cleaner summary figures for grant use:
%   1. Rose plot: valence modalities (motion vs physiology)
%   2. Lollipop with CI: Front STb across clip ratings

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
valCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_valence_mixed_models_20260413_110142', ...
    'valence_mixed_model_summary.csv');
multiCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_multirating_mixed_models_20260413_111354', ...
    'multirating_mixed_model_summary.csv');
outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_grant_style_20260413');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

V = readtable(valCsv);
M = readtable(multiCsv);

makeValenceRose(V, outDir);
makeFrontStbLollipop(M, outDir);

function makeValenceRose(V, outDir)
[~, ord] = sort(abs(V.within_beta), 'descend');
V = V(ord, :);

labels = localPrettyMetricLabels(string(V.metric));
n = height(V);
theta = linspace(0, 2*pi, n+1);
r = [V.within_beta; V.within_beta(1)];
rLo = [V.within_CI_lo; V.within_CI_lo(1)];
rHi = [V.within_CI_hi; V.within_CI_hi(1)];

fig = figure('Color', [0.99 0.985 0.975], 'Position', [100 100 860 860]);
pax = polaraxes(fig);
hold(pax, 'on');
pax.ThetaZeroLocation = 'top';
pax.ThetaDir = 'clockwise';
pax.FontName = 'Helvetica';
pax.FontSize = 12;
pax.LineWidth = 1.0;
pax.GridAlpha = 0.16;
pax.RColor = [0.55 0.55 0.55];
pax.ThetaColor = [0.35 0.35 0.35];
pax.Color = [0.99 0.985 0.975];

% Tight positive scale so the differences are visible.
pax.RLim = [0 0.16];
pax.RTick = [0.04 0.08 0.12 0.16];
pax.RTickLabel = {'0.04','0.08','0.12','0.16'};

% CI rings
polarplot(pax, theta, max(rLo, 0), '-', 'Color', [0.87 0.72 0.67], 'LineWidth', 1.2);
polarplot(pax, theta, max(rHi, 0), '-', 'Color', [0.87 0.72 0.67], 'LineWidth', 1.2);

% Main line
polarplot(pax, theta, max(r, 0), '-o', ...
    'Color', [0.80 0.28 0.18], 'LineWidth', 3.0, ...
    'MarkerFaceColor', [0.80 0.28 0.18], ...
    'MarkerEdgeColor', 'w', 'MarkerSize', 9);

% Subtle reference ring at the top competing physiology effect
polarplot(pax, linspace(0,2*pi,300), repmat(0.05,1,300), ':', ...
    'Color', [0.45 0.45 0.45], 'LineWidth', 0.9);

anglesDeg = rad2deg(theta(1:end-1));
pax.ThetaTick = anglesDeg;
pax.ThetaTickLabel = cellstr(labels);

title(pax, 'Valence: motion vs physiological signals', ...
    'FontWeight', 'bold', 'FontSize', 18);

% Annotation text block
annotation(fig, 'textbox', [0.30 0.02 0.40 0.08], ...
    'String', 'Radius = within-subject mixed-model beta', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 11, 'Color', [0.25 0.25 0.25]);

exportgraphics(fig, fullfile(outDir, 'grant_valence_modalities_rose.png'), 'Resolution', 240);
savefig(fig, fullfile(outDir, 'grant_valence_modalities_rose.fig'));
end

function makeFrontStbLollipop(M, outDir)
R = M(strcmp(M.metric, 'clipDynamicMedian'), :);
ratingOrder = ["valence","liking","arousal","familiarity"];
[~, ord] = ismember(string(R.rating), ratingOrder);
R = sortrows(addvars(R, ord, 'Before', 1, 'NewVariableNames', 'ord'), 'ord');
labels = localPrettyRatingLabels(string(R.rating));

fig = figure('Color', [0.99 0.985 0.975], 'Position', [120 120 900 620]);
ax = axes(fig); hold(ax, 'on');
ax.FontName = 'Helvetica';
ax.FontSize = 12;
ax.LineWidth = 1.0;
ax.YGrid = 'on';
ax.XGrid = 'off';
ax.GridAlpha = 0.16;
ax.Color = [0.99 0.985 0.975];
ax.YColor = [0.25 0.25 0.25];
ax.XColor = [0.25 0.25 0.25];

x = 1:height(R);
y = R.within_beta;
lo = y - R.within_CI_lo;
hi = R.within_CI_hi - y;

for i = 1:numel(x)
    line(ax, [x(i) x(i)], [0 y(i)], 'Color', [0.66 0.72 0.78], 'LineWidth', 3.0);
end
errorbar(ax, x, y, lo, hi, 'o', ...
    'Color', [0.20 0.20 0.20], ...
    'MarkerFaceColor', [0.22 0.58 0.37], ...
    'MarkerEdgeColor', 'w', ...
    'LineWidth', 1.5, 'CapSize', 10, 'MarkerSize', 10);
yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);

xlim(ax, [0.5 numel(x)+0.5]);
ylim(ax, [0 0.16]);
xticks(ax, x);
xticklabels(ax, labels);
ylabel(ax, 'Within-subject beta');
title(ax, 'Front STb clip motion across clip ratings', 'FontWeight', 'bold', 'FontSize', 18);

for i = 1:height(R)
    text(ax, x(i), R.within_CI_hi(i) + 0.005, sprintf('p = %.2g', R.within_p(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 10, 'Color', [0.25 0.25 0.25]);
end

exportgraphics(fig, fullfile(outDir, 'grant_frontstb_ratings_lollipop.png'), 'Resolution', 240);
savefig(fig, fullfile(outDir, 'grant_frontstb_ratings_lollipop.fig'));
end

function labels = localPrettyMetricLabels(metrics)
labels = strings(size(metrics));
for i = 1:numel(metrics)
    switch string(metrics(i))
        case "clipDynamicMedian"
            labels(i) = "Front STb motion";
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

function labels = localPrettyRatingLabels(ratings)
labels = strings(size(ratings));
for i = 1:numel(ratings)
    switch string(ratings(i))
        case "valence"
            labels(i) = "Valence";
        case "liking"
            labels(i) = "Liking";
        case "arousal"
            labels(i) = "Arousal";
        case "familiarity"
            labels(i) = "Familiarity";
        otherwise
            labels(i) = replace(string(ratings(i)), "_", " ");
    end
end
end

