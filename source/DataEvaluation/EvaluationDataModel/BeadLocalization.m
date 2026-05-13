classdef BeadLocalization<MicrofluidicsEvaluation
    properties(Access=private)
        frameCount=nan;
        rpScale;
        rpImage;
    end
    
    methods(Access=public)
        function obj=BeadLocalization(filename,loadResults,initFigure)
            obj=obj@MicrofluidicsEvaluation(filename,loadResults,initFigure);
        end
        
        function detectBeads(obj)
            [obj.rpImage,obj.rpScale]=mfCnnConstants.getReferenceParticle();
            % obj.rpImage=-obj.rpImage;
            %obj.rpImage=safeGpuArray(obj.rpImage);
            
            obj.frameCount=obj.getFrameCount();
            obj.clearBeads();
            beadPos=cell(obj.frameCount,1);
            th=obj.determineThreshold();
            parfor i=1:obj.frameCount
                resized=obj.getPrefilteredImage(i);
                beadPos{i,1}=pkfndFast(resized,th,3*obj.rpScale,2*obj.rpScale,max(max(resized)));
                beadPos{i,1}=findMaxPositionWith2DGaussianFit(resized,beadPos{i,1},round(1.5*obj.rpScale),true,false)./obj.rpScale;
                obj.logger.info(obj.getShortFilename(), ': Detected ',size(beadPos{i,1},1), ' beads in frame',i);
            end
            obj.beadPositions=beadPos;
            obj.detectedBeadPositions=beadPos;
            obj.clearClassification();
            obj.frameCount=NaN;
        end
        
        function resized=getPrefilteredImage(obj,i)
            img=obj.getImage(i);
            resized=imresize(img,obj.rpScale);
            resized=fastBPass(resized,ceil(0.3*obj.rpScale),ceil(0.7*obj.rpScale),-inf);
            resized=imgaussfilt(resized,1.*obj.rpScale);
            resized=conv2(resized,obj.rpImage,'same');
        end
        
        function th=determineThreshold(obj)
            intens=nan(0);
            sampledImageIds=floor(linspace(1,obj.getFrameCount(),10));
            parfor i=1:size(sampledImageIds,2)
                xcorrfunc=obj.getPrefilteredImage(sampledImageIds(i));
                xcorrfunc=safeGather(imresize(xcorrfunc,1/obj.rpScale));
                currentTh=max(xcorrfunc(:));
                numberOfPoints=0;
                pks=[];
                while numberOfPoints<3000
                    currentTh=0.5.*currentTh;
                    pks=pkfndFast(xcorrfunc,currentTh ,3*obj.rpScale,2*obj.rpScale,inf);
                    numberOfPoints=size(pks,1);
                end
                intens=[intens;xcorrfunc(sub2ind(size(xcorrfunc),pks(:,2),pks(:,1)))];
                obj.logger.debug(obj.getShortFilename(), ': Frame: ',sampledImageIds(i));
            end
            histBinCount=100;
            [intensCount,intensEdges]=histcounts(intens(1:floor(end/1)),histBinCount);
            centers = intensEdges(1:end-1) + diff(intensEdges) / 2;
            maxCorr=obj.getAvgParticleMaxCorr(intensCount,histBinCount);
            obj.logger.debug(obj.getShortFilename(), ': Max at: ', centers(maxCorr));
            % count peaks up to max
            peakCount=0;
            for i=size(centers,2):-1:maxCorr
                peakCount=peakCount+intensCount(i);
                obj.logger.debug(obj.getShortFilename(), ': PeakCount: ', peakCount ,' at ', maxCorr);
            end
            avgSz=3;
            peakCountMax=peakCount;
            minFracCorrId=Inf;
            minFrac=Inf;
            %look for next minimum
            for i=maxCorr-1:-1:(avgSz+1)
                frac=mean(intensCount(i-avgSz:i+avgSz))/peakCount;
                peakCount=peakCount+intensCount(i);
                if frac<minFrac
                    minFracCorrId=i;
                    minFrac=frac;
                end
                if peakCount>3*peakCountMax
                    break;
                end
            end
            obj.logger.debug(obj.getShortFilename(), ': Min at ', minFracCorrId);
            totalDiff=mean(intensCount(maxCorr-avgSz:maxCorr+avgSz))-mean(intensCount(minFracCorrId-avgSz:minFracCorrId+avgSz));
            for i=maxCorr-1:-1:(avgSz+1)
                if (mean(intensCount(i-avgSz:i+avgSz))-mean(intensCount(minFracCorrId-avgSz:minFracCorrId+avgSz)))/totalDiff<0.1
                    minFracCorrId=i;
                    break;
                end
            end
            obj.logger.debug(obj.getShortFilename(), ': 10% at ', minFracCorrId);
            th=centers(minFracCorrId);
            
            figure(5);
            clf;
            histogram(intens);
            set(gca,'YScale','log')
            hold on;
            plot([th,th],[1,max(intensCount)],'r-');
            obj.logger.debug(obj.getShortFilename(), ': TH: ', th);
        end
        
        function cropParticle(obj,img)
            cropSZ=10;
            position=[836,1241];
            bead=img(position(1)-cropSZ:position(1)+cropSZ,position(2)-cropSZ:position(2)+cropSZ);
            mask=createCirclesMask(size(bead),[cropSZ+1,cropSZ+1],cropSZ);
            bead=bead.*mask;
            figure(9);
            imagesc(bead);
            axis image;
            colormap gray;
            rpPath=[mfCnnConstants.getCBPath(),filesep,'bead3UmSCALE3_tightCrop.mat'];
            save(rpPath,'bead');
        end
        
        function maxCorr=getAvgParticleMaxCorr(obj,intensCount,histBinCount)
            maxCorr=max(pkfndFast(intensCount,10,histBinCount/7,histBinCount/4));
            if isempty(maxCorr)
                maxCorr=max(pkfndFast(intensCount,10,histBinCount/30,histBinCount/10));
                obj.logger.debug(obj.getShortFilename(), ': Max corr was empty. retried');
            end
        end
        
        function trackBeadsCGT(obj,maxdisp,memory,minTrackLength)
            obj.logger.info(obj.getShortFilename(), ': Started CGTracking.');
            cgt=CrockerGrierTracker();
            for i=1:obj.getFrameCount()
                cgt.setPositionsInNewFrame(obj.beadPositions{i,1});
                obj.logger.trace(obj.getShortFilename(), ': Frame ',i,': Loading ',size(obj.beadPositions{i,1},1));
            end
            cgt.setSettings(maxdisp,memory,minTrackLength);
            [obj.beadPositions,obj.beadIds]=cgt.getTrackCellByFrames();
            obj.logger.info(obj.getShortFilename(), ': Ended CGTracking. Found ', obj.getTrajectoryCount(),' Beads.');
            obj.clearClassification();
        end
        
        %number of tracked trajectories
        function count=getTrajectoryCount(obj)
            count=size(unique(cell2mat(obj.beadIds)),1);
        end
        
        function trackBeadsUTrack(obj,uTrackParameters)
            obj.logger.info(obj.getShortFilename(), ': Started CGTracking.');
            tracker=UTrackWrapper();
            tracker.setUTrackParameters(uTrackParameters);
            for i=1:obj.getFrameCount()
                tracker.setPositionsInNewFrame(obj.beadPositions{i,1});
                obj.logger.trace(obj.getShortFilename(), ': Frame ',i,': Loading ',size(obj.beadPositions{i,1},1));
            end
            [obj.beadPositions,obj.beadIds]=tracker.getTrackCellByFrames();
            obj.logger.info(obj.getShortFilename(), ': Ended CGTracking. Found ', obj.getTrajectoryCount(),' Beads.');
            obj.clearClassification();
        end
        
    end
end

