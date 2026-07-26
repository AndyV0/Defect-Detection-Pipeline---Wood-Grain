function [scratchMask, props] = scratchDetection(image, showDebug)
%   Scratch Defect Detection
% Classical defect mask & evidence extraction for the wood-grain-img dataset known as '02'.
% INPUTS:
%   image        - original image
%
%   showDebug    - OPTIONAL parameter. When 'true' displays evidence metrics  
%                showDebug is off by default.             
% OUTPUTS:
%   scratchMask  - defect mask stored in variable. use imshow(varName) to
%                call
%
%   props        - Stored evidence metrics. disp(varName)
% Combine with brushDetection for best results
    if nargin < 2, showDebug = false; end

    % ---- Preprocessing ------------
    imgGS = im2gray(image);
    imgFlat = imflatfield(imgGS, 60);
    
    % ---- Defect Isolation ---------
    % just use a fibermetric to detect all lines
    imgFiber = fibermetric(imgFlat, [2 3 4], 'ObjectPolarity', 'dark');
    
    % ---- Dynamic Global Threshold --------
    % Shows the most extreme intensity distribution as potential defects
    thresh = max(prctile(imgFiber(:), 99.5) * 0.2, 0.1);
    evidenceMask = imgFiber > thresh;
    % Remove tiny bits of noise
    rawscratchMask = bwareaopen(evidenceMask, 20);

    % ---- Morphological Clean-Up ----------
    % Stitch scratches into a more cohesive area
    scratchMask = imclose(rawscratchMask,  strel('disk', 5));
    
    % ---- Compute metrics -----
    props = scratchEvidence(rawscratchMask, scratchMask, imgFlat, showDebug); 
    
    % NOTE: A known issue we have documented is that scratch defect gets a
    % lot of vertical natural grain as false positives
    % This is most apparent in non-defect images, where a lot of vertical
    % lines get flagged. 
end

%% ---- Helper: classical evidence metrics ----
function evidence = scratchEvidence(rawMask, defectMask, imgGS, showDebug)
    % Extract Area and bounding box dimensions for the blobs
    lineStats = regionprops(rawMask, 'Area', 'MajorAxisLength', 'MinorAxisLength', 'Orientation');
    areaStats = regionprops(defectMask, 'Area');

    % Handle clean images
    if isempty(areaStats)
        evidence.PercentageFlagged  = 0;
        evidence.TotalDefectPixels  = 0;
        evidence.LargestRegionArea  = 0;
        evidence.NumRegions         = 0;
        evidence.MaxAspectRatio     = 0;
        evidence.MaxAngleDeviation  = 0;
        evidence.MeanAngleDeviation = 0;
        evidence.IntensityContrast  = 0;

        if showDebug
                disp('--- Scratch Evidence Metrics ---');
                disp('Clean Image: No regions detected.');
        end
    return;
    end
    
    % Area Metrics
    areas = [areaStats.Area];
    numRegions = length(areaStats);
    totalArea = sum(areas);
    largestRegion = max(areas);
    % Percent of the image flagged
    percentFlagged = (totalArea / numel(defectMask)) * 100;
    
    % Shape Metrics
    % Maximum Aspect Ratio (Length vs Width)
    aspectRatios = [lineStats.MajorAxisLength] ./ ([lineStats.MinorAxisLength] + eps);
    maxAspectRatio = max(aspectRatios);

    % Grain Metrics
    % Wood grain runs vertical, while a defect doesn't. Thus:
    % Orientation deviating from 90 degrees is evidence of going against the grain
    grainAxisAngle = 90; % near-vertical grain
    angleDeviations = abs(mod([lineStats.Orientation] - grainAxisAngle + 90, 180) - 90);
    maxAngleDeviation = max(angleDeviations);
    meanAngleDeviation = mean(angleDeviations);

    % Darkness contrast
    intensityContrast = mean2(imgGS(~rawMask)) - mean2(imgGS(rawMask));
    
    % Evidences
    evidence.NumRegions        = numRegions;
    evidence.TotalDefectPixels = totalArea;
    evidence.LargestRegionArea = largestRegion;
    evidence.PercentageFlagged = percentFlagged;
    % Specific to Scratches
    % A high aspect ratio indicates a long, thin scratch
    evidence.MaxAspectRatio = maxAspectRatio;
    % A high angle deviation indicates the mask area cuts against the grain
    evidence.MaxAngleDeviation  = maxAngleDeviation;
    evidence.MeanAngleDeviation = meanAngleDeviation;
    % Positive = flagged region is darker than surrounding wood, as expected
    evidence.IntensityContrast = intensityContrast;

    if showDebug
        % Print the evidence directly to the workspace window
        disp('--- Scratch Evidence Metrics ---');
        disp(evidence);
    end
end