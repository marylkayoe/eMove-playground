% summarize_manifest_vs_premanifest_ks.m
%
% Summarize per-subject KS tables into median-across-subject rows and compare
% manifest vs pre-manifest corpora.

clearvars;
clc;

outDir = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/manifest_vs_premanifest_20260311_153108';

A = readtable(fullfile(outDir, 'ks_manifest.csv'));
B = readtable(fullfile(outDir, 'ks_premanifest.csv'));

S1 = localSummarize(A, 'manifest');
S2 = localSummarize(B, 'pre');

C = outerjoin(S1, S2, 'Keys', {'markerGroup','pairLabel'}, 'MergeKeys', true, 'Type', 'full');
C.dKs = C.ksD_manifest_med - C.ksD_pre_med;
C.dDelta = C.delta_manifest_med - C.delta_pre_med;
C = sortrows(C, {'markerGroup','pairLabel'});

writetable(C, fullfile(outDir, 'ks_manifest_vs_premanifest_median_summary.csv'));

disp('Target rows:');
m1 = strcmp(string(C.markerGroup), 'WRIST_L') & strcmp(string(C.pairLabel), 'FEAR-JOY');
m2 = strcmp(string(C.markerGroup), 'HEAD') & strcmp(string(C.pairLabel), 'FEAR-JOY');
disp(C(m1 | m2, :));

disp('Top |dKs| rows:');
[~, ix] = maxk(abs(C.dKs), min(10, height(C)));
disp(C(ix, {'markerGroup','pairLabel','ksD_manifest_med','ksD_pre_med','dKs'}));

function S = localSummarize(T, tag)
    mg = string(T.markerGroup);
    pl = string(T.pairLabel);
    [G, mgU, plU] = findgroups(mg, pl);

    ksMed = splitapply(@(x) median(x, 'omitnan'), T.ksD, G);
    dMed = splitapply(@(x) median(x, 'omitnan'), T.deltaMedian_sorted, G);
    nRows = splitapply(@numel, T.ksD, G);

    if strcmp(tag, 'manifest')
        S = table(cellstr(mgU), cellstr(plU), ksMed, dMed, nRows, ...
            'VariableNames', {'markerGroup','pairLabel','ksD_manifest_med','delta_manifest_med','n_manifest'});
    else
        S = table(cellstr(mgU), cellstr(plU), ksMed, dMed, nRows, ...
            'VariableNames', {'markerGroup','pairLabel','ksD_pre_med','delta_pre_med','n_pre'});
    end
end

