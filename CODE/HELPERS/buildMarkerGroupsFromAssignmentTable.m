function [groupedMarkerNames, groupedBodypartNames, groupTbl] = buildMarkerGroupsFromAssignmentTable(markerTbl, varargin)
% buildMarkerGroupsFromAssignmentTable Convert marker assignment table to group cell arrays.
%
% Input table requirements:
%   markerName, groupName, include
%
% Outputs:
%   groupedMarkerNames - 1xN cell, each cell contains marker-name cellstr
%   groupedBodypartNames - 1xN cellstr of group names
%   groupTbl - compact summary table (groupName, markerCount, markerList)

    p = inputParser;
    addRequired(p, 'markerTbl', @istable);
    addParameter(p, 'excludeEmptyGroups', true, @(x) islogical(x) && isscalar(x));
    parse(p, markerTbl, varargin{:});

    needed = {'markerName', 'groupName', 'include'};
    if ~all(ismember(needed, markerTbl.Properties.VariableNames))
        error('buildMarkerGroupsFromAssignmentTable:MissingColumns', ...
            'markerTbl must contain columns: markerName, groupName, include');
    end

    markerName = string(markerTbl.markerName);
    groupName = upper(strtrim(string(markerTbl.groupName)));
    include = logical(markerTbl.include);

    useMask = include;
    if p.Results.excludeEmptyGroups
        useMask = useMask & groupName ~= "";
    end

    markerName = markerName(useMask);
    groupName = groupName(useMask);

    [groupedBodypartNames, ia] = unique(groupName, 'stable');
    groupedBodypartNames = cellstr(groupedBodypartNames(:)');
    groupedMarkerNames = cell(1, numel(ia));

    groupNameAll = upper(strtrim(string(markerTbl.groupName)));
    markerNameAll = string(markerTbl.markerName);
    includeAll = logical(markerTbl.include);

    groupNameCol = strings(numel(ia), 1);
    markerCountCol = zeros(numel(ia), 1);
    markerListCol = strings(numel(ia), 1);

    for i = 1:numel(ia)
        g = groupedBodypartNames{i};
        m = includeAll & (groupNameAll == string(g));
        markers = markerNameAll(m);
        groupedMarkerNames{i} = cellstr(markers(:));

        groupNameCol(i) = string(g);
        markerCountCol(i) = numel(markers);
        markerListCol(i) = strjoin(cellstr(markers), ';');
    end

    groupTbl = table(groupNameCol, markerCountCol, markerListCol, ...
        'VariableNames', {'groupName', 'markerCount', 'markerList'});
end
