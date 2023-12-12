%%  <-- These two percentage symbols together make the matlab editor use "Cell mode" - 
%       this is very useful for code that you might want to execute stage by stage.
%       Have a look at <https://uk.mathworks.com/videos/managing-code-in-matlab-cell-mode-scripts-97209.html>

% addpath blah                             % Add any paths you need
addpath('/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Code/EEGUI')                             % Add any paths you need
filenames = dir('/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/Original');  % Change as appropriate
finalFilenames = {};
c = 0;
for n = 1:numel(filenames)
    if endsWith(lower(filenames(n).name),'.edf')    % If the file extension is .edf
        c = c+1;  % Increment counter
        finalFilenames{c} = fullfile(filenames(n).folder,filenames(n).name);  % Construct the full path to the file
    end
end

%%
% Pre-allocate some cell arrays and matrices for stuff we want to store
nFiles = numel(finalFilenames);             % Number of files to analyse
% collect_meanResponseFirstHalf  = {};        % Cell array for mean responses
% collect_meanResponseSecondHalf = {};
allData = nan(nFiles,84);                   % Construct a matrix to store meanResultFirstHalf     
stdData = nan(nFiles,84);                   % Variability of response at each time point
collect_maxMinusMin = {};
allData2 = nan(nFiles,1);                   % Construct a matrix to store average max-min (first half)
allData3 = nan(nFiles,2);                   % Construct a matrix to store regression coefficients
allData4 = nan(nFiles,2);
successfulSubs = zeros(1,nFiles);           % Vector to store who the main loop runs successfully for
dataInverted   = zeros(1,nFiles);           % Vector to store who we inverted the data for
timeTaken      = zeros(1,nFiles);           % Vector to store the time it takes the loop to run for each file

