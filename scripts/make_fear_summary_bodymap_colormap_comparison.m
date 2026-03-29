function out = make_fear_summary_bodymap_colormap_comparison(varargin)
% make_fear_summary_bodymap_colormap_comparison
% Generate a small comparison set of FEAR body maps with different
% sequential colormaps, keeping data and scale fixed.

p = inputParser;
addParameter(p, 'repoRoot', '/Users/yoe/Documents/REPOS/eMove-playground', @(x) ischar(x) || isstring(x));
addParameter(p, 'dataRoot', '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

repoRoot = char(string(p.Results.repoRoot));
dataRoot = char(string(p.Results.dataRoot));

ylorrd = [ ...
    1.0000 0.9800 0.7000
    0.9980 0.8900 0.3800
    0.9960 0.7200 0.1800
    0.9850 0.4500 0.1200
    0.8900 0.1800 0.0900
    0.7000 0.0000 0.0000];
ylorrd = interp1(linspace(0,1,size(ylorrd,1)), ylorrd, linspace(0,1,256));

grayRed = [linspace(0.93, 0.86, 256)', linspace(0.93, 0.10, 256)', linspace(0.93, 0.10, 256)'];
whiteRed = [ones(256,1), linspace(1, 0, 256)', linspace(1, 0, 256)'];

variants = { ...
    struct('name','ylorrd','title','FEAR Distinguishability | YlOrRd', 'cmap', ylorrd), ...
    struct('name','grayred','title','FEAR Distinguishability | Gray to Red', 'cmap', grayRed), ...
    struct('name','whitered','title','FEAR Distinguishability | White to Red', 'cmap', whiteRed)};

outs = cell(numel(variants),1);
for i = 1:numel(variants)
    v = variants{i};
    outs{i} = make_fear_summary_bodymap( ...
        'repoRoot', repoRoot, ...
        'dataRoot', dataRoot, ...
        'doBaselineNormalize', true, ...
        'colormapSpec', v.cmap, ...
        'titleText', v.title, ...
        'exportStem', ['fear_summary_bodymap_' v.name]);
end

out = struct();
out.variants = variants;
out.outputs = outs;
end
