function scratchDefectMask = scratchDetection(image)
%   Scratch Defect Detection
%   Detects the dark scratches on a wood grain texture. Input 'image' can be any test image from BeanTech's 02 data set,
%   and it will output a scratch defect overlay.
    imgGS = im2gray(image);
    imgFlat = imflatfield(imgGS, 60);
    
    % Fibermetric to enhance the lines
    imgFiber = fibermetric(imgFlat, [2 3 4], 'ObjectPolarity', 'dark');
    
    % Single generous threshold
    thresh = max(prctile(imgFiber(:), 99.5) * 0.2, 0.1);
    evidenceMask = imgFiber > thresh;
 
    % Remove tiny bits of noise
    scratchDefectMask = bwareaopen(evidenceMask, 20);
    
    % Compute and display metrics directly
    scratchEvidence(scratchDefectMask);
end

%% --- Helper: classical evidence metrics ---
function scratchEvidence(defectMask)
    % Extract the centroid and angle of every individual line segment
    stats = regionprops(defectMask, 'Centroid', 'Orientation', 'Area');
    
    if isempty(stats)
        disp('Clean Image: No regions detected.');
        return;
    end
    
    % Orientation Consistency (Standard Deviation of Angles)
    % A low number means the lines are all perfectly parallel (likely a scuff).
    % A high number means chaotic, random noise.
    angles = [stats.Orientation];
    angularVariance = std(angles);
    
    % Spatial Clustering
    % Extract X and Y coordinates of the centroids
    centroids = cat(1, stats.Centroid);
    xCoords = centroids(:, 1);
    yCoords = centroids(:, 2);

    % Calculate how spread out the regions are. 
    % Small spread = tightly clustered defect. Large spread = random static.
    spatialSpread = std(xCoords) + std(yCoords);

    % Total Defect Area
    totalArea = sum([stats.Area]);

    % Calculate fraction of the image flagged (total true pixels / total pixels)
    percentFlagged = nnz(defectMask)*100 / numel(defectMask);

    % Bundle into a struct for clean command window output
    evidence.PercentageFlagged = percentFlagged;
    
    % Bundle and Display
    evidence.TotalDefectPixels = totalArea;
    evidence.PercentageFlagged = percentFlagged;
    evidence.AngularVariance = angularVariance;
    evidence.SpatialSpread = spatialSpread;
    
    % Print the evidence directly to the workspace/command window
    disp('--- Scratch Evidence Metrics ---');
    disp(evidence);
end