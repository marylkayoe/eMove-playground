function plotStimDistanceSummary(D, videoIDs, varargin)
% plotStimDistanceSummary - Visualize stimulus distance matrix.
%
%   plotStimDistanceSummary(D, videoIDs, ...)
%
% Optional name-value:
%   'labelRotation' - x-axis label rotation for heatmap (default 45)
%   'mds'           - logical, show 2D MDS scatter (default true)
%   'dendrogram'    - logical, show dendrogram (default true)
%   'heatmap'       - logical, show heatmap (default true)
%
    p = inputParser;
    addParameter(p, 'labelRotation', 45, @(x) isscalar(x));
    addParameter(p, 'mds', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'dendrogram', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'heatmap', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});

    doHeat = p.Results.heatmap;
    doDend = p.Results.dendrogram;
    doMDS = p.Results.mds;

    if ischar(videoIDs) || isstring(videoIDs)
        videoIDs = cellstr(videoIDs);
    end

    % Heatmap
    if doHeat
        figure('Color','w');
        imagesc(D);
        axis square;
        colormap(parula);
        colorbar;
        title('Stimulus distance (Wasserstein-1)');
        set(gca, 'XTick', 1:numel(videoIDs), 'XTickLabel', videoIDs, ...
            'YTick', 1:numel(videoIDs), 'YTickLabel', videoIDs);
        xtickangle(p.Results.labelRotation);
    end

    % Dendrogram
    if doDend
        figure('Color','w');
        dVec = squareform(D, 'tovector');
        Z = linkage(dVec, 'average');
        dendrogram(Z, 0, 'Labels', videoIDs, 'Orientation', 'top');
        title('Hierarchical clustering (average linkage)');
    end

    % MDS scatter
    if doMDS
        figure('Color','w');
        [Y, ~] = mdscale(D, 2);
        scatter(Y(:,1), Y(:,2), 60, 'filled');
        text(Y(:,1), Y(:,2), videoIDs, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
        xlabel('MDS-1'); ylabel('MDS-2');
        title('MDS embedding of stimulus distances');
        grid on;
    end
end
