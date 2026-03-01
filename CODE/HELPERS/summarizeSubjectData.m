function summary = summarizeSubjectData(assignments)
% summarizeSubjectData Summarize available modalities per subject.
%
% summary = summarizeSubjectData(assignments)
%   assignments: table returned by buildDatasetAssignments
%
% Output table columns:
%   subject        - subject ID
%   hasMocap       - logical
%   hasUnity       - logical
%   hasHR          - logical
%   hasEDA         - logical
%   nUnityLogs     - count of unity files
%   nHR            - count of HR files
%   nEDA           - count of EDA files
%   notes          - concatenated notes for missing modalities

    % normalize subject column
    subjects = assignments.assignedSubject;
    if iscell(subjects)
        subjects = string(subjects);
    end

    allSubjects = unique(subjects);
    rows = struct([]);
    for i = 1:numel(allSubjects)
        subj = allSubjects(i);
        idx = subjects == subj;
        subTbl = assignments(idx, :);

        hasMocap = any(strcmp(subTbl.modality, 'mocap'));
        hasUnity = any(strcmp(subTbl.modality, 'unity'));
        hasHR    = any(strcmp(subTbl.modality, 'hr'));
        hasEDA   = any(strcmp(subTbl.modality, 'eda'));

        nUnity = sum(strcmp(subTbl.modality, 'unity'));
        nHR    = sum(strcmp(subTbl.modality, 'hr'));
        nEDA   = sum(strcmp(subTbl.modality, 'eda'));

        noteParts = {};
        if ~hasMocap, noteParts{end+1} = 'no mocap'; end
        if ~hasUnity, noteParts{end+1} = 'no unity'; end
        if ~hasHR,    noteParts{end+1} = 'no HR'; end
        if ~hasEDA,   noteParts{end+1} = 'no EDA'; end
        notes = strjoin(noteParts, '; ');

        rows(end+1).subject    = subj; %#ok<AGROW>
        rows(end).hasMocap      = hasMocap;
        rows(end).hasUnity      = hasUnity;
        rows(end).hasHR         = hasHR;
        rows(end).hasEDA        = hasEDA;
        rows(end).nUnityLogs    = nUnity;
        rows(end).nHR           = nHR;
        rows(end).nEDA          = nEDA;
        rows(end).notes         = notes;
    end

    summary = struct2table(rows);
end
