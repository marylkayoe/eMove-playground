function convertViconCSVtoMat(dataFolder, fileName, outputFolder, varargin)
% convertCSVtoMat - Converts a Vicon CSV file into a MATLAB .mat file.
%
% This function reads trajectory data from a Vicon CSV file, processes it,
% and saves the resulting matrix into a .mat file in the specified output folder.
%
% Inputs:
%   dataFolder   - Folder containing the input CSV file.
%   fileName     - Name of the CSV file to process.
%   outputFolder - Folder where the .mat file will be saved.
%
% Outputs:
%   None (the function saves the .mat file to the specified output folder).

    trialData = parseViconCSV(dataFolder, fileName, varargin{:});

    % let's clean the file name to remove spaces and special characters
    [~, fileNameBase, ext] = fileparts(fileName);
    fileNameBase = regexprep(fileNameBase, '[^a-zA-Z0-9]', '_');
    fileNameBase = [fileNameBase, '_cleaned'];

     % Ensure the output folder exists
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    outputFileName = fullfile(outputFolder, [fileNameBase, '.mat']); 
    save(outputFileName, 'trialData');

end
