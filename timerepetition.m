%SPM Preprocessing script
% Define the root folder where your subject data and trial definition folders are located
root_folder = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/';

% Get a list of all subject folders
subject_folders = dir(fullfile(root_folder, 'Data', 'Photic*')); 

start_index = 1;

%%

for i = start_index:numel(subject_folders)

    subject_folder_name = subject_folders(i).name; % Get the subject folder name 
    
    % Assuming that the epoched file has the same name as the subject folder:
    subject_file = fullfile(root_folder, 'Data', subject_folder_name, ['effMuECspmeeg_' subject_folder_name '.mat']);

    % Change the current directory to the subject-specific folder
    cd(fullfile(root_folder, 'Data', subject_folder_name));

    % Naming file specific to this subject
    subject_name = ['effMunoFPspmeeg_' subject_folder_name '.mat'];

    % Define the subject-specific output folder
    outputFolder = fullfile(root_folder, 'Data', subject_folder_name);

   % Load the trial definition file specific to this subject
    trialdef_file = fullfile(root_folder, 'Data', subject_folder_name, ['trialdef_170_eyes_closed_' subject_folder_name '.mat']);
    load(trialdef_file); % This loads 'trl' and 'conditionlabels' from the trial definition file
        
    alltrialdef_file = fullfile(root_folder, 'Data', subject_folder_name, ['trialdef_170_combined_', subject_folder_name '.mat']);
    load(alltrialdef_file,'combinedTrl'); % This loads 'trl' and 'conditionlabels' from the trial definition file
    
    [LIA,LOCB] = ismember(combinedTrl(:,1),eyesClosedTrl(:,1));
    
    % After this step, save some useful things for constructing “contrasts” below
    epochTimes = eyesClosedTrl;                 % Store the data for the epoch times
    epochFname = subject_name;               % Filename for epoched data
    
    % Weighted contrast to obtain linear effect of time
    nEpochs    = size(epochTimes,1);     % Number of epochs
    S          = [];
    S.D        = epochFname;
    
    % Construct parametric effects of time/repetition
    ons        = 1:nEpochs;
    pOrder     = 3;           % Parametric modulation order
    u          = ons.^0;      % Zeroth order i.e. plain average
    pLabels    = {'EC_effectRep^0'};
    for j = 1:pOrder
        u = [u; ons.^j];   % Modulate the repetition number by the current modulation order
        pLabels{end+1} = sprintf('EC_effectRep^%d',j);
    end
    u       = spm_orth(u');  % Orthogonalise the parametric modulators (including the first column mean corrects them too)
    u       = spm_en(u);     % Scale the modulators to normalise variance with Euclidean normalisation

    zeroBlock = zeros(numel(find(LIA==0)),4);
    if LIA(1)==0
        u1 = [zeroBlock; u];
    else
        u1 = [u; zeroBlock];
    end

    % Construct parametric effects of time/repetition for the other
    % condition (eyes open)
    nEpochs    = numel(find(LIA==0));
    ons        = 1:nEpochs;
    pOrder     = 3;           % Parametric modulation order
    u          = ons.^0;      % Zeroth order i.e. plain average
    pLabels{end+1} = sprintf('EO_effectRep^0',j);
    for j = 1:pOrder
        u = [u; ons.^j];   % Modulate the repetition number by the current modulation order
        pLabels{end+1} = sprintf('EO_effectRep^%d',j);
    end
    u       = spm_orth(u');  % Orthogonalise the parametric modulators (including the first column mean corrects them too)
    u       = spm_en(u);     % Scale the modulators to normalise variance with Euclidean normalisation

    zeroBlock = zeros(numel(find(LIA==1)),4);
    if LIA(1)==1
        u2 = [zeroBlock; u];
    else
        u2 = [u; zeroBlock];
    end

    % Now we put the two matrices side by side to end up with 8 columns
    S.c     = [u1 u2]';            % This will have pOrder+1 rows, with average effect, linear, second order etc
    S.label = pLabels;
    % S.c = ([1:nEpochs]-mean(1:nEpochs))/nEpochs;   % Construct a mean-corrected vector of increasing values,
    % scaled by the number of epochs. This will model the linear
    % effect of time/repetition
    % S.label    = {'LinearRepetition6Hz'};
    S.weighted = 0;
    S.prefix   = 'w';
    D          = spm_eeg_contrast(S);
    
    % Convert to images
    S          = [];
    S.D        = D.fname;
    S.mode     = 'scalp x time';
    S.timewin  = [-inf inf];
    S.freqwin  = [-inf inf];
    S.channels = 'all';
    [contrastImages{i}, outroot{i}] = spm_eeg_convert2images(S);    % Save the filenames and paths - these might be useful to construct a second level analysis e.g repeated measures ANOVA
end