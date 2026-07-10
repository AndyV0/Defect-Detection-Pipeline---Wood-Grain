function scratchDefectMask = scratchDetection(image)
%   Scratch Defect Detection
%   Detects the dark scratches on a wood grain texture. Input 'image' can be any test image from BeanTech's 02 data set,
%   and it will output a scratch defect overlay.
    imgGS = im2gray(image);
    imgFlat = imflatfield(imgGS, 60);
    % Fibermetric to enhance the lines
    imgFiber = fibermetric(imgFlat, [2 3 4], 'ObjectPolarity', 'dark');
    
    % Single generous threshold
    thresh = max(prctile(imgFiber(:), 99.5) *0.2, 0.1);
    evidenceMask = imgFiber > thresh;
 
    % Remove tiny bits of noise
    scratchDefectMask = bwareaopen(evidenceMask, 5);
end


