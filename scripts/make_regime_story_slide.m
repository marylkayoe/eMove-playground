% make_regime_story_slide.m
%
% Create a presentation-style figure that tells a simple story:
%   A) one memorable regime-reversal example (HEAD, DISGUST vs JOY)
%   B) where regime shift is strongest in the body (pooled upper body vs lower limbs)
%   C) pooled shift vs subject-level stability for selected bodyparts

clearvars;
clc;
close all;

%% Paths
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
pooledDir = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_distinctness_20260314_195024';
subjectDir = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_subject_level_20260314_195909';
headDir = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_joy_head_regime_20260314_194230';

outDir = fullfile(repoRoot, 'outputs', 'figures', ['regime_story_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

pooledDiag = readtable(fullfile(pooledDir, 'regime_diagnostics.csv'));
subjectSummary = readtable(fullfile(subjectDir, 'subject_regime_summary.csv'));
headSummary = readtable(fullfile(headDir, 'pooled_summary.csv'));
pooledPairs = readtable(fullfile(pooledDir, 'pairwise_regime_contrasts.csv'));
subjectPairs = readtable(fullfile(subjectDir, 'subject_pairwise_flips.csv'));

%% Use absolute values for the main visual; note separately that normalization agrees.
pooledAbs = pooledDiag(strcmp(pooledDiag.normalization, 'absolute'), :);
subjectAbs = subjectSummary(strcmp(subjectSummary.normalization, 'absolute'), :);
headAbs = headSummary(strcmp(headSummary.normalization, 'absolute'), :);
pooledAbsNoFear = localComputeFearExcludedShiftTable(pooledPairs, 'absolute');
subjectAbsNoFear = localComputeFearExcludedSubjectShiftTable(subjectPairs, 'absolute');

%% Figure
f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 80 1680 820]);
tl = tiledlayout(f, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

% Panel A
axA = nexttile(tl, 1);
localDrawHeadReversalPanel(axA, headAbs);

% Panel B
axB = nexttile(tl, 2);
localDrawBodyShiftPanel(axB, pooledAbsNoFear);

% Panel C
axC = nexttile(tl, 3);
localDrawConsistencyPanel(axC, pooledAbsNoFear, subjectAbsNoFear);

annotation(f, 'textbox', [0.02 0.95 0.96 0.045], ...
    'String', 'Upper-body micromovement is not just weaker movement: emotion relationships reorganize across regimes', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 20, 'FontWeight', 'bold');

annotation(f, 'textbox', [0.02 0.015 0.96 0.035], ...
    'String', 'Main figure uses absolute pooled values. FEAR is excluded from panels B-C so the regime shift index reflects the remaining emotion space.', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 12, 'Color', [0.25 0.25 0.25]);

exportgraphics(f, fullfile(outDir, 'regime_story_slide.png'), 'Resolution', 240);
exportgraphics(f, fullfile(outDir, 'regime_story_slide.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'regime_story_slide.fig'));

fprintf('Saved story slide under:\n%s\n', outDir);

%% Helpers
function localDrawHeadReversalPanel(ax, headAbs)
    cla(ax);
    axis(ax, 'off');
    title(ax, 'A. One clear reversal in HEAD', 'FontSize', 18, 'FontWeight', 'bold');

    disgustFull = headAbs.medianValue(strcmp(headAbs.regime, 'full speed') & strcmp(headAbs.emotion, 'DISGUST'));
    joyFull = headAbs.medianValue(strcmp(headAbs.regime, 'full speed') & strcmp(headAbs.emotion, 'JOY'));
    disgustMicro = headAbs.medianValue(contains(headAbs.regime, 'micromovement') & strcmp(headAbs.emotion, 'DISGUST'));
    joyMicro = headAbs.medianValue(contains(headAbs.regime, 'micromovement') & strcmp(headAbs.emotion, 'JOY'));

    axes('Position', [0.08 0.18 0.23 0.58], 'Parent', ancestor(ax, 'figure')); %#ok<LAXES>
    axInner = gca; hold(axInner, 'on');
    x = [1 2];
    cDisgust = [0.88 0.40 0.16];
    cJoy = [0.87 0.17 0.47];
    plot(axInner, x, [disgustFull disgustMicro], '-o', 'Color', cDisgust, 'LineWidth', 4, ...
        'MarkerFaceColor', cDisgust, 'MarkerSize', 9);
    plot(axInner, x, [joyFull joyMicro], '-o', 'Color', cJoy, 'LineWidth', 4, ...
        'MarkerFaceColor', cJoy, 'MarkerSize', 9);
    set(axInner, 'XTick', x, 'XTickLabel', {'Full motion','Micromovement'}, ...
        'FontSize', 13, 'LineWidth', 1.2, 'Box', 'off');
    ylabel(axInner, 'Median speed (mm/s)', 'FontSize', 14, 'FontWeight', 'bold');
    grid(axInner, 'on');
    text(1, disgustFull + 1.5, 'DISGUST', 'Color', cDisgust, 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    text(1, joyFull + 1.5, 'JOY', 'Color', cJoy, 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    txt = sprintf(['In full head motion:\nDISGUST < JOY\n\n' ...
                   'In micromovement:\nDISGUST > JOY']);
    annotation(ancestor(ax, 'figure'), 'textbox', [0.045 0.08 0.29 0.17], ...
        'String', txt, 'EdgeColor', 'none', 'FontSize', 14, 'FontWeight', 'bold', ...
        'Color', [0.15 0.15 0.15], 'HorizontalAlignment', 'left');
end

function localDrawBodyShiftPanel(ax, pooledAbs)
    cla(ax);
    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');
    title(ax, 'B. Pooled regime shift is strongest in the upper body (FEAR excluded)', 'FontSize', 18, 'FontWeight', 'bold');

    nodes = localBodyNodes();
    segments = localBodySegments();
    groupMap = localGroupNodeMap();

    baseColor = [0.87 0.87 0.87];
    vals = containers.Map;
    for i = 1:height(pooledAbs)
        vals(char(pooledAbs.markerGroup{i})) = pooledAbs.signFlipFraction(i);
    end
    cmap = turbo(256);

    for i = 1:size(segments,1)
        p1 = nodes.(segments{i,1});
        p2 = nodes.(segments{i,2});
        plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', 'Color', baseColor, 'LineWidth', 18, 'HandleVisibility', 'off');
    end

    groupNames = {'HEAD','UTORSO','LTORSO','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LOWER_LIMB_L','LOWER_LIMB_R'};
    for g = 1:numel(groupNames)
        name = groupNames{g};
        if ~isfield(groupMap, name) || ~isKey(vals, name)
            continue;
        end
        frac = vals(name);
        c = localColorForValue(frac, cmap, 0, 0.5);
        segs = groupMap.(name);
        for i = 1:size(segs,1)
            p1 = nodes.(segs{i,1});
            p2 = nodes.(segs{i,2});
            plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', 'Color', c, 'LineWidth', 20, 'HandleVisibility', 'off');
        end
        localPlaceGroupLabel(ax, name, frac);
    end

    nodeNames = fieldnames(nodes);
    xy = zeros(numel(nodeNames), 2);
    for i = 1:numel(nodeNames)
        xy(i,:) = nodes.(nodeNames{i});
    end
    plot(ax, xy(:,1), xy(:,2), 'o', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.25 0.25 0.25], ...
        'MarkerSize', 7, 'LineWidth', 1.0, 'HandleVisibility', 'off');

    xlim(ax, [-1.55 1.75]);
    ylim(ax, [-2.15 1.35]);
    cb = colorbar(ax, 'eastoutside');
    colormap(ax, cmap);
    caxis(ax, [0 0.5]);
    ylabel(cb, 'Regime shift index', 'FontSize', 12, 'FontWeight', 'bold');
    cb.Ticks = [0 0.25 0.5];
    cb.TickLabels = {'0','0.25','0.50'};

    text(ax, -1.48, -2.05, 'Index = fraction of non-FEAR emotion-pair contrasts that flip sign between full and micromovement regimes', ...
        'FontSize', 11, 'Color', [0.2 0.2 0.2], 'Interpreter', 'none');
end

function localDrawConsistencyPanel(ax, pooledAbs, subjectAbs)
    cla(ax);
    hold(ax, 'on');
    title(ax, 'C. The pooled shift is stronger than the typical individual shift (FEAR excluded)', 'FontSize', 18, 'FontWeight', 'bold');

    keyGroups = {'HEAD','UTORSO','WRIST_L','LOWER_LIMB_R'};
    y = 1:numel(keyGroups);
    pooledVals = nan(1, numel(keyGroups));
    subjVals = nan(1, numel(keyGroups));
    for i = 1:numel(keyGroups)
        pooledVals(i) = pooledAbs.signFlipFraction(strcmp(pooledAbs.markerGroup, keyGroups{i}));
        subjVals(i) = subjectAbs.medianPairFlipFraction(strcmp(subjectAbs.markerGroup, keyGroups{i}));
        plot(ax, [subjVals(i) pooledVals(i)], [y(i) y(i)], '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 5);
        plot(ax, subjVals(i), y(i), 'o', 'MarkerFaceColor', [0.1 0.45 0.85], 'MarkerEdgeColor', 'w', 'MarkerSize', 11, 'LineWidth', 1.2);
        plot(ax, pooledVals(i), y(i), 'o', 'MarkerFaceColor', [0.9 0.35 0.1], 'MarkerEdgeColor', 'w', 'MarkerSize', 11, 'LineWidth', 1.2);
    end

    set(ax, 'YTick', y, 'YTickLabel', strrep(keyGroups, '_', '-'), 'FontSize', 13, 'LineWidth', 1.2, 'Box', 'off');
    set(ax, 'YDir', 'reverse');
    xlabel(ax, 'Regime shift index', 'FontSize', 14, 'FontWeight', 'bold');
    xlim(ax, [0 0.55]);
    grid(ax, 'on');
    legend(ax, {'', 'Median subject-level shift', 'Pooled shift'}, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'Box', 'off');

    annotation(ancestor(ax, 'figure'), 'textbox', [0.70 0.18 0.26 0.11], ...
        'String', ['Interpretation:' newline ...
                   'The upper body does shift at the group level,' newline ...
                   'but the typical individual shows a smaller change.'], ...
        'EdgeColor', 'none', 'FontSize', 13, 'Color', [0.2 0.2 0.2]);
end

function T = localComputeFearExcludedShiftTable(pairTbl, normLabel)
    T = pairTbl(strcmp(pairTbl.normalization, normLabel), :);
    keep = ~contains(T.pairLabel, 'FEAR');
    T = T(keep, :);
    groups = unique(T.markerGroup, 'stable');
    rows = {};
    for i = 1:numel(groups)
        idx = strcmp(T.markerGroup, groups{i});
        rows(end+1, :) = {groups{i}, mean(T.signFlip(idx), 'omitnan')}; %#ok<AGROW>
    end
    T = cell2table(rows, 'VariableNames', {'markerGroup','signFlipFraction'});
end

function T = localComputeFearExcludedSubjectShiftTable(flipTbl, normLabel)
    T = flipTbl(strcmp(flipTbl.normalization, normLabel) & flipTbl.comparable, :);
    keep = ~contains(T.pairLabel, 'FEAR');
    T = T(keep, :);
    groups = unique(T.markerGroup, 'stable');
    rows = {};
    for i = 1:numel(groups)
        idxG = strcmp(T.markerGroup, groups{i});
        subjIDs = unique(T.subjectID(idxG), 'stable');
        subjFracs = nan(numel(subjIDs), 1);
        for s = 1:numel(subjIDs)
            idx = idxG & strcmp(T.subjectID, subjIDs{s});
            subjFracs(s) = mean(T.signFlip(idx), 'omitnan');
        end
        rows(end+1, :) = {groups{i}, median(subjFracs, 'omitnan')}; %#ok<AGROW>
    end
    T = cell2table(rows, 'VariableNames', {'markerGroup','medianPairFlipFraction'});
end

function c = localColorForValue(v, cmap, vmin, vmax)
    t = (v - vmin) / (vmax - vmin);
    t = max(0, min(1, t));
    idx = 1 + round(t * (size(cmap,1)-1));
    c = cmap(idx, :);
end

function localPlaceGroupLabel(ax, name, frac)
    switch name
        case 'HEAD', pos = [0 1.22];
        case 'UTORSO', pos = [0 0.52];
        case 'LTORSO', pos = [0 -0.18];
        case 'UPPER_LIMB_L', pos = [-1.25 0.55];
        case 'UPPER_LIMB_R', pos = [1.25 0.55];
        case 'WRIST_L', pos = [-1.30 -0.40];
        case 'WRIST_R', pos = [1.30 -0.40];
        case 'LOWER_LIMB_L', pos = [-0.95 -1.45];
        case 'LOWER_LIMB_R', pos = [0.95 -1.45];
        otherwise, pos = [0 0];
    end
    text(ax, pos(1), pos(2), sprintf('%s\n%.2f', strrep(name,'_','-'), frac), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.15 0.15 0.15]);
end

function nodes = localBodyNodes()
    nodes = struct();
    nodes.headTop = [0, 1.10];
    nodes.neck = [0, 0.65];
    nodes.shoulderL = [-0.55, 0.55];
    nodes.shoulderR = [0.55, 0.55];
    nodes.elbowL = [-0.85, 0.10];
    nodes.elbowR = [0.85, 0.10];
    nodes.wristL = [-1.02, -0.35];
    nodes.wristR = [1.02, -0.35];
    nodes.chest = [0, 0.20];
    nodes.waist = [0, -0.35];
    nodes.hipL = [-0.30, -0.45];
    nodes.hipR = [0.30, -0.45];
    nodes.kneeL = [-0.42, -1.10];
    nodes.kneeR = [0.42, -1.10];
    nodes.ankleL = [-0.48, -1.85];
    nodes.ankleR = [0.48, -1.85];
end

function segments = localBodySegments()
    segments = {
        'headTop','neck';
        'shoulderL','neck';
        'shoulderR','neck';
        'neck','chest';
        'chest','waist';
        'shoulderL','elbowL';
        'elbowL','wristL';
        'shoulderR','elbowR';
        'elbowR','wristR';
        'waist','hipL';
        'waist','hipR';
        'hipL','kneeL';
        'kneeL','ankleL';
        'hipR','kneeR';
        'kneeR','ankleR'};
end

function m = localGroupNodeMap()
    m = struct();
    m.HEAD = {'headTop','neck'};
    m.UTORSO = {'shoulderL','neck'; 'neck','shoulderR'; 'neck','chest'};
    m.LTORSO = {'chest','waist'; 'waist','hipL'; 'waist','hipR'};
    m.UPPER_LIMB_L = {'shoulderL','elbowL'; 'neck','shoulderL'};
    m.UPPER_LIMB_R = {'shoulderR','elbowR'; 'neck','shoulderR'};
    m.WRIST_L = {'elbowL','wristL'};
    m.WRIST_R = {'elbowR','wristR'};
    m.LOWER_LIMB_L = {'hipL','kneeL'; 'kneeL','ankleL'};
    m.LOWER_LIMB_R = {'hipR','kneeR'; 'kneeR','ankleR'};
end
