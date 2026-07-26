function [pass, scratch, brush] = classicalTesting(image)
%Classical detection function
%   Uses classical methods to count scratches, brushes, and determine
%   if a product is a pass or fail

% Editable Parameters
maxBrushes = 1;
maxScratches = 10;
largestScratch = 500;
defectPercentage = 5;
maxDifferential = 30;
% --------------------------

pass = true;
scratch = struct('NumRegions', 0, 'Areas', [], 'Location', [], 'Orientations', []);
brush = struct('NumRegions', 0, 'Areas', [], 'Location', []);

[scratchMask, scratchProperties]= scratchDetection(image);
[brushMask, brushProperties] = brushDetection(image);

showDefects(image, scratchMask, brushMask);

% Initial Check for Brushes

if brushProperties.NumRegions > maxBrushes
    pass = false;
    brush.NumRegions = brushProperties.NumRegions;
    brush.Areas = brushProperties.Areas;
    brush.Location = brushProperties.Location;
    return
end

% Scratch Analysis

if scratchProperties.NumRegions == 0
    return;
end

angles = scratchProperties.Orientations;  
areas = scratchProperties.Areas;
locations = scratchProperties.Location;  
numScratches = scratchProperties.NumRegions;

angleDifference = -90:5:90;
histCounts = zeros(size(angleDifference));

for i = 1:numScratches
    [~, j] = min(abs(angleDifference - angles(i)));
    histCounts(j) = histCounts(j) + areas(i);
end

[~, peak] = max(histCounts);
grainAngle = angleDifference(peak); 

numRealScratch = 0;
realScratchLocation = [];
realScratchArea = [];

for i = 1:numScratches
    diff = abs(angles(i) - grainAngle);
    diff = min(diff, 180 - diff);

    if diff > maxDifferential
        numRealScratch = numRealScratch + 1;
        realScratchArea = [realScratchArea, areas(i)];
        realScratchLocation = [realScratchLocation; locations(i, :)];
    end
end

scratch.NumRegions = numRealScratch;
scratch.Areas = realScratchArea;
scratch.Location = realScratchLocation;

% Final Checks

if scratch.NumRegions >= maxScratches
    pass = false;
    return;
end

if scratch.NumRegions > 0 && max(scratch.Areas) > largestScratch
    pass = false;
    return;
end

if scratch.NumRegions > 0
    totalAgainstPixels = sum(scratch.Areas);
    imagePixels = numel(scratchMask);
    againstPercent = (totalAgainstPixels / imagePixels) * 100;

    if againstPercent >= defectPercentage
        pass = false;
        return;
    end
end