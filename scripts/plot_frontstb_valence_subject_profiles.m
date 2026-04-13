% plot_frontstb_valence_subject_profiles.m
%
% Subject-wise view of front STb clip-view low-animation motion against
% valence bins. Motion is centered within subject before binning.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataCsv = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'frontstb_vs_physiology_joined.csv');
outDir = fullfile(repoRoot, 'outputs', 'figures', ...
    'emowear_frontstb_vs_physiology_clip_compare_20260413_103655', ...
    'subject_profiles');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

T = readtable(dataCsv);
keep = isfinite(T.clipDynamicMedian) & isfinite(T.valence);
T = T(keep, :);
T.participantID = string(T.participantID);

[G, subjectIDs] = findgroups(T.participantID);
mu = splitapply(@mean, T.clipDynamicMedian, G);
T.clipCentered = T.clipDynamicMedian - mu(G);
T.valBin = discretize(T.valence, [0 3 6 9], 'IncludedEdge', 'right');

subjects = unique(T.participantID, 'stable');
profileRows = [];
for i = 1:numel(subjects)
    sid = subjects(i);
    X = T(T.participantID == sid & ~isnan(T.valBin), :);
    if height(X) < 3
        continue;
    end
    med = nan(1, 3);
    n = zeros(1, 3);
    for b = 1:3
        vals = X.clipCentered(X.valBin == b);
        n(b) = nnz(~isnan(vals));
        if n(b) > 0
            med(b) = median(vals, 'omitnan');
        end
    end
    if nnz(n > 0) < 2
        continue;
    end
    slope13 = NaN;
    if all(n([1 3]) > 0)
        slope13 = med(3) - med(1);
    end
    profileRows = [profileRows; table(sid, med(1), med(2), med(3), n(1), n(2), n(3), slope13, ...
        'VariableNames', {'participantID','lowMed','midMed','highMed','nLow','nMid','nHigh','highMinusLow'})]; %#ok<AGROW>
end

writetable(profileRows, fullfile(outDir, 'frontstb_valence_subject_profiles.csv'));

valid3 = ~isnan(profileRows.lowMed) & ~isnan(profileRows.midMed) & ~isnan(profileRows.highMed);
P3 = profileRows(valid3, :);

fig = figure('Color', 'w', 'Position', [90 90 980 760]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
box(ax1, 'off');
ax1.FontName = 'Helvetica';
ax1.FontSize = 11;
ax1.YGrid = 'on';
ax1.GridAlpha = 0.15;
ax1.Color = [0.995 0.995 0.995];

x = [1 2 3];
lineColor = [0.50 0.55 0.62];
for i = 1:height(P3)
    y = [P3.lowMed(i) P3.midMed(i) P3.highMed(i)];
    plot(ax1, x, y, '-', 'Color', [lineColor 0.35], 'LineWidth', 1.0);
end

groupMed = [median(P3.lowMed,'omitnan') median(P3.midMed,'omitnan') median(P3.highMed,'omitnan')];
groupIQRlo = [prctile(P3.lowMed,25) prctile(P3.midMed,25) prctile(P3.highMed,25)];
groupIQRhi = [prctile(P3.lowMed,75) prctile(P3.midMed,75) prctile(P3.highMed,75)];
patch(ax1, [x fliplr(x)], [groupIQRlo fliplr(groupIQRhi)], [0.16 0.48 0.74], ...
    'FaceAlpha', 0.14, 'EdgeColor', 'none');
plot(ax1, x, groupMed, '-o', 'Color', [0.16 0.48 0.74], ...
    'LineWidth', 2.8, 'MarkerFaceColor', [0.16 0.48 0.74], ...
    'MarkerEdgeColor', 'w', 'MarkerSize', 8);
yline(ax1, 0, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
xlim(ax1, [0.8 3.2]);
xticks(ax1, x);
xticklabels(ax1, {'1-3','4-6','7-9'});
ylabel(ax1, 'Centered clip motion');
title(ax1, sprintf('Subject-wise valence profiles (n = %d subjects with all 3 bins)', height(P3)), ...
    'FontWeight', 'bold');

for k = 1:3
    text(ax1, k, max(groupIQRhi) + 0.15 * range([groupIQRlo groupIQRhi]), ...
        sprintf('n=%d', sum(~isnan(P3{:,k+1}))), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 9, 'Color', [0.25 0.25 0.25]);
end

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
box(ax2, 'off');
ax2.FontName = 'Helvetica';
ax2.FontSize = 11;
ax2.YGrid = 'on';
ax2.GridAlpha = 0.15;
ax2.Color = [0.995 0.995 0.995];

edges = -6:0.5:6;
histogram(ax2, P3.highMinusLow, edges, 'FaceColor', [0.16 0.48 0.74], ...
    'FaceAlpha', 0.75, 'EdgeColor', 'w');
xline(ax2, 0, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
medSlope = median(P3.highMinusLow, 'omitnan');
xline(ax2, medSlope, '-', 'Color', [0.84 0.36 0.14], 'LineWidth', 2.0);
xlabel(ax2, 'High minus low valence centered motion');
ylabel(ax2, 'Subjects');
title(ax2, sprintf('Distribution of subject-level high-low differences (median = %.3f)', medSlope), ...
    'FontWeight', 'bold');

title(tlo, 'Front STb clip-view low-animation motion by valence within subject', ...
    'FontSize', 18, 'FontWeight', 'bold');

exportgraphics(fig, fullfile(outDir, 'frontstb_valence_subject_profiles.png'), 'Resolution', 220);
savefig(fig, fullfile(outDir, 'frontstb_valence_subject_profiles.fig'));

