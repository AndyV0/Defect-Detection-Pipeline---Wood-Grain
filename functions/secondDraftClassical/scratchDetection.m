function [scratchDefectMask, props]= scratchDetection(image)
%   Scratch Defect Detection
%   Detects the dark scratches on a wood grain texture. Input 'image' can be any test image from BeanTech's 02 data set,
%   and it will output a scratch defect overlay.

% Editable Parameters
lightPercent = 99.5;
sensitivity = 0.2;
minThreshold = 0.1;
minSize = 20;
%

imgGS = im2gray(image);
imgFlat = imflatfield(imgGS, 60);

% Fibermetric to enhance the lines
imgFiber = fibermetric(imgFlat, [2 3 4], 'ObjectPolarity', 'dark');

% Single generous threshold
thresh = max(prctile(imgFiber(:), lightPercent) * sensitivity, minThreshold);
evidenceMask = imgFiber > thresh;

% Remove tiny bits of noise
scratchDefectMask = bwareaopen(evidenceMask, minSize);

% Compute and display metrics directly
props = scratchEvidence(scratchDefectMask);
end

%% --- Helper: classical evidence metrics ---
function evidence = scratchEvidence(defectMask)
% Extract the centroid and angle of every individual line segment
stats = regionprops(defectMask,'Area', 'Centroid', 'Orientation');

% Total Defect Area
totalArea = sum([stats.Area]);

% Calculate fraction of the image flagged (total true pixels / total pixels)
percentFlagged = nnz(defectMask)*100 / numel(defectMask);

% Bundle into a struct for clean command window output
evidence.PercentageFlagged = percentFlagged;

% Bundle and Display
evidence.NumRegions = length(stats);
evidence.TotalDefectPixels = totalArea;
evidence.PercentageFlagged = percentFlagged;
evidence.Location = cat(1, stats.Centroid);
evidence.Areas = [stats.Area];
evidence.Orientations = [stats.Orientation];
end