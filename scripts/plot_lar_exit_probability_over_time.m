function out = plot_lar_exit_probability_over_time(varargin)
% plot_lar_exit_probability_over_time
%
% Build simple time-from-start summaries for brief LAR exits.
%
% Main outputs:
%   1) per-bin probability that a subject shows >=1 exit in that bin
%   2) pooled exit rate per subject-minute by bin
%   3) cumulative fraction of all exits by time

clearvars -except varargin
clc;

p = inputParser;
addParameter(p, 'subjectSummaryPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'exitTablePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'outDir', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'binEdgesNorm', 0:0.1:1, @(x) isnumeric(x) && isvector(x) && numel(x) >= 2);
parse(p, varargin{:});

subjectSummaryPath = char(string(p.Results.subjectSummaryPath));
exitTablePath = char(string(p.Results.exitTablePath));
outDir = char(string(p.Results.outDir));
binEdges = p.Results.binEdgesNorm(:)';

if isempty(subjectSummaryPath) || ~isfile(subjectSummaryPath)
    error('plot_lar_exit_probability_over_time:BadSubjectSummary', ...
        'subjectSummaryPath missing or not found.');
end
if isempty(exitTablePath) || ~isfile(exitTablePath)
    error('plot_lar_exit_probability_over_time:BadExitTable', ...
        'exitTablePath missing or not found.');
end
if isempty(outDir)
    outDir = fileparts(subjectSummaryPath);
end

subjectSummary = readtable(subjectSummaryPath, 'TextType', 'string');
exitTable = readtable(exitTablePath, 'TextType', 'string');
included = subjectSummary(subjectSummary.status == "ok", :);
nSubjects = height(included);

if ~ismember('peakTimeNorm', exitTable.Properties.VariableNames)
    error('plot_lar_exit_probability_over_time:MissingPeakTimeNorm', ...
        'exit_table must contain peakTimeNorm.');
end

binCenters = 0.5 * (binEdges(1:end-1) + binEdges(2:end));
nBins = numel(binCenters);
subjectIDs = string(included.subjectID);

binProbAny = zeros(1, nBins);
binCounts = zeros(1, nBins);
binRatePerSubjectMin = zeros(1, nBins);
binWidthNorm = diff(binEdges);

for b = 1:nBins
    leftEdge = binEdges(b);
    rightEdge = binEdges(b+1);
    if b < nBins
        inBin = exitTable.peakTimeNorm >= leftEdge & exitTable.peakTimeNorm < rightEdge;
    else
        inBin = exitTable.peakTimeNorm >= leftEdge & exitTable.peakTimeNorm <= rightEdge;
    end
    exitsBin = exitTable(inBin, :);
    binCounts(b) = height(exitsBin);
    if ~isempty(exitsBin)
        subjInBin = unique(string(exitsBin.subjectID));
        binProbAny(b) = sum(ismember(subjectIDs, subjInBin)) / nSubjects;
    else
        binProbAny(b) = 0;
    end

    % Since every included subject contributes the full analyzed baseline,
    % pooled subject-time per normalized bin is constant.
    subjectMinutesInBin = nSubjects * median(included.analysisDurSec ./ 60, 'omitnan') * binWidthNorm(b);
    if subjectMinutesInBin > 0
        binRatePerSubjectMin(b) = binCounts(b) / subjectMinutesInBin;
    end
end

[sortedPeakTime, sortIdx] = sort(exitTable.peakTimeNorm);
cumulativeFrac = (1:height(exitTable)) ./ max(1, height(exitTable));
sortedPeakSpeed = [];
if ismember('peakSpeedMmps', exitTable.Properties.VariableNames)
    sortedPeakSpeed = exitTable.peakSpeedMmps(sortIdx);
end

fig = figure('Color', 'w', 'Position', [110 110 1450 520]);
tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
bar(ax1, binCenters, binProbAny, 1.0, 'FaceColor', [0.30 0.58 0.86], 'EdgeColor', 'w');
xlabel(ax1, 'Normalized time from trial start');
ylabel(ax1, 'P(subject has >=1 exit in bin)');
title(ax1, 'Per-bin subject probability');
xlim(ax1, [binEdges(1) binEdges(end)]);
ylim(ax1, [0 max(0.05, 1.1 * max(binProbAny))]);
grid(ax1, 'on');
box(ax1, 'off');

ax2 = nexttile;
bar(ax2, binCenters, binRatePerSubjectMin, 1.0, 'FaceColor', [0.95 0.65 0.20], 'EdgeColor', 'w');
xlabel(ax2, 'Normalized time from trial start');
ylabel(ax2, 'Exit rate (per subject-minute)');
title(ax2, 'Per-bin pooled exit rate');
xlim(ax2, [binEdges(1) binEdges(end)]);
grid(ax2, 'on');
box(ax2, 'off');

ax3 = nexttile;
if ~isempty(sortedPeakSpeed)
    scatter(ax3, sortedPeakTime, cumulativeFrac, 34, sortedPeakSpeed, 'filled');
    cb = colorbar(ax3);
    cb.Label.String = 'Peak speed (mm/s)';
else
    plot(ax3, sortedPeakTime, cumulativeFrac, 'o', 'Color', [0.20 0.45 0.75], 'MarkerFaceColor', [0.20 0.45 0.75]);
end
hold(ax3, 'on');
plot(ax3, sortedPeakTime, cumulativeFrac, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0);
xlabel(ax3, 'Normalized time from trial start');
ylabel(ax3, 'Cumulative fraction of exits');
title(ax3, 'Cumulative exit incidence');
xlim(ax3, [0 1]);
ylim(ax3, [0 1]);
grid(ax3, 'on');
box(ax3, 'off');

sgtitle(fig, sprintf('Brief LAR exits vs time from trial start | n subjects = %d | n exits = %d', ...
    nSubjects, height(exitTable)), 'FontWeight', 'bold', 'FontSize', 16);

pngPath = fullfile(outDir, 'exit_probability_over_time.png');
pdfPath = fullfile(outDir, 'exit_probability_over_time.pdf');
csvPath = fullfile(outDir, 'exit_probability_over_time.csv');
exportgraphics(fig, pngPath, 'Resolution', 220);
exportgraphics(fig, pdfPath, 'ContentType', 'vector');

outTbl = table(binCenters(:), binProbAny(:), binCounts(:), binRatePerSubjectMin(:), ...
    'VariableNames', {'binCenterNorm','probAnyExit','exitCount','exitRatePerSubjectMin'});
writetable(outTbl, csvPath);

out = struct();
out.figure = fig;
out.pngPath = pngPath;
out.pdfPath = pdfPath;
out.csvPath = csvPath;
out.summaryTable = outTbl;
end
