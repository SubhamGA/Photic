% Script to compute mean and standard deviation and create a line graph

basePath = 'C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\'; %Photic0001\weffMunoFPspmeeg_Photic0001\condition_EO_effectRep3.nii,1';
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\meffMunoFPspmeeg_Photic0001.mat
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\tmeffMunoFPspmeeg_Photic0001\condition_6HzFlash.nii,1
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\meffMunoFPspmeeg_Photic0001_1_t-20_150_f_1.nii,1
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\weffMunoFPspmeeg_Photic0001\condition_EffectRep3.nii,1
% Initialize a cell array to store the paths
% allPaths = cell(53, 1);

% Loop through numbers 1 to 26 and 2000 to 2026
grpA = 1:26;
grpB = 2001:2026;
grpAfiles = [];
grpBfiles = [];
condName = 'condition_EffectRep0';
for i = grpA
    sName = sprintf('Photic%04d',i);
    fname = fullfile(basePath,sName,sprintf('weffMunoFPspmeeg_%s',sName),sprintf('%s.nii,1',condName));
    grpAfiles = strvcat(grpAfiles,fname);
end

for i = grpB
    sName = sprintf('Photic%04d',i);
    fname = fullfile(basePath,sName,sprintf('weffMunoFPspmeeg_%s',sName),sprintf('%s.nii,1',condName));
    grpBfiles = strvcat(grpBfiles,fname);
end


% First script to compute mean and standard deviation
baseDir = pwd;  % Change this to your base directory

% % Example: Assuming you have two groups, Group A and Group B
% fnamesGroupA = spm_select(inf, 'image', 'Select images for Group A', [], baseDir);
% fnamesGroupB = spm_select(inf, 'image', 'Select images for Group B', [], baseDir);

% Read image headers and information for Group A
VGroupA = spm_vol(grpAfiles);
YGroupA = spm_read_vols(VGroupA);
stdDataGroupA = std(YGroupA, 0, 4);
meanDataGroupA = mean(YGroupA, 4);
sampleSizeGroupA = numel(VGroupA);

% Read image headers and information for Group B
VGroupB = spm_vol(grpBfiles);
YGroupB = spm_read_vols(VGroupB);
stdDataGroupB = std(YGroupB, 0, 4);
meanDataGroupB = mean(YGroupB, 4);
sampleSizeGroupB = numel(VGroupB);

% Compute standard error
stderrGroupA = stdDataGroupA / sqrt(sampleSizeGroupA);
stderrGroupB = stdDataGroupB / sqrt(sampleSizeGroupB);

% Now construct headers to write out the standard deviation images
Vout_std_GroupA = rmfield(VGroupA(1), {'fname', 'private', 'descrip'});
Vout_std_GroupA.descrip = sprintf('Standard deviation across %d subjects (Group A)', numel(VGroupA));
Vout_std_GroupA.fname = fullfile(baseDir, sprintf('stdPhotic_GroupA_%02dsubs.nii', numel(VGroupA)));
Vout_std_GroupA = spm_write_vol(Vout_std_GroupA, stdDataGroupA);

Vout_std_GroupB = rmfield(VGroupB(1), {'fname', 'private', 'descrip'});
Vout_std_GroupB.descrip = sprintf('Standard deviation across %d subjects (Group B)', numel(VGroupB));
Vout_std_GroupB.fname = fullfile(baseDir, sprintf('stdPhotic_GroupB_%02dsubs.nii', numel(VGroupB)));
Vout_std_GroupB = spm_write_vol(Vout_std_GroupB, stdDataGroupB);

% Now construct headers to write out the mean images
Vout_mean_GroupA = rmfield(VGroupA(1), {'fname', 'private', 'descrip'});
Vout_mean_GroupA.descrip = sprintf('Mean VEP across %d subjects (Group A)', numel(VGroupA));
Vout_mean_GroupA.fname = fullfile(baseDir, sprintf('meanPhotic_GroupA_%02dsubs.nii', numel(VGroupA)));
Vout_mean_GroupA = spm_write_vol(Vout_mean_GroupA, meanDataGroupA);

Vout_mean_GroupB = rmfield(VGroupB(1), {'fname', 'private', 'descrip'});
Vout_mean_GroupB.descrip = sprintf('Mean VEP across %d subjects (Group B)', numel(VGroupB));
Vout_mean_GroupB.fname = fullfile(baseDir, sprintf('meanPhotic_GroupB_%02dsubs.nii', numel(VGroupB)));
Vout_mean_GroupB = spm_write_vol(Vout_mean_GroupB, meanDataGroupB);

figure;

% Second script to create a line graph using mean and standard deviation data

% Create time vector
tb = (1:size(meanDataGroupA, 3)) / 500 - 0.02;

% Plot average voltage for Group A
plot(tb, squeeze(meanDataGroupA(19, 3, :)), 'LineWidth', 2, 'Color', 'b');
hold on

% Plot standard deviation for Group A
std_upper_GroupA = squeeze(meanDataGroupA(19, 3, :) + stderrGroupA(19, 3, :));
std_lower_GroupA = squeeze(meanDataGroupA(19, 3, :) - stderrGroupA(19, 3, :));
std_upper_GroupA = std_upper_GroupA';
std_lower_GroupA = std_lower_GroupA';
fill([tb, fliplr(tb)], [std_upper_GroupA, fliplr(std_lower_GroupA)], 'b', 'FaceAlpha', 0.3);

% Plot average voltage for Group B
plot(tb, squeeze(meanDataGroupB(19, 3, :)), 'LineWidth', 2, 'Color', 'r');

% Plot standard deviation for Group B
std_upper_GroupB = squeeze(meanDataGroupB(19, 3, :) + stderrGroupB(19, 3, :));
std_lower_GroupB = squeeze(meanDataGroupB(19, 3, :) - stderrGroupB(19, 3, :));
std_upper_GroupB = std_upper_GroupB';
std_lower_GroupB = std_lower_GroupB';
fill([tb, fliplr(tb)], [std_upper_GroupB, fliplr(std_lower_GroupB)], 'r', 'FaceAlpha', 0.3);

hold off

xlim([tb(1), 0.15]);

% Set axis labels and title
xlabel('Time (s)')
ylabel('Average Field Intensity (uV)')
% title('Average Voltage Over Time with Standard Deviation (Groups A and B)')
title('Average Voltage Over Time with Standard Error (Groups A and B)')

% Add legend with explicit line styles and colors
% legend('Group A - Mean', 'Group A - Standard Deviation', 'Group B - Standard Deviation', 'Group B - Mean', 'Location', 'Best')
legend('Photic - Mean', 'Photic - Standard Error', 'Non-Photic - Mean', 'Non-Photic - Standard Error', 'Location', 'Best')

% Adjust other plot properties as needed
grid on

dataA = squeeze(YGroupA(19,3,:,:));
dataB = squeeze(YGroupB(19,3,:,:));
[H,P] = ttest2(dataA',dataB');
fprintf('number of significant differences at p<0.05 = %d\n',numel(find(P<0.05)))