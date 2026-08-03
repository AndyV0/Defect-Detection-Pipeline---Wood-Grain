function [hairlineMask, props] = hairlineScratchDetection(img, showDebug)
% Function for documenting the unused super-fine scratch detection
    if nargin < 2, showDebug = false; end
    % ---- Preprocessing (same as scratchDetection) ----
    imgGS   = im2gray(img);
    imgFlat = im2double(imflatfield(imgGS, 60));
    
    % ---- Directional gradients ----
    [Gx, Gy] = imgradientxy(imgFlat);
    
    % ---- Directional response ----
    % Positive where vertical-gradient energy exceeds a discounted
    % horizontal-gradient energy 
    grainDiscountWeight = 0.6;
    directionalResponse = abs(Gy) - grainDiscountWeight * abs(Gx);
    directionalResponse(directionalResponse < 0) = 0;
    
    % ---- Threshold ----
    threshPercentile = 99.7;
    threshScale = 0.5;
    thresh = max(prctile(directionalResponse(:), threshPercentile) * threshScale, 1e-6);
    evidenceMask = directionalResponse > thresh;
    
    % Remove tiny noise specks
    hairlineMask = bwareaopen(evidenceMask, 10);
    hairlineMask = imclose(hairlineMask, strel('rectangle', [1 5]));

    % ---- Compute metrics ----
    props = hairlineEvidence(hairlineMask, showDebug);
end 
 
%% ---- Helper: evidence metrics ----
function evidence = hairlineEvidence(mask, showDebug)
    stats = regionprops(mask, 'Area', 'MajorAxisLength', 'MinorAxisLength', 'Orientation');
 
    if isempty(stats)
        evidence.NumRegions        = 0;
        evidence.TotalDefectPixels = 0;
        evidence.LargestRegionArea = 0;
        evidence.PercentageFlagged = 0;
        evidence.MaxAspectRatio    = 0;
 
        if showDebug
            disp('--- Hairline Scratch Evidence Metrics ---');
            disp('Clean Image: No regions detected.');
        end
        return;
    end
 
    areas = [stats.Area];
    aspectRatios = [stats.MajorAxisLength] ./ ([stats.MinorAxisLength] + eps);
 
    evidence.NumRegions        = numel(stats);
    evidence.TotalDefectPixels = sum(areas);
    evidence.LargestRegionArea = max(areas);
    evidence.PercentageFlagged = 100 * sum(areas) / numel(mask);
    evidence.MaxAspectRatio    = max(aspectRatios);
 
    if showDebug
        disp('--- Hairline Scratch Evidence Metrics ---');
        disp(evidence);
    end
end