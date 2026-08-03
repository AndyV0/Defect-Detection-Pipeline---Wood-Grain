function result = inspectPart(image, net, classNames, showDebug)
% Hybrid inspection combining classical evidence + AI classification. For
% the 02 dataset
%
% INPUTS:
%   image      - original RGB (or grayscale) part image
%   net        - trained classifier (loaded from trainedInspectAI.mat)
%   classNames - cell array of class labels in net's output order,
%                e.g. {'ok'; 'ko'}  (load from trainedInspectAI.mat)
%   showDebug  - OPTIONAL. When true, plots intermediate results. Default false.
%
% REQUIRED FILES: scratchDetection.m, brushDetection.m, 1785125303951_trainedInspectAI.mat
%
% TO RUN THIS CODE
%   S = load('1785125303951_trainedInspectAI.mat'); (found in GitHub Releases)
%   net        = S.netTransfer;
%   classNames = S.classNames;
%   result = inspectPart(imageVariable, net, classNames);
%
% OUTPUT: result struct with fields
%   .finalLabel            - 'PASS' or 'FAIL' (FINAL DECISION)
%   .aiRawLabel            - 'PASS' or 'FAIL' -- the AI classifier's own
%                            decision, before any override is applied.
%   .confidenceScore        - AI's confidence in finalLabel (0-1)
%   .evidenceOverlay       - combined binary mask (scratch | brush) for visualization
%   .evidenceMetrics       - struct of classical evidence metrics (prefixed by detector)
%   .baselineDecision      - 'PASS' or 'FAIL' from conservative rule-based check
%   .disagreementFlag      - true if AI and rule-based baseline disagree
%   .overrideApplied       - true if confidenceScore was below
%                            75%, so finalLabel was taken
%                            from baselineDecision instead of the AI
%   .crossDetectorAgreement - true if scratch AND brush both independently
%                             flagged the same image.
%

    if nargin < 4, showDebug = false; end

    % ---- Classical Evidence Extraction -----------------------
    [scratchMask, scratchProps] = scratchDetection(image); % Debug remove here since it prints twice if so 
    [brushMask,   brushProps]   = brushDetection(image);

    % Combined evidence overlay and metrics
    evidenceOverlay = scratchMask | brushMask;
    evidenceMetrics = mergeEvidence(scratchProps, brushProps, evidenceOverlay);

    % ---- AI classification ---------------------------------
    imgForNet = prepareForNet(image);
    [aiLabelCat, scores] = classify(net, imgForNet);

    aiLabelStr       = string(aiLabelCat);
    confidenceScore  = max(scores);
    aiRawLabel       = mapToPassFail(aiLabelStr, classNames);

    % ---- Rule-based classical evidence decisions -------------
    [baselineDecision, scratchFail, brushFail] = decideRules(evidenceMetrics); 
    % Check helper func for more details on the decision making

    % ---- Flags: AI/classical evidence disagreement -------------
    disagreementFlag       = ~strcmp(aiRawLabel, baselineDecision);
    crossDetectorAgreement = scratchFail && brushFail;

    % ---- Confidence-gated override ----------------------------
    % If the AI isn't confident enough in its own call, defer to the
    % classical rule-based baseline instead of trusting a low-confidence
    % AI decision.
    overrideApplied = confidenceScore < 0.75; % Threshold of confidence
    if overrideApplied
        finalLabel = baselineDecision;
    else
        finalLabel = aiRawLabel; % AI is default unless its not confident
    end

    % ============================================================
    % Package result
    % ============================================================
    result.finalLabel             = finalLabel;
    result.aiRawLabel             = aiRawLabel; 
    result.confidenceScore        = confidenceScore;
    result.evidenceOverlay        = evidenceOverlay;
    result.evidenceMetrics        = evidenceMetrics;
    result.baselineDecision       = baselineDecision;
    result.disagreementFlag       = disagreementFlag;
    result.overrideApplied        = overrideApplied; % Added override after seeing classical outperforming ai classifier on simple defects
    result.crossDetectorAgreement = crossDetectorAgreement;

    if showDebug
        % THIS SECTION ADDS CLUTTER TO THE LIVE SCRIPT
        % IF TYOU WANT TO USE THIS TO DEBUG, just remove the comment '%'s
        % Display the final verdict of both
        %%if overrideApplied
            %fprintf('*** OVERRIDE: AI confidence %.2f < 0.75 -- using rule-based decision ***\n', ...
                %confidenceScore);
        %end
        %fprintf('Final Decision:    %s\n', finalLabel);
     
        % Mark if they disagree
        %if disagreementFlag
            %fprintf('*** DISAGREEMENT: AI raw decision and rule-based baseline do not match ***\n');
        %end
        % Mark if classical detections disagree (typically means an img is either only brush defects or contains only cross grain)
        %if brushFail && ~scratchFail
            %fprintf('NOTE: flagged by brush only -- check for curved-grain false positive\n');
        %end
     
      
        %disp('=== Hybrid Inspection Result ===');
        %fprintf('AI Raw Decision:   %s (confidence %.2f)\n', aiRawLabel, confidenceScore);
        %fprintf('Rule-Based Backup: %s (scratchFail=%d, brushFail=%d)\n', ...
            %baselineDecision, scratchFail, brushFail);
        figure('Name', 'Hybrid Inspection Overlay');
        imshow(labelOverlayImage(image, evidenceOverlay, finalLabel, confidenceScore, disagreementFlag));
        % End of debug
    end
