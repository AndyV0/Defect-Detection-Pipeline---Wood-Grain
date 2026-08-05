function maskAI = segmentDefect(I, datasetName)
% Segment Defect, AI-based pixel segmentation of a single image, per the
% README's optional extension deliverable.
%
% INPUTS:
%   I         - original image
%
%   datasetName - OPTIONAL string identifying which trained model to use,
%                 e.g. '01', '02', '03'. 
%                 Checks for segmentDefectNet_<datasetName>.mat next to
%                 this script. Defaults to '03' if omitted. Make sure to
%                 write it as a string exactly how its seen in the file
% OUTPUT:
%   maskAI - the deliverable. Logical mask the same height/width as I

if nargin < 2 || isempty(datasetName)
    datasetName = '03';
end

% Returns the complete disk path to segmentDefect.m
currentFunctionDir = fileparts(mfilename('fullpath'));
% Checks if model type (with its respective #) is in same path
modelFile = fullfile(currentFunctionDir, sprintf('segmentDefectNet_%s.mat', datasetName));

% Auto-download pre-trained models if the model isn't present locally
modelDownload_URL = 'https://github.com/AndyV0/Defect-Detection-Pipeline---Wood-Grain/releases/download/1.0'; 

% Checks if pre-trained model exists in disk at functions path
if ~exist(modelFile, 'file')
    % If not then download it
    modelURL = sprintf('%s/segmentDefectNet_%s.mat', modelDownload_URL, datasetName);
    fprintf('Model not found locally -- downloading from my GitHub URL...\n');
    options = weboptions('HeaderFields', {'User-Agent', 'Mozilla/5.0'});
    websave(modelFile, modelURL, options);
    fprintf('Download complete: %s\n', modelFile);   % Let user know the downlaod is done
end

% Without checking cache, calling segmentDefect simply loads the first
% model loaded every time
% This issue was 'persistent' in testing trainSegmentDefect, but prevented
% here
persistent net inputSize classNames loadedFile
% Reload  from disk only if either nothing's been loaded yet
% OR if previously loaded file doesn't match what's needed this cal
if isempty(net) || ~strcmp(loadedFile, modelFile)
    % load the things in file properly
    loaded = load(modelFile, 'net', 'inputSize', 'classNames');
    net = loaded.net;
    inputSize = loaded.inputSize;
    classNames = loaded.classNames;
    loadedFile = modelFile;
end

originalSize = [size(I,1), size(I,2)]; % Save original size
if size(I,3) == 4
    I = I(:,:,1:3);  % drop alpha channel if present
end

% Then Resizes to resolution the model was trained on
Iresized = imresize(I, inputSize(1:2));

% Runs the actual trained network on the resized image, 
% By producing a per-pixel categorical prediction with class labels
predCategorical = semanticseg(Iresized, net, 'Classes', classNames);
% Resize prediction back up to the ORIGINAL image size. 
predCategoricalFullSize = imresize(predCategorical, originalSize);

% Compares each pixels label to defect 
defectCat = classNames(strcmpi(classNames, 'defect'));
% Produces the glorious deliverable from that comparison
maskAI = predCategoricalFullSize == defectCat;
end
