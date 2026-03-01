function R = displayAllStimAverageSpeeds(trialData, markerGroups, FRAMERATE, varargin)
    % Plot average instantaneous speed for marker groups across all stimulus videos.
    %
    % Inputs:
    %   trialData     - struct containing markerNames, trajectoryData, etc.
    %   markerGroups  - cell array where each cell is a list of marker names for one group
    %   FRAMERATE     - frames per second
    %
    % Optional name-value pairs:
    %   'figureTitle'  - overall title (default constructed)
    %   'speedWindow'  - speed window in seconds (default 0.1)
    %   'colors'       - nVideos x 3 colormap (default: resolved via coding or turbo)
    %   'mocapMetaData' - struct with videoIDs and stimScheduling (default: trialData.metaData)
    %   'stimVideoEmotionCoding' - lookup table for video->group coloring
    %
    % Output:
    %   R - figure handle

    p = inputParser;
    % Backward compatibility: allow third positional arg as mocapMetaData
    if ~isempty(varargin) && isstruct(varargin{1})
        varargin = [{'mocapMetaData'}, varargin];
    end

    p = inputParser;
    addRequired(p, 'trialData');
    addRequired(p, 'markerGroups', @(x) iscell(x) || isstring(x) || ischar(x));
    addRequired(p, 'FRAMERATE', @(x) isnumeric(x) && isscalar(x) && x > 0);

    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'markerGroupNames', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'speedWindow', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'colors', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'stimVideoEmotionCoding', {}, @(x) istable(x) || iscell(x));

    parse(p, trialData, markerGroups, FRAMERATE, varargin{:});

    figureTitle = p.Results.figureTitle;
    speedWindow = p.Results.speedWindow;
    customColors = p.Results.colors;
    markerGroupNames = p.Results.markerGroupNames;
    metaData = trialData.metaData;
    codingTable = p.Results.stimVideoEmotionCoding;

    if isempty(metaData) && isfield(trialData, 'metaData')
        metaData = trialData.metaData;
    end
    if isempty(codingTable) && isfield(trialData, 'stimVideoEmotionCoding')
        codingTable = trialData.stimVideoEmotionCoding;
    end

    % normalize markerGroupNames
    if ischar(markerGroupNames)
        markerGroupNames = {markerGroupNames};
    elseif isstring(markerGroupNames)
        markerGroupNames = cellstr(markerGroupNames);
    end

    if ~isfield(metaData, 'videoIDs') || ~isfield(metaData, 'stimScheduling')
        error('Metadata must contain videoIDs and stimScheduling.');
    end

    videoIDs = metaData.videoIDs;
    if isrow(videoIDs); videoIDs = videoIDs(:); end
    nVideos = numel(videoIDs);

    [colors, groupCodes, uniqueGroups, groupColorMap] = resolveColors(videoIDs, customColors, codingTable);

    % if no marker group names provided, create default names based on marker lists
    if isempty(markerGroupNames)
        nGroups = numel(markerGroups);
        markerGroupNames = cell(nGroups, 1);
        for g = 1:nGroups
            grpMarkers = markerGroups{g};
            if isstring(grpMarkers)
                grpMarkers = cellstr(grpMarkers);
            end
            if iscell(grpMarkers) && ~isempty(grpMarkers)
                markerGroupNames{g} = strjoin(grpMarkers, ', ');
            else
                markerGroupNames{g} = sprintf('Group %d', g);
            end
        end
    end

    % Normalize markerGroups into a cell array of cellstr
    if ischar(markerGroups) || isstring(markerGroups)
        markerGroups = {cellstr(markerGroups)};
    else
        markerGroups = cellfun(@cellstr, markerGroups, 'UniformOutput', false);
    end
    nGroups = numel(markerGroups);



    subjID = 'subject';
    if isfield(trialData, 'subjectID')
        subjID = char(trialData.subjectID);
    end
    if isempty(figureTitle)
        figureTitle = sprintf('%s: Average speed across %d stimuli, window = %.1f s', subjID, nVideos, speedWindow);
    end

    R = figure;
    if nGroups == 1
        NCOLS = 1;
        NROWS = 1;
    else
  
    NCOLS = floor(nGroups/2);
    NROWS = ceil(nGroups/NCOLS);
    end
    tiledlayout(NROWS, NCOLS, 'Padding', 'compact', 'TileSpacing', 'compact');

    salMat = NaN(nGroups, nVideos);

    for g = 1:nGroups
        nexttile;
        hold on;
        set(gca, 'Color', [0.5 0.5 0.5]); % gray background
        for v = 1:nVideos
            vid = videoIDs{v};
            [avgSpeed, ~] = getAverageTrajectorySpeed(trialData, markerGroups{g}, FRAMERATE, ...
                'speedWindow', speedWindow, 'videoID', vid, 'mocapMetaData', metaData);
            t = (0:numel(avgSpeed)-1).' / FRAMERATE; % seconds relative to start of stim

            % spectral arc length on the average speed trace
            salMat(g, v) = computeSALFromSpeed(avgSpeed, FRAMERATE);

            % thin line for the time series
            plot(t, avgSpeed, 'Color', colors(v, :), 'DisplayName', groupCodes{v}, 'LineWidth', 0.8);

            % thick horizontal line for the mean speed (ignore NaNs)
            meanSpeed = median(avgSpeed, 'omitnan');
            if ~isnan(meanSpeed) && ~isempty(t)
                line([t(1) t(end)], [meanSpeed meanSpeed], 'Color', colors(v, :), 'LineWidth', 2.5, 'HandleVisibility', 'off');
            end

            % clip to 25 seconds
            xlim([0 25]);
            % make y-axis log
            set(gca, 'YScale', 'log');
        end
        ylabel('Speed (mm/s)');
        title(markerGroupNames{g});
        grid off;
        if g == nGroups
            xlabel('Time (s)');
        end
        legend('off');
    end
    if isempty(uniqueGroups)
        lgd = legend('show');
    else
        grpKeys = uniqueGroups;
        grpHandles = gobjects(numel(grpKeys),1);
        hold on;
        for k = 1:numel(grpKeys)
            grpColor = groupColorMap(grpKeys{k});
            grpHandles(k) = plot(NaN, NaN, '-', 'Color', grpColor, 'LineWidth', 2);
        end
        lgd = legend(grpHandles, grpKeys);
    end
    if ~isempty(lgd) && isvalid(lgd)
        set(lgd, 'Location', 'northeastoutside', 'FontSize', 12, 'Color', [0.5 0.5 0.5], 'TextColor', 'w');
    end

    sgtitle(figureTitle);

    % Bar plot for spectral arc length (per group, per video)
    figure;
    if nGroups == 1
        NCOLS = 1; NROWS = 1;
    else
        NCOLS = floor(nGroups/2);
        NROWS = ceil(nGroups/NCOLS);
    end
    tiledlayout(NROWS, NCOLS, 'Padding', 'compact', 'TileSpacing', 'compact');
    catNames = categorical(videoIDs, videoIDs, 'Ordinal', true);
    for g = 1:nGroups
        nexttile;
        b = bar(catNames, salMat(g, :), 'FaceColor', 'flat');
        b.CData = colors;
        ylabel('SAL (arb.)');
        title(sprintf('%s - Spectral arc length', markerGroupNames{g}));
        grid on;
    end
    if isempty(uniqueGroups)
        lgd2 = legend('show');
    else
        grpKeys = uniqueGroups;
        grpHandles = gobjects(numel(grpKeys),1);
        hold on;
        for k = 1:numel(grpKeys)
            grpColor = groupColorMap(grpKeys{k});
            grpHandles(k) = plot(NaN, NaN, '-', 'Color', grpColor, 'LineWidth', 2);
        end
        lgd2 = legend(grpHandles, grpKeys);
    end
    if ~isempty(lgd2) && isvalid(lgd2)
        set(lgd2, 'Location', 'northeastoutside', 'FontSize', 12);
    end
    sgtitle(sprintf('%s: Spectral arc length of average speeds', subjID));
