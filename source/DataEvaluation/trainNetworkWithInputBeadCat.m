 clear;
%% Global params
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);
l.setLogLevel(Logger.DEBUG);

%% Copy to training folder new
% ORIGINAL_FILENAMES=getFilesByRegexName('/ep1/home/wolfgang/Messdaten/mf/',true,'^mf016(.+).tif$')';
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

FILENAMES=getFilesByRegexName(mfCnnConstants.getTrainDataSourceFolder(),true,'mf.+.tif')';% reicht hier auch der Ordner mit den einzelnen Frames fürs Training, also mfCnnConstants.getTrainDataSourceFolderNew()?

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
cb=CatBeads([FILENAMES{1,1}(1:(end-4))],true,true); % only one frame for categorization?

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

% Train new network
lgraph=getPretrainedTransferNetworkLayerGraph('googlenet',2,'Dropout',0.5,'WeightLearnRateFactor',1.5,'BiasLearnRateFactor',1.5);
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
                        'MaxEpochs',50000,...
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
cb.trainNetwork(lgraph,trainOpt,aug,mfCnnConstants.getTrainDataFolder(),0.8);
cb.saveNetwork(mfCnnConstants.getNetworkPath());
cb.initFigure();







