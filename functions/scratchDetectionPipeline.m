function scratchDefectMask = scratchDetection(image)
%   Scratch Defect Detection
%   Detects the dark scratches on a wood grain texture. Input 'image' can be any test image from BeanTech's 02 data set,
%   and it will output a scratch defect overlay.

    imgGS = im2gray(image);
    % Flatten the lighting gradient to erase the glare band
    imgFlat = imflatfield(imgGS, 150); 
    
    % Bilateral filter to preserve the sharp scratch edges while smoothing the wood
    DoS = 0.10; 
    SpatialSigma = 5; % SpatialSigma controls the pixel neighborhood size
    imgHealed = imbilatfilt(imgFlat, DoS, SpatialSigma);
    % CLAHE to enhance image contrast
    % Raise 'NumTiles' for more detailed defects at the cost of false
    % positives <- delete in final draft
    imgHealed = adapthisteq(imgHealed, 'NumTiles', [8 8], 'ClipLimit',0.01);
    
    % Adaptive threshold to delete most noise
    T = adaptthresh(imgHealed, 0.4, 'ForegroundPolarity', 'dark');
    binaryMask = ~imbinarize(imgHealed, T);
    % Thin line correction for noisy background grain
    thinLineSE = strel('line', 5, 0); 
    binaryMask = imopen(binaryMask, thinLineSE);
    
    % Removing non-defect grain that is present in all passable wooden patterns
    lineLength = 18; % Length of the vertical lines being removed 
    toleranceWidth = 3; % Tolerance width to account for grain curvature
    vertSE = strel('rectangle', [lineLength, toleranceWidth]); 
    backgroundGrain = imopen(binaryMask, vertSE); % Mask of the background grain
    % Subtract the background grain from binaryMask to get a refined Mask
    refinedMask = binaryMask & ~backgroundGrain;
    
    % Isolating Scratch Defects through bwconncomp
    bwMask = refinedMask;
    % Find connected components and categorize them
    cc = bwconncomp(bwMask);
    stats = regionprops(cc, 'MajorAxisLength', 'Area', 'Eccentricity');
    % Component Variables
    lengths = [stats.MajorAxisLength];
    eccentricities = [stats.Eccentricity];
    [imgHeight, imgWidth] = size(image);
    maxLengthThreshold = imgHeight * 0.9;
    % Sifts through the components for valid defects 
    % Defect length cannot span whole screen, cannot have too big of area,
    % not be too line-like
    validDefectIDX = find(lengths < maxLengthThreshold & [stats.Area] > 375 & eccentricities > 0.9);
    % End result is the valid Defects
    scratchDefectMask = ismember(labelmatrix(cc), validDefectIDX);
end


