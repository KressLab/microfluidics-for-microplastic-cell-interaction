classdef CatBeads<MicrofluidicsEvaluation
    properties(Constant)
        CAT_INVALID='invalid';
        CAT_TOUCHING_CELL='touching';
        CAT_NOT_TOUCHING_CELL='notTouching';
        CAT_NOT_IN_FRAME='notInFrame';
    end
    
    properties
        cropRadius=40;
        net;
    end
    
    methods
        function obj = CatBeads(filename,loadResults,initFigure)
            obj=obj@MicrofluidicsEvaluation(filename,loadResults,initFigure);
        end
        
        function calculateClassifiedTrajectories(obj)
            beadTraj=cell(obj.getTrajectoryCount(),1);
            allBeadIds=unique(vertcat(obj.beadIds{:}))';
            for beadId=allBeadIds
                cat=obj.darkMagic(beadId,obj.beadCategories,categorical({obj.CAT_NOT_IN_FRAME}));
                pos=obj.darkMagic(beadId,obj.beadPositions,[NaN,NaN]);
                catScores=obj.darkMagic(beadId,obj.beadCategoryScores,[NaN,NaN]);
                beadTraj{beadId,1}=table(pos,cat,catScores);
            end
            obj.classifiedBeadTrajectories=beadTraj;
        end
        
        function writeImageFilesForTraining(obj,frameId)
            baseFolder=mfCnnConstants.getTrainDataFolder();
            TOUCHING_FOLDER=[baseFolder,filesep,obj.CAT_TOUCHING_CELL,filesep];
            NOT_TOUCHING_FOLDER=[baseFolder,filesep,obj.CAT_NOT_TOUCHING_CELL,filesep];
            
            mkdir(TOUCHING_FOLDER);
            mkdir(NOT_TOUCHING_FOLDER);
            obj.logger.info(obj.getShortFilename(),': Writing image files for training (TOUCHING_FOLDER) to ',TOUCHING_FOLDER);
            obj.logger.info(obj.getShortFilename(),': Writing image files for training (NOT_TOUCHING_FOLDER) to ',NOT_TOUCHING_FOLDER);
            
            [~,fileName]=fileparts(obj.filename);
            imgs=obj.cropBeadImagesForNetwork(frameId);
            for i=1:size(imgs,1)
                if obj.beadCategories{frameId,1}(i)==obj.CAT_TOUCHING_CELL && ~isempty(imgs{i,1})
                    try
                        imwrite(imgs{i,1},[TOUCHING_FOLDER,fileName,'_',num2str(frameId),'_',num2str(i),'.tif']);
                    catch e
                        obj.logger.debug('Unexpected error writing image ',i);
                        obj.logger.debug(e);
                    end
                elseif obj.beadCategories{frameId,1}(i)==obj.CAT_NOT_TOUCHING_CELL && ~isempty(imgs{i,1})
                    try
                        imwrite(imgs{i,1},[NOT_TOUCHING_FOLDER,fileName,'_',num2str(i),'.tif']);
                    catch e
                        obj.logger.debug('Unexpected error writing image ',i);
                        obj.logger.debug(e);
                    end
                end
            end
        end
        
        function plotConfusion(obj)
            imds = imageDatastore(mfCnnConstants.getTrainDataFolder(),'IncludeSubfolders',true,'FileExtensions','.tif','LabelSource','foldernames');
            lGraph=layerGraph(obj.net);
            augImds=augmentedImageDatastore(lGraph.Layers(1).InputSize(1:2),...
                                            imds,...
                                            'ColorPreprocessing','gray2rgb');
            
            res=classify(obj.net,augImds);
            [~,netname]=fileparts(mfCnnConstants.getNetworkPath());
            figure(3);
            plotconfusion(imds.Labels,res,netname);
        end

        function trainNetworkNew(obj,net,trainOpt,imageDataAug,trainDataFolder,trainRatio)
            imds = shuffle(imageDatastore(trainDataFolder,'IncludeSubfolders',true,'FileExtensions','.tif','LabelSource','foldernames'));
            total=min(imds.countEachLabel.Count);
            [imdsTrain,imdsValidation] = splitEachLabel(imds,floor(total*trainRatio),'randomize');
            augImdsTrain=augmentedImageDatastore(net.Layers(1).InputSize(1:2),...
                imdsTrain,...
                'DataAugmentation',imageDataAug,...
                'ColorPreprocessing','gray2rgb');
            augImdsValidation=augmentedImageDatastore(net.Layers(1).InputSize(1:2),...
                imdsValidation,...
                'DataAugmentation',imageDataAug,...
                'ColorPreprocessing','gray2rgb');
            obj.logger.info('Starting training with: ',imdsTrain.countEachLabel);
            obj.logger.info('Validating training with: ',imdsValidation.countEachLabel);
            if isa(trainOpt,'nnet.cnn.TrainingOptionsSGDM')
                trainOpt=trainingOptions('sgdm',...
                    'Momentum',trainOpt.Momentum,...
                    'InitialLearnRate',trainOpt.InitialLearnRate,...
                    'LearnRateDropFactor',trainOpt.LearnRateScheduleSettings.DropRateFactor,...
                    'LearnRateSchedule',trainOpt.LearnRateScheduleSettings.Method,...
                    'L2Regularization',trainOpt.L2Regularization,...
                    'GradientThresholdMethod',trainOpt.GradientThresholdMethod,...
                    'GradientThreshold', trainOpt.GradientThreshold,...
                    'MaxEpochs',trainOpt.MaxEpochs,...
                    'MiniBatchSize',trainOpt.MiniBatchSize,...
                    'Verbose',trainOpt.Verbose,...
                    'VerboseFrequency',trainOpt.VerboseFrequency,...
                    'ValidationData',augImdsValidation,...
                    'ValidationFrequency',trainOpt.ValidationFrequency,...
                    'ValidationPatience',trainOpt.ValidationPatience,...
                    'Shuffle',trainOpt.Shuffle,...
                    'CheckpointPath',trainOpt.CheckpointPath,...
                    'ExecutionEnvironment',trainOpt.ExecutionEnvironment,...
                    'WorkerLoad',trainOpt.WorkerLoad,...
                    'OutputFcn',trainOpt.OutputFcn,...
                    'Plots',trainOpt.Plots,...
                    'SequenceLength',trainOpt.SequenceLength,...
                    'SequencePaddingValue',trainOpt.SequencePaddingValue);
            elseif isa(trainOpt,'nnet.cnn.TrainingOptionsADAM')
                gradDec=1-trainOpt.MiniBatchSize/sum(imdsTrain.countEachLabel.Count);
                gradDecSquared=1-(trainOpt.MiniBatchSize/sum(imdsTrain.countEachLabel.Count)).^2;
                valFreq=floor(sum(imdsTrain.countEachLabel.Count)/trainOpt.MiniBatchSize);
                trainOpt=trainingOptions('adam',...
                    'GradientDecayFactor',gradDec,...
                    'SquaredGradientDecayFactor',gradDecSquared,...
                    'Epsilon',trainOpt.Epsilon,...
                    'InitialLearnRate',trainOpt.InitialLearnRate,...
                    'LearnRateDropFactor',trainOpt.LearnRateScheduleSettings.DropRateFactor,...
                    'LearnRateSchedule',trainOpt.LearnRateScheduleSettings.Method,...
                    'LearnRateDropPeriod',trainOpt.LearnRateScheduleSettings.DropPeriod,...
                    'L2Regularization',trainOpt.L2Regularization,...
                    'GradientThresholdMethod',trainOpt.GradientThresholdMethod,...
                    'GradientThreshold', trainOpt.GradientThreshold,...
                    'MaxEpochs',trainOpt.MaxEpochs,...
                    'MiniBatchSize',trainOpt.MiniBatchSize,...
                    'Verbose',trainOpt.Verbose,...
                    'VerboseFrequency',trainOpt.VerboseFrequency,...
                    'ValidationData',augImdsValidation,...
                    'ValidationFrequency',valFreq,...
                    'ValidationPatience',trainOpt.ValidationPatience,...
                    'Shuffle',trainOpt.Shuffle,...
                    'CheckpointPath',trainOpt.CheckpointPath,...
                    'ExecutionEnvironment',trainOpt.ExecutionEnvironment,...
                    'WorkerLoad',trainOpt.WorkerLoad,...
                    'OutputFcn',trainOpt.OutputFcn,...
                    'Plots',trainOpt.Plots,...
                    'SequenceLength',trainOpt.SequenceLength,...
                    'SequencePaddingValue',trainOpt.SequencePaddingValue);
            else
                error('unknown training options class');
            end
            obj.net=trainnet(augImdsTrain,net,"crossentropy",trainOpt);
        end
        
        function trainNetwork(obj,lGraph,trainOpt,imageDataAug,trainDataFolder,trainRatio)
            imds = shuffle(imageDatastore(trainDataFolder,'IncludeSubfolders',true,'FileExtensions','.tif','LabelSource','foldernames'));
            
            
            total=min(imds.countEachLabel.Count);
            [imdsTrain,imdsValidation] = splitEachLabel(imds,floor(total*trainRatio),'randomize');
            total=min(imdsValidation.countEachLabel.Count);
            [imdsValidation,~] = splitEachLabel(imdsValidation,total,'randomize');
            
            augImdsTrain=augmentedImageDatastore(lGraph.Layers(1).InputSize(1:2),...
                imdsTrain,...
                'DataAugmentation',imageDataAug,...
                'ColorPreprocessing','gray2rgb');
            augImdsValidation=augmentedImageDatastore(lGraph.Layers(1).InputSize(1:2),...
                imdsValidation,...
                'DataAugmentation',imageDataAug,...
                'ColorPreprocessing','gray2rgb');
            
            obj.logger.info('Starting training with: ',imdsTrain.countEachLabel);
            obj.logger.info('Validating training with: ',imdsValidation.countEachLabel);
            if isa(trainOpt,'nnet.cnn.TrainingOptionsSGDM')
                trainOpt=trainingOptions('sgdm',...
                    'Momentum',trainOpt.Momentum,...
                    'InitialLearnRate',trainOpt.InitialLearnRate,...
                    'LearnRateDropFactor',trainOpt.LearnRateScheduleSettings.DropRateFactor,...
                    'LearnRateSchedule',trainOpt.LearnRateScheduleSettings.Method,...
                    'L2Regularization',trainOpt.L2Regularization,...
                    'GradientThresholdMethod',trainOpt.GradientThresholdMethod,...
                    'GradientThreshold', trainOpt.GradientThreshold,...
                    'MaxEpochs',trainOpt.MaxEpochs,...
                    'MiniBatchSize',trainOpt.MiniBatchSize,...
                    'Verbose',trainOpt.Verbose,...
                    'VerboseFrequency',trainOpt.VerboseFrequency,...
                    'ValidationData',augImdsValidation,...
                    'ValidationFrequency',trainOpt.ValidationFrequency,...
                    'ValidationPatience',trainOpt.ValidationPatience,...
                    'Shuffle',trainOpt.Shuffle,...
                    'CheckpointPath',trainOpt.CheckpointPath,...
                    'ExecutionEnvironment',trainOpt.ExecutionEnvironment,...
                    'WorkerLoad',trainOpt.WorkerLoad,...
                    'OutputFcn',trainOpt.OutputFcn,...
                    'Plots',trainOpt.Plots,...
                    'SequenceLength',trainOpt.SequenceLength,...
                    'SequencePaddingValue',trainOpt.SequencePaddingValue);
            elseif isa(trainOpt,'nnet.cnn.TrainingOptionsADAM')
                gradDec=1-trainOpt.MiniBatchSize/sum(imdsTrain.countEachLabel.Count);
                gradDecSquared=1-(trainOpt.MiniBatchSize/sum(imdsTrain.countEachLabel.Count)).^2;
                valFreq=floor(sum(imdsTrain.countEachLabel.Count)/trainOpt.MiniBatchSize);
                trainOpt=trainingOptions('adam',...
                    'GradientDecayFactor',gradDec,...
                    'SquaredGradientDecayFactor',gradDecSquared,...
                    'Epsilon',trainOpt.Epsilon,...
                    'InitialLearnRate',trainOpt.InitialLearnRate,...
                    'LearnRateDropFactor',trainOpt.LearnRateScheduleSettings.DropRateFactor,...
                    'LearnRateSchedule',trainOpt.LearnRateScheduleSettings.Method,...
                    'LearnRateDropPeriod',trainOpt.LearnRateScheduleSettings.DropPeriod,...
                    'L2Regularization',trainOpt.L2Regularization,...
                    'GradientThresholdMethod',trainOpt.GradientThresholdMethod,...
                    'GradientThreshold', trainOpt.GradientThreshold,...
                    'MaxEpochs',trainOpt.MaxEpochs,...
                    'MiniBatchSize',trainOpt.MiniBatchSize,...
                    'Verbose',trainOpt.Verbose,...
                    'VerboseFrequency',trainOpt.VerboseFrequency,...
                    'ValidationData',augImdsValidation,...
                    'ValidationFrequency',valFreq,...
                    'ValidationPatience',trainOpt.ValidationPatience,...
                    'Shuffle',trainOpt.Shuffle,...
                    'CheckpointPath',trainOpt.CheckpointPath,...
                    'ExecutionEnvironment',trainOpt.ExecutionEnvironment,...
                    'WorkerLoad',trainOpt.WorkerLoad,...
                    'OutputFcn',trainOpt.OutputFcn,...
                    'Plots',trainOpt.Plots,...
                    'SequenceLength',trainOpt.SequenceLength,...
                    'SequencePaddingValue',trainOpt.SequencePaddingValue);
            else
                error('unknown training options class');
            end
            obj.net = trainNetwork(augImdsTrain,lGraph,trainOpt);
        end
        
        function classifyAllFrames(obj)
            obj.clearClassification();
            obj.logger.info(obj.getShortFilename(), ': Classifying all Frames automatically.');
            beadCats=obj.beadCategories;
            beadCatScores=obj.beadCategoryScores;
            parfor i=1:obj.getFrameCount()
                if ~isempty(obj.beadPositions{i,1})
                    [beadImgs,beadFrameIds]=obj.resizeBeadImagesForNetwork(obj.cropBeadImagesForNetwork(i));
                    if ~isempty(beadFrameIds) % beadIds can be empty when the only bead(s) are too close to the boundary
                        [beadCats{i,1}(beadFrameIds,:),...
                         beadCatScores{i,1}(beadFrameIds,:)]=classify(obj.net,beadImgs,'ExecutionEnvironment','auto',...
                                                                                       'Acceleration','auto',...
                                                                                       'MiniBatchSize',6);
                        touchingCount=sum(beadCats{i,1}==obj.CAT_TOUCHING_CELL);
                        notTouchingCount=sum(beadCats{i,1}==obj.CAT_NOT_TOUCHING_CELL);
                    else
                        touchingCount=0;
                        notTouchingCount=0;
                    end
                else
                    touchingCount=0;
                    notTouchingCount=0;
                end
                obj.logger.info(obj.getShortFilename(), ': Frame ', i,': Touching: ',touchingCount,' Not touching: ',notTouchingCount);
            end
            obj.beadCategories=beadCats;
            obj.beadCategoryScores=beadCatScores;
        end
        
        function beadTraj=getClassifiedBeadTrajectories(obj)
            if isempty(obj.classifiedBeadTrajectories)
                obj.calculateClassifiedTrajectories();
            end
            beadTraj=obj.classifiedBeadTrajectories;
        end
        
        function classifyFrame(obj,frameId)
            [imgs,beadFrameIds]=obj.resizeBeadImagesForNetwork(obj.cropBeadImagesForNetwork(frameId));
            [obj.beadCategories{frameId,1}(beadFrameIds,:),...
                obj.beadCategoryScores{frameId,1}(beadFrameIds,:)]=classify(obj.net,imgs,'ExecutionEnvironment','gpu');
            
            
            touchingCount=sum(obj.beadCategories{frameId,1}==obj.CAT_TOUCHING_CELL);
            notTouchingCount=sum(obj.beadCategories{frameId,1}==obj.CAT_NOT_TOUCHING_CELL);
            obj.logger.info(obj.getShortFilename(), ' frame ', frameId,': Touching: ',touchingCount,' Not touching: ',notTouchingCount);
        end
        
        function loadNetwork(obj)
            obj.logger.info(obj.getShortFilename(),': Loading network ', mfCnnConstants.getNetworkPath());
            loaded=load(mfCnnConstants.getNetworkPath(),'net');
            obj.net=loaded.net;
        end
        
        function saveNetwork(obj,filename)
            net=obj.net;
            save(filename,'net');
            obj.logger.info(obj.getShortFilename(),': Saved network ', filename);
        end
        
        function lgraph=getNetworkLayerGraph(obj)
            try
                lgraph=layerGraph(obj.net);
            catch e
                if strcmp(e.identifier,'nnet_cnn:layerGraph:InvalidLayerArray')
                    lgraph=layerGraph(obj.net.Layers);
                else
                    rethrow(e);
                end
            end
        end
        
        function [timeAfterMotorStartS,relCount]=getRelStatusCountTimeDependence(obj,status)
            relCount=nan(1,obj.getFrameCount());
            for i=1:obj.getFrameCount()
                relCount(1,i)=sum(obj.beadCategories{1,1}==status);
            end
            
            motorOn=abs(obj.cctlResult.microfluidics.flowRateM3S)>0;
            firstMotorOn=find(motorOn,1);
            timeAfterMotorStartS=obj.cctlResult.timesS(firstMotorOn:end)-obj.cctlResult.timesS(firstMotorOn);
            relCount=relCount(firstMotorOn:end)./relCount(firstMotorOn);
        end
    end
    
    methods(Access=private)
        function angryBunny=darkMagic(theBunny,theMagician,someDarkSalt,psychodelicHerb)
            metaBunny=cellfun(@(x)(x==theMagician),theBunny.beadIds,'UniformOutput',false);
            angryBunny=cellfun(@(a,metaBunny)(a(metaBunny,:)),someDarkSalt,metaBunny,'UniformOutput',false);
            angryBunny(cellfun(@isempty,angryBunny))={psychodelicHerb};
            angryBunny=vertcat(angryBunny{:});
        end
        
        % this is (and has to be) in line with the transformations taken by the
        % augmentedImageDatastore used for training
        function [imgs,validBeadIndices]=resizeBeadImagesForNetwork(obj,imgs)
            [imgs,validBeadIndices]=selectValidImgs(obj,imgs);
            lgraph=obj.getNetworkLayerGraph();
            neuralNetImageInputSize=lgraph.Layers(1).InputSize;
            for i=1:size(imgs,1)
                imgs{i,1}=imresize(imgs{i,1},neuralNetImageInputSize(1:2));
                if size(imgs{i,1},3)==1
                    imgs{i,1}=repmat(imgs{i,1},1,1,neuralNetImageInputSize(3)); % gray to rgb color
                end
            end
            imgs=cell2table(imgs);
        end
        
        function [validImgs,validImgIndices]=selectValidImgs(~,imgs)
            validImgs=cellfun(@(x)(~isempty(x)),imgs);
            
            allImgIdx=(1:size(imgs,1))';
            validImgIndices=allImgIdx(validImgs);
            validImgs=imgs(validImgs);
        end
        
        function imgs=cropBeadImagesForNetwork(obj,frameId)
            imgs=cell(0);
            beadPosInFrame=obj.beadPositions{frameId,1};
            
            [bpassedimg,localContrastImg,enhancedEdges]=getDetectionImages(obj,frameId);
            for i=1:size(beadPosInFrame,1)
                pk=round(beadPosInFrame(i,:));
                xlow=pk(1,1)-obj.cropRadius;
                xhigh=pk(1,1)+obj.cropRadius;
                ylow=pk(1,2)-obj.cropRadius;
                yhigh=pk(1,2)+obj.cropRadius;
                try
                    red=scaleMatToRange(bpassedimg(ylow:yhigh,xlow:xhigh),0,255);
                    
                    green=enhancedEdges(ylow:yhigh,xlow:xhigh);
                    center=obj.cropRadius+1;
                    green(center-1:center+1,center)=255;
                    green(center,center-1:center+1)=255;
                    
                    blue=localContrastImg(ylow:yhigh,xlow:xhigh);
                    cropImg=cat(3,red,green,blue);
                    imgs{i,1}=uint8(cropImg);
                catch
                    imgs{i,1}=[];
                end
            end
        end
        
        function [img,img2,img3]=getDetectionImages(obj,frameId)
            img=obj.getImage(frameId);
            img=fastBPass(img,1,obj.cropRadius,-inf);
            img=scaleMatToRange(img,0,255);
            
            imgMed=img-median(img(:));
            img2=imgMed;
            img2(img2<0)=0;
            img2=scaleMatToRange(img2,0,255);
            img3=-imgMed;
            img3(img3<0)=0;
            img3=scaleMatToRange(img3,0,255);
        end
    end
end
