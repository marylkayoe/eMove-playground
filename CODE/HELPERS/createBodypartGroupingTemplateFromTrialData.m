function [markerTbl, groupTbl] = createBodypartGroupingTemplateFromTrialData(trialDataInput, varargin)
% createBodypartGroupingTemplateFromTrialData Build editable marker-group templates.
%
% Purpose:
%   Create student-friendly CSV templates for bodypart grouping:
%   1) marker-level sheet (one marker per row)
%   2) grouped summary sheet (one group with semicolon marker list)
%
% Usage:
%   [markerTbl, groupTbl] = createBodypartGroupingTemplateFromTrialData('/path/subj.mat')
%   [markerTbl, groupTbl] = createBodypartGroupingTemplateFromTrialData(trialDataStruct, 'outputDir', '/tmp')
%
% Output marker table columns:
%   markerName, suggestedGroup, suggestedSide, groupName, include, notes
%
% Output group table columns:
%   groupName, markerCount, markerList

    p = inputParser;
    addRequired(p, 'trialDataInput');
    addParameter(p, 'outputDir', '', @(x) ischar(x) || isstring(x));
    parse(p, trialDataInput, varargin{:});

    markerNames = localGetMarkerNames(p.Results.trialDataInput);
    markerNames = markerNames(:);
    n = numel(markerNames);
    if n == 0
        error('createBodypartGroupingTemplateFromTrialData:NoMarkers', ...
            'No marker names found in input.');
    end

    suggestedGroup = strings(n, 1);
    suggestedSide = strings(n, 1);
    groupName = strings(n, 1);
    include = true(n, 1);
    notes = repmat("", n, 1);

    for i = 1:n
        name = char(markerNames(i));
        side = localSuggestSide(name);
        grp = localSuggestGroup(name, side);
        suggestedSide(i) = string(side);
        suggestedGroup(i) = string(grp);
        groupName(i) = string(grp);
    end

    markerTbl = table(markerNames, suggestedGroup, suggestedSide, groupName, include, notes, ...
        'VariableNames', {'markerName','suggestedGroup','suggestedSide','groupName','include','notes'});

    groupTbl = localBuildGroupTable(markerTbl);

    outputDir = char(string(p.Results.outputDir));
    if ~isempty(outputDir)
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        markerCsv = fullfile(outputDir, 'bodypart_marker_template.csv');
        groupCsv = fullfile(outputDir, 'bodypart_groups_template.csv');
        writetable(markerTbl, markerCsv);
        writetable(groupTbl, groupCsv);
    end
end

function markerNames = localGetMarkerNames(inputArg)
    if isstruct(inputArg)
        if isfield(inputArg, 'markerNames')
            markerNames = string(inputArg.markerNames);
        else
            markerNames = strings(0,1);
        end
        return;
    end

    if ischar(inputArg) || isstring(inputArg)
        pth = char(string(inputArg));
        if isfile(pth)
            S = load(pth);
            if isfield(S, 'trialData') && isfield(S.trialData, 'markerNames')
                markerNames = string(S.trialData.markerNames);
            elseif isfield(S, 'markerNames')
                markerNames = string(S.markerNames);
            else
                markerNames = strings(0,1);
            end
            return;
        end
    end

    if iscell(inputArg) || isstring(inputArg) || ischar(inputArg)
        markerNames = string(inputArg);
        return;
    end

    markerNames = strings(0,1);
end

function side = localSuggestSide(markerName)
    m = lower(strtrim(char(markerName)));
    if ~isempty(regexp(m, '(^l|_l$|\bleft\b)', 'once'))
        side = 'L';
    elseif ~isempty(regexp(m, '(^r|_r$|\bright\b)', 'once'))
        side = 'R';
    else
        side = 'C';
    end
end

function grp = localSuggestGroup(markerName, side)
    m = lower(strtrim(char(markerName)));

    if contains(m, 'head') || contains(m, 'ear') || contains(m, 'eye') || ...
       contains(m, 'nose') || contains(m, 'jaw') || contains(m, 'chin') || ...
       contains(m, 'forehead')
        grp = 'HEAD';
        return;
    end

    if contains(m, 'spine') || contains(m, 'chest') || contains(m, 'stern') || ...
       contains(m, 'pelvis') || contains(m, 'clav') || contains(m, 'torso') || ...
       contains(m, 'hip')
        grp = 'TORSO';
        return;
    end

    if contains(m, 'shoulder') || contains(m, 'upperarm') || contains(m, 'arm') || ...
       contains(m, 'elbow') || contains(m, 'wrist') || contains(m, 'hand') || ...
       contains(m, 'thumb') || contains(m, 'finger')
        if strcmp(side, 'L')
            grp = 'UPPER_LIMB_L';
        elseif strcmp(side, 'R')
            grp = 'UPPER_LIMB_R';
        else
            grp = 'UPPER_LIMB';
        end
        return;
    end

    if contains(m, 'thigh') || contains(m, 'knee') || contains(m, 'shin') || ...
       contains(m, 'ankle') || contains(m, 'foot') || contains(m, 'toe') || ...
       contains(m, 'calf') || contains(m, 'heel')
        if strcmp(side, 'L')
            grp = 'LOWER_LIMB_L';
        elseif strcmp(side, 'R')
            grp = 'LOWER_LIMB_R';
        else
            grp = 'LOWER_LIMB';
        end
        return;
    end

    grp = 'OTHER';
end

function groupTbl = localBuildGroupTable(markerTbl)
    names = unique(string(markerTbl.groupName), 'stable');
    names = names(names ~= "");
    n = numel(names);

    groupName = strings(n,1);
    markerCount = zeros(n,1);
    markerList = strings(n,1);

    for i = 1:n
        g = names(i);
        mask = string(markerTbl.groupName) == g & markerTbl.include;
        m = string(markerTbl.markerName(mask));
        groupName(i) = g;
        markerCount(i) = numel(m);
        markerList(i) = strjoin(cellstr(m), ';');
    end

    groupTbl = table(groupName, markerCount, markerList, ...
        'VariableNames', {'groupName','markerCount','markerList'});
end
