# Photic
Photosensitivity in Epilepsy Scripts

07/12/2023 

Code written by: Subham Ganguly

Institution: King's College London

Programme: MRC-ITND

First Rotation with Joel Winston and Sam Cooke

Duration: 09/10/2023 - 08/12/2023

Project: Photosensitivity in Epilepsy

Branches of Code:

Matlab: Data analysis pipeline for processing photic/non-photic participants presented with photic stimulation

Dependencies: SPM12

Files:

'Preprocessing for human EEG Photic Data': Script files with comments and editable choices for analysing and processing human eeg data from initial recording software EDF files to fully processed .mat files using spm12.

'Dependencies for EEG data analysis': Files containing referencing, EEG channel selection and sensor coordinate information specific to data collected in XLTEK and Nicolet systems using Modified Maudsley coordinates in our subjects.

Python: Visual photic stimulation to be presented to mice in behavioral paradigm

Dependencies: Psychopy

Files: 'Photic_Stimulus*' differentiated by either 'exclusively' presenting photic stimulus or recording the presence of stimulus over a period of time using a 'Nidaq' system in order to relate activity to stimulus presentation
