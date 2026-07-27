function [bleedMask, props] = bleedDetection(I, showDebug)
% Bleed Defect Detection
% Classical defect mask & evidence extraction for the ellipse dataset known as '03'.
% INPUTS:
%   image       - original image
%
%   showDebug   - OPTIONAL parameter. When true displays evidence metrics and 
%                 flagged area. showDebug is off by default.
% OUTPUTS:
%   bleedMask   -  defect mask stored in variable. use imshow(varName) to
%                  call
%
%   props       - Stored evidence metrics
if nargin < 2, showDebug = false; end

% ---- Preprocess ------------------------------
stdSize = [600 800]; % Size of images in 03 dataset
Irgb = imresize(I, stdSize);
Igray = im2double(rgb2gray(Irgb));
Iflat = imflatfield(Igray, 30);   % illumination correction

% ---- Segment background for evidence ------------------------
t = graythresh(Iflat);
partMask = imbinarize(Iflat, t);
partMask = imclose(partMask, strel('disk', 5));
partMask = imfill(partMask, 'holes');
partMask = bwareafilt(partMask, 1);   % keep the largest blob only

% ---- Extract defect evidence -------------------
% Gaussian background subtraction
maskF = double(partMask);
% Estimates the "expected" smooth appearance via a wide blur 
blurredMaskedImg = imgaussfilt(Iflat .* maskF, 25);
blurredWeight = imgaussfilt(maskF, 25);
background = blurredMaskedImg ./ (blurredWeight + eps);
% then looks at what's left over
residual = Iflat - background;
% Only issue is that the waviness of the core & noisy edges are also left

% Creates Elliptical radius map 
cx = 398.90; cy = 299.95;
rx = 769.42/2; ry = 577.16/2;
% Creates meshgrid with coords
[X, Y] = meshgrid(1:stdSize(2), 1:stdSize(1));
R = sqrt(((X-cx)/rx).^2 + ((Y-cy)/ry).^2);   % radius


nBins = 40;
% Builds 41 evenly-spaced boundary values
binEdges = linspace(0, max(R(partMask)) + eps, nBins + 1);
% Groups every pixel's radius value in R and labels it with which of the 40 bands it falls into
binIdx = discretize(R, binEdges);

defectMaskRaw = false(size(partMask)); % Creates empty mask
for b = 1:nBins
    sel = partMask & (binIdx == b); % Looks at the selected band
    if nnz(sel) < 30 % Skips the very center with few pxiels
        continue
    end
    vals = residual(sel);
    m = median(vals); % Gets the median of the residuals 
    madVal = median(abs(vals - m)) * 1.4826 + eps; % Spread of deviation
    defectMaskRaw(sel) = abs(vals - m) > 2.5 * madVal; % Add whatever is deviating a lot
end

% ---- Morphological Cleanup -------------------------------------
defectMask = imopen(defectMaskRaw, strel('disk', 1));
defectMask = imclose(defectMask, strel('disk', 2));
bleedMask = bwareaopen(defectMask, 50);

%NOTE: This dataset is unruly. The center is wavy and sporratic, the edges
% of the ellipse are scratchy and noisy. Overall, these details make it
% VERY difficult to isolate the defect classically. Directional filters get
% tripped up, entropy and frequency focus on the wrong things, and it
% becomes worse when the core itself has defect, since we can't simply
% ignore it. Spending time trying to get an accurate detection is a WASTE
% of time, so just be satisfied with what you have in life.

% ---- Compute a small set of interpretable measurements ---------
props = evidenceMetrics(bleedMask, partMask, showDebug);

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
        disp('--- Bleed Evidence Metrics ---');
        disp('Clean image: no regions detected.');
    end
    return
end

areas = [stats.Area];
totalArea = sum(areas);
[largestRegionArea] = max(areas);

evidence.NumRegions = cc.NumObjects;
evidence.TotalDefectPixels = totalArea;
evidence.LargestRegionArea = largestRegionArea;
evidence.PercentageFlagged = (totalArea / partArea) * 100;
evidence.ConcentrationRatio = largestRegionArea / totalArea; 

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
    disp('--- Bleed Evidence Metrics ---');
    disp(evidence);
end
end
