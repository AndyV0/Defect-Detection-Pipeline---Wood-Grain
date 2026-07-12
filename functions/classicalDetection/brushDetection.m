function brushMask = brushDetection(image, showDebug)
    % Enter a second parameter as 'true' for debug tools
    % Debug includes images of the process & classical evidence metrics
    if nargin < 2
        showDebug = false;
    end
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
    bw = bwconncomp(cohesiveMask, 4); 
    stats = regionprops(bw, 'Area', 'MinorAxisLength', 'Eccentricity');

    areas = [stats.Area];
    minorAxes = [stats.MinorAxisLength];
    eccentricities = [stats.Eccentricity];

    keepIdx = find(areas > 100 & minorAxes > 8 & eccentricities < 0.95); 
    brushMask = ismember(labelmatrix(bw), keepIdx);
    
    % --- OPTIONAL DEBUG VISUALIZATION ---
    if showDebug
        figure('Name', 'Gabor Diagonal Detector', 'Position', [100, 100, 1200, 800]);
        subplot(2,2,1); 
        imshow(imgFlat, []); 
        title('1. Flat-Fielded Grayscale');

        subplot(2,2,2); 
        imshow(diagHeatmap, []); 
        colormap(subplot(2,2,2), hot); 
        title('2. Gabor Diagonal Heatmap');

        subplot(2,2,3); 
        imshow(cohesiveMask); 
        title('3. Blobbed Diagonals');

        subplot(2,2,4); 
        imshow(lightDefectMask); 
        title('4. Final Light Defect Mask');
        brushEvidence(lightDefectMask);
    end
end

%% --- Helper: classical evidence metrics ---
function brushEvidence(defectMask)
% Extract area statistics for all distinct blobs
stats = regionprops(defectMask, 'Area');

% The number of distinct regions is just the length of the stats array
numRegions = length(stats);

% Find the largest region area 
if isempty(stats)
    largestRegion = 0;
else
    largestRegion = max([stats.Area]);
end

% Calculate fraction of the image flagged
fractionFlagged = nnz(defectMask) / numel(defectMask);
% Evidences
evidence.NumRegions = numRegions;
evidence.LargestRegionArea = largestRegion;
evidence.FractionFlagged = fractionFlagged;
% Print the evidence directly to workspace window
disp('--- Brush Evidence Metrics ---');
disp(evidence);
end

