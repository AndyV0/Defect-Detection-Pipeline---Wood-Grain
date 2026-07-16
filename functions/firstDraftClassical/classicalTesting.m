function [pass, scratch, brush] = classicalTesting(image)
%Classical detection function
%   Uses classical detection to count scratches, brushes, and determine
%   if product is a pass or fail

pass = "Pass";

[scratchMask, scratchProperties]= scratchDetection(image);
[brushMask, brushProperties] = brushDetection(image);
showDefects(image, scratchMask, brushMask);

% initial checks
if scratchProperties.PercentageFlagged >= 5
    pass = 'Fail';
    scratch = {};
    brush = {};
    return;
end

if brushProperties.NumRegions > 0
    pass = 'Fail';
    scratch = {};
    brush = brushProperties.NumRegions;
    return
end

% Scratch Search

scratches = bwconncomp(scratchMask, 4);
numScratches = scratches.NumObjects;

if numScratches > 0
    scratch = regionprops(scratches, 'Area', 'Centroid');
    brush = {};
else
    scratch = struct('Area', {}, 'Centroid', {});
    brush = {};
end

if numScratches > 50
    pass = "Fail";
end