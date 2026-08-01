%% trainInspectionClassifier.m
% Trains a PASS/FAIL image classifier using transfer learning on resnet18.
%
% EXPECTED FOLDER STRUCTURE (ImageDatastore uses folder names as labels):
%   datasetFolder/
%       PASS/
%           img001.png
%           img002.png
%           ...
%       FAIL/
%           img101.png
%           img102.png
%           ...
%
% OUTPUT:
%   trainedNet.mat  -- contains the trained network 'netTransfer'
%                      and the class names 'classNames'

function trainInspectionClassifier(datasetFolder, outputMatFile)

    if nargin < 1
        datasetFolder = fullfile(pwd, 'dataset');
    end
    if nargin < 2
        outputMatFile = fullfile(pwd, 'trainedNet.mat');
    end

    %% 1. Load pretrained network
    net = resnet18;
    inputSize = net.Layers(1).InputSize;   % typically [224 224 3]

    %% 2. Load data
    imds = imageDatastore(datasetFolder, ...
        'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');

    disp("Class counts: ");
    disp(countEachLabel(imds));

    % Split into training (80%) and validation (20%), stratified per class
    [imdsTrain, imdsValidation] = splitEachLabel(imds, 0.8, 'randomized');

    %% 3. Data augmentation (helps generalize with limited images)
    pixelRange = [-15 15];
    imageAugmenter = imageDataAugmenter( ...
        'RandXReflection', true, ...
        'RandXTranslation', pixelRange, ...
        'RandYTranslation', pixelRange);

    augimdsTrain = augmentedImageDatastore(inputSize(1:2), imdsTrain, ...
        'DataAugmentation', imageAugmenter, ...
        'ColorPreprocessing', 'gray2rgb');   % handles grayscale part images too

    augimdsValidation = augmentedImageDatastore(inputSize(1:2), imdsValidation, ...
        'ColorPreprocessing', 'gray2rgb');

    %% 4. Replace final layers for transfer learning (binary PASS/FAIL)
    classNames = categories(imdsTrain.Labels);
    numClasses = numel(classNames);

    lgraph = layerGraph(net);

    % resnet18's final layers are named 'fc1000', 'prob', 'ClassificationLayer_predictions'
    newFC = fullyConnectedLayer(numClasses, ...
        'Name', 'fc_inspection', ...
        'WeightLearnRateFactor', 10, ...
        'BiasLearnRateFactor', 10);
    lgraph = replaceLayer(lgraph, 'fc1000', newFC);

    newSoftmax = softmaxLayer('Name', 'softmax_inspection');
    lgraph = replaceLayer(lgraph, 'prob', newSoftmax);

    newOutput = classificationLayer('Name', 'output_inspection');
    lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', newOutput);

    %% 5. Training options
    options = trainingOptions('sgdm', ...
        'MiniBatchSize', 16, ...
        'MaxEpochs', 10, ...
        'InitialLearnRate', 1e-4, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', augimdsValidation, ...
        'ValidationFrequency', 5, ...
        'Verbose', true, ...
        'Plots', 'training-progress');

    %% 6. Train
    netTransfer = trainNetwork(augimdsTrain, lgraph, options);

    %% 7. Evaluate on validation set
    [predLabels, predScores] = classify(netTransfer, augimdsValidation);
    accuracy = mean(predLabels == imdsValidation.Labels);
    fprintf('Validation accuracy: %.2f%%\n', accuracy * 100);

    confusionchart(imdsValidation.Labels, predLabels);

    %% 8. Save
    save(outputMatFile, 'netTransfer', 'classNames', 'inputSize');
    fprintf('Trained network saved to %s\n', outputMatFile);

end
