function [colors, groupCodes, uniqueGroups, groupColorMap, codingTable] = resolveStimVideoColors(videoIDs, codingTable)
% resolveStimVideoColors - Assign colors and group codes for stimulus videos.
%
%   [colors, groupCodes, uniqueGroups, groupColorMap, codingTable] = ...
%       resolveStimVideoColors(videoIDs, codingTable)
%
% Inputs:
%   videoIDs    - cell array of video ID strings
%   codingTable - (optional) table or cell array {videoID, groupCode}; if empty,
%                 a default mapping is used (emotion coding provided by user).
%
% Outputs:
%   colors        - nVideos x 3 array of RGB colors
%   groupCodes    - cell array of group codes per video
%   uniqueGroups  - cell array of unique group codes
%   groupColorMap - containers.Map of groupCode -> RGB color
%   codingTable   - the mapping actually used (cell array)
%
% Notes:
%   - Baseline group '0' is always colored black.
%   - If a video ID is not found in the coding table, it is assigned gray.

    if ischar(videoIDs) || isstring(videoIDs)
        videoIDs = cellstr(videoIDs);
    end

    % Default coding table (videoID, groupCode)
    defaultCoding = { ...
        'BASELINE', '0'; ...
        '0806', 'A'; ...
        '1007', 'E'; ...
        '5102', 'D'; ...
        '3001', 'C'; ...
        '3502', 'A'; ...
        '7405', 'D'; ...
        '0602', 'B'; ...
        '6201', 'C'; ...
        '2501', 'E'; ...
        '2704', 'D'; ...
        '4903', 'C'; ...
        '1502', 'B'; ...
        '6611', 'B'; ...
        '6906', 'A'; ...
        '0302', 'E' ...
    };

    if nargin < 2 || isempty(codingTable)
        codingTable = defaultCoding;
    elseif istable(codingTable)
        codingTable = [codingTable{:,1}, codingTable{:,2}];
    end

    vids = cellstr(codingTable(:,1));
    grps = cellstr(codingTable(:,2));
    grps(strcmpi(grps, 'baseline')) = {'0'};

    uniqueGrps = unique(grps);
    uniqueGroups = uniqueGrps;

    cmap = lines(numel(uniqueGrps));
    groupColorMap = containers.Map;
    for j = 1:numel(uniqueGrps)
        if strcmp(uniqueGrps{j}, '0')
            groupColorMap(uniqueGrps{j}) = [0 0 0];
        else
            groupColorMap(uniqueGrps{j}) = cmap(j, :);
        end
    end

    n = numel(videoIDs);
    colors = zeros(n,3);
    groupCodes = videoIDs;

    for i = 1:n
        vid = videoIDs{i};
        idx = find(strcmp(vids, vid), 1);
        grp = '';
        if ~isempty(idx)
            grp = grps{idx};
        elseif contains(lower(vid), 'baseline')
            grp = '0';
        end

        if isempty(grp)
            colors(i,:) = [0.5 0.5 0.5]; % fallback gray
        else
            groupCodes{i} = grp;
            if isKey(groupColorMap, grp)
                colors(i,:) = groupColorMap(grp);
            else
                colors(i,:) = [0.5 0.5 0.5];
            end
        end
    end
end
