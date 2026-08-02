% This is less of an actual wokring function and more for documentation
% Of my failure to isolate the super-fine scratch defects
imds = imageDatastore("C:\Users\andy0\Downloads\btad (1)\BTech_Dataset_transformed\02\test\ko");

img = readimage(imds, 90); % super0fine are 80-108 in img, so input 81-109

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

% ---- Compute metrics ----
props = hairlineEvidence(hairlineMask, imgFlat, showDebug);
 
%% ---- Helper: evidence metrics ----
function evidence = hairlineEvidence(mask, imgGS, showDebug)
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