function [brushMask, props] = brushDetection(image, showDebug)
%  Brush Defect Detection
% Classical defect mask & evidence extraction for the wood-grain-img dataset known as '02'.
% INPUTS:
%   image      - original image
%
%   showDebug  - OPTIONAL parameter. When 'true' displays evidence metrics  
%                showDebug is off by default. 
% OUTPUTS:
%   brushMask  - defect mask stored in variable. use imshow(varName) to
%                call
%
%   props      - Stored evidence metrics. disp(varName)
% Combine with brushDetection for best results
    if nargin < 2, showDebug = false; end % showDebug is off by default
    % Pre processing
    imgGS = im2double(im2gray(image));
    imgFlat = imflatfield(imgGS, 60);

    
    % FFT Notch Filter 
    F = fftshift(fft2(imgFlat));
    [M, N] = size(imgFlat);
    % This creates a 2D coordinate system (U, V) centered at (0,0)
    [U, V] = meshgrid(-floor(N/2):ceil(N/2)-1, -floor(M/2):ceil(M/2)-1);
    D = sqrt(U.^2 + V.^2);
    
    % Blocks purely vertical spatial lines w/directional bandpass filter
    filterMask = double(abs(V) > 4 & D >= 2 & D <= 40);
    % <40: Removes High frequency. >2: Removes Low frequncy, 
    % abs(V) > vertLineExclusion (4) erase vert
    filterFrequencyMask = F .* filterMask;
    % Reconstructed Image w less vertical grain
    nonVertFeature = abs(ifft2(ifftshift(filterFrequencyMask)));
    
    % Raw Threshold
    rawFftMask = nonVertFeature > 0.035;

    % Clean Mask
    % Remove noise speckles before next step
    FFTMask = bwareaopen(rawFftMask, 200); 

  
    % ROI-Constrained Local Entropy 
    % Sets anchors as fft mask's blobs
    % Allowing smaller particles to remain but not grow 
    % While allowing true brush defects to shine
    ccAnchor = bwconncomp(FFTMask);
    statsAnchor = regionprops(ccAnchor, 'Area');
    keepIdx = false(ccAnchor.NumObjects, 1);
    minAnchorArea = 300; % anchor min
    for i = 1:ccAnchor.NumObjects
        keepIdx(i) = statsAnchor(i).Area >= minAnchorArea;
    end 
    FFTMask = ismember(labelmatrix(ccAnchor), find(keepIdx));

    % Defect has a specific amount of entropy. Not too much but not too
    % little
    nhood = getnhood(strel('disk', 9)); 
    entropyMap = entropyfilt(imgFlat, nhood);
    invertedEntropy = max(entropyMap(:)) - entropyMap;
    
    % Instead of a fixed src, madde it dynamic 
    anchorArea = nnz(FFTMask);
    netRadius = min(40, max(10, round(sqrt(anchorArea) * 0.8))); % scales with anchor size
    searchNet = imdilate(FFTMask, strel('disk', netRadius));

    % If Search Net is flagging everything (happens on diagonal grain)
    isMoreThanHalf = nnz(searchNet) > (numel(searchNet) / 2);
    if isMoreThanHalf
        % Then remove this feature by setting it to a black screen
        searchNet = false(600, 600);
    end 
    % Since the net protects us, we can safely grab weaker defect signals.
    rawEntropyBand = (invertedEntropy > 1.2) & (invertedEntropy < 5.0);
    % Extract entropy in areas close to defect frequencies
    localizedEntropy = rawEntropyBand & searchNet;


    % FUSION & MORPHOLOGICAL CLEANUP
    % Union both filters (FFT being the main one)
    combinedMask = FFTMask | localizedEntropy;
    
    % Snap the perimeter closed 
    closedEdges = imclose(combinedMask, strel('disk', 12));
    % Fill the interior
    filledMask = imfill(closedEdges, 'holes');
    % Final execution of floating noise clusters
    brushMask = bwareaopen(filledMask, 1000);

    % Calculate properties of the detected brush regions
    props = brushEvidence(brushMask, imgFlat, showDebug);

    % NOTE: This detector only has one main 'issue.' For some reason, cross grain is
    % present ONLY in defect images, leading this brush mask to mark cross grain. 
    % According to the ground truth masks provided, these cross
    % grains (only present in defect images) are not actually defects. 
    % Despite this, our team has decided to keep the brush mask as is.