%%
for i = 1:numel(finalFilenames)    % I like numel ("number of elements") rather than length but this is purely stylistic
    try  % We will embed our attempts to process the data in a try...catch... format - see "help try"
        hdr = JSW_edfread(finalFilenames{i});                                           % Read the EDF header
        hdr = JSW_edfread(hdr.fname, hdr, 'annotations');                                   % Add annotations to the header structure
        [~,record] = JSW_edfread(hdr.fname,hdr,'all');                                      % Read the data
        tbAll      = [1:size(record,2)]./hdr.frequency(1);                                  % Construct an initial timebase
        if hdr.frequency(1)~=500
            % Need to resample the data
            fprintf('Resampling the data for the %dth file...\n',i)
            [rRecord,tbAll] = resample(record',tbAll,500);
            record          = rRecord';
            photicChanTxt = 'PhoticREF';
        else
            photicChanTxt = 'TriggerEvent';
        end
        
        photicTxt  = contains({hdr.annotation.event},'Hz');                     % Logical index for whether an annotation contains "Hz" i.e. might be onset of photic stimulation
        trigInd    = find(contains(hdr.label,photicChanTxt));                   % Which row of data corresponds to "Trigger events"
        if hdr.frequency(1)==500
            allFlashTimes  = tbAll(find(record(trigInd,:)==1));                 % Find times where trigger was 1 (i.e. there was a flash)
        else  % Data were resampled to 500Hz, leading to all sorts of problems
            firstPassFlashes  = find(record(trigInd,:)>500);     % 500 chosen as a threshold based upon inspecting the data
            dFirstPassFlashes = diff([0 firstPassFlashes]);      % Measure the gaps between the flashes (including the first one)
            allFlashInd       = firstPassFlashes(dFirstPassFlashes>2);  % Only include the flash times when there is a gap bigger than two samples
            allFlashTimes     = tbAll(allFlashInd);              % Convert from index to time
            
            % A second small(!) problem is that these data were not inverted
            % on export so they are the opposite polarity to the XLTEK data
            chansToInvert           = setdiff(1:size(record,1),trigInd);  % Find the channels which are not the photic trigger
            record(chansToInvert,:) = -record(chansToInvert,:);           % Invert those channels
            dataInverted(i)         = 1;                                  % Keep a record of whose data we inverted                               
       end

        dAllFlashTimes = diff([0 allFlashTimes]);                                           % Distance (in s) between sequential flashes; include the first flash
        brkPtsSt       = find(dAllFlashTimes>1.1);                                          % Gaps between blocks of flashes
        brkPtsEn       = [brkPtsSt(2:end)-1 numel(allFlashTimes)];                          % Ends of blocks of flashes
        
        blkInd         = nan(1,numel(allFlashTimes));                                       % This will be an index of which block a particular flash belongs to
        blkFlashRate   = nan(1,numel(brkPtsSt));                                            % This will be to record the average flash rate within a block
        blkFlashRate2  = nan(1,numel(brkPtsSt));                                            % Can also calculate this from the distance between flashes
        blkTb          = nan(1,numel(tbAll));                                               % Will hold the index of whether a time point is inside a block
        blkStTime      = nan(1,numel(brkPtsSt));                                            % Will hold the start time in s of each block
        blkDur         = nan(1,numel(brkPtsSt));                                            % Will hold the duration (in s) of each block
        
        for b = 1:numel(brkPtsSt)
            blkInd(brkPtsSt(b):brkPtsEn(b)) = b;                                      % Assign current block count to index
            nFlashesInBlk    = brkPtsEn(b)-brkPtsSt(b);                               % Number of flashes in the current block
            
            blkStTime(b)     = allFlashTimes(brkPtsSt(b));                            % Start time for current block
            blkEnTime        = allFlashTimes(brkPtsEn(b));                            % End time for current block
            blkDur(b)        = blkEnTime-blkStTime(b);                                % Total time in the current block
            blkTb(tbAll>=blkStTime(b)&tbAll<=blkEnTime) = b;                          % Time series for blocks
            
            blkFlashRate(b)  = nFlashesInBlk/blkDur(b);                               % Average flash rate in the current block
            blkFlashRate2(b) = 1/mean(dAllFlashTimes(brkPtsSt(b)+1:brkPtsEn(b)));     % Average flash rate calculated a different way
            collect_blkFlashRate{i} = blkFlashRate;
            collect_blkDur{i} = blkDur;
        end
        
        O1Ind        = find(contains(hdr.label,['O1']));                                         % Which channel?
        fO1ref       = JSW_BandAndNotchFilter(record(O1Ind,:)',hdr.frequency(O1Ind),1,120,50);   % Bandpass filter from 1-70Hz with a notch at 50Hz
        
        % Find a block with the right frequency of stimulation e.g. 6Hz
        blkToTestInd = find(blkFlashRate<6.2&blkFlashRate>5.8);
        if numel(blkToTestInd)>1
            blkToTestInd = blkToTestInd(1);
            fprintf('************************************\nNB only taking first stimulation run at 6Hz.\n************************************\n')
        end

        % This is an elegant way of constructing event-related data - make a matrix of indices
        % that are peri-event and use this to index into the data-containing vector.
        fs           = 500;                                                                              % Sampling frequency (now set manually to 500Hz; if it's not empirically 500Hz, data got resampled above)
        incMat       = round(repmat(-0.0*fs:0.167*fs,numel(find(blkInd==blkToTestInd)),1));              % Start time +/- a certain amount
        timeInd      = repmat(round(fs*allFlashTimes(blkInd==blkToTestInd)'),1,size(incMat,2))+incMat;   % Matrix of start index + relative onset index
        binnedData   = fO1ref(timeInd);
        
        brkPoint = round(size(binnedData,1)/2);                                                     % Get the number of rows of binnedData, divide by 2 and round this
        responseFirstHalf = (binnedData(1:brkPoint,:));                                             % gives all responses for the first half of data when eyes are opem
        responseSecondHalf = (binnedData(brkPoint+1:end,:));
        
        maxMinusMin = (max(responseFirstHalf,[], 2))-(min(responseFirstHalf, [], 2));               % max-min value (check time window) for either binnedData of responseFirstHalf
        collect_maxMinusMin{i} = maxMinusMin;                                                       % collect responses in an array

        meanResponse = mean(binnedData);
        meanResponseFirstHalf = mean(binnedData(1:brkPoint,:));                                     % Take the mean from the first row to the middle row
        meanResponseSecondHalf = mean(binnedData(brkPoint+1:end,:));                                % Take the mean from just after the middle point to the end
%         collect_meanResponseFirstHalf{i} = meanResponseFirstHalf;                                   % add mean response for each file into arrray

        AverageMaxMinFirstHalf = (max(meanResponseFirstHalf,[], 2))-(min(meanResponseFirstHalf, [], 2));
        allData2(i,:) = AverageMaxMinFirstHalf;
        
        allData(i,:) = meanResponseFirstHalf; % change matrix size if time window is altered        % this stores the mean response (first half) for each patient
        stdData(i,:) = std(binnedData(1:brkPoint,:));                                               % Take the standard deviation for each time point as a measure of spread (useful to plot inividual subjects)
%         tbPlot = [1:numel(mean(responseFirstHalf))]./fs;                                             % gives the value in peristimulus time (in seconds) for each sample in the plot
%         tbPlot2 = tbPlot.*1000;
%         plot(tbPlot,mean(binnedData))                                                               % plot averaged evoke potential for whole block (x in secs)
        
        % Regression analysis where y=max-min and x=stimulus (first half)
        n = [1:1:length(maxMinusMin)];                                                               % create an array for stimulus number ([1:1:n])
        X = [n' ones(numel(n),1)];                                                                   % Construct design matrix with two columns; first is stimulus count and the second a constant term
        [bCoef,bint,r,rint,stats] = regress(maxMinusMin,X);                                          % Run the regression and return all the good stuff in 'stats'
        allData3(i,:) = (bCoef);
        
        successfulSubs(i) = 1;  % If we've got here, it means there were no errors and this subject was successfully processed
    catch
        fprintf('\n**************************\nFailed to process subject %d \n**************************\n')
    end

        %create trialdef.mat data file
        [~, edfName, ~] = fileparts(finalFilenames{i}); % Extract the filename without extension
        epochStartTimes = allFlashTimes(blkInd == blkToTestInd); % defining epoch start time in relation to flashtimes
        baselineSamp = 0.02 * fs;
        epochStartSamp = epochStartTimes * fs - baselineSamp;
        epochEndSamp = (epochStartSamp + (0.02 + 0.15) * fs);
        trl = [epochStartSamp' epochEndSamp' -repmat(baselineSamp, numel(epochStartSamp), 1)];

        trialdef = struct('conditionlabel', '6HzFlash', 'eventtype', 'Stimulus', 'eventvalue', 1, 'trlshift', 0);
        timewin = [-20; 150];
        conditionlabels = cell(1, numel(epochStartSamp));

        for k = 1:numel(epochStartSamp)
            conditionlabels{k} = '6HzFlash';
        end

        source = sprintf('spmeeg_Photic_%s.mat', edfName); % Adjust the source name
        
        % Extract subject folder from the file path
        [~, subjectFolder, ~] = fileparts(fileparts(finalFilenames{i}));

        % Construct the destination folder for saving the trialdef_ file
        destinationFolder = fullfile('/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data/', subjectFolder);

        % Save the trialdef_ file in the subject-specific folder
        trialdef_filename = fullfile(destinationFolder, ['trialdef_170_', edfName, '.mat']);
        save(trialdef_filename, 'trl', 'trialdef', 'timewin', 'conditionlabels', 'source', '-mat');

        timeTaken(i) = toc;
end

%% This is not really needed, but just in case we need the code for how to make a avref file
% Define the folder path where you want to save the file
folderPath = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data'; % Replace with the actual folder path

% Create the struct named "montage"
montage.labelorg = {...
    'F3', 'F4', 'C3', 'C4', 'P3', 'P4', 'O1', 'O2', ...
    'F7', 'F8', 'T3', 'T4', 'T5', 'T6', 'A1', 'A2', 'Fz', 'Cz', 'Pz'...
};
montage.labelnew = montage.labelorg;

% Create the "tra" matrix
n = numel(montage.labelorg);
montage.tra = -0.0476 * ones(n, n);
montage.tra(1:n+1:end) = 0.9524;

% Save the struct as "avref.mat" in the specific folder
save(fullfile(folderPath, 'avref.mat'), 'montage');

% Display the struct
disp(montage);