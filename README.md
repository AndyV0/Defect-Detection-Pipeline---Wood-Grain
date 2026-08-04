# Defect-Detection-Pipeline
An inspection station built in MATLAB that processes Wood Grain Texture.

# Information on the Dataset Chosen
Data set was taken from an external source: https://github.com/pankajmishra000/VT-ADL/tree/master. This repository focuses on the '02' dataset, which consists of wood grain textures.  
This dataset comes with a ground truth set, a training image set, and a testing image set. The training set (Further labeled 'ok') consists of 400 close-up non-defect images of wood grain textures. The testing set consists of two separate folders (Labeled 'ok' and 'ko'). 30 non-defective images are contained within test/ok, while 200 images of defective wood grain textures can be found within test/ko. Finally, the ground_truth set is the pixel-level ground truth masks of the testing defective wood images (the 'ko' folder).

# Types of Defects
While the defects are all categorized in one folder, our team has further categorized these anomalies into scratch defects and gradient defects. Scratch defects are sharp, jagged localized distortions disrupting the natural wood grain pattern. Scratch defects appear abrupt and high-contrast. Brush Defects are gradual, low-frequency shifts that act as a 'wash' of lighter intensity, countering natural grain. This distinction is important in image processing, as it allows our automated systems to determine the root cause of an issue and apply specific corrective actions.

Teammate Agreement: https://docs.google.com/document/d/1XQGZMSu_NMyhzP1d9ov_trOdaDU9POm8/edit?usp=sharing&ouid=102112280022279059905&rtpof=true&sd=true

P. Mishra, R. Verk, D. Fornasier, C. Piciarelli, G.L. Foresti
"VT-ADL: A Vision Transformer Network for Image Anomaly Detection and Localization"
30th IEEE/IES International Symposium on Industrial Electronics (ISIE)
Kyoto, Japan, June 20-23, 2021

# Objective
The objective of this project is to create a function to find and interpret defects in materials using the Image Toolbox in MATLAB and integrate AI-based detection into the function. This would allow the AI classifier to also be backed by our classical styles of image detection.

# Usage and Testing
To use the program, place the images you want to test into the 'myImages' folder and run 'testYourImages.m'. This should import all your images into a 600x600x3xN, 4D uint8 array. Then you may call the function 'inspectPart.m', abiding by the parameters listed within the help function, using myImages(:,:,:,N) as the first parameter (N repesents the number of the image you want to select).

# Requirements
MATLAB R2026a,
MATLAB Image Processing Toolbox,
Computer Processing Toolbox,
Deep Learning Toolbox,
Statistics Toolbox

# Reproducing Results
To reproduce the results we obtained, download the requirements and files found within the repository under 'releases' or repository folders named 'functions', 'imageSampleSets', and 'robustImageTesting'.