%{
        -----------------------------------------------------------
        VISUALIZATION SUITE
        ONLY FOR DISPLAYING INDIVUDAL STEPS

        figure('Name', 'Streamlined Defect Fusion', 'NumberTitle', 'off', 'Position', [100, 100, 1800, 900]);
        colormap('jet'); 
        subplot(2, 3, 1);
        imshow(imgFlat, []);
        title('1. Preprocessed Flatfield');
        
        subplot(2, 3, 2);
        imshow(FFTMask);
        title('2. Clean Anchor (FFT Edges)');
        
        subplot(2, 3, 3);
        imagesc(invertedEntropy); colorbar; hold on;
        hold off;
        title('3. Entropy Map + Search Net ROI');
        
        subplot(2, 3, 4);
        imshow(localizedEntropy);
        title('4. Extracted Entropy Fill');
        
        subplot(2, 3, 5);
        imshow(combinedMask);
        title('5. Fused Mask (Pre-Cleanup)');
        
        subplot(2, 3, 6);
        imshow(brushMask);
        title('6. Final Clean Output');
    end
%}
end


%% --- Helper: classical evidence metrics ---
function evidence = brushEvidence(defectMask, imgGS, showDebug)
    % Extract area statistics for all distinct blobs
    stats = regionprops(defectMask, 'Area', 'Solidity');
    
    % The number of distinct regions
    numRegions = length(stats);
    
    % Handle clean images
    if isempty(stats)
        evidence.NumRegions = 0;
        evidence.TotalDefectPixels = 0;
        evidence.LargestRegionArea = 0;
        evidence.PercentFlagged = 0;
        evidence.AvgSolidity = NaN;
        evidence.TextureDeficit = NaN;
        evidence.IntensityContrast = NaN;
    
        if showDebug
            disp('--- Brush Evidence Metrics ---');
            disp('Clean Image: No regions detected.');
        end
        return;
    end
    
    % Area Metrics
    areas = [stats.Area];
    totalArea = sum(areas);
    largestRegion = max(areas);
    avgSolidity = mean([stats.Solidity]); % when high: likely brush
    
    % Percent of the image flagged
    percentFlagged = (totalArea / numel(defectMask)) * 100;
    
    % Texture extractions
    bgMask = ~defectMask;
    defectStdIntensity = std2(imgGS(defectMask));
    bgStdIntensity = std2(imgGS(bgMask));
    textureDeficit = bgStdIntensity - defectStdIntensity;
    
    % Light/Intensity extraction
    defectMeanIntensity = mean2(imgGS(defectMask));
    bgMeanIntensity   = mean2(imgGS(bgMask));
    intensityContrast = defectMeanIntensity - bgMeanIntensity;
    
    % Evidences
    evidence.NumRegions = numRegions;
    evidence.TotalDefectPixels = totalArea;
    evidence.LargestRegionArea = largestRegion;
    evidence.PercentageFlagged    = percentFlagged;
    % Specific to brush defects
    evidence.AvgSolidity       = avgSolidity; % Blob-ness of defect
    evidence.TextureDeficit    = textureDeficit; % Avg texture intensity
    evidence.IntensityContrast = intensityContrast; % Avg light intensity
    % Defects tend to be lighter, lack full grain texture, and are blobby
    
    if showDebug
        % Print the evidence directly to workspace window
        disp('--- Brush Evidence Metrics ---');
        disp(evidence);
    end
end