end

function [colors, groupCodes, uniqueGroups, groupColorMap] = resolveColors(videoIDs, customColors, codingTable)
    n = numel(videoIDs);
    groupCodes = videoIDs; % default: one group per video
    uniqueGroups = {};
    groupColorMap = containers.Map;

    if ~isempty(customColors)
        colors = customColors;
        if size(colors, 1) < n
            warning('Provided colors must have at least one row per video ID.');
            colors = repmat(colors, ceil(n/size(colors,1)), 1);
        end
        colors = colors(1:n, :);
        return;
    end

    if ~isempty(codingTable)
        if istable(codingTable)
            vids = codingTable{:,1};
            grps = codingTable{:,2};
        else
            vids = codingTable(:,1);
            grps = codingTable(:,2);
        end
        vids = cellstr(vids);
        grps = cellstr(grps);
        uniqueGrps = unique(grps);
        uniqueGroups = uniqueGrps;
        cmap = lines(numel(uniqueGrps));
        colors = zeros(n, 3);
        for i = 1:n
            vid = videoIDs{i};
            idx = find(strcmp(vids, vid), 1);
            if isempty(idx)
                colors(i, :) = [0.5 0.5 0.5];
            else
                grp = grps{idx};
                groupCodes{i} = grp;
                gIdx = find(strcmp(uniqueGrps, grp), 1);
                colors(i, :) = cmap(gIdx, :);
                if strcmp(grp, '0')
                    colors(i, :) = [0 0 0];
                end
            end
        end
        for j = 1:numel(uniqueGrps)
            if strcmp(uniqueGrps{j}, '0')
                groupColorMap(uniqueGrps{j}) = [0 0 0];
            else
                groupColorMap(uniqueGrps{j}) = cmap(j, :);
            end
        end
        return;
    end

    colors = turbo(n);
end

function sal = computeSALFromSpeed(speedVec, sampleRate)
    % Compute spectral arc length from a 1-D speed signal.
    speedVec = speedVec(:);
    if numel(speedVec) < 8 || all(isnan(speedVec))
        sal = NaN; return;
    end
    speedVec = fillmissing(speedVec, 'linear', 'EndValues', 'nearest');
    speedVec = speedVec - mean(speedVec, 'omitnan');
    N = numel(speedVec);
    Y = abs(fft(speedVec));
    freqs = (0:N-1)' * (sampleRate / N);
    halfIdx = 1:floor(N/2);
    freqs = freqs(halfIdx);
    Y = Y(halfIdx);
    nyq = sampleRate/2;
    maxFreq = min(10, nyq);
    mask = freqs <= maxFreq;
    freqs = freqs(mask);
    Y = Y(mask);
    if isempty(freqs) || max(Y)==0
        sal = NaN; return;
    end
    fNorm = freqs / maxFreq;
    aNorm = Y / max(Y);
    df = diff(fNorm);
    da = diff(aNorm);
    arcLen = sum(sqrt(df.^2 + da.^2));
    sal = -arcLen;
end
