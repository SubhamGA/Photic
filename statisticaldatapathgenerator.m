basePath = 'C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\weffMunoFPspmeeg_Photic0001\condition_noFP_effectRep0.nii,1';
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\meffMunoFPspmeeg_Photic0001.mat
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\tmeffMunoFPspmeeg_Photic0001\condition_6HzFlash.nii,1
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\meffMunoFPspmeeg_Photic0001_1_t-20_150_f_1.nii,1
% C:\Users\rick2\Documents\MATLAB\Winston_Lab\Photic\Data\Photic0001\weffMunoFPspmeeg_Photic0001\condition_EffectRep3.nii,1
% Initialize a cell array to store the paths
allPaths = cell(53, 1);

% Loop through numbers 1 to 26 and 2000 to 2026
for i = [1:26, 2001:2026] % 2001:2026 
    % Replace 'Photic0001' with the current number
    currentPath = strrep(basePath, 'Photic0001', sprintf('Photic%04d', i));
    
    % Store the generated path in the cell array
    allPaths{i} = currentPath;
    
    % Display the path as text
    disp(currentPath);
end