end
 
 
%% ---- Helper Functions----
function imgForNet = prepareForNet(image)
    % Standardize size/channels to what the network expects (224x224x3).
    imgForNet = imresize(image, [224 224]);
    if size(imgForNet, 3) == 1
        imgForNet = repmat(imgForNet, [1 1 3]);
    end
    if ~isa(imgForNet, 'uint8')
        imgForNet = im2uint8(imgForNet);
    end
end
 
 
% ---- Map network's raw class name to PASS/FAIL ----
function label = mapToPassFail(aiLabelStr, classNames)
    % classNames are set in the order used when training, e.g. {'ok';'ko'}.
    % 'ok'  -> PASS
    % 'ko'  -> FAIL
    okNames = ["ok", "pass", "good"];
    if any(strcmpi(aiLabelStr, okNames))
        label = "PASS";
    else
        label = "FAIL";
    end
end
 
 
% ---- Merge classical evidence structs into one ----
function evidence = mergeEvidence(scratchProps, brushProps, combinedMask)
    evidence = struct();
    sFields = fieldnames(scratchProps);
    for i = 1:numel(sFields)
        evidence.(['scratch_' sFields{i}]) = scratchProps.(sFields{i});
    end
 
    bFields = fieldnames(brushProps);
    for i = 1:numel(bFields)
        evidence.(['brush_' bFields{i}]) = brushProps.(bFields{i});
    end
 
    % Overall combined metric
    evidence.combined_PercentageFlagged = 100 * nnz(combinedMask) / numel(combinedMask);
end
 
 
% ---- Conservative rule-based baseline decision ----
function [decision, scratchFail, brushFail] = decideRules(evidence)
    % Thresholds finalized from empirical batch analysis
 
    % SCRATCH: LargestRegionArea is the valid
    % discriminator. LargestRegionArea,measured on a hand-picked scratch-defect batch 
    % vs. the clean-image batch showed a clean, zero-overlap
    % gap: clean max ~123px, defect min ~871px. Threshold of 300 sits
    % comfortably in that gap. Validated end-to-end: 100% recall (50/50)
    % on the first 50 defects batch, 0 false positives contributed on the
    % clean batch (first 50 clean iamges in train).
 
    % LIMITATIONW: This threshold is tuned for moderate/obvious
    % scratches, not super-thin scratches in 'ko' images 80 and onward. A super-thin scratch's surviving
    % blob area (e.g. Defect 121: 120px) sits well below 300, inside the
    % clean-image noise range. This threshold is intentionally NOT
    % lowered to try to catch super-thin cases, since that would reopen the
    % clean-image false-positive problem this fix solved.
    scratchFail = evidence.scratch_LargestRegionArea > 300;
 
    % BRUSH: requires both a nonzero detection AND a large-enough flagged
    % area. The >2% cutoff sits in the gap between small grain-noise false
    % positives (max ~1.46% in a 20 img batch) and real brush defects (min
    % ~4.24% from the first 20). 
 
    % LIMITATION: This mask not resolve the large false-positive
    % mode caused by curved/wavy grain fooling the FFT notch filter on some
    % clean images.
 
    brushFail = evidence.brush_NumRegions > 0 && evidence.brush_PercentageFlagged > 2;
 
    % Both detectors are strong on their own, so they will detect what they
    % are supposed to detect
    if scratchFail || brushFail
        decision = "FAIL";
    else
        decision = "PASS";
    end
end
 
 
%% ---- Helper: build a visual overlay for debug display ----
function outImg = labelOverlayImage(image, mask, label, score, disagreement)
    outImg = im2uint8(image);
    if size(outImg, 3) == 1
        outImg = repmat(outImg, [1 1 3]);
    end
 
    % Tint suspicious regions red
    boundaries = bwperim(mask);
    redChannel = outImg(:,:,1);
    redChannel(boundaries) = 255;
    outImg(:,:,1) = redChannel;
 
    txt = sprintf('%s (%.0f%%)', label, score * 100);
    if disagreement
        txt = [txt ' -- DISAGREEMENT'];
    end
    outImg = insertText(outImg, [10 10], txt, 'FontSize', 18, ...
        'BoxColor', 'yellow', 'TextColor', 'black');
end
 
