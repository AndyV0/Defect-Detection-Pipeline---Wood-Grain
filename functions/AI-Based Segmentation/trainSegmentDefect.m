function net = trainSegmentDefect(defectImageDir, defectMaskDir, cleanImageDir, datasetNum)
    %% trainSegmentDefect.m
    % Trains a semantic segmentation network to produce maskAI = segmentDefect(I),
    % for comparison against the classical evidence mask & 
    % (optional extension deliverable).
    %
    % INPUTS:
    %   defectImageDir - folder of defect images
    %   defectMaskDir  - folder of matching binary masks. same sort order
    %   as defectImageDir (should be by default)
    %   cleanImageDir  - folder of defect-free images 
    %   datasetNum    - short string identifying the dataset, e.g. '01',
    %                    '02', '03', Used both to name output
    %                    files (so different datasets never overwrite each
    %                    other's saved models/generated masks) & to select
    %                    the right augmentation settings via getAugParams
    % 
    % AFTER RUNNING 
    %   train/cleanMasks_generataed - Should be generated in the train
    %   folder
    %
    % MAKE SURE TO COPY THE FILE WHERE IMAGES ARE STORED (ko & ok) not their parents
    %% ---- Configurations ---------------------------------------------
        % Btad/ datasetNum is used as a param to the func
    augParams = getAugParams(datasetNum); % Sets augmentations based on dataset
    inputSize = getInputSize(datasetNum);  % network input size (resized down from images)
    classNames = ["background", "defect"]; % Class names to create weights
    pixelIDs   = [0 255]; % raw mask pixel values for each class
    
    %% ---- Build datastores for the labeled defect images -------------
    imdsDefect = imageDatastore(defectImageDir);
    pxdsDefect = pixelLabelDatastore(defectMaskDir, classNames, pixelIDs);
     
    % Quick double check to ensure every defect img has a gt mask
    assert(numel(imdsDefect.Files) == numel(pxdsDefect.Files), ...
        'Mismatch between defect image count and mask count -- check folders.');
     
    %% ---- Build ground truths for all non-defect training images -----
    imdsClean = imageDatastore(cleanImageDir);
     
    % The network needs a ground-truth mask for every training image, defect or not
    % Since the clean images  have zero defect pixels, the mask for each clean image is all-zero
    cleanMaskDir = fullfile(fileparts(cleanImageDir), sprintf('cleanMasks_generated_%s', datasetNum));
    if ~exist(cleanMaskDir, 'dir')
        mkdir(cleanMaskDir);
        % Line to check if its working
        fprintf('Generating all-background masks for %d clean images...\n', numel(imdsClean.Files));
        for i = 1:numel(imdsClean.Files)
            I = imread(imdsClean.Files{i});
            [~, name] = fileparts(imdsClean.Files{i});
            % uint8 so that empty masks can be in pixel values: [0]
            allBackground = zeros(size(I,1), size(I,2), 'uint8');  % all pixels = background class
            imwrite(allBackground, fullfile(cleanMaskDir, [name '.png'])); % Writes gt masks for non-defect
        end
    end
    % Wraps generated masks s pixel Label datastore 
    % so later steps can treat defect and clean image/mask pairs uniformly.
    pxdsClean = pixelLabelDatastore(cleanMaskDir, classNames, pixelIDs);
     
    %% ---- Stratified Train/Val /Test split ------------------------------
    % Stratified split  splits each category (defect images, clean images) separately first, 
    % and then combines the pieces s.t ratio of each category are preserved in every split
    rng(42);  % arbitrary; any fixed integer with a reproducible starting state
     
    nDefect = numel(imdsDefect.Files);
    defectPerm = randperm(nDefect); % shuffled index list of defects
    nTrainD = round(0.7*nDefect); % Number of defect images in training 
    nValD = round(0.15*nDefect); % Number images in validation 
    trainIdxD = defectPerm(1:nTrainD); % Gets id's of the shuffeled data
    valIdxD   = defectPerm(nTrainD+1:nTrainD+nValD); % Id's of different shuffle area
    testIdxD  = defectPerm(nTrainD+nValD+1:end); % ID of what left of shuffle train data
     
    % Do the same thing with the clean data
    nClean = numel(imdsClean.Files);
    cleanPerm = randperm(nClean);
    nTrainC = round(0.7*nClean); 
    nValC = round(0.15*nClean);
    trainIdxC = cleanPerm(1:nTrainC);
    valIdxC   = cleanPerm(nTrainC+1:nTrainC+nValC);
    testIdxC  = cleanPerm(nTrainC+nValC+1:end);
     
    %% ---- Oversampling -----------------------------
    targetDefectFraction = 0.45; % What percent of data is defects 
REPEAT_FACTOR = max(1, round( ...
    targetDefectFraction * nTrainC / (nTrainD * (1 - targetDefectFraction)) )); %  Times to duplicate each training-split defect image/mask pair.
    % Explicitely for low counts of defect (like in 03)
    % Duplicate Defect Pairs
    defectFilesRepeated = repmat(imdsDefect.Files(trainIdxD), REPEAT_FACTOR, 1);
    defectMasksRepeated = repmat(pxdsDefect.Files(trainIdxD), REPEAT_FACTOR, 1);
     
    % Builds the actual training image datastore
    imdsTrain = imageDatastore([defectFilesRepeated; imdsClean.Files(trainIdxC)]); % Semi-colon stackes both into one long column
    pxdsTrain = pixelLabelDatastore([defectMasksRepeated; pxdsClean.Files(trainIdxC)], classNames, pixelIDs);
     
    % Build validation image datastore
    imdsVal = imageDatastore([imdsDefect.Files(valIdxD); imdsClean.Files(valIdxC)]);
    pxdsVal = pixelLabelDatastore([pxdsDefect.Files(valIdxD); pxdsClean.Files(valIdxC)], classNames, pixelIDs);
     
    % Builds testing image datastore
    imdsTest = imageDatastore([imdsDefect.Files(testIdxD); imdsClean.Files(testIdxC)]);
    pxdsTest = pixelLabelDatastore([pxdsDefect.Files(testIdxD); pxdsClean.Files(testIdxC)], classNames, pixelIDs);
     
    % Print Checkpoint
    fprintf('Train: %d defect (%d unique x%d repeats) + %d clean = %d total\n', ...
        numel(defectFilesRepeated), numel(trainIdxD), REPEAT_FACTOR, numel(trainIdxC), numel(imdsTrain.Files));
    fprintf('Val:   %d defect + %d clean = %d total\n', numel(valIdxD), numel(valIdxC), numel(imdsVal.Files));
    fprintf('Test:  %d defect + %d clean = %d total\n', numel(testIdxD), numel(testIdxC), numel(imdsTest.Files));
     
    %% ---- Class-weighted loss --------------------
    % Mitigates the fact that defect pixels are rare by weighting them
    % Defects are now fat
    tble = countEachLabel(pxdsTrain); % Reads through every mask in pxdsTrain
    totalPixels = sum(tble.PixelCount);
    frequency = tble.PixelCount / totalPixels; % Converts raw counts into proportions
    classWeights = 1 ./ sqrt(frequency); % Inv Sqrt is substantially better than just inv
    classWeights = classWeights / sum(classWeights);  % normalize
    % Print Checkpoint
    fprintf('Class weights: background=%.4f, defect=%.4f\n', classWeights(1), classWeights(2));
     
    %% ---- Data augmentation ------------------------------------------------
    % Creates a new, small function on the spot that takes data
    resizeElem = @(data) resizeImageAndLabel(data, inputSize(1:2));
    augmentFcn = @(data) augmentImageAndLabel(data, augParams);
     
    dsTrain = combine(imdsTrain, pxdsTrain); % Combines image and pixel data into one elem
    dsTrain = transform(dsTrain, resizeElem); % Resizes elements (both img and mask)
    dsTrain = transform(dsTrain, augmentFcn); % Creates new images to prevent overfitting 
     
    dsVal = combine(imdsVal, pxdsVal);
    dsVal = transform(dsVal, resizeElem); % validation doesn't need augmentation
     
    %% ---- Build the network ----------------------------------------------
    % My favorite step
    net = deeplabv3plus(inputSize, numel(classNames), "resnet18");
    % Print Checkpoint
    fprintf('Using DeepLabv3+ with pretrained resnet18 encoder.\n');
     
    %% ---- Weighted loss function ---------
    % Actualizes class weights into the training network
    lossFcn = @(Y, T) crossentropy(Y, T, classWeights, WeightsFormat="C");
     
    %% ---- Training options ---------------------------------------------------
    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-4, ...
        'MaxEpochs', 60, ...
        'MiniBatchSize', 8, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', dsVal, ...
        'ValidationFrequency', 20, ...
        'ValidationPatience', 8, ...     % early stopping -- important with this little data
        'L2Regularization', 1e-4, ...    % extra regularization, same reason
        'ExecutionEnvironment', 'gpu', ... % uses GPU if available, falls back to CPU
        'Plots', 'training-progress', ...
        'Verbose', true);
    
    %% ---- Train ---------------------------------------------------------------
    % The actual training function
    % Everything build was for this step
    net = trainnet(dsTrain, net, lossFcn, options);

    % Writes the specified trained machine to a .mat file on disk, 
    % so the trained model isn't lost when the MATLAB session ends
    outFile = sprintf('segmentDefectNet_%s.mat', datasetNum);
    save(outFile, 'net', 'classNames', 'inputSize', 'imdsTest', 'pxdsTest');
    % Print Checkpoint
    fprintf('Saved trained model to %s\n', outFile);
     
    %% ---- 10. Evaluation----------------
    % labels are kept apart so evaluateSemanticSegmentation can compare
    % predictions and truth at the same resolution 
    imdsTestResized = transform(imdsTest, @(I) imresize(I, inputSize(1:2)));
    pxdsTestResized = transform(pxdsTest, @(C) {imresize(C{1}, inputSize(1:2))});
     
    % Creates pixel-label datastore of the network's guesses
    predictions = semanticseg(imdsTestResized, net, 'Classes', classNames, 'MiniBatchSize', 8, ...
        'WriteLocation', tempdir);
    % Evaluates the metrics against the real answers
    metrics = evaluateSemanticSegmentation(predictions, pxdsTestResized);
     
    fprintf('\n--- Test set segmentation metrics ---\n');
    disp(metrics.DataSetMetrics);
    disp(metrics.ClassMetrics);
