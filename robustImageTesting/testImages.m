searchResult = dir(fullfile('.', '**', 'robustImageTesting*'));

if isempty(searchResult)
    error('Could not find "robustImageTesting". Make sure it is inside your current folder structure.');
end

% If 'robustImageTesting' is a folder, use its path. If it's a file, get its parent folder.
if searchResult(1).isdir
    folderPath = fullfile(searchResult(1).folder, searchResult(1).name);
else
    folderPath = searchResult(1).folder;
end

fileList = dir(fullfile(folderPath, '*.png'));
numImages = numel(fileList);

if numImages == 0
    error('No PNG files found in the folder: %s', folderPath);
elseif numImages ~= 14
    warning('Expected 14 files, but found %d files. Proceeding anyway.', numImages);
end

% Creates the 600x600x3x14 uint8 matrix instantly
allImages = zeros(600, 600, 3, numImages, 'uint8');

for i = 1:numImages
    fullImagePath = fullfile(folderPath, fileList(i).name);
    allImages(:,:,:,i) = imread(fullImagePath);
end

clear fileList;
clear folderPath;
clear fullImagePath;
clear i;
clear numImages;
clear searchResult;