classdef UTrackWrapper<handle
    properties(Access=private)
        logger;
        movieInfo;
        dim;
        frameCount;
        trackingDone;
        
        tracks;
        uTrackParameters;
        kalmanInfoLink;
    end
    
    methods(Access=public)
        function obj=UTrackWrapper()
            obj.logger=Logger.getInstance();
            obj.clearData();
            warning("u-track V 2.3 has to be downloaded and added to the project (or MATLAB path) for this file to work properly.");
            warning("Download from: https://github.com/DanuserLab/u-track/releases/tag/v2.3");
        end
        
        function clearData(obj)
            obj.movieInfo=struct([]);
            obj.frameCount=0;
            obj.trackingDone=false;
            obj.dim=NaN;
        end
        
        function setUTrackParameters(obj,uTrackParameters)
            obj.uTrackParameters=uTrackParameters;
        end
        
        function setMovieInfo(obj,movieInfo,dim)
            obj.movieInfo=movieInfo;
            obj.setDimension(dim);
            obj.trackingDone=false;
        end
        
        function setPositionsInNewFrame(obj,pos)
            obj.trackingDone=false;
            obj.frameCount=obj.frameCount+1;
            if ~isempty(pos)
                framePartCount=size(pos,1);
                obj.movieInfo(obj.frameCount).xCoord=[pos(:,1),zeros(framePartCount,1)];
                obj.movieInfo(obj.frameCount).yCoord=[pos(:,2),zeros(framePartCount,1)];
                obj.movieInfo(obj.frameCount).amp=[ones(framePartCount,2),zeros(framePartCount,2)];
                obj.setDimension(size(pos,2));
            end
        end
        
        function setDimension(obj,dim)
            if ~isnan(obj.dim) && obj.dim~=dim
                obj.logger.fatal(obj.dim, ' is not equal to the dimension specified before: ', dim);
            end
            obj.dim=dim;
        end
        
        function loadTestData(obj)
            obj.movieInfo=getUTrackTestData();
        end
        
        function count=getFrameCount(obj)
             count = obj.frameCount;
        end
        
        function [positions,ids]=getTrackCellByFrames(obj)
            obj.track();
            positions=cell(obj.getFrameCount(),1);
            ids=cell(obj.getFrameCount(),1);
            
            [trackedFeatureInfo,~,~,~] = convStruct2MatIgnoreMS(obj.tracks);
            tracksX = trackedFeatureInfo(:,1:8:end)';
            tracksY = trackedFeatureInfo(:,2:8:end)';
            % interpolate tracks
            for trackId=1:size(tracksX,2)
                tracksX(:,trackId)=obj.interpolateVect(tracksX(:,trackId));
                tracksY(:,trackId)=obj.interpolateVect(tracksY(:,trackId));
            end
            
            for i=1:size(tracksX,1)
                validIds=find(~isnan(tracksX(i,:)));
                positions{i,1}=[tracksX(i,validIds)',tracksY(i,validIds)'];
                ids{i,1}=validIds';
            end
        end
        
        function vect=interpolateVect(obj,vect)
            interpStartFrame=NaN;
            interpStartVal=NaN;
            for frameId=1:length(vect)-1
                if frameId>interpStartFrame && ~isnan(interpStartFrame) && ~isnan(vect(frameId)) && isnan(vect(frameId-1))
                    interpEndFrame=frameId;
                    interpEndVal=vect(frameId);
                    
                    framesSinceStart=linspace(interpStartFrame,interpEndFrame,interpEndFrame-interpStartFrame+1)-interpStartFrame;
                    valDiff=interpEndVal-interpStartVal;
                    vect(interpStartFrame:interpEndFrame)=interpStartVal+framesSinceStart/max(framesSinceStart)*valDiff;
                    interpStartFrame=NaN;
                    interpStartVal=NaN;
                end
                if ~isnan(vect(frameId)) && isnan(vect(frameId+1))
                    interpStartFrame=frameId;
                    interpStartVal=vect(frameId);
                end
            end
        end
        
        function track(obj)
            if obj.trackingDone
                return;
            end            
            
            costMatrices(1).funcName = obj.uTrackParameters.getFrameLinkingFuncName();            
            costMatrices(1).parameters = obj.uTrackParameters.getFrameLinkingFuncParameters();
            
            costMatrices(2).funcName = obj.uTrackParameters.getGapClosingFuncName();
            costMatrices(2).parameters = obj.uTrackParameters.getClosingFuncParameters();
            
            saveResults = 0;
            [obj.tracks,obj.kalmanInfoLink,errFlag] =...
                trackCloseGapsKalmanSparse(obj.movieInfo,...
                                           costMatrices,...
                                           obj.uTrackParameters.getGapCloseParams(),...
                                           obj.uTrackParameters.getKalmanFunctionNames(),...
                                           obj.dim,...
                                           saveResults,...
                                           obj.uTrackParameters.getVerboseState());
            
            if errFlag
                obj.logger.fatal('uTrack crashed with error flag ', errFlag,'. Dont know why...');
            end
            obj.trackingDone=true;
        end
        
        function tracks=getTracks(obj)
            obj.track();
            tracks=obj.tracks;
        end
        
        function plot(obj)
            figure(2);
            clf;
            colormap gray;
            mainAx=axes();
            for i=500:950
                cla(mainAx);
                imagesc(mainAx,bl.getImage(i));
                plotTracks2D(obj.tracks,'colorTime','2','timeRange',[i-10,i+10],'newFigure',mainAx,'ask4sel',0);
                axis image;
                set(mainAx,'XLim',[1,300],'YLim',[1,300]);
                drawnow;
            end
        end
    end
end

