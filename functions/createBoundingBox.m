function createBoundingBox(defectMask, image)
%  Creates individual bounding boxes for each defect in defect mask and overlays it on an image.
%  Inputs: original image & defect mask to be overlayed.

    [labeledMask, numDefects] = bwlabel(defectMask);
    defectFeatures = regionprops(labeledMask, 'BoundingBox', 'Area');
    if numDefects > 0
        figure('Name', 'Bounding Boxes');
        imshow(image); hold on;
        for k = 1:numDefects
            rectangle('Position', defectFeatures(k).BoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);
        end
        title(sprintf('Detected %d Defect(s)', numDefects));
        hold off;
    else
        figure('Name', 'No Defects Detected');
        imshow(image);
        title('No Defects Detected', 'HorizontalAlignment', 'center');
    end
end