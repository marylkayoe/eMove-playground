function subjectIDs = getSubjectsWithMocapAndUnity(assignments)
    % getSubjectsWithMocapAndUnity - Finds subject IDs with both mocap recordings and unity logs.
    %
    % Inputs:
    %   assignments - Table containing the dataset assignments.
    %
    % Outputs:
    %   subjectIDs - Cell array of subject IDs that have both mocap and unity logs.

    % Validate the assignments table
    if ~istable(assignments) || ~ismember('modality', assignments.Properties.VariableNames) || ~ismember('assignedSubject', assignments.Properties.VariableNames)
        error('The assignments input must be a table with "modality" and "assignedSubject" columns.');
    end

    % Find unique subject IDs with mocap recordings
    mocapSubjects = unique(assignments.assignedSubject(strcmp(assignments.modality, 'mocap')));

    % Find unique subject IDs with unity logs
    unitySubjects = unique(assignments.assignedSubject(strcmp(assignments.modality, 'unity')));

    % Find intersection of both sets
    subjectIDs = intersect(mocapSubjects, unitySubjects);
end