% make_analysis_workflow_figure.m
%
% Assemble a pedagogical workflow figure explaining the motion analysis.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
outDir = fullfile(repoRoot, 'outputs', 'figures', 'analysis_workflow_20260322');

tracePng = fullfile(outDir, 'workflow_trace_panel.png');
pooledDensityPng = fullfile(repoRoot, 'outputs', 'figures', ...
    'pooled_disgust_density_20260315_131050', 'pooled_disgust_density_baseline_normalized.png');
stickFigPng = fullfile(repoRoot, 'outputs', 'figures', ...
    'disgust_fear_ks_stickfigures_20260315_133403', 'disgust_ks_stickfigures.png');

if ~isfile(tracePng), error('Missing trace panel: %s', tracePng); end
if ~isfile(pooledDensityPng), error('Missing pooled density: %s', pooledDensityPng); end
if ~isfile(stickFigPng), error('Missing stick figure: %s', stickFigPng); end

traceImg = imread(tracePng);
pooledImg = imread(pooledDensityPng);
stickImg = imread(stickFigPng);

% Crop pooled density to emphasize the top row.
[hp, wp, ~] = size(pooledImg);
pooledCrop = pooledImg(round(0.03*hp):round(0.67*hp), round(0.03*wp):round(0.98*wp), :);

% Crop stick-figure figure slightly to reduce white margin.
[hs, ws, ~] = size(stickImg);
stickCrop = stickImg(round(0.05*hs):round(0.97*hs), round(0.03*ws):round(0.97*ws), :);

f = figure('Color', 'w', 'Units', 'pixels', 'Position', [40 40 1720 1040]);
tlo = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

title(tlo, 'From continuous movement to emotion-specific micromovement signatures', ...
    'FontSize', 24, 'FontWeight', 'bold');
subtitle(tlo, ['Workflow summary: segment trials, isolate the low-speed regime, ' ...
    'pool samples by emotion, compare distributions, and map the strongest pairwise differences back onto the body.']);

% Panel 1: timeline schematic
ax1 = nexttile(tlo, 1);
axis(ax1, [0 1 0 1]); axis(ax1, 'off'); hold(ax1, 'on');
localPanelTitle(ax1, '1. Record a continuous session', ...
    'One long mocap recording is later segmented into baseline and stimulus windows.');
localDrawTimeline(ax1);

% Panel 2: trace panel
ax2 = nexttile(tlo, 2);
imshow(traceImg, 'Parent', ax2);
axis(ax2, 'off');
localPanelTitle(ax2, '2. Isolate the micromovement regime', ...
    'Example: SC3001, disgust video 0602, HEAD + upper torso + lower torso.');

% Panel 3: pooling schematic
ax3 = nexttile(tlo, 3);
axis(ax3, [0 1 0 1]); axis(ax3, 'off'); hold(ax3, 'on');
localPanelTitle(ax3, '3. Pool retained samples by emotion', ...
    'All low-speed samples from the selected bodypart are accumulated across trials and subjects.');
localDrawPooling(ax3);

% Panel 4: distributions
ax4 = nexttile(tlo, [1 2]);
imshow(pooledCrop, 'Parent', ax4);
axis(ax4, 'off');
localPanelTitle(ax4, '4. Compare the resulting distributions', ...
    'Here shown as pooled density curves; the same samples can also be summarized as CDFs.');

% Panel 5: body map summary
ax5 = nexttile(tlo, 6);
imshow(stickCrop, 'Parent', ax5);
axis(ax5, 'off');
localPanelTitle(ax5, '5. Map pairwise emotion differences onto the body', ...
    'Unsigned KS intensity asks where a given emotion pair differs most strongly.');

% Arrows in top row
annotation(f, 'textarrow', [0.30 0.37], [0.69 0.69], 'String', '', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.5);
annotation(f, 'textarrow', [0.63 0.70], [0.69 0.69], 'String', '', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.5);

exportgraphics(f, fullfile(outDir, 'analysis_workflow_figure.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'analysis_workflow_figure.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'analysis_workflow_figure.fig'));

fprintf('Saved workflow explainer under:\n%s\n', outDir);

function localPanelTitle(ax, titleText, subtitleText)
    text(ax, 0.0, 1.06, titleText, 'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
        'FontSize', 15, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    text(ax, 0.0, 1.00, subtitleText, 'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
        'FontSize', 10.5, 'Color', [0.3 0.3 0.3]);
end

function localDrawTimeline(ax)
    x0 = 0.08; y0 = 0.48; W = 0.84; H = 0.13;
    labels = {'BASELINE','0302','0602','4903','5102','...','more videos'};
    colors = [0.86 0.86 0.86;
              0.30 0.70 0.35;
              0.90 0.33 0.10;
              0.49 0.18 0.56;
              0.30 0.76 0.98;
              0.92 0.92 0.92;
              0.92 0.92 0.92];
    fracs = [0.14 0.14 0.14 0.14 0.14 0.14 0.16];
    cursor = x0;
    for i = 1:numel(labels)
        wi = W * fracs(i);
        rectangle(ax, 'Position', [cursor y0 wi H], ...
            'FaceColor', colors(i,:), 'EdgeColor', [1 1 1], 'LineWidth', 2);
        text(ax, cursor + wi/2, y0 + H/2, labels{i}, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 11, 'FontWeight', 'bold');
        cursor = cursor + wi;
    end
    text(ax, 0.08, 0.74, 'Continuous Vicon trajectory data', ...
        'FontSize', 12, 'FontWeight', 'bold');
    text(ax, 0.08, 0.31, 'Each block becomes one trial window aligned to the Unity log schedule.', ...
        'FontSize', 11, 'Color', [0.25 0.25 0.25]);
    text(ax, 0.08, 0.20, 'Inter-report intervals are not used in the current emotion analysis.', ...
        'FontSize', 10, 'Color', [0.45 0.45 0.45]);
end

function localDrawPooling(ax)
    labels = {'NEUTRAL','DISGUST','JOY','SAD'};
    colors = [0.30 0.70 0.35;
              0.90 0.33 0.10;
              0.49 0.18 0.56;
              0.30 0.76 0.98];
    xs = linspace(0.14, 0.86, numel(labels));
    rng(3);
    for i = 1:numel(labels)
        x = xs(i);
        rectangle(ax, 'Position', [x-0.09 0.12 0.18 0.62], ...
            'FaceColor', [1 1 1], 'EdgeColor', [0.86 0.86 0.86], 'LineWidth', 1.2);
        text(ax, x, 0.84, labels{i}, 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'FontWeight', 'bold', 'Color', colors(i,:));
        px = x + 0.03 * randn(70, 1);
        py = 0.16 + 0.52 * rand(70, 1);
        scatter(ax, px, py, 20, repmat(colors(i,:), 70, 1), 'filled', ...
            'MarkerFaceAlpha', 0.55, 'MarkerEdgeAlpha', 0.0);
    end
    text(ax, 0.06, 0.05, ...
        'Each bodypart/emotion pool contains many low-speed samples collected across trials and subjects.', ...
        'FontSize', 10, 'Color', [0.35 0.35 0.35]);
end