end
 
 
%% =============HELPER FUNCTIONS============================
function augParams = getAugParams(datasetNum)
    %GETAUGPARAMS Maps a dataset nunber to the right augmentation settings.
    % The wood grain images in 02 are the only reason this exists
    switch lower(datasetNum)
        case {'01', '03'}
            % BTAD oval/circular parts on a plain black background.
            % 01 and 03 share this: both are ring/oval structures on black,
            % just with 03 being more elliptical and 01 more strictly
            % circular -- that geometry difference didn't warrant different
            % augmentation ranges, just different underlying image content.
            augParams = struct( ...
                'Rotation', [-15 15], ...
                'XReflection', true, ...
                'YReflection', true, ...
                'Translation', [-10 10], ...
                'Scale', [0.9 1.1], ...
                'BorderFill', 'black');
    
        case '02'
            augParams = struct( ...
            'Rotation', [-5 5], ... % Less rotation
            'XReflection', true, ...
            'YReflection', false, ...  % no reflection along y
            'Translation', [-5 5], ...
            'Scale', [0.95 1.05], ...
            'BorderFill', 'mirror'); % pad the image with symmetric content

        otherwise
                warning('No augmentation settings defined for datasetNum "%s".', datasetNum);
                % Set to default 
                augParams = struct( ...
                    'Rotation', [-15 15], ...
                    'XReflection', true, ...
                    'YReflection', true, ...
                    'Translation', [-10 10], ...
                    'Scale', [0.9 1.1], ...
                    'BorderFill', 'black');
        end
