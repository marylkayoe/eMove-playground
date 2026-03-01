function results = queryAssignmentsByDate(assignments, queryDate)
    % queryAssignmentsByDate - Filters the assignments table for files acquired on a specific date.
    %
    % Inputs:
    %   assignments - Table containing the dataset assignments.
    %   queryDate   - Datetime or string representing the date to query (e.g., '2025-07-16').
    %
    % Outputs:
    %   results - Subset of the assignments table matching the query date.

    % Ensure queryDate is a datetime object
    if ischar(queryDate) || isstring(queryDate)
        queryDate = datetime(queryDate, 'InputFormat', 'yyyy-MM-dd');
    end

    % Validate the assignments table
    if ~istable(assignments) || ~ismember('parsedTimestamp', assignments.Properties.VariableNames)
        error('The assignments input must be a table with a "parsedTimestamp" column.');
    end

    % Filter rows where the parsedTimestamp matches the query date
    results = assignments(day(assignments.parsedTimestamp) == day(queryDate) & ...
                          month(assignments.parsedTimestamp) == month(queryDate) & ...
                          year(assignments.parsedTimestamp) == year(queryDate), :);
end