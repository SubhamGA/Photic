%SPM Preprocessing script
% Define the root folder where your subject data and trial definition folders are located
root_folder = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/';

% Get a list of all subject folders
subject_folders = dir(fullfile(root_folder, 'Data', 'Photic*'));

% Define the path to the "avref.mat" file and load Avref for XLTEK - subjects recorded using XLTEK
% avrefFilePath = '/Users/subham/MATLAB/Photic/Data/avref_XLTEK.mat'; % Specify the correct path 
avrefFilePath = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/avref_XLTEK_noFP.mat'; % Specify the correct path _noFP for FP1+FP2 removed
refX = load(avrefFilePath);

% Define the path to the "avref.mat" file and load Avref for nicolet - subjects recorded using Nicolet
% refNFilePath = '/Users/subham/MATLAB/Photic/Data/avref_nicolet.mat'; % Specify the correct path 
refNFilePath = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/avref_nicolet_noFP.mat'; % Specify the correct path _noFP
refN = load(refNFilePath);

%Define the path to the "channelselection.mat" file and load channelselection_XLTEK.mat made for subjects recorded using XLTEK
%channelselectionFilePath = '/Users/subham/MATLAB/Photic/Data/channelselection_XLTEK.mat'; % Specify the correct path 
channelselectionFilePath = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/channelselection_XLTEK_noFP.mat'; % Specify the correct path _noFP
channelX = load(channelselectionFilePath);

%Define the path to the "channelselection_mod.mat" file and load channelselection_nicolet.mat made for subjects recorded using Nicolet
% channelNselectionFilePath = '/Users/subham/MATLAB/Photic/Data/channelselection_nicolet.mat'; % Specify the correct path 
channelNselectionFilePath = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/channelselection_nicolet_noFP.mat'; % Specify the correct path _noFP
channelN = load(channelNselectionFilePath);

%Define the path to the "sensors.pol" file and load sensors.pol
%sensorsFilePath = '/Users/subham/Documents/MATLAB/Photic/Data/modMaudsleyCoordinatesRadius104.sfp';
%sensors = load(sensorsFilePath);

% Define the index from which you want to start processing subjects
start_index = 1; % Change this to the desired starting index

%% 
% Loop through each subject folder and apply preprocessing steps
for i = 1 %start_index:numel(subject_folders)
    subject_folder_name = subject_folders(i).name; % Get the subject folder name 

    % Now, you need to locate the subject-specific EDF file in the subject folder.
    % Assuming that the EDF file has the same name as the subject folder and always has the ".EDF" extension:
    subject_file = fullfile(root_folder, 'Data', subject_folder_name, [subject_folder_name '.EDF']);

    cd('/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Code/EEGUI');
    %Separates the processing of XLTEK and Nicolet files using flag
    hdr = JSW_edfread(subject_file);
    if strncmp(hdr.label{1},'EEG',3)
        nicoletFlag = 1;
    else
        nicoletFlag = 0;
    end
    
    % Naming file specific to this subject
    subject_name = subject_folder_name;

    % Define the subject-specific output folder
    outputFolder = fullfile(root_folder, 'Data', subject_folder_name);

    % Change the current directory to the subject-specific folder
    cd(fullfile(root_folder, 'Data', subject_folder_name));

    % Load the EEG data for this subject
    S = [];
    S.dataset = subject_file; % Specify the path to your subject's EEG data file (EDF, MEEG, etc.)
    % Define your channel selection logic here
    if ~nicoletFlag
        S.channels = channelX.label;
        D = spm_eeg_convert(S);
    else
        S.channels = channelN.label;
        D = spm_eeg_convert(S);
    end
    
    % Load the trial definition file specific to this subject
    [subject_folder, subject_name, ~] = fileparts(subject_file);
    trialdef_file = fullfile(subject_folder, ['trialdef_170_eyes_closed_' subject_name '.mat']); %trialdef_ %trialdef_eyes_open_ %trialdef_eyes_closed_
    
    if exist(trialdef_file, 'file')
        load(trialdef_file); % This loads 'trl' and 'conditionlabels' from the trial definition file
        
        % Construct the subject-specific destination folder path
        outputFolder = fullfile(root_folder, 'Data', subject_folder_name);

        % Preprocessing steps for this subject
        % Preprocessing Step 1: Convert
        spm('defaults', 'eeg');

        % Define the subject-specific output folder
        outputFolder = fullfile(root_folder, 'Data', subject_folder_name);

         % Ensure the output folder exists
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
        end
        
        S = [];
        S.dataset = subject_file;
        if ~nicoletFlag
            S.channels = channelX.label;
            % use_refN_montage = false; % Set a flag to indicate using refX montage
        else
            % If an error occurs, use the mod channel
            S.channels = channelN.label;
            % use_refN_montage = true; % Set a flag to indicate using refN montage
        end
        S.blocksize = D.nsamples * D.nchannels;
        S.checkboundary = 1;
        S.eventpadding = 0;
        S.saveorigheader = 0;
        S.conditionlabels = closedConditionLabels; %conditionlabels %openConditionLabels %closedConditionLabels
        S.inputformat = [];
        S.mode = 'continuous';
        D = spm_eeg_convert(S);

        outputFile = fullfile(outputFolder, ['spmeeg_EC_170_' subject_name, '.dat']);
        save(outputFile, 'D');

        % Preprocessing Step 2: Resample to 500
        S = [];
        S.D = fullfile(D.fname);
        S.fsample_new = 500;
        S.method = 'resample';
        S.prefix = 'u';
        D = spm_eeg_downsample(S);

        % Preprocessing Step 3: Montage
        S = [];
        S.D = fullfile(D.fname);
        S.mode = 'write';
        % Define your montage logic here
        if nicoletFlag 
            % Use the refN montage
            S.montage = refN.montage;
        else
            % Use refX montage
            S.montage = refX.montage;
        end
        % Update blocksize if necessary (if you want it to be different for each subject)
        S.blocksize = D.nsamples * D.nchannels; % You can customize this as needed
        S.prefix = 'M';
        S.keepothers = 0;
        S.keepsensors = 1;
        S.updatehistory = 1;
        D = spm_eeg_montage(S);
        
        %Preprocessing Step 4: Sensor Location
        % Add these lines before the error occurs
        S = [];
        S.D = fullfile(D.fname);
        S.task = 'loadeegsens';
        S.source = 'locfile';
        S.sensfile = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/modMaudsleyCoordinatesRadius104_noFP.sfp'; %don't do this like me, define the sensors file at the top of the script and then plug it in here insead of the path
        S.save = 1;
        D = spm_eeg_prep(S);
    
        % Preprocessing Step 5: Filter
        S = [];
        S.D = fullfile(D.fname);
        S.type = 'butterworth';
        S.band = 'high';
        S.freq = 0.1;
        S.dir = 'twopass';
        S.order = 5;
        S.prefix = 'f';
        D = spm_eeg_filter(S);
    
        % Preprocessing Step 6: Filter (Low-pass)
        S = [];
        S.D = fullfile(D.fname);
        S.type = 'butterworth';
        S.band = 'low';
        S.freq = 30;
        S.dir = 'twopass';
        S.order = 5;
        S.prefix = 'f';
        D = spm_eeg_filter(S);

        % Preprocessing Step 7: Epoching
        S = [];
        S.D = fullfile(D.fname);
        S.fsample = 500;
        S.timeonset = 0.05;
        S.trl = eyesClosedTrl; %trl %eyesOpenTrl %eyesClosedTrl
        S.conditionlabels = closedConditionLabels; %conditionlabels %openConditionLabels %closedConditionLabels
        S.timewin = [-0.02, 0.15];  % Set the desired time window
        S.bc = 1;
        S.inputformat = [];
        S.reviewtrials = 0;
        S.save = 0;
        S.prefix = 'e';
        S.eventpadding = 0;
        D = spm_eeg_epochs(S);
    
        % Preprocessing Step 8: Artifact rejection
