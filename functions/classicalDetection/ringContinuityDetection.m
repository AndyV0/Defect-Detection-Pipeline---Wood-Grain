function [radialMask, props] = ringContinuityDetection(image, showDebug)
% Ring Continuity Defect Detection
% Classical defect mask & evidence extraction for the circular-img dataset known as '01'.
% INPUTS:
%   image        - original image
%
%   showDebug    - OPTIONAL parameter. When true displays evidence metrics and 
%                flagged area. showDebug is off by default.
% OUTPUTS:
%   radialMask   -  defect mask stored in variable. use imshow(varName) to
%                   call
%
%   props        - Stored evidence metrics

if nargin < 2, showDebug = false; end

% ---- Preprocess -------------------------------------------
stdSize = [1600 1600]; % Dataset 01 uses 1600x1600
imgRGB = imresize(image, stdSize);
imgGS = im2double(rgb2gray(imgRGB));
Iflat = imflatfield(imgGS, 30); % illumination correction

% ---- Segment the object area -------------
t = graythresh(Iflat);
partMask = imbinarize(Iflat, t);
partMask = imclose(partMask, strel('disk', 5));
partMask = imfill(partMask, 'holes');
partMask = bwareafilt(partMask, 1); % keep the largest blob only

% ---- Fixed circular radius map ----------------------------------------
cx = 800; cy = 800; % Hardcoded center
r = 800.25; 
[X, Y] = meshgrid(1:stdSize(2), 1:stdSize(1)); % Mesh grid to map coords
R = sqrt(((X-cx)/r).^2 + ((Y-cy)/r).^2);  % 0 at center, 1 at edge
% Exclude core
coreExclusionR = 0.38; % Exclude big dark core in the middle
searchMask = partMask & (R > coreExclusionR);

% ---- Tangent Gradients ----------------------------------
Theta = atan2(Y-cy, X-cx); % Calculates pixels angular position
[Ix, Iy] = gradient(Iflat);
% Calculates unit vector pointing in the tangent direction
% (direction line is going)
tangentX = -sin(Theta);
tangentY = cos(Theta);
% Calcs Magnitude of directional change happening along the ring
angularGrad = abs(Ix.*tangentX + Iy.*tangentY);

% ---- Per-radius-bin threshold --------------------
nBins = 200; % Number of subsections analyzed independently
k = 2.2; % Intensity of deviation from mean of absolute deviation (MAD)
% Builds 201 evenly-spaced boundary values
binEdges = linspace(coreExclusionR, max(R(searchMask)) + eps, nBins + 1);
% Groups every pixel's radius value in R and labels it with which of the 40 bands it falls into
binIdx = discretize(R, binEdges);

% First Pass
rawMads = nan(nBins, 1); % Pre-allocate for speed
for b = 1:nBins
    sel = searchMask & (binIdx == b); % Looks at the selected band section
    if nnz(sel) < 30, continue % Skips the very center with few pixels
    end
    vals = angularGrad(sel);
    m = median(vals); % Gets the median of the gradient.
    rawMads(b) = median(abs(vals - m)) * 1.4826 + eps; % Get un-floored MAD,
end
% That whole first loops was to get the average Mean of absolute deviation
typicalMad = median(rawMads, 'omitnan'); 

% Add a floor
madFloorFrac = 1.8;
%Second pass: threshold using each bin's own MAD, floored against that
% typical value.
defectMaskRaw = false(size(partMask));
for b = 1:nBins
    sel = searchMask & (binIdx == b); % Looks at the selected band section
    if nnz(sel) < 30  % Skips the very center with few pixels
        continue
    end
    vals = angularGrad(sel);
    m = median(vals);  % Gets the median of the gradient. 
    madVal = median(abs(vals - m)) * 1.4826 + eps; % Get MAD
    % Compare the MAD to a number bigger than typical (typicalMad * madFloorFrac)
    madVal = max(madVal, madFloorFrac * typicalMad);
    defectMaskRaw(sel) = abs(vals - m) > k * madVal; % Accept only high deviations
end

% ---- Morphological cleanup --------------------------
% Clean small specs
radialMask = imopen(defectMaskRaw, strel('disk', 1));
% Fuse close island together
radialMask = imclose(radialMask, strel('disk', 4));
% Finalize the defect mask by removing small areas 
radialMask = bwareaopen(radialMask, 800);

if showDebug
    fprintf('Flagged %d px (%.2f%% of searchable part area)\n', ...
        nnz(radialMask), 100*nnz(radialMask)/nnz(searchMask));
end

% Compute a small set of interpretable measurements
props = evidenceMetrics(radialMask, partMask, showDebug);

% NOTE: Should work well. From my testing, very few false positives in
% non-defect images. The defect detection is robust and gets the general
% areas well, even on smaller defects. I am happy with this one
end

%% --- Helper: classical evidence metrics ---
function evidence = evidenceMetrics(defectMask, partMask, showDebug)
% Metrics to help better understand the outcome
cc = bwconncomp(defectMask);
stats = regionprops(cc, 'Area');
partArea = max(nnz(partMask), 1);

if isempty(stats)
    evidence.NumRegions = 0;
    evidence.TotalDefectPixels = 0;
    evidence.LargestRegionArea = 0;
    evidence.ConcentrationRatio = 0; % How much the largest region takes up
    evidence.PercentageFlagged = 0;
    evidence.AngularCoverageFraction = 0;
    if showDebug
        disp('--- Ring Evidence Metrics ---');
        disp('Clean image: no regions detected.');
    end
    return
end

areas = [stats.Area];
totalArea = sum(areas);
[largestRegionArea] = max(areas);

evidence.NumRegions = cc.NumObjects;
evidence.TotalDefectPixels = totalArea; % False positive non-defect images have low total area
evidence.LargestRegionArea = largestRegionArea;
evidence.PercentageFlagged = (totalArea / partArea) * 100; % How much of the circle was flagged
evidence.ConcentrationRatio = largestRegionArea / totalArea; % Ratio of defect pixels that land in largest area

% Deriving Angular coverage
ellipseProps = regionprops(partMask, 'Centroid', 'MajorAxisLength', ...
    'MinorAxisLength', 'Orientation');
ellipseProps = ellipseProps(1);
cx = ellipseProps.Centroid(1); cy = ellipseProps.Centroid(2);
rx = ellipseProps.MajorAxisLength/2; ry = ellipseProps.MinorAxisLength/2;
theta0 = deg2rad(ellipseProps.Orientation);
[rows, cols] = find(defectMask);
Xc = cols - cx; Yc = rows - cy;
Xr =  Xc*cos(theta0) + Yc*sin(theta0);
Yr = -Xc*sin(theta0) + Yc*cos(theta0);
angles = atan2(Yr/ry, Xr/rx);   % radians, -pi..pi

nSectors = 72;   % 5-degree resolution
sectorIdx = mod(floor((angles + pi) / (2*pi) * nSectors), nSectors);
% Angular Coverage Fraction: Out of the full 360° sweep around the part, how much of that sweep does the flagged evidence touch
evidence.AngularCoverageFraction = numel(unique(sectorIdx)) / nSectors;

if showDebug
    disp('--- Ring Evidence Metrics ---');
    disp(evidence);
end
end