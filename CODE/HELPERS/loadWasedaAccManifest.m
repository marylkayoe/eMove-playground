function manifest = loadWasedaAccManifest(manifestPath)
%LOADWASEDAACCMANIFEST Load the repo-local Waseda ACC JSON manifest.
if nargin < 1 || isempty(manifestPath)
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    manifestPath = fullfile(repoRoot, 'resources', 'waseda_acc', 'dataset_manifest.json');
end
rawText = fileread(manifestPath);
manifest = jsondecode(rawText);
end
