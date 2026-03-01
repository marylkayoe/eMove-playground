function grp = getStimGroup(videoID, lookupTable)
% getStimGroup - Return group code for a given videoID using a lookup table.
%   grp = getStimGroup(videoID, lookupTable)
%   lookupTable: 2-column cell array or table with videoID and groupID.

    grp = '';
    if istable(lookupTable)
        vids = lookupTable{:,1};
        grps = lookupTable{:,2};
    else
        vids = lookupTable(:,1);
        grps = lookupTable(:,2);
    end
    vids = cellstr(vids);
    grps = cellstr(grps);

    idx = find(strcmp(vids, videoID), 1);
    if ~isempty(idx)
        grp = grps{idx};
    end
end
