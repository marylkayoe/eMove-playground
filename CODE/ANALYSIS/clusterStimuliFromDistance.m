function out = clusterStimuliFromDistance(D, videoIDs, varargin)
% clusterStimuliFromDistance - Cluster stimuli using a precomputed distance matrix.
%
%   out = clusterStimuliFromDistance(D, videoIDs, ...)
%
% Optional name-value:
%   'excludeBaseline' - logical (default true) remove baseline videos
%   'excludeVideos'   - cell array of video IDs to remove (default {})
%   'kRange'          - vector of k values to try (default 2:6)
%   'linkage'         - linkage method (default 'average')
%   'makePlot'        - logical (default true) show dendrogram
%   'plotSilhouette'  - logical (default true) plot mean silhouette vs k
%
% Output struct:
%   .videoIDs         - video IDs used for clustering
%   .kBest            - selected number of clusters
%   .idxBest          - cluster labels (nVideos x 1)
%   .silhouette       - average silhouette per k (table)
%   .Z                - linkage matrix
%
    p = inputParser;
    addParameter(p, 'excludeBaseline', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'excludeVideos', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'kRange', 2:6, @(x) isnumeric(x) && isvector(x));
    addParameter(p, 'linkage', 'average', @(x) ischar(x) || isstring(x));
    addParameter(p, 'makePlot', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'plotSilhouette', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});

    excludeBaseline = p.Results.excludeBaseline;
    excludeVideos = p.Results.excludeVideos;
    kRange = p.Results.kRange;
    linkageMethod = char(p.Results.linkage);
    makePlot = p.Results.makePlot;
    plotSilhouette = p.Results.plotSilhouette;

    if ischar(videoIDs) || isstring(videoIDs)
        videoIDs = cellstr(videoIDs);
    end

    if ischar(excludeVideos) || isstring(excludeVideos)
        excludeVideos = cellstr(excludeVideos);
    end

    useIdx = true(numel(videoIDs), 1);
    if excludeBaseline
        isBase = contains(lower(videoIDs), 'baseline') | strcmp(videoIDs, 'BASELINE') | strcmp(videoIDs, '0');
        useIdx = ~isBase;
    end
    if ~isempty(excludeVideos)
        useIdx = useIdx & ~ismember(videoIDs, excludeVideos);
    end

    D = D(useIdx, useIdx);
    videoIDs = videoIDs(useIdx);

    dVec = squareform(D, 'tovector');
    Z = linkage(dVec, linkageMethod);

    silVals = NaN(numel(kRange), 1);
    for i = 1:numel(kRange)
        k = kRange(i);
        idx = cluster(Z, 'maxclust', k);
        silVals(i) = localMeanSilhouette(D, idx);
    end

    [~, bestIdx] = max(silVals);
    kBest = kRange(bestIdx);
    idxBest = cluster(Z, 'maxclust', kBest);

    silTable = table(kRange(:), silVals(:), 'VariableNames', {'k','meanSilhouette'});

    if makePlot
        figure('Color','w');
        dendrogram(Z, 0, 'Labels', videoIDs, 'Orientation', 'top');
        title(sprintf('Dendrogram (%s linkage), k=%d', linkageMethod, kBest));
    end

    if plotSilhouette
        figure('Color','w');
        plot(kRange, silVals, '-o', 'LineWidth', 1.5);
        xlabel('k (number of clusters)');
        ylabel('Mean silhouette');
        title('Silhouette vs k');
        grid on;
    end

    % Print cluster membership
    fprintf('Selected k=%d (mean silhouette=%.3f)\n', kBest, silVals(bestIdx));
    for k = 1:kBest
        members = videoIDs(idxBest == k);
        fprintf('  Cluster %d: %s\n', k, strjoin(members, ', '));
    end

    out = struct();
    out.videoIDs = videoIDs;
    out.kBest = kBest;
    out.idxBest = idxBest;
    out.silhouette = silTable;
    out.Z = Z;
end

function sMean = localMeanSilhouette(D, idx)
    n = numel(idx);
    s = NaN(n, 1);
    for i = 1:n
        same = idx == idx(i);
        same(i) = false;
        if any(same)
            a = mean(D(i, same));
        else
            a = 0;
        end
        b = inf;
        for c = unique(idx)'
            if c == idx(i), continue; end
            other = idx == c;
            if any(other)
                b = min(b, mean(D(i, other)));
            end
        end
        s(i) = (b - a) / max(a, b);
    end
    sMean = mean(s, 'omitnan');
end
