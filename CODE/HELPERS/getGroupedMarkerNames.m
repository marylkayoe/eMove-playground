function groupedMarkerNames = getGroupedMarkerNames(markerNames, groupIndicator)
    % find all marker names matching the group indicator, for example 'Toe', case insensitive
    matches = contains(markerNames, groupIndicator, 'IgnoreCase', true);
    groupedMarkerNames = markerNames(matches);
end
