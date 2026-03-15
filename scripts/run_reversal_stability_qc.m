% run_reversal_stability_qc.m
%
% Subject-aware QC for the pooled reversal story.
%
% Outputs:
%   - per-cell stability table
%   - figures comparing pooled flips, subject-level flip fractions,
%     bootstrap stability, and pooled-vs-subject aggregation agreement
%   - markdown report summarizing the strongest vs weakest reversal cells

clearvars;
clc;
close all;
rng(1);

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
nBootstrap = 2000;

latestPooledDir = localFindLatestStampedDir(figRoot, 'regime_distinctness_');
latestSubjectDir = localFindLatestStampedDir(figRoot, 'regime_subject_level_');
pooledCsv = fullfile(latestPooledDir, 'pairwise_regime_contrasts.csv');
subjectCsv = fullfile(latestSubjectDir, 'subject_pairwise_flips.csv');

if ~isfile(pooledCsv)
    error('Pooled pairwise CSV not found: %s', pooledCsv);
end
if ~isfile(subjectCsv)
    error('Subject pairwise CSV not found: %s', subjectCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['reversal_stability_qc_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

pooledTbl = readtable(pooledCsv, 'TextType', 'string');
subjectTbl = readtable(subjectCsv, 'TextType', 'string');

keepPairsPooled = ~contains(pooledTbl.pairLabel, "FEAR");
keepPairsSubject = ~contains(subjectTbl.pairLabel, "FEAR");
pooledTbl = pooledTbl(keepPairsPooled & ismember(pooledTbl.markerGroup, markerGroupsPlot), :);
subjectTbl = subjectTbl(keepPairsSubject & ismember(subjectTbl.markerGroup, markerGroupsPlot) & subjectTbl.comparable == 1, :);

pairLabels = unique(pooledTbl.pairLabel, 'stable');
pairDisplayLabels = cell(size(pairLabels));
for i = 1:numel(pairLabels)
    pairDisplayLabels{i} = localReversePairLabel(pairLabels{i});
end

metricRows = {};
for normIdx = 1:2
    if normIdx == 1
        normLabel = "absolute";
    else
        normLabel = "baseline-normalized";
    end

    pooledNorm = pooledTbl(pooledTbl.normalization == normLabel, :);
    subjNorm = subjectTbl(subjectTbl.normalization == normLabel, :);

    for g = 1:numel(markerGroupsPlot)
        mg = string(markerGroupsPlot{g});
        for p = 1:numel(pairLabels)
            pairLabel = string(pairLabels{p});

            pooledRow = pooledNorm(pooledNorm.markerGroup == mg & pooledNorm.pairLabel == pairLabel, :);
            subjRows = subjNorm(subjNorm.markerGroup == mg & subjNorm.pairLabel == pairLabel, :);
            if isempty(pooledRow) || isempty(subjRows)
                continue;
            end

            pooledFlip = logical(pooledRow.signFlip(1));
            pooledDeltaFull = pooledRow.deltaFull(1);
            pooledDeltaMicro = pooledRow.deltaMicro(1);

            subjectFlipFrac = mean(subjRows.signFlip);
            subjectMedDeltaFull = median(subjRows.deltaFull, 'omitnan');
            subjectMedDeltaMicro = median(subjRows.deltaMicro, 'omitnan');
            subjectMedianFlip = localIsFlip(subjectMedDeltaFull, subjectMedDeltaMicro);
            pooledVsSubjectAgree = pooledFlip == subjectMedianFlip;

            [bootFlipProb, bootQuadrantAgreeProb] = localBootstrapFlipProbability(subjRows, nBootstrap, pooledDeltaFull, pooledDeltaMicro);

            metricRows(end+1, :) = {char(normLabel), char(mg), char(pairLabel), ...
                pooledDeltaFull, pooledDeltaMicro, pooledFlip, ...
                subjectMedDeltaFull, subjectMedDeltaMicro, subjectMedianFlip, ...
                pooledVsSubjectAgree, subjectFlipFrac, bootFlipProb, bootQuadrantAgreeProb, height(subjRows)}; %#ok<AGROW>
        end
    end
end

metricsTbl = cell2table(metricRows, 'VariableNames', { ...
    'normalization','markerGroup','pairLabel', ...
    'pooledDeltaFull','pooledDeltaMicro','pooledFlip', ...
    'subjectMedianDeltaFull','subjectMedianDeltaMicro','subjectMedianFlip', ...
    'pooledVsSubjectAgree','subjectFlipFraction','bootstrapFlipProbability','bootstrapQuadrantAgreeProbability','nSubjects'});

writetable(metricsTbl, fullfile(outDir, 'reversal_stability_metrics.csv'));

%% Figures
for normIdx = 1:2
    if normIdx == 1
        normLabel = 'absolute';
        figureLabel = 'Absolute';
    else
        normLabel = 'baseline-normalized';
        figureLabel = 'Baseline-normalized';
    end
    Tn = metricsTbl(strcmp(metricsTbl.normalization, normLabel), :);

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 80 1600 980]);
    tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Reversal stability QC | %s | upper body | FEAR excluded', figureLabel), ...
        'FontSize', 22, 'FontWeight', 'bold');

    localPlotMatrix(nexttile(tl, 1), Tn, markerGroupsPlot, pairLabels, pairDisplayLabels, ...
        'pooledFlip', [0 1], parula, 'Pooled raw sign flip (0/1)', '%.0f');
    localPlotMatrix(nexttile(tl, 2), Tn, markerGroupsPlot, pairLabels, pairDisplayLabels, ...
        'subjectFlipFraction', [0 1], turbo, 'Fraction of subjects with sign flip', '%.2f');
    localPlotMatrix(nexttile(tl, 3), Tn, markerGroupsPlot, pairLabels, pairDisplayLabels, ...
        'bootstrapFlipProbability', [0 1], turbo, 'Bootstrap probability aggregate flip persists', '%.2f');
    localPlotMatrix(nexttile(tl, 4), Tn, markerGroupsPlot, pairLabels, pairDisplayLabels, ...
        'pooledVsSubjectAgree', [0 1], summer, 'Pooled-vs-subject-median agreement (0/1)', '%.0f');

    baseName = sprintf('reversal_stability_qc_%s', strrep(normLabel, '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

%% Report
reportPath = fullfile(repoRoot, 'docs', sprintf('REVERSAL_STABILITY_REPORT_%s.md', datestr(now, 'yyyy-mm-dd')));
localWriteReport(reportPath, outDir, metricsTbl, markerGroupsPlot);

fprintf('Saved reversal-stability QC under:\n%s\n', outDir);
fprintf('Saved report:\n%s\n', reportPath);

%% Helpers
function latestDir = localFindLatestStampedDir(rootDir, prefix)
    d = dir(rootDir);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    isMatch = startsWith(names, prefix);
    names = sort(names(isMatch));
    if isempty(names)
        error('No directories starting with %s found under %s', prefix, rootDir);
    end
    latestDir = fullfile(rootDir, char(names(end)));
end

function out = localReversePairLabel(label)
    parts = split(string(label), "-");
    if numel(parts) == 2
        out = char(parts(2) + "-" + parts(1));
    else
        out = char(label);
    end
end

function tf = localIsFlip(deltaFull, deltaMicro)
    tf = isfinite(deltaFull) && isfinite(deltaMicro) && sign(deltaFull) ~= 0 && sign(deltaMicro) ~= 0 && sign(deltaFull) ~= sign(deltaMicro);
end

function [bootFlipProb, bootQuadrantAgreeProb] = localBootstrapFlipProbability(subjRows, nBootstrap, pooledDeltaFull, pooledDeltaMicro)
    subjIDs = unique(subjRows.subjectID, 'stable');
    nSubj = numel(subjIDs);
    bootFlip = false(nBootstrap, 1);
    bootQuadrantAgree = false(nBootstrap, 1);
    pooledQuad = [sign(pooledDeltaFull), sign(pooledDeltaMicro)];

    for b = 1:nBootstrap
        idx = randi(nSubj, nSubj, 1);
        sampledIDs = subjIDs(idx);
        dFull = nan(nSubj, 1);
        dMicro = nan(nSubj, 1);
        for i = 1:nSubj
            row = subjRows(subjRows.subjectID == sampledIDs(i), :);
            dFull(i) = row.deltaFull(1);
            dMicro(i) = row.deltaMicro(1);
        end
        aggFull = median(dFull, 'omitnan');
        aggMicro = median(dMicro, 'omitnan');
        bootFlip(b) = localIsFlip(aggFull, aggMicro);
        bootQuadrantAgree(b) = sign(aggFull) == pooledQuad(1) && sign(aggMicro) == pooledQuad(2);
    end

    bootFlipProb = mean(bootFlip);
    bootQuadrantAgreeProb = mean(bootQuadrantAgree);
end

function localPlotMatrix(ax, Tn, markerGroupsPlot, pairLabels, pairDisplayLabels, fieldName, climVals, cmap, plotTitle, fmt)
    M = nan(numel(markerGroupsPlot), numel(pairLabels));
    for r = 1:numel(markerGroupsPlot)
        for c = 1:numel(pairLabels)
            row = Tn(strcmp(Tn.markerGroup, markerGroupsPlot{r}) & strcmp(Tn.pairLabel, pairLabels{c}), :);
            if ~isempty(row)
                M(r,c) = row.(fieldName)(1);
            end
        end
    end
    imagesc(ax, M, climVals);
    colormap(ax, cmap);
    colorbar(ax);
    title(ax, plotTitle, 'FontSize', 14, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax, 35);
    for r = 1:size(M,1)
        for c = 1:size(M,2)
            if isfinite(M(r,c))
                text(ax, c, r, sprintf(fmt, M(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 9, 'FontWeight', 'bold', 'Color', localTextColor(M(r,c), climVals));
            end
        end
    end
end

function c = localTextColor(v, climVals)
    mid = mean(climVals);
    if v > mid + 0.25 * (climVals(2) - climVals(1))
        c = [1 1 1];
    else
        c = [0 0 0];
    end
end

function localWriteReport(reportPath, outDir, metricsTbl, markerGroupsPlot)
    fid = fopen(reportPath, 'w');
    assert(fid ~= -1, 'Could not open report for writing: %s', reportPath);
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '# Reversal Stability Report (%s)\n\n', datestr(now, 'yyyy-mm-dd'));
    fprintf(fid, 'This report tests whether the pooled reversal picture is stable once subjects are treated as subjects.\n\n');
    fprintf(fid, 'Outputs used here:\n');
    fprintf(fid, '- `%s`\n', fullfile(outDir, 'reversal_stability_metrics.csv'));
    fprintf(fid, '- ![Absolute QC](%s)\n', fullfile(outDir, 'reversal_stability_qc_absolute.png'));
    fprintf(fid, '- ![Normalized QC](%s)\n\n', fullfile(outDir, 'reversal_stability_qc_baseline_normalized.png'));

    for normCell = ["absolute","baseline-normalized"]
        Tn = metricsTbl(strcmp(metricsTbl.normalization, normCell), :);
        pooledFlipRows = Tn(Tn.pooledFlip == 1, :);
        [~, idxStable] = sortrows(table(-pooledFlipRows.bootstrapFlipProbability, -pooledFlipRows.subjectFlipFraction));
        stableRows = pooledFlipRows(idxStable(1:min(6, height(pooledFlipRows))), :);

        [~, idxFragile] = sortrows(table(pooledFlipRows.bootstrapFlipProbability, pooledFlipRows.subjectFlipFraction));
        fragileRows = pooledFlipRows(idxFragile(1:min(6, height(pooledFlipRows))), :);

        fprintf(fid, '## %s\n\n', char(normCell));
        fprintf(fid, '### Read\n');
        fprintf(fid, '- `pooledFlip=1` means the pooled raw summary lands in a reversal quadrant.\n');
        fprintf(fid, '- `subjectFlipFraction` asks how many individual subjects show a reversal for that same bodypart/pair.\n');
        fprintf(fid, '- `bootstrapFlipProbability` asks how often the aggregate subject-median reversal survives subject resampling.\n');
        fprintf(fid, '- `pooledVsSubjectAgree` asks whether pooled raw and subject-median aggregation tell the same sign-flip story.\n\n');

        fprintf(fid, '### Most Stable Pooled-Reversal Cells\n');
        for i = 1:height(stableRows)
            fprintf(fid, '- `%s | %s`: subject flip fraction `%.2f`, bootstrap `%.2f`, pooled-vs-subject agreement `%d`\n', ...
                stableRows.markerGroup{i}, localReversePairLabel(stableRows.pairLabel{i}), stableRows.subjectFlipFraction(i), ...
                stableRows.bootstrapFlipProbability(i), stableRows.pooledVsSubjectAgree(i));
        end
        fprintf(fid, '\n');

        fprintf(fid, '### Most Fragile Pooled-Reversal Cells\n');
        for i = 1:height(fragileRows)
            fprintf(fid, '- `%s | %s`: subject flip fraction `%.2f`, bootstrap `%.2f`, pooled-vs-subject agreement `%d`\n', ...
                fragileRows.markerGroup{i}, localReversePairLabel(fragileRows.pairLabel{i}), fragileRows.subjectFlipFraction(i), ...
                fragileRows.bootstrapFlipProbability(i), fragileRows.pooledVsSubjectAgree(i));
        end
        fprintf(fid, '\n');

        medByBody = groupsummary(Tn, 'markerGroup', 'median', {'subjectFlipFraction','bootstrapFlipProbability','pooledVsSubjectAgree'});
        fprintf(fid, '### Bodypart-Level Median Stability\n');
        for i = 1:height(medByBody)
            fprintf(fid, '- `%s`: median subject flip fraction `%.2f`, median bootstrap `%.2f`, median agreement `%.2f`\n', ...
                medByBody.markerGroup{i}, medByBody.median_subjectFlipFraction(i), ...
                medByBody.median_bootstrapFlipProbability(i), medByBody.median_pooledVsSubjectAgree(i));
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## Working Interpretation\n\n');
    fprintf(fid, 'If many pooled-reversal cells have only modest subject flip fractions and modest bootstrap persistence, then the pooled reversal map should be treated as suggestive rather than definitive. The most defensible claims will then focus on the subset of pair/bodypart combinations that remain stable under subject-aware resampling.\n');
end
