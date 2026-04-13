% run_grant_clip_descriptor_bar.m
%
% Build a simple grant-style summary chart showing how informative each
% modality is across clip descriptors. Informativeness is defined as the
% mean absolute within-subject mixed-model beta across:
%   - valence
%   - arousal
%   - liking
%   - familiarity
%
% Colored dots show the descriptor-specific absolute betas.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
summaryCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_grant_clip_descriptor_rose_20260413_133835', ...
    'clip_descriptor_mixed_model_summary.csv');

if ~exist(summaryCsv, 'file')
    error('Missing summary CSV: %s', summaryCsv);
end

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    ['emowear_grant_clip_descriptor_bar_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(summaryCsv);
T.abs_beta = abs(T.within_beta);

[G, labels] = findgroups(string(T.label));
meanAbs = splitapply(@mean, T.abs_beta, G);

U = table();
U.label = labels;
U.mean_abs_beta = meanAbs;
U.nRatings = splitapply(@numel, T.abs_beta, G);

% Sort by overall informativeness.
U = sortrows(U, 'mean_abs_beta', 'descend');

fig = figure('Color', [0.987 0.982 0.972], 'Position', [120 120 1100 620]);
ax = axes(fig, 'Position', [0.15 0.17 0.78 0.72]);
hold(ax, 'on');
box(ax, 'off');
ax.FontName = 'Helvetica';
ax.FontSize = 15;
ax.XGrid = 'on';
ax.GridAlpha = 0.14;
ax.GridColor = [0.55 0.55 0.55];

y = 1:height(U);
barColor = [0.76 0.79 0.80];
barh(ax, y, U.mean_abs_beta, 0.68, ...
    'FaceColor', barColor, ...
    'EdgeColor', 'none');

ratingOrder = ["valence","arousal","liking","familiarity"];
ratingLabels = ["Valence","Arousal","Liking","Familiarity"];
colors = [ ...
    0.73 0.22 0.16;  % valence
    0.20 0.43 0.70;  % arousal
    0.20 0.57 0.38;  % liking
    0.53 0.34 0.63   % familiarity
    ];
offsets = [-0.22 -0.07 0.07 0.22];

for i = 1:height(U)
    rows = T(string(T.label) == U.label(i), :);
    for r = 1:numel(ratingOrder)
        idx = strcmp(string(rows.rating), ratingOrder(r));
        if any(idx)
            scatter(ax, rows.abs_beta(idx), y(i) + offsets(r), ...
                72, colors(r,:), 'filled', ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.9, ...
                'DisplayName', char(ratingLabels(r)));
        end
    end
end

% Show mean values at bar tips.
for i = 1:height(U)
    text(ax, U.mean_abs_beta(i) + 0.003, y(i), sprintf('%.3f', U.mean_abs_beta(i)), ...
        'FontSize', 13, 'Color', [0.20 0.20 0.20], ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

yticks(ax, y);
yticklabels(ax, U.label);
xlabel(ax, 'Mean absolute within-subject beta across clip descriptors', ...
    'FontSize', 16, 'FontWeight', 'bold');
xlim(ax, [0 max(U.mean_abs_beta) + 0.05]);
ax.YDir = 'reverse';

lgd = legend(ax, ratingLabels, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'Box', 'off', 'FontSize', 14);
title(lgd, '');

title(ax, 'Overall informativeness of motion and physiological signals', ...
    'FontSize', 22, 'FontWeight', 'bold', 'Color', [0.16 0.16 0.16]);

annotation(fig, 'textbox', [0.16 0.045 0.74 0.05], ...
    'String', 'Bars: mean absolute beta across valence, arousal, liking, familiarity. Dots: descriptor-specific values.', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 12, 'Color', [0.28 0.28 0.28]);

writetable(U, fullfile(outDir, 'modality_informativeness_summary.csv'));
exportgraphics(fig, fullfile(outDir, 'grant_clip_descriptor_bar.png'), 'Resolution', 240);

disp(U);
fprintf('Saved outputs to:\n%s\n', outDir);
