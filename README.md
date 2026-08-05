# Defect Detection Pipeline for Wood Grain Dataset
**Group 8 — Internship Project**

## Overview:

This MATLAB project is an automated inspection station for detecting defects in wood grain textures. It combines classical image processing with an AI classifier to yield a final result.

The main function, `inspectPart.m`, returns:
- A **PASS**/**FAIL** classification decision
- A confidence score for that decision
- An evidence overlay image
- Supporting evidence metrics used as the basis for the decision

The pipeline is demonstrated through two live scripts. `DetailedInspectionPipeline.mlx` walks through every step of the single inspection function. From  scratch and brush masks, to evidence metrics, to AI classification, to override state, the script ends with the final image & verdict. `DefectDetectionReport.mlx` is the full project report: methodology, defect definitions, batch testing results across 230 images, and an analysis of design tradeoffs and open challenges. 


## Getting Started
This project is made entirely on MATLAB and requires MATLAB to open and run live scripts. For a static version of the report, [click here to view the PDF](https://github.com/AndyV0/Defect-Detection-Pipeline---Wood-Grain/blob/main/Image-Based%20Defect%20Detection%20Report%20-%20G8.pdf). 

To run the live scripts yourself, follow the steps below

### Requirements
- MATLAB R2023b or later (for live script compatibility)
- MATLAB Computer Vision Toolbox
- MATLAB Deep Learning Toolbox
- MATLAB Image Processing Toolbox
- MATLAB Statistics and Machine Learning Toolbox

### How to Run
1. Clone the repo
   ```sh
   git clone https://github.com/AndyV0/Defect-Detection-Pipeline---Wood-Grain.git
   ```
2. Open the scripts/ folder and choose the live script you want to run 
3. In the live script, click 'Run All'

The script will execute top to bottom, displaying results, figures, and evidence 
metrics as it runs. 

> Running any of the live scripts will auto-download required `.mat` files 
> (trained models) on first execution, which may take a moment.   



## Relevant Information

### Folder Structure
This is the code/data folders tree documenting all functions, folder, and .mat files present in this project (not including root config/doc files). Descriptions of what a file does are to the side of it's position.
```
Root
├───robustImageTesting
│   └───testImages.m    # Standard script that tests inspection on augmented images
├───scripts
│   ├───segmentDefectDemo.mlx             # Demo of AI segmentation in action
│   ├───DetailedInspectionPipeline.mlx    # Step-by-step interactive pipeline demo
│   └───DefectDetectionReport.mlx         # Live script generating the defect report
├───myImages
│   ├───importYourImages.m      
│   └───imageTestRunner.m
├───functions
│   ├───Test and Train                              # Functions to test & train AI Classifier
│   │   ├───trainInspectionClassifier.m             # Trains the AI Classifier
│   │   └───fullDatasetBatchTest_noFineScratch.m    # Creates a batch test to test inspectPart.m
│   ├───classicalDetection                # Human-made Defect Detectors
│   │   ├───ringContinuityDetection.m     # Finds errors in 01 dataset's rings
│   │   ├───scratchDetection.m            # Finds scratch defects in 02 dataset
│   │   ├───hairlineScratchDetection.m    # Unused Detector meant for 02
│   │   ├───bleedDetection.m              # Finds bleeds in 03 dataset's ellipse
│   │   └───brushDetection.m              # Finds brush defects in 02 dataset (combines w/ scratch)
│   ├───AI-Based Segmentation          
│   │   ├───trainSegmentDefect.m    # Trains the AI to capture defect area
│   │   └───segmentDefect.m         # Produces maskAI (optional deliverable) 
│   └───inspectPart.m               # Main entry point — runs full inspection
├───imageSampleSets                       
│   ├───sample_test_01    # Sample of 20 images & masks for scripts
│   │   ├───masks
│   │   └───images
│   ├───sample_test_02    # This sample is used for all main deliverables
│   │   ├───masks
│   │   └───images
│   ├───sample_test_03
│   │   ├───masks
│   │   └───images
│   ├───fullDatasetResults_test30.mat                # Batch Test on the full dataset      
│   ├───fullDatasetResults_noFineScratch_test30.mat  # Batch Test excluding super-fine scratches
│   └───02DatasetResults_noFineScratch428Clean.mat   # Batch Test including Training images & excluding super-fine scratches
```

> Running segmentDefectDemo.mlx will automatically download the required segmentDefectNet_0X.mat model files on first execution. No large `.mat` files are  stored in the repository. Nor is 1785125303951_trainedInspectAI.mat, which is also auto-downloaded. To find these check the release

### Dataset
The dataset was taken from an external source: https://github.com/pankajmishra000/VT-ADL/tree/master. This repository focuses on the '02' dataset, which consists of wood grain textures.
This dataset comes with a ground truth set, a training image set, and a testing image set. The training set (Further labeled 'ok') consists of 400 close-up non-defect images of wood grain textures. The testing set consists of two separate folders (Labeled 'ok' and 'ko'). 30 non-defective images are contained within test/ok, while 200 images of defective wood grain textures can be found within test/ko. Finally, the ground_truth set is the pixel-level ground truth masks of the testing defective wood images (the 'ko' folder). While this project was designed specifically for this dataset, it is not bundled with the repository to keep the repo lightweight.


## Reproducing Results
This project gives users access to these inspection functions without the need for downloading the bulky BTAD dataset. However, this also means that, in order to reproduce the results, the dataset needs to be sought out. To reproduce the batch testing results, 
1. Download the dataset from [VT-ADL](https://avires.dimi.uniud.it/papers/btad/btad.zip) 
2. Extract the '02' dataset from the .zip file
3. Call:
```matlab
fullDatasetBatchTest_noFineScratch("path/to/02")
```
replacing "path/to/02" with the path to the dataset's root folder (the one containing `test/` and `train/`). 

> By default, this excludes super-fine scratch defects; to include the full defect set, open the function and change `fineScratchCutoff` from `80` to `200`, 
> as noted in the comments of the file.

## Testing Your Own Images


## Contributions
Teammate Agreement: https://docs.google.com/document/d/1XQGZMSu_NMyhzP1d9ov_trOdaDU9POm8/edit?usp=sharing&ouid=102112280022279059905&rtpof=true&sd=true

**Andy Viche**: Worked on classical detections, training the AI Classifier, segment defect (function, script, & training), DefectDetectionReport live script, DetailedInspectionPipeline script, and this readme :)

**Member Name**: Put your contributions here team

## Citations
P. Mishra, R. Verk, D. Fornasier, C. Piciarelli, G.L. Foresti
"VT-ADL: A Vision Transformer Network for Image Anomaly Detection and Localization"
30th IEEE/IES International Symposium on Industrial Electronics (ISIE)
Kyoto, Japan, June 20-23, 2021




