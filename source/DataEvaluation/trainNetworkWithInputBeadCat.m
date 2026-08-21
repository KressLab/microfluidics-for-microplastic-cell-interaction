%Copyright 2026 Wolfgrang Gross, Matteo Kumar
%
%Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
%
%Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
%Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
%Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
%
%THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
%STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 
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
    bl.detectBeads();
    bl.saveBeadStatus();
end

%% Manually classify images. Use the keyboard. For key bindings, see MicrofluidicsEvaluation.WindowKeyPressFunction
cb=CatBeads([FILENAMES{1,1}(1:(end-4))],true,true);
%Do not close window before saving!

%% Save manually classified bead status
cb.saveBeadStatus();

%% Manually copy classified new training source data to source folder
try
    copyfile([mfCnnConstants.getTrainDataSourceFolderNew,filesep,'*'],mfCnnConstants.getTrainDataSourceFolder());
catch e
    l.error(e);
end
%% Write training data
try
    rmdir(mfCnnConstants.getTrainDataFolder(),'s');
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
net=imagePretrainedNetwork("googlenet",Weights = 'pretrained',NumClasses=2);
% lgraph=net.layerGraph();


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
cb.trainNetworkNew(net,trainOpt,aug,mfCnnConstants.getTrainDataFolder(),0.8);
%make sure to adjust the network path in mfCnnConstants.getNetworkPath() to
%the path where you want to save your network!
cb.saveNetwork(mfCnnConstants.getNetworkPath());
%% Test network
%You can use this example to explore the method
%for your own usage, statethe filenames you want to use for testing in
%ORIGINAL_FILENAMES as a cell array
%make sure to adjust the network path in mfCnnConstants.getNetworkPath()
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
            if isa(cb.net, 'dlnetwork')
                cb.classifyAllFramesDlNetwork([string(CatBeads.CAT_TOUCHING_CELL), string(CatBeads.CAT_NOT_TOUCHING_CELL)]);
            else    
                cb.classifyAllFrames();
            end
            cb.saveBeadStatus();
        end
    catch e
        l.error(FILENAMES{i,1}(1:(end-4)), ' COULD NOT BE PROCESSED. See log.',e);
    end
end
%display figure for checking
cb.initFigure();




