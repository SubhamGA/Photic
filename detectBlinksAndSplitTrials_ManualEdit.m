root_folder = '/Users/rick2/Documents/MATLAB/Winston_Lab/Photic/Data';
snums       = [1:26 2001:2026];  % Subject numbers - check these!!
figFlag     = 1;   % Draw a pretty figure or not...

% Loop over subjects
for n = 1:numel(snums)
    sName       = sprintf('Photic%04d',snums(n));   % Subject name e.g. Photic0001, Photic2015 etc
    sDir        = fullfile(root_folder,sName);          % Directory name for each subject

    % Get a list of EDF files in the directory
    edfFiles = dir(fullfile(sDir, '*.EDF'));

    % Find the EDF file with the corresponding number in its name
    matchingFile = find(contains({edfFiles.name}, sName), 1);

    if ~isempty(matchingFile)
        edfName = fullfile(sDir, edfFiles(matchingFile).name);
        % Read the EDF 
        hdr          = JSW_edfread(edfName);              % Read the EDF header
        [hdr,record] = JSW_edfread(hdr.fname,hdr);           % Read the full dataset
        fs           = median(hdr.frequency);                % Sampling frequency
        tb           = [1:size(record,2)]./fs;               % Construct a time base for this patient
    end
    
    % Look for the photic channel
    nicoletFlag  = 0;
    photInd      = contains(hdr.label,'Trigger');  % XLTEK
    if ~any(photInd)
        photInd     = contains(hdr.label,'Photic');   % Nicolet
        nicoletFlag = 1;
    end
    photChan     = find(photInd);

    % Load the trial definition file
    trlDefFname  = fullfile(sDir,sprintf('trialdef_170_%s.mat',sName));   % Construct filename for this patient's trial definitions
    load(trlDefFname);                                                % ...and load it

    if nicoletFlag
        trl = round(trl./(500/256));  % Convert from 500Hz sampling to 256Hz
    else
        trl = round(trl);
    end

    % Establish the time window of interest in seconds
    timeWindowS = [tb(min(trl(:,1)))-5 tb(max(trl(:,2)))+5];

    % Find Fp1 and Fp2 
    fp1Ind      = contains(lower(hdr.label),'fp1');
    fp2Ind      = contains(lower(hdr.label),'fp2');
    
    % Extract data and take the average
    fp1TW       = record(fp1Ind,min(trl(:,1)):max(trl(:,2)));   % Data from Fp1 during the time window of interest
    fp2TW       = record(fp2Ind,min(trl(:,1)):max(trl(:,2)));   % Data from Fp2 during the time window of interest
    fpTW        = mean([fp1TW;fp2TW]);         % Average the data
    if nicoletFlag      % Invert the data (really should do this for the XLTEK data instead but I wrote the algorithm this way up!!!)
        fpTW = -fpTW;
    end

    % Filter the data, take the differential and normalise
    ffpTW       = JSW_BandAndNotchFilter(fpTW,fs,0.1,5,50);   % Filter aggressively to smooth the data an optimise for sensitivity to the blink
    zdffpTW     = zscore(diff(ffpTW));   % Take the differential of the smoothed data and z-normalise it

    izdffpTW    = zdffpTW<-1;            % Find where the z-scored differential is below -1
    

    % This next bit is pretty rubbish code and could be vectorised but it's
    % late and I'm tired!!  It looks for sequential values that are the
    % same in the input vector and stores the counts of sequential values
    %
    % I think you can get the same result from: consecVals = diff(find(diff([nan; izdffpTW(:);  nan]) ~=0));
    vals        = [];
    consecVals  = [];
    c           = 1;   % number of consecutive values so far
    for i = 2:numel(izdffpTW)
        if izdffpTW(i)==izdffpTW(i-1)
            c = c + 1;                   % Increment the counter
        else
            consecVals(end+1) = c;
            vals(end+1)       = izdffpTW(i-1);   % The previous value corresponds to that runlength
            c                 = 1;               % Reinitialise this
        end
    end
    consecVals(end+1) = c;
    vals(end+1)       = izdffpTW(i);   % The last value corresponds to the last runlength

    cConsecVals    = cumsum(consecVals);     % Cumulative sum of consecutive values
    maxConsec      = max(consecVals(vals==1));

    matchConsecVal = consecVals==maxConsec&vals==1;   % Look for consecutive values that match the maximum of the target state (==maxConsec) and are in the target state (vals==1)
    matchInd       = find(matchConsecVal,1,"first");  % Take the first match (it would be cosmic coincidence if two values matched the biggest eye closure)
    blinkOnsInd    = cConsecVals(matchInd-1);         % Onset of the blink within the time window is the cumulative number of consecutive values up to that point
    blinkOffInd    = cConsecVals(matchInd);           % This is a poor marker of the offset of the blink but it's when the steep trajectory ends and is useful below

    % Now for offset of the blink/eye closure....this is harder.  We coudl
    % use blinkOffInd = cConsecVals(matchInd); but this leaves lots
    % of quite active eyeball movement.
    % So we'll use a simple criterion of when the zscored amplitude of the
    % filtered FP data returns to above -1 SD from its mean prior to the
    % detected blink
    zffpTW      = zscore(ffpTW);                % z-score the frontopolar trace for the whole window
    baseLineZ   = mean(zffpTW(1:blinkOnsInd));  % Mean z-scored amplitude in the baseline period prior to the blink
    targReturnZ = baseLineZ - 1;                % Target z-scored amplitude
    iBaseline   = zffpTW>targReturnZ;           % Is the zscored trace above the target value?
    sampInd     = 1:numel(zffpTW);              % A vector representing sample count
    iReturnAfterBlink = iBaseline'&(sampInd>blinkOffInd);    % Intersection of suprabaseline values and post-eye closure offset
    blinkOffsetInd    = find(iReturnAfterBlink,1,'first');   % Earliest time when value is suprabaseline after the initial eye movement

    % Adjust for the fact that we only looked within a window 
    blinkOnsInd     = blinkOnsInd+min(trl(:,1));
    blinkOffsetInd  = blinkOffsetInd + min(trl(:,1));

    % Plot a figure with the raw data for Fp1 and Fp2 and the photic
    % stimulus train with the latter coloured by which phase it is in 
    % (eyes open/act of closing/whilst closed)
    if figFlag
        figure(11); clf
        plot(tb(min(trl(:,1)):max(trl(:,2))), fp1TW);
        hold on
        plot(tb(min(trl(:,1)):max(trl(:,2))), fp2TW);
        % plot(tb(min(trl(:,1)):max(trl(:,2))), 50 * zscore(record(1, min(trl(:,1)):max(trl(:,2)))));
    
        photStim = record(photChan,:);
        sPhotStim = photStim ./ max(photStim(:));  % Scale to max value
        initialPhotic = 100 + 50 * sPhotStim;  % Save initial photic data
        plot(tb(min(trl(:,1)):blinkOnsInd), initialPhotic(min(trl(:,1)):blinkOnsInd));  % Eyes open period
        plot(tb(blinkOnsInd+1:blinkOffsetInd), initialPhotic(blinkOnsInd+1:blinkOffsetInd));  % During the blink
        plot(tb(blinkOffsetInd+1:max(trl(:,2))), initialPhotic(blinkOffsetInd+1:max(trl(:,2))));  % Eyes closed period
        
        title('Press "s" to skip or click on the plot to adjust the blink period start and end.');
        choice = waitforbuttonpress;  % Wait for a mouse click or button press
    
        if choice == 0  % Mouse click
            selected = false;
            while ~selected
                [x, ~] = ginput(2);  % Click two points on the plot to set new start and end for the blink period
                x = sort(x);  % Sort the clicked coordinates
                blinkOnsInd = round(x(1) * fs);  % Update the blink period indices
                blinkOffsetInd = round(x(2) * fs);
                % Prompt to confirm the selection
                disp('Check if the blink period looks right. If not, click again; else, press "s" to save.');
                choice = waitforbuttonpress;
                if choice == 1  % Check for a keypress
                    selected = true;  % If the choice is a keypress, exit the loop
                end
            end
        elseif choice == 1  % Button press
            % Keep the blink period the same (skip updating)
        end
        
        % Clear the figure and redraw the plot with the updated blink period
        clf
        plot(tb(min(trl(:,1)):max(trl(:,2))), fp1TW);
        hold on
        plot(tb(min(trl(:,1)):max(trl(:,2))), fp2TW);
    %    plot(tb(min(trl(:,1)):max(trl(:,2))), 50 * zscore(record(1, min(trl(:,1)):max(trl(:,2)))));
        photStim = record(photChan, :);
        sPhotStim = photStim ./ max(photStim(:));
        plot(tb(min(trl(:,1)):blinkOnsInd), 100 + 50 * sPhotStim(min(trl(:,1)):blinkOnsInd));  % Eyes open period
        plot(tb(blinkOnsInd + 1:blinkOffsetInd), 100 + 50 * sPhotStim(blinkOnsInd + 1:blinkOffsetInd));  % During the blink
        plot(tb(blinkOffsetInd + 1:max(trl(:,2))), 100 + 50 * sPhotStim(blinkOffsetInd + 1:max(trl(:,2))));  % Eyes closed period

        % Pause after plotting since the figure will be cleared for the next patient
        pause;
        fprintf('Press a key to continue...\n')
    end

    % Identifying the indices that fall within the "eyes open" and "eyes closed" periods
    % eyesOpenIndices = find(trl(:, 2) < blinkOnsInd); % Indices before the blink onset
    % eyesClosedIndices = find(trl(:, 1) > blinkOffsetInd); % Indices after the blink offset

    % Using these indices to extract the trial definitions for eyes open and eyes closed periods
    % eyesOpenTrl = trl(eyesOpenIndices, :);
    % eyesClosedTrl = trl(eyesClosedIndices, :);

    % For "eyes open"
    % Assuming you need to replace "conditionlabel" and "conditionlabels" based on your specific requirements
    % openTrialdef = struct('conditionlabel', '6HzFlash', 'eventtype', 'Stimulus', 'eventvalue', 1, 'trlshift', 0);
    % openConditionLabels = repmat({'6HzFlash'}, 1, size(eyesOpenTrl, 1));

    % For "eyes closed"
    % Again, change "conditionlabel" and "conditionlabels" accordingly
    % closedTrialdef = struct('conditionlabel', '6HzFlash', 'eventtype', 'Stimulus', 'eventvalue', 1, 'trlshift', 0);
    % closedConditionLabels = repmat({'6HzFlash'}, 1, size(eyesClosedTrl, 1));

    % Assuming the edfName variable contains the name of the EDF file
    % [~, edfFilename, ~] = fileparts(edfName);

    % Saving the open trial definition in the EDF file's directory
    % openTrialdefFilename = fullfile(sDir, ['trialdef_170_eyes_open_', edfFilename, '.mat']);
    % save(openTrialdefFilename, 'eyesOpenTrl', 'openTrialdef', 'timewin', 'openConditionLabels', 'source');

    % Saving the closed trial definition in the EDF file's directory
    % closedTrialdefFilename = fullfile(sDir, ['trialdef_170_eyes_closed_', edfFilename, '.mat']);
    % save(closedTrialdefFilename, 'eyesClosedTrl', 'closedTrialdef', 'timewin', 'closedConditionLabels', 'source');

end
