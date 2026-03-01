function [colors, groupCodes, uniqueGroups, groupColorMap] = localResolveColors(videoIDs, codingTable)
    % Match the color/group resolution used in displayAllStimMarkerTrajectories.
    % Baseline group "0" is forced to black; other groups use lines() palette.

    n = numel(videoIDs);
    groupCodes = videoIDs; % default: each video is its own group
    uniqueGroups = {};
    groupColorMap = containers.Map;

    % If no coding table, just give distinct colors per video
    if isempty(codingTable)
        colors = lines(n);
        % make baseline black if present
        for i = 1:n
            if contains(lower(videoIDs{i}), 'baseline')
                colors(i,:) = [0 0 0];
                groupCodes{i} = '0';
            end
        end
        return;
    end

    % Extract mappings
    if istable(codingTable)
        vids = codingTable{:,1};
        grps = codingTable{:,2};
    else
        vids = codingTable(:,1);
        grps = codingTable(:,2);
    end
    vids = cellstr(vids);
    grps = cellstr(grps);

    % Normalize baseline code
    grps(strcmpi(grps, 'baseline')) = {'0'};

    uniqueGrps = unique(grps);
    if any(contains(lower(videoIDs), 'baseline')) && ~any(strcmp(uniqueGrps, '0'))
        uniqueGrps{end+1} = '0';
    end
    uniqueGroups = uniqueGrps;
    cmap = lines(numel(uniqueGrps));
    colors = zeros(n, 3);

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
            % fallback gray if not in coding table
            colors(i, :) = [0.5 0.5 0.5];
            groupCodes{i} = vid;
            continue;
        end
        groupCodes{i} = grp;
        gIdx = find(strcmp(uniqueGrps, grp), 1);
        if strcmp(grp, '0')
            colors(i, :) = [0 0 0];
        else
            colors(i, :) = cmap(gIdx, :);
        end
    end

    % Build group -> color map
    for j = 1:numel(uniqueGrps)
        if strcmp(uniqueGrps{j}, '0')
            groupColorMap(uniqueGrps{j}) = [0 0 0];
        else
            groupColorMap(uniqueGrps{j}) = cmap(j, :);
        end
    end
end