end

%% ----------------------------------------------------------------------
function inputSize = getInputSize(datasetNum)
% GETINPUTSIZE Maps a datasetNum to the network's input resolution.
% BTAD (01/03) defects are large, blob-like -- 256x256 loses nothing.
% BTAD (02) has thin, small defects that were getting squashed below detection by 
% internal downsampling. This function is the fix
switch lower(datasetNum)
    case '02'
        inputSize = [512 512 3];   % Wood grain is a pain
    otherwise
        inputSize = [256 256 3];   % BTAD default (01, 03, and anything
        % else not explicitly listed)
end
end

%% ----------------------------------------------------------------------
function dataOut = resizeImageAndLabel(data, targetSize)
    % RESIZEIMAGANDLABEL Resizes an {image, label} pair
    dataOut = data;
    for i = 1:size(data,1)
        dataOut{i,1} = imresize(data{i,1}, targetSize);
        dataOut{i,2} = imresize(data{i,2}, targetSize);
    end
end
 
%% ----------------------------------------------------------------------
function dataOut = augmentImageAndLabel(data, augParams)
dataOut = data;
for i = 1:size(data,1)
    img = data{i,1};
    lbl = data{i,2};
 
    % Written to create new, randomized defect images
    % Ranges come from augParams now instead of instead of hardcoded
    tform = randomAffine2d( ...
        Rotation=augParams.Rotation, ...
        XReflection=augParams.XReflection, ...
        YReflection=augParams.YReflection, ...
        XTranslation=augParams.Translation, ...
        YTranslation=augParams.Translation, ...
        Scale=augParams.Scale);
 
    if strcmpi(augParams.BorderFill, 'black')
        % Fill exposed border with black 
        rout = affineOutputView(size(img), tform, BoundsStyle='centerOutput');
        imgWarp = imwarp(img, tform, OutputView=rout, FillValues=0);
        lblWarp = imwarp(lbl, tform, OutputView=rout);
    else
        % Mirror-pad first so there's no border to fill at all -- for
        % edge-to-edge textures with no plain background (wood grain)
        % I couldn't figure this out, but Claude did
        % Turns out, augmenting an image with no bg makes most transforms
        % create a lot of new empty space at the edges. So that has to be
        % circumvented 
        padAmt = round(0.15 * size(img,1));
        imgPad = padarray(img, [padAmt padAmt], 'symmetric', 'both');
        lblPad = padarray(lbl, [padAmt padAmt], 'symmetric', 'both');

        % Apply the transform
        rout = affineOutputView(size(imgPad), tform, BoundsStyle='centerOutput');
        imgWarpPad = imwarp(imgPad, tform, OutputView=rout);
        lblWarpPad = imwarp(lblPad, tform, OutputView=rout);
 
        % Crop back down to original size, centered
        [h, w, ~] = size(imgWarpPad);
        r0 = round((h - size(img,1))/2) + 1;
        c0 = round((w - size(img,2))/2) + 1;
        imgWarp = imgWarpPad(r0:r0+size(img,1)-1, c0:c0+size(img,2)-1, :);
        lblWarp = lblWarpPad(r0:r0+size(lbl,1)-1, c0:c0+size(lbl,2)-1, :);
    end
 
    dataOut{i,1} = imgWarp;
    % Fixed "value of 'FillValues' is invalid" error
    % by finding whatever MATLAB says the valid categories actually are
    cats = categories(lblWarp);
    bgCat = cats{strcmpi(cats, 'background')};
    lblWarp(isundefined(lblWarp)) = bgCat;
    dataOut{i,2} = lblWarp;
end
end
%% ========================================================================
% NOTE: For 02, the model appears to under-flag defect regions overlapping cross-grain texture
% likely due to inconsistent ground-truth labeling of cross-grain in the training data
% The model also struggles specifically with thin pixel length lines, which  
% in the local neighborhood around most points along look like almost nothing but a short horizontal segment
% These two issues are what led to a drop in performance, but ultimately
% satisfactory result for most defects in 02

% OTHER NOTE : 02 Wood grain's IoU (0.603) is actually the best of the
% three, with decent recall (0.911)
% 03 has the best recall (0.979) but the worst IoU (0.359), likely the
% tradeoff from the class-weighting, where softening the weights traded
% some precision for recall. All of which stems from the small defect
% sample
% 01 sits in between on most metrics — benefiting from having the most consistent circular geometry. 
% Nearly as good recall (0.970) as 03 with an almost as good as 02 IoU of 01: 0.577

% LAST NOTE: Each dataset created a new problem with a different fix needed: 
% 01 needed nothing beyond the defaults (already had good data), 
% 02 needed both different augmentation (mirror-fill, tighter rotation) and higher resolution (small-defect vanishing)
% 03 needed softer class weights (over-prediction), 
