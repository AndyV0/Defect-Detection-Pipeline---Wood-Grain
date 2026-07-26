function imageOutput = showDefects(image, scratchMask, brushMask)
% Visual Display of Defects
% 
imageOutput = figure('Name','Defects');

% Scratches
subplot(1,2,1);
imshow(image);
hold on;

stats = regionprops(scratchMask, "BoundingBox");
arrayfun(@(s) rectangle('Position', s.BoundingBox, 'EdgeColor','r','LineWidth',2), stats);

% Brushes
subplot(1,2,2);
imshow(image); hold on;
stats = regionprops(brushMask, 'BoundingBox');
arrayfun(@(s) rectangle('Position', s.BoundingBox, 'EdgeColor','b','LineWidth',2), stats);

end