 clear;
%% Global params
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);
l.setLogLevel(Logger.DEBUG);

%% Copy to training folder new
%You can use this example to explore the method
%for your own usage, statethe filenames you want to use for training in
%ORIGINAL_FILENAMES as a cell array
ORIGINAL_FILENAMES = getFilesByRegexName(append(char(currentProject().RootFolder),filesep,'data'),false,'mf240828_micromodNR3_50pN_Channel2_01_40min.tif');
for i=1:size(ORIGINAL_FILENAMES,2)
    mfe=MicrofluidicsEvaluation(ORIGINAL_FILENAMES{1,i}(1:(end-4)),false,false);
    mps=MeasurementPhaseSegmenter(ORIGINAL_FILENAMES{1,i}(1:(end-4)));
    mps.setForce(mfe.getForceN());
    [~,~,ruptureStartFrame]= mps.getPhaseStartFrames();
    mfe.copyFrameToLearningSourceFolderNew(ruptureStartFrame-10);
end

%% Particle detection in new folder
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);

FILENAMES=getFilesByRegexName(mfCnnConstants.getTrainDataSourceFolderNew(),true,'mf.+.tif')';

beadCCThresh=0.87;
movingMedianRange=0;
for i=1:size(FILENAMES,2)
    bl=BeadLocalization(FILENAMES{1,i}(1:(end-4)),false,true);
    % bl.detectBeads(movingMedianRange,beadCCThresh);           %
    % detectBeads nimmt nur obj als Argument; obige Zeile wirft einen
    % Fehler
    bl.detectBeads();
    bl.saveBeadStatus();
end

%% Manually classify images. Use the keyboard. For key bindings, see MicrofluidicsEvaluation.WindowKeyPressFunction
cb=CatBeads([FILENAMES{1,1}(1:(end-4))],true,true);

%% Save manually classified bead status
cb.saveBeadStatus();

%% Manually copy classified new training source data to source folder
% to be automized

%% Write training data
try
    rmdir(mfCnnConstants.getTrainDataFolder(),'s'); % ich bin ein bisschen verwirrt, welcher Ordner für was da ist
end
FILENAMES=getFilesByRegexName(mfCnnConstants.getTrainDataSourceFolder(),true,'.+.tif')';
for i=1:size(FILENAMES,2)
    try
        cb=CatBeads(FILENAMES{1,i}(1:(end-4)),true,false);
        cb.writeImageFilesForTraining(1);
    catch e
        l.error(e);
    end
end

%% Train Network
FILENAMES=getFilesByRegexName(mfCnnConstants.getTrainDataSourceFolder(),true,'mf.+.tif')';
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);

% Train new network; 
% uses the googlenet network; requires the MATLAB Deep Learning Toolbox™ Model for GoogLeNet Network
% weights = 'none' should be supported without logging in;
% otherwise set Weights = 'pretrained'
net=imagePretrainedNetwork("googlenet",Weights = 'none',NumClasses=2);
% lgraph=net.layerGraph();

%old fct
% lgraph=getPretrainedTransferNetworkLayerGraph('googlenet',2,'Dropout',0.5,'WeightLearnRateFactor',1.5,'BiasLearnRateFactor',1.5);

% Retrain old network
%lgraph=cb.getNetworkLayerGraph();

trainOpt=trainingOptions('adam',...
                        'GradientDecayFactor',0.90,...
                        'SquaredGradientDecayFactor',0.99,...
                        'Epsilon',1E-6,...
                        'InitialLearnRate',3E-4,...
                        'LearnRateDropFactor',0.5,...
                        'LearnRateSchedule','piecewise',...
                        'LearnRateDropPeriod',10,...
                        'L2Regularization',1E-4,...
                        'GradientThresholdMethod','l2norm',...
                        'GradientThreshold', Inf,...
                        'MaxEpochs',8000,...
                        'MiniBatchSize',64,...
                        'Verbose',1,...
                        'VerboseFrequency',10,...
                        'ValidationPatience',Inf,...
                        'Shuffle','every-epoch',...
                        'CheckpointPath',fileparts(mfCnnConstants.getNetworkPath()),...
                        'Plots','training-progress');

