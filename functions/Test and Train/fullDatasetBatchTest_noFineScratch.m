%% fullDatasetBatchTest_noFineScratch.m
function fullDatasetBatchTest_noFineScratch(datasetFilePath)
    % Function for creating a batch test
    % Can be run locally with full dataset. 
    % Requires BTAD Dataset found in readme
    
    clc; close all;
    
    %% ------- USER CONFIGURATION  ---------------------
    datasetRoot    = datasetFilePath;   % <-- UPDATE
    testFolder     = fullfile(datasetRoot, "test");
    netMatFile     = "1785125303951_trainedInspectAI.mat";
    outputResultsFile = "primaryResults_test30_noFineScratches.mat";
    
    % Defect index cutoff: test/ko/ images numbered 0080.png and above are
    % the super-fine scratch defects and get excluded 
    fineScratchCutoff = 80; % Modify to 200 to get the All Defects Metrics
    % Later testing found this cutoff to exclude 12 normal defects
    % This is explored in the main live script's 12 unaccounted defects
    
    %% -------- LOAD EVALUATION SET (TEST-ONLY) ----------
    imdsTest = imageDatastore({char(fullfile(testFolder, "ok")), ...
                               char(fullfile(testFolder, "ko"))}, ...
        "LabelSource", "foldernames");
    
    fprintf("Loaded evaluation set (before filtering): %d images across classes: %s\n", ...
        numel(imdsTest.Files), strjoin(string(categories(imdsTest.Labels)), ", "));
    
    %% ------- FILTER OUT FINE-SCRATCH DEFECTS (test/ko/ only) -------
    numFiles = numel(imdsTest.Files);
    keepMask = true(numFiles, 1);
    
    for i = 1:numFiles
        isFail = ~strcmpi(mapLabelToPassFail(string(imdsTest.Labels(i))), "PASS");
        if ~isFail
            continue;   % only filter ko/ (FAIL) images
        end
    
        [~, name, ~] = fileparts(imdsTest.Files{i});
        digitsStr = regexp(name, '\d+', 'match', 'once');
        if isempty(digitsStr)
            warning("fullDatasetBatchTest_noFineScratch_test30:noIndexFound", ...
                "Could not parse a numeric index from filename '%s'. Keeping it by default.", name);
            continue;
        end
        idx = str2double(digitsStr);
        if idx >= fineScratchCutoff
            keepMask(i) = false;
        end
    end
    
    numExcluded = sum(~keepMask);
    
    imdsTest = subset(imdsTest, find(keepMask));
    
    fprintf("Remaining test set: %d images across classes: %s\n", ...
        numel(imdsTest.Files), strjoin(string(categories(imdsTest.Labels)), ", "));
    disp("Test set class balance after filtering:");
    disp(countEachLabel(imdsTest));
    
    %% ------------ LOAD TRAINED CLASSIFIER -----------------------------
    S = load(netMatFile);
    net           = S.netTransfer;
    netClassNames = S.classNames;
    
    %% ------------ RUN INSPECTION ON TEST SET --------------------------
    numTest = numel(imdsTest.Files);
    predictedLabels    = strings(numTest, 1);
    trueLabels         = strings(numTest, 1);
    confidences        = zeros(numTest, 1);
    disagreementFlags  = false(numTest, 1);
    
    fprintf("Running inspectPart on %d held-out test images (fine scratches excluded)...\n", numTest);
    for i = 1:numTest
        I = readimage(imdsTest, i);
        trueLabels(i) = mapLabelToPassFail(string(imdsTest.Labels(i)));
    
        fprintf('File: %s\n', imdsTest.Files{i});
        result = inspectPart(I, net, netClassNames);
    
        predictedLabels(i)   = string(result.finalLabel);
        confidences(i)        = result.confidenceScore;
        disagreementFlags(i)  = result.disagreementFlag;
    end
    
    trueLabels      = categorical(trueLabels, ["PASS","FAIL"]);
    predictedLabels = categorical(predictedLabels, ["PASS","FAIL"]);
    
    %% ------- CONFUSION MATRIX + SUMMARY STATS ---------------------
    confMat  = confusionmat(trueLabels, predictedLabels);
    accuracy = sum(diag(confMat)) / sum(confMat(:));
    
    numPassPred = sum(predictedLabels == "PASS");
    numFailPred = sum(predictedLabels == "FAIL");
    numPassTrue = sum(trueLabels == "PASS");
    numFailTrue = sum(trueLabels == "FAIL");
    
    yieldActual    = numPassTrue / numTest;
    yieldPredicted = numPassPred / numTest;
    defectRate     = numFailPred / numTest;
    
    falseRejects = sum(trueLabels == "PASS" & predictedLabels == "FAIL");
    falseAccepts = sum(trueLabels == "FAIL" & predictedLabels == "PASS");
    falseRejectRate = falseRejects / max(numPassTrue, 1);
    falseAcceptRate = falseAccepts / max(numFailTrue, 1);
    disagreementRate = sum(disagreementFlags) / numTest;
    
    fprintf("\n--- Full Dataset Batch Test Summary (fine scratches EXCLUDED, test-only PASS n=%d) ---\n", numPassTrue);
    fprintf("Test set size:      %d\n", numTest);
    fprintf("Accuracy:           %.2f%%\n", accuracy * 100);
    fprintf("Actual yield:       %.2f%%\n", yieldActual * 100);
    fprintf("Predicted yield:    %.2f%%\n", yieldPredicted * 100);
    fprintf("Defect rate:        %.2f%%\n", defectRate * 100);
    fprintf("False reject rate:  %.2f%%\n", falseRejectRate * 100);
    fprintf("False accept rate:  %.2f%%\n", falseAcceptRate * 100);
    fprintf("AI/rule disagreement rate: %.2f%%\n", disagreementRate * 100);
    
    figure;
    cm = confusionchart(confMat, ["PASS","FAIL"]);
    cm.Title = "Confusion Matrix -- Fine Scratches Excluded, Test-Only PASS (n=30)";
    cm.RowSummary = "row-normalized";
    cm.ColumnSummary = "column-normalized";
    saveas(gcf, "fullDatasetConfusionMatrix_noFineScratch_test30.png");
    
    %% ------SAVE SMALL RESULTS FILE FOR THE REPO ------------------
    fullResults.confMat           = confMat;
    fullResults.classNames        = ["PASS","FAIL"];
    fullResults.numTest           = numTest;
    fullResults.accuracy          = accuracy;
    fullResults.yieldActual       = yieldActual;
    fullResults.yieldPredicted    = yieldPredicted;
    fullResults.defectRate        = defectRate;
    fullResults.falseRejectRate   = falseRejectRate;
    fullResults.falseAcceptRate   = falseAcceptRate;
    fullResults.disagreementRate  = disagreementRate;
    fullResults.fineScratchCutoff = fineScratchCutoff;
    fullResults.numExcluded       = numExcluded;
    fullResults.passSource        = "test/ok only (n=30)";
    fullResults.dateGenerated     = datetime("now");
    
    save(outputResultsFile, "fullResults");
    fprintf("\nSaved results file: %s\n", outputResultsFile);
end

%% ------- LOCAL FUNCTION: MAP GROUND-TRUTH LABEL TO PASS/FAIL --
function label = mapLabelToPassFail(labelStr)
    okNames = ["ok", "pass", "good"];
    if any(strcmpi(labelStr, okNames))
        label = "PASS";
    else
        label = "FAIL";
    end
end