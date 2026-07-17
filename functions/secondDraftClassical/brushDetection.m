function [brushMask, props] = brushDetection(image)
% Enter a second parameter as 'true' for debug tools
% Debug includes images of the process & classical evidence metrics

% Editable Parameters
maxBrushSize = 1000;
minMinorAxis = 8;
maxEccentricities = 0.95;
%

% Standard Pre-processing
imgGS = im2double(im2gray(image));
imgFlat = imflatfield(imgGS, 60);
% Reduce Glare
background = imclose(imgFlat, strel('disk', 50));
imgFlat = imgFlat - background; % Remove it

% Create a Gabor Filter Bank
wavelengths = [8, 16]; % Wavelengths dictate the thickness of the textures
orientations = [30, 45, 60, 120, 135, 150]; % Orientations dictate the angles.
gBank = gabor(wavelengths, orientations);

% Apply Gabor Filters to the Grayscale Image
gMag = imgaborfilt(imgFlat, gBank);
% Take the maximum response across all our diagonal filters to create a single heatmap.
diagHeatmap = max(gMag, [], 3);
% Relative Thresholding using mean and std 
% Done to negate assumption of defect from methods like percentile thresh
heatmapMean = mean(diagHeatmap(:));
heatmapStd = std(diagHeatmap(:));
% Flag pixels statistically brighter than the natural grain
thresh = heatmapMean + (2 * heatmapStd); 
rawDiagMask = diagHeatmap > thresh;

% Imclose fills in the gaps between fragmented defect pixels to make them cohesive.
cohesiveMask = imclose(rawDiagMask, strel('disk', 15));

% Use 4-connectivity on the newly blobbed mask
% Path can only be formed by moving horizontally or vertical.
bw = bwconncomp(cohesiveMask, 8); 
stats = regionprops(bw, 'Area', 'MinorAxisLength', 'Eccentricity');

areas = [stats.Area];
minorAxes = [stats.MinorAxisLength];
eccentricities = [stats.Eccentricity];

keepIdx = find(areas > maxBrushSize & minorAxes > minMinorAxis & eccentricities < maxEccentricities); 
brushMask = ismember(labelmatrix(bw), keepIdx);

props = brushEvidence(brushMask);
end

%% --- Helper: classical evidence metrics ---
function evidence = brushEvidence(defectMask)
% Extract area statistics for all distinct blobs
stats = regionprops(defectMask, 'Area','Centroid');

% The number of distinct regions is just the length of the stats array
numRegions = length(stats);

% Evidences
evidence.NumRegions = numRegions;
evidence.Areas = [stats.Area];
evidence.Location = cat(1, stats.Centroid);

end