aug = imageDataAugmenter('RandXReflection',true,...
                         'RandYReflection',true,...
                         'RandRotation',[0,360],...@randRotAngle90,...
                         'RandXScale',[0.5,2],...
                         'RandYScale',[0.5,2],...
                         'RandXShear',[-15,15],...
                         'RandYShear',[-15,15],...
                         'RandXTranslation',[-3,3],...
                         'RandYTranslation',[-3,3]);
                     
cb=CatBeads(FILENAMES{1,1}(1:(end-4)),false,false);
% cb.trainNetwork(net,trainOpt,aug,mfCnnConstants.getTrainDataFolder(),0.8);
cb.trainNetworkNew(net,trainOpt,aug,mfCnnConstants.getTrainDataFolder(),0.8);
% imds = shuffle(imageDatastore(mfCnnConstants.getTrainDataFolder(),'IncludeSubfolders',true,'FileExtensions','.tif','LabelSource','foldernames'));
% total=min(imds.countEachLabel.Count);
% trainRatio = 0.8;
% [imdsTrain,imdsValidation] = splitEachLabel(imds,floor(total*trainRatio),'randomize');
% augImdsTrain=augmentedImageDatastore(net.Layers(1).InputSize(1:2),...
%                 imdsTrain,...
%                 'DataAugmentation',aug,...
%                 'ColorPreprocessing','gray2rgb');
% net=trainnet(augImdsTrain,net,"crossentropy",trainOpt);
cb.saveNetwork(mfCnnConstants.getNetworkPath());
%% Test network
%You can use this example to explore the method
%for your own usage, statethe filenames you want to use for testing in
%ORIGINAL_FILENAMES as a cell array
ORIGINAL_FILENAMES = getFilesByRegexName(append(char(currentProject().RootFolder),filesep,'data'),false,'mf250129_micromodCOOH_400pN_Channel05_01_40min.tif');
for i=1:size(ORIGINAL_FILENAMES,2)
    mfe=MicrofluidicsEvaluation(ORIGINAL_FILENAMES{1,i}(1:(end-4)),false,false);
    mps=MeasurementPhaseSegmenter(ORIGINAL_FILENAMES{1,i}(1:(end-4)));
    mps.setForce(mfe.getForceN());
    [~,~,ruptureStartFrame]= mps.getPhaseStartFrames();
    mfe.copyFrameToTestFolder(ruptureStartFrame-10);
end
%particle detection
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);

FILENAMES=getFilesByRegexName(mfCnnConstants.getTestFolder(),true,'mf.+.tif')';

beadCCThresh=0.87;
movingMedianRange=0;
for i=1:size(FILENAMES,2)
    bl=BeadLocalization(FILENAMES{1,i}(1:(end-4)),false,true);
    bl.detectBeads();
    bl.saveBeadStatus();
end
%track particles
for i=1:size(FILENAMES,1)
    try
        bl=BeadLocalization(FILENAMES{i,1}(1:(end-4)),true,false);

        if all(cellfun(@isempty,bl.beadIds))
            bl.trackBeadsUTrack(UTrackParametersMFCellEval());
            bl.saveBeadStatus();
        end
    catch e
        l.error(FILENAMES{i,1}(end-4), ' COULD NOT BE PROCESSED. See log.',e);
    end
end
%particle classification by new net
for i=1:size(FILENAMES,1)
    try
        cb=CatBeads(FILENAMES{i,1}(1:(end-4)),true,false);
        if ~all(cellfun(@isempty,cb.beadIds)) && all(vertcat(cb.beadCategories{:})==CatBeads.CAT_INVALID)
            cb.loadNetwork();
            cb.classifyAllFramesDlNetwork([string(CatBeads.CAT_TOUCHING_CELL), string(CatBeads.CAT_NOT_TOUCHING_CELL)]);
            cb.saveBeadStatus();
        end
    catch e
        l.error(FILENAMES{i,1}(1:(end-4)), ' COULD NOT BE PROCESSED. See log.',e);
    end
end
%display figure for checking
cb.initFigure();




