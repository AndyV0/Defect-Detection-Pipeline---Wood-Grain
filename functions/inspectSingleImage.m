%% inspectSingleImage.m
% Inspects a single part image, combining:
%   1) AI classifier prediction (resnet18 transfer learning) -> label + confidence
%   2) Classical evidence metrics (defect area, edge density, intensity variance)
% into one easily interpretable result.
%
% USAGE:
%   result = inspectSingleImage('part_057.png', 'trainedNet.mat');
%   disp(result)
%
% OUTPUT (struct 'result'):
%   .aiLabel          - "PASS" or "FAIL" from the AI classifier
%   .aiConfidence     - scalar 0-1, probability of the predicted class
%   .evidence         - struct with classical metrics (defectAreaPct, edgeDensity, intensityStd)
%   .evidenceFlag     - "PASS" or "FAIL" from evidence-metric thresholds alone
%   .finalDecision    - combined human-readable verdict (see decision logic below)
%   .summary          - one-line printable string for logs/reports

function result = inspectSingleImage(imagePath, netMatFile)

    if nargin < 2
        netMatFile = fullfile(pwd, 'trainedNet.mat');
    end

    %% 1. Load trained network
    loaded = load(netMatFile, 'netTransfer', 'classNames', 'inputSize');
    net        = loaded.netTransfer;
    classNames = loaded.classNames;
    inputSize  = loaded.inputSize;

    %% 2. Read and prepare image
    img = imread(imagePath);
    if size(img, 3) == 1
        imgRGB = repmat(img, [1 1 3]);   % grayscale -> RGB for resnet18
    else
        imgRGB = img;
    end
    imgResized = imresize(imgRGB, inputSize(1:2));

    %% 3. AI classification (PASS/FAIL + confidence)
    [predLabel, scores] = classify(net, imgResized);
    [aiConfidence, idx]  = max(scores);
    aiLabel = string(classNames{idx});   % should match predLabel, kept explicit

    %% 4. Classical evidence metrics (from your earlier single-image inspection step)
    evidence = computeEvidenceMetrics(img);

    % Simple threshold-based evidence verdict (tune to your part/tolerance)
    defectAreaThresh   = 1.0;   % % of image area flagged as defect
    edgeDensityThresh  = 0.12;  % fraction of pixels that are edges
    intensityStdThresh = 45;    % gray-level std dev (surface texture irregularity)

    evidenceFail = evidence.defectAreaPct > defectAreaThresh || ...
                   evidence.edgeDensity  > edgeDensityThresh || ...
                   evidence.intensityStd > intensityStdThresh;
    evidenceFlag = "FAIL";
    if ~evidenceFail
        evidenceFlag = "PASS";
    end

    %% 5. Combine AI + evidence into one interpretable decision
    % Decision logic:
    %   - AI and evidence agree            -> confident PASS/FAIL
    %   - AI and evidence disagree         -> flagged for manual REVIEW
    %   - AI FAIL but low confidence (<0.6) -> REVIEW regardless of evidence
    lowConfidenceThresh = 0.60;

    if aiLabel == "FAIL" && aiConfidence < lowConfidenceThresh
        finalDecision = "REVIEW (low AI confidence)";
    elseif aiLabel == evidenceFlag
        finalDecision = sprintf("%s (AI + evidence agree, %.1f%% confidence)", ...
            aiLabel, aiConfidence * 100);
    else
        finalDecision = sprintf("REVIEW (AI says %s @ %.1f%%, evidence says %s)", ...
            aiLabel, aiConfidence * 100, evidenceFlag);
    end

    %% 6. Package result
    result.aiLabel       = aiLabel;
    result.aiConfidence  = aiConfidence;
    result.evidence      = evidence;
    result.evidenceFlag  = evidenceFlag;
    result.finalDecision = finalDecision;
    result.summary = sprintf( ...
        "[%s] AI: %s (%.1f%%) | Evidence: %s | DefectArea=%.2f%% EdgeDensity=%.3f IntensityStd=%.1f", ...
        finalDecision, aiLabel, aiConfidence*100, evidenceFlag, ...
        evidence.defectAreaPct, evidence.edgeDensity, evidence.intensityStd);

    disp(result.summary);

end

%% --- Helper: classical evidence metrics ---
function evidence = computeEvidenceMetrics(img)
    % Replace/extend this with the exact evidence metrics from your
    % previous single-image inspection function if they differ.

    if size(img, 3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end
    gray = im2double(gray);

    % Edge density: fraction of pixels detected as edges
    edges = edge(gray, 'Canny');
    edgeDensity = nnz(edges) / numel(edges);

    % Intensity variability: std dev of gray levels (0-255 scale)
    intensityStd = std(double(gray(:))) * 255;

    % Defect area: threshold-based blob detection as % of image area
    bw = imbinarize(gray, 'adaptive', 'Sensitivity', 0.5);
    bw = imcomplement(bw);
    bw = bwareaopen(bw, 20);   % remove tiny noise specks
    defectAreaPct = 100 * nnz(bw) / numel(bw);

    evidence.defectAreaPct = defectAreaPct;
    evidence.edgeDensity   = edgeDensity;
    evidence.intensityStd  = intensityStd;
end