# Defect-Detection-Pipeline
An inspection station built in MATLab that processes Wood Grain Texture.

# Information on the Dataset Chosen
Data set was taken from an external source: https://github.com/pankajmishra000/VT-ADL/tree/master. This repository focuses on the '02' dataset, which consists of wood grain textures.  
This dataset comes with groundtruth set, training image set, and a testing image set. The training set (Further labeled 'ok') consist of 400 close-up non-defect images of wood grain textures. The testing set consists of two seperate folders (Labeled 'ok' and 'ko'). 30 non-defective images are contain within test/ok, while 200 images of defective wood grain textures can be found within test/ko. Finally, the ground_truth set is the pixel-level ground truth masks of the testing's defective wood images (the 'ko' folder).

# Types of Defects
While the defects are all categorized in one folder, our team has further categorized these anomalies into scratch defects and gradient defects. Scratch defects are sharp, jagged localized distorions disrupting the natural wood grain pattern. Scratch defects appear abrupt and high-contrast. Brush Defects are gradual, low-frequency shifts that act as a 'wash' of lighter intensity countering natural grain. This distinction is important in image processing, as it allows our automated systems to determine the root cause of an issue and apply specific corrective actions.

Teammate Agreement: https://docs.google.com/document/d/1XQGZMSu_NMyhzP1d9ov_trOdaDU9POm8/edit?usp=sharing&ouid=102112280022279059905&rtpof=true&sd=true

P. Mishra, R. Verk, D. Fornasier, C. Piciarelli, G.L. Foresti
"VT-ADL: A Vision Transformer Network for Image Anomaly Detection and Localization"
30th IEEE/IES International Symposium on Industrial Electronics (ISIE)
Kyoto, Japan, June 20-23, 2021
