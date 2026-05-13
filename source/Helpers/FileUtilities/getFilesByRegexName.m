function fileList = getFilesByRegexName(directory,recursion,fileNameRegex,folderNameRegex,removeFileTypeExtension)
    if nargin<5
        removeFileTypeExtension=false;
    end
    if nargin<4
        folderNameRegex=[];
    end
    dirData = dir(directory);      %# Get the data for the current directory
    dirIndex = [dirData.isdir];  %# Find the index for directories
    fileList = {dirData(~dirIndex).name}';  %'# Get a list of the files
    if ~isempty(fileList)
        fileList=filterByRegexName(fileList,fileNameRegex);
        fileList = cellfun(@(x) fullfile(directory,x),...  %# Prepend path to files
                              fileList,'UniformOutput',false);
        if removeFileTypeExtension
            for i=1:size(fileList,1)
                [path,file,~]=fileparts(fileList{i,1});
                fileList{i,1}=[path,filesep,file];
            end
        end
        if ~isempty(folderNameRegex)
            fileList=filterByRegexName(fileList,folderNameRegex);
        end
    end
    if recursion
        subDirs = {dirData(dirIndex).name};  %# Get a list of the subdirectories
        validIndex = ~ismember(subDirs,{'.','..'});  %# Find index of subdirectories
        %#   that are not '.' or '..'
        for iDir = find(validIndex)                  %# Loop over valid subdirectories
            nextDir = fullfile(directory,subDirs{iDir});    %# Get the subdirectory path
            fileList = [fileList; getFilesByRegexName(nextDir,recursion,fileNameRegex,folderNameRegex,removeFileTypeExtension)];  %# Recursively call getAllFiles
        end
    end
end