%        S = [];
%        S.D = fullfile(D.fname);
%        S.mode = 'reject';
%        S.badchanthresh = 0.2;
%        S.prefix = 'a';
%        S.append = true;
%        S.methods.channels = {'all'};
%        S.methods.fun = 'threshchan';
%        S.methods.settings.threshold = 80;
%        S.methods.settings.excwin = 1000;
%        D = spm_eeg_artefact(S);
    
        % Preprocessing Step 9: Average
        S = [];
        S.D = fullfile(D.fname);
        S.robust.ks = 3;
        S.robust.bycondition = true;
        S.robust.savew = false;
        S.robust.removebad = false;
        S.circularise = false;
        S.prefix = 'm';
        S.trim = 0;
        D = spm_eeg_average(S);

% Change the current directory back to the root folder
    cd('/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Code/EEGUI'); %Script finds it hard to find and use functions from the EEGUI folder unless it is cd'd to for the start of the next subject

% Print a message indicating the completion of preprocessing for this subject
        fprintf('Preprocessing completed for subject file: %s/n', subject_file);
    else
        fprintf('No trial definition file found for subject: %s/n', subject_name);
    end
end

%%
% Save the current working directory
original_directory = pwd;

% Loop through each subject folder and convert to images to perform statistical analysis
for i = start_index:numel(subject_folders)
    subject_folder_name = subject_folders(i).name; % Get the subject folder name 

    % Now, you need to locate the subject-specific processed .mat file
    % Assuming that the processed .mat file starts with 'effMuspmeeg_' followed by the subject name:
    subject_file_pattern = ['meffMuspmeeg_noFP_170_' subject_folder_name '.mat'];
    subject_files = dir(fullfile(root_folder, 'Data', subject_folder_name, subject_file_pattern));

    if ~isempty(subject_files)
        % Assume you want to process the first matching .mat file (you can adjust this as needed)
        subject_file = fullfile(root_folder, 'Data', subject_folder_name, subject_files(1).name);

        % Change the current directory to the subject-specific folder
        cd(fullfile(root_folder, 'Data', subject_folder_name));

            % Continue with image conversion for the subject using subject_file
            S = [];
            S.D = subject_file;
            S.mode = 'scalp'; %scalp time
            S.conditions = {};
            S.timewin = [-Inf Inf];
            S.freqwin = [-Inf Inf];
            S.channels = 'EEG';
            S.prefix = 't';
            D = spm_eeg_convert2images(S);

            % Restore the original working directory
            cd(original_directory);
    end
end
