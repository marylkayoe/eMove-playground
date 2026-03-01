function R = plot3Dtrajectories(data, varargin)
    % visualize 3D trajectories of markers, given data and marker names
    % Inputs:
    %   data - 3D matrix of size (nFrames x 3 x nMarkers)
    %   markerNames - Cell array of marker names corresponding to the 3rd dimension
    %   varargin - Optional parameters
    %      'figureTitle' - Title of the figure (default: '3D Marker Trajectories')
    %. 'markerNames' - Cell array of marker names (default: 'marker'), can be char if only one marker
    %  'relativePositionMarker' - Marker name to use as reference for relative positioning, char
    % ' plotWhere' - figure handle to plot into (default: new figure)
    % 'groupColor' - color for all markers in the group (default: different colors for each marker)
    % 'groupLabel' - label for the group of markers, used when coloring with same color (default: none)
    %  'showAverageTrajectory' - boolean to plot average trajectory across markers (default: false)


    % parse optional inputs
    p = inputParser;
    addParameter(p, 'markerNames', 'marker', @(x) iscell(x) || ischar(x));
    addParameter(p, 'figureTitle', '3D Marker Trajectories', @ischar);
    addParameter(p, 'relativePositionMarker', '', @ischar);
    addParameter(p, 'plotWhere', [], @(x) isempty(x) || ishandle(x));
    addParameter(p, 'groupColor', [], @(x) isempty(x) || ischar(x) || isnumeric(x));
    addParameter(p, 'groupLabel', '', @ischar);
    addParameter(p, 'showAverageTrajectory', false, @(x) islogical(x) && isscalar(x));



    parse(p, varargin{:});
    figureTitle = p.Results.figureTitle;   
    markerNames = p.Results.markerNames;
    relativePositionMarker = p.Results.relativePositionMarker;
    plotWhere = p.Results.plotWhere;
    groupColor = p.Results.groupColor;
    groupLabel = p.Results.groupLabel;
    nMarkers = size(data, 3);
    showAverageTrajectory = p.Results.showAverageTrajectory;

    if ischar(markerNames)
        markerNames = {markerNames};
    end 

    if ~isempty(relativePositionMarker)
        % shift all marker positions to be relative to the specified marker
        % check if the relativePositionMarker exists in markerNames
        refIdx = find(strcmp(markerNames, relativePositionMarker));
        if isempty(refIdx)
            warning('Relative position marker not found: %s', relativePositionMarker);
        else
            refTrajectory = squeeze(data(:, :, refIdx)); % nFrames x 3
            for m = 1:nMarkers
                data(:, :, m) = data(:, :, m) - refTrajectory;
            end
        end
    end

    if showAverageTrajectory
        avgTrajectory = mean(data, 3, 'omitnan'); % nFrames x 3
        data = reshape(avgTrajectory, size(avgTrajectory, 1), 3, 1); % nFrames x 3 x 1
        markerNames = {'Average Trajectory'};
        nMarkers = 1;
    end

    if isempty(plotWhere)
    figure;
    else
        set(gcf, 'CurrentAxes', plotWhere);
    end

    hold on;
    if isempty(groupColor)
        colors = lines(nMarkers); % different colors for each marker
    else
        colors = repmat(reshape(groupColor, 1, []), nMarkers, 1); % same color for all markers
    end

    useGroupLegend = ~isempty(groupColor) && ~isempty(groupLabel);
    for m = 1:nMarkers
        traj = squeeze(data(:, :, m));
        if useGroupLegend
            % hide individual markers from the legend when using a group label
            plot3(traj(:, 1), traj(:, 2), traj(:, 3), ...
                'DisplayName', markerNames{m}, 'Color', colors(m, :), 'HandleVisibility', 'off', 'LineWidth', 2 );
        else
            plot3(traj(:, 1), traj(:, 2), traj(:, 3), 'DisplayName', markerNames{m}, 'Color', colors(m, :), 'LineWidth', 2 );
        end
    end
    xlabel('X');
    ylabel('Y');
    zlabel('Z');
    title(figureTitle);
    % if we color all markers with one color, add only one legend entry for the entire group based on groupLabel
    if useGroupLegend
        legendEntries = legend(gca);
        if ~isempty(legendEntries) && isvalid(legendEntries)
            legendEntries.AutoUpdate = 'off';
            existingLabels = legendEntries.String;
            if ischar(existingLabels)
                existingLabels = cellstr(existingLabels);
            end

            if ~any(strcmp(existingLabels, groupLabel))
                existingHandles = legendEntries.PlotChildren;
                h = plot3(NaN, NaN, NaN, 'Color', groupColor, 'DisplayName', groupLabel);
                legend([existingHandles(:); h], [existingLabels(:); {groupLabel}]);
            end
        else
            % add a single legend entry for the group
            h = plot3(NaN, NaN, NaN, 'Color', groupColor, 'DisplayName', groupLabel);
            legend(h, groupLabel, 'AutoUpdate', 'off');
        end
    else
        legend('show');
    end
    grid on;
    axis equal;
    R = gcf; % return the figure handle
end
