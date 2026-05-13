classdef SedimentationAnalysis<MicrofluidicsEvaluation
    properties(Access=private)
        MAX_V_MEDIAN_FOR_FIXED_UMS=0.25; %Wolfi: 0.25, %TimeDependent Ecocorona: 0.20
        sedimentationTrajectoriesInSedTime=[];
        sedimentationTrajectoriesInContactTimeCells=[];
    end
    
    properties(Access=public)
        vMedianFilterSizeFrames=31;
        clusterFilterIntervalFrames=31;
        clusterDistancePx=6.5;
    end
    
    properties(Access=public,Constant)
        MOTION_STATUS_FIXED='fixed';
        MOTION_STATUS_FREE='free';
        MOTION_STATUS_INVALID='invalid';
        MOTION_STATUS_NOT_IN_FRAME='notInFrame';
    end
    
    methods(Access=public,Static)
        function [relFixedOnCells,relFixedOnCoverslips]=multiFileAnalysis(FILENAMES)
            sedimentationTrajectories=SedimentationAnalysis.getAllTrajectoriesSedimentationPhase(FILENAMES);
            
            maxLength=max(cellfun(@(x)(size(x,1)),sedimentationTrajectories));
            beadCat=categorical(repmat({CatBeads.CAT_INVALID},maxLength,size(sedimentationTrajectories,1)));
            motionStatus=categorical(repmat({SedimentationAnalysis.MOTION_STATUS_INVALID},maxLength,size(sedimentationTrajectories,1)));
            
            for i=1:size(sedimentationTrajectories,1)
                beadCat(1:size(sedimentationTrajectories{i,1}.cat,1),i)=sedimentationTrajectories{i,1}.cat;
                motionStatus(1:size(sedimentationTrajectories{i,1}.motionStatus,1),i)=sedimentationTrajectories{i,1}.motionStatus;
            end
           
            onCells=double(beadCat==CatBeads.CAT_TOUCHING_CELL);
            onCells(beadCat==CatBeads.CAT_INVALID | ...
                    beadCat==CatBeads.CAT_NOT_IN_FRAME)=NaN;
            
            notOnCells=double(beadCat==CatBeads.CAT_NOT_TOUCHING_CELL);
            notOnCells(beadCat==CatBeads.CAT_INVALID | ...
                       beadCat==CatBeads.CAT_NOT_IN_FRAME)=NaN;
            
            fixed=double(motionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED);
            fixed(motionStatus==SedimentationAnalysis.MOTION_STATUS_INVALID | ...
                  motionStatus==SedimentationAnalysis.MOTION_STATUS_NOT_IN_FRAME)=NaN;
            
            free=double(motionStatus==SedimentationAnalysis.MOTION_STATUS_FREE);
            free(motionStatus==SedimentationAnalysis.MOTION_STATUS_INVALID| ...
                 motionStatus==SedimentationAnalysis.MOTION_STATUS_NOT_IN_FRAME)=NaN;
            
            totalFixedOnCells=nansum(fixed.*onCells,2);
            totalFreeOnCells=nansum(free.*onCells,2);
            totalFixedNotOnCells=nansum(fixed.*notOnCells,2);
            totalFreeNotOnCells=nansum(free.*notOnCells,2);
            
            relFixedOnCells=totalFixedOnCells./(totalFixedOnCells+totalFreeOnCells);
            relFixedOnCoverslips=totalFixedNotOnCells./(totalFixedNotOnCells+totalFreeNotOnCells);
        end
        
        function [kOnCellsS,kOnCellsErrorS,kOffCellsS,kOffCellsErrorS,kOnCoverslipsS,kOnCoverslipsErrorS,kOffCoverslipsS,kOffCoverslipsErrorS]=calculateChangeRates(FILENAMES)
            totalDeltaCountFixedCells=0;
            totalDeltaTimeFixedCellsS=0;
            
            totalDeltaCountFreeCells=0;
            totalDeltaTimeFreeCellsS=0;
            
            totalDeltaCountFixedCoverslips=0;
            totalDeltaTimeFixedCoverslipsS=0;
            
            totalDeltaCountFreeCoverslips=0;
            totalDeltaTimeFreeCoverslipsS=0;
            safeParpool(12);
            parfor i=1:size(FILENAMES,2)
                try
                    sa=SedimentationAnalysis(FILENAMES{1,i}(1:(end-4)),true,false);
                    if ~isempty(sa.classifiedBeadTrajectories)
                        [newDeltaCountFixedCells,newDeltaTimeFixedCellsS]=sa.getBindingRateParameters(CatBeads.CAT_TOUCHING_CELL,sa.MOTION_STATUS_FIXED);
                        totalDeltaCountFixedCells=totalDeltaCountFixedCells+newDeltaCountFixedCells;
                        totalDeltaTimeFixedCellsS=totalDeltaTimeFixedCellsS+newDeltaTimeFixedCellsS;
                        
                        [newDeltaCountFreeCells,newDeltaTimeFreeCellsS]=sa.getBindingRateParameters(CatBeads.CAT_TOUCHING_CELL,sa.MOTION_STATUS_FREE);
                        totalDeltaCountFreeCells=totalDeltaCountFreeCells+newDeltaCountFreeCells;
                        totalDeltaTimeFreeCellsS=totalDeltaTimeFreeCellsS+newDeltaTimeFreeCellsS;
                        
                        [newDeltaCountFixedCoverslips,newDeltaTimeFixedCoverslipsS]=sa.getBindingRateParameters(CatBeads.CAT_NOT_TOUCHING_CELL,sa.MOTION_STATUS_FIXED);
                        totalDeltaCountFixedCoverslips=totalDeltaCountFixedCoverslips+newDeltaCountFixedCoverslips;
                        totalDeltaTimeFixedCoverslipsS=totalDeltaTimeFixedCoverslipsS+newDeltaTimeFixedCoverslipsS;
                        
                        [newDeltaCountFreeCoverslips,newDeltaTimeFreeCoverslipsS]=sa.getBindingRateParameters(CatBeads.CAT_NOT_TOUCHING_CELL,sa.MOTION_STATUS_FREE);
                        totalDeltaCountFreeCoverslips=totalDeltaCountFreeCoverslips+newDeltaCountFreeCoverslips;
                        totalDeltaTimeFreeCoverslipsS=totalDeltaTimeFreeCoverslipsS+newDeltaTimeFreeCoverslipsS;
                    end
                catch e
                    l=Logger.getInstance();
                    l.warn('File ',FILENAMES{1,i}(1:(end-4)),' excluded. Error: ', e.message);
                    l.warn(e);
                end
            end
            
            kOnCellsS=totalDeltaCountFreeCells/totalDeltaTimeFreeCellsS;
            kOnCellsErrorS=sqrt(totalDeltaCountFreeCells)/totalDeltaTimeFreeCellsS;
            kOffCellsS=totalDeltaCountFixedCells/totalDeltaTimeFixedCellsS;
            kOffCellsErrorS=sqrt(totalDeltaCountFixedCells)/totalDeltaTimeFixedCellsS;
            
            kOnCoverslipsS=totalDeltaCountFreeCoverslips/totalDeltaTimeFreeCoverslipsS;
            kOnCoverslipsErrorS=sqrt(totalDeltaCountFreeCoverslips)/totalDeltaTimeFreeCoverslipsS;
            kOffCoverslipsS=totalDeltaCountFixedCoverslips/totalDeltaTimeFixedCoverslipsS;
            kOffCoverslipsErrorS=sqrt(totalDeltaCountFixedCoverslips)/totalDeltaTimeFixedCoverslipsS;
        end
        
        function boundTimesS=getAllTrajectoriesBoundTimes(FILENAMES,cat,immobilizedThresholdS)
            boundTimesS=[];
            safeParpool(12);
            parfor i=1:size(FILENAMES,2)
                try
                    sa=SedimentationAnalysis(FILENAMES{1,i}(1:(end-4)),true,false);
                    if ~isempty(sa.classifiedBeadTrajectories)
                        boundTimesS=[boundTimesS;sa.getBoundTimesS(cat,immobilizedThresholdS)];
                    end
                catch e
                    l=Logger.getInstance();
                    l.warn('File ',FILENAMES{1,i}(1:(end-4)),' excluded. Error: ', e.message);
                    l.warn(e);
                end
            end
        end
        
        function sedimentationTrajectories=getAllTrajectoriesSedimentationPhase(FILENAMES)
            sedimentationTrajectories=cell(0);
            safeParpool(12);
            parfor i=1:size(FILENAMES,2)
                try
                    sa=SedimentationAnalysis(FILENAMES{1,i}(1:(end-4)),true,false);
                    if ~isempty(sa.classifiedBeadTrajectories)
                        sedimentationTrajectories=[sedimentationTrajectories;sa.getSedimentationTrajectoriesInSedTime()];
                    end
                catch e
                    l=Logger.getInstance();
                    l.warn('File ',FILENAMES{1,i}(1:(end-4)),' excluded. Error: ', e.message);
                    l.warn(e);
                end
            end
        end
        
        function [changesMotionCell,changesMotionCoverslip]=testMaxVMedianSampling(fname,vmedAll,vMedianFilterSizeFrames)
            safeParpool(12);
            parfor i=1:size(vmedAll,2)
                sa=SedimentationAnalysis(fname,true,false);
                sa.vMedianFilterSizeFrames=vMedianFilterSizeFrames;
                sa.MAX_V_MEDIAN_FOR_FIXED_UMS=vmedAll(i);
                sa.sedimentationTrajectoriesInSedTime=[];
                trajSedimentationPhase=getSedimentationTrajectoriesInSedTime(sa);
                
                changesMotionCell(i)=nansum(cellfun(@(x)(nansum(abs(diff(x.motionStatus(x.cat==CatBeads.CAT_TOUCHING_CELL)==sa.MOTION_STATUS_FREE)))),trajSedimentationPhase));
                changesMotionCoverslip(i)=nansum(cellfun(@(x)(nansum(abs(diff(x.motionStatus(x.cat==CatBeads.CAT_NOT_TOUCHING_CELL)==sa.MOTION_STATUS_FREE)))),trajSedimentationPhase));
            end
        end
    end
    
    methods(Access=public)
        function obj = SedimentationAnalysis(filename,loadResults,initFigure)
            obj=obj@MicrofluidicsEvaluation(filename,loadResults,initFigure);
        end
        
        function plotValidTrajectoriesStatusesContinuous(obj,ax)
            obj.plotTrajectoryStatusesContiuous(ax,obj.getValidSedimentationTrajectories());
        end
        
        function plotValidTrajectoriesStatuses(obj,ax)
            obj.plotTrajectoryStatuses(ax,obj.getValidSedimentationTrajectories());
        end
        
        function plotAllTrajectoriesStatuses(obj,ax)
            obj.plotTrajectoryStatuses(ax,obj.getTrajectoriesWithMotionStatus());
        end
        
        function loadValidSedimentationTrajectories(obj)
            traj=obj.getSedimentationTrajectoriesInSedTime();
            
            beadPositions=cell(size(obj.cctlResult.timesS));
            beadCategories=cell(size(obj.cctlResult.timesS));
            beadIds=cell(size(obj.cctlResult.timesS));
            beadMotionStatus=cell(size(obj.cctlResult.timesS));
            for trajecoryId=1:size(traj,1)
                frameIds=cell2mat(arrayfun(@(x)(find(obj.cctlResult.timesS==x,1,'first')),traj{trajecoryId,1}.timesS,'UniformOutput',false));
                for j=1:size(frameIds,1)
                    frameId=frameIds(j);
                    beadPositions{frameId,1}(end+1,1:2)=traj{trajecoryId,1}.pos(j,:);
                    beadCategories{frameId,1}(end+1,1)=traj{trajecoryId,1}.cat(j,:);
                    beadIds{frameId,1}(end+1,1)=trajecoryId;
                    beadMotionStatus{frameId,1}(end+1,1)=traj{trajecoryId,1}.motionStatus(j,:);
                end
            end
            obj.beadPositions=beadPositions;
            obj.beadCategories=beadCategories;
            obj.beadIds=beadIds;
            obj.beadMotionStatus=beadMotionStatus;
        end
        
        function plotTrajectoryStatuses(obj,ax,trajectories)
            yyaxis('right');
            plot(obj.cctlResult.timesS,abs(obj.getForceN())/1E-12,'w-','Hittest','off');
            ylabel('Force/pN');
            fuAutosetPlotLimits(gca,0.05);
            yyaxis('left');
            
            hold(ax,'on');
            minTime=cellfun(@(x)(find(~isnan(x.pos(:,1)),1,'first')),trajectories);
            [~,sortInd]=sort(minTime);
            trajectories=trajectories(sortInd,1);
            for i=1:size(trajectories,1)
                currCat=trajectories{i,1}.cat;
                notTouch=currCat==CatBeads.CAT_NOT_TOUCHING_CELL;
                touch=currCat==CatBeads.CAT_TOUCHING_CELL;

                currMotionStatus=trajectories{i,1}.motionStatus;
                free=currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE;
                fixed=currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED;

                plotStatus(ax,trajectories{i,1}.timesS,i-0.15,free,0.3,'y');
                plotStatus(ax,trajectories{i,1}.timesS,i-0.15,fixed,0.3,'b');
                plotStatus(ax,trajectories{i,1}.timesS,i+0.15,notTouch,0.3,'r');
                plotStatus(ax,trajectories{i,1}.timesS,i+0.15,touch,0.3,'g');
            end

            colorbar('Visible',false,'Location','westoutside');
            [~,fname]=fileparts(obj.filename);
            title(fname,'interpreter','none');
            xlabel('time / s');
            ylabel('Particle id');
        end
        
        
        function plotTrajectoryStatusesContiuous(obj,ax,trajectories)
            axes(ax);
            
            innerMap=createDivergingColormap([0.75,0.01,0.01],[0,0,0],[0.3,.90,0.3],256);
            outerMap=createDivergingColormap([0.2,0.2,0.95],[1,1,1],[1,1,0.3],256);
            
            axDummy=axes();
            colormap(gca,innerMap);
            caxis([0,1]);
            c=colorbar(gca,'FontSize',14,'Location','eastoutside');
            c.Label.String='Near Cell';
            yyaxis('right');
            set(axDummy,'Visible',false);

            axes(ax);
            yyaxis('right');
            plot(obj.cctlResult.timesS,abs(obj.getForceN())/1E-12,'-','Hittest','off');
            ylabel('Force/pN');
            fuAutosetPlotLimits(gca,0.05);
            yyaxis('left');
            colormap(gca,outerMap);
            caxis([0,2*obj.MAX_V_MEDIAN_FOR_FIXED_UMS]);
            c=colorbar(gca,'FontSize',14,'Location','westoutside');
            c.Label.String='speed / um/s';
            axDummy.Position=ax.Position;
            
            
            hold(ax,'on');
            minTime=cellfun(@(x)(find(~isnan(x.pos(:,1)),1,'first')),trajectories);
            [~,sortInd]=sort(minTime);
            trajectories=trajectories(sortInd,1);
            for i=1:size(trajectories,1)
                currVel=trajectories{i,1}.currVMedianUMS;
                currCatScore=trajectories{i,1}.catScores(:,2);

                plotStatusContinuous(gca,obj.cctlResult.timesS,i,currVel,3,0.5,outerMap,0,2*obj.MAX_V_MEDIAN_FOR_FIXED_UMS);
                plotStatusContinuous(gca,obj.cctlResult.timesS,i,currCatScore,3,0.25,innerMap,0,1);
            end

            [~,fname]=fileparts(obj.filename);
            title(fname,'interpreter','none');
            xlabel('time / s');
            ylabel('Particle id');
        end
        
        function boundTimesS=getBoundTimesS(obj,cat,immobilizedThresholdS)
            [boundTimesS]=cellfun(@(x)obj.getTrajectoryBoundTimes(x,cat,immobilizedThresholdS),...
                                  obj.getSedimentationTrajectoriesInSedTime(),...
                                  'UniformOutput',false);
            boundTimesS=vertcat(boundTimesS{:});
            boundTimesS=vertcat(boundTimesS{:});
        end
        
        function unboundTimesS=getUnboundTimesS(obj,cat,immobilizedThresholdS)
            [unboundTimesS]=cellfun(@(x)obj.getTrajectoryUnboundTimes(x,cat,immobilizedThresholdS),...
                                  obj.getSedimentationTrajectoriesInSedTime(),...
                                  'UniformOutput',false);
            unboundTimesS=vertcat(unboundTimesS{:});
            unboundTimesS=vertcat(unboundTimesS{:});
        end
        
        function firstBindTimesS=getFirstBindTimes(obj)
            firstBindTimesS=cellfun(@(x)obj.getTrajectoryFirstBindTime(x),...
                                           obj.getSedimentationTrajectoriesInSedTime(),...
                                           'UniformOutput',false);
            firstBindTimesS=cell2mat(firstBindTimesS);
        end
        
        function [deltaCount,deltaTimeS]=getBindingRateParameters(obj,cat,motionStatus)
            [deltaCount,deltaTimeS]=cellfun(@(x)obj.getTrajectoryBindingRateParameters(x,cat,motionStatus),...
                                           obj.getSedimentationTrajectoriesInSedTime(),...
                                           'UniformOutput',false);
            deltaCount=sum(cell2mat(deltaCount));
            deltaTimeS=sum(cell2mat(deltaTimeS));
        end
        
        function sedimentationTrajectoriesInSedTime=getSedimentationTrajectoriesInSedTime(obj)
            if isempty(obj.sedimentationTrajectoriesInSedTime)
                sedimentationTrajectoriesInSedTime=cellfun(@obj.switchTimeToSedimentationTime,...
                                           obj.getValidSedimentationTrajectories(),...
                                           'UniformOutput',false);
                obj.sedimentationTrajectoriesInSedTime=sedimentationTrajectoriesInSedTime;
            else
                sedimentationTrajectoriesInSedTime=obj.sedimentationTrajectoriesInSedTime;
            end
        end
        
        function sedimentationTrajectoriesInContactTimeCells=getSedimentationTrajectoriesInContactTimeCells(obj)
            if isempty(obj.sedimentationTrajectoriesInContactTimeCells)
                sedimentationTrajectoriesInContactTimeCells=cellfun(@(x)obj.switchTimeToContactTime(x,CatBeads.CAT_TOUCHING_CELL),...
                                           obj.getValidSedimentationTrajectories(),...
                                           'UniformOutput',false);
                sedimentationTrajectoriesInContactTimeCells=horzcat(sedimentationTrajectoriesInContactTimeCells{:})';
                obj.sedimentationTrajectoriesInContactTimeCells=sedimentationTrajectoriesInContactTimeCells;
            else
                sedimentationTrajectoriesInContactTimeCells=obj.sedimentationTrajectoriesInContactTimeCells;
            end
        end
        
        function sedimentationTrajectories=getTrajectoriesWithMotionStatus(obj)
            baseMotionStatus=categorical(zeros(size(obj.cctlResult.timesS)),0,obj.MOTION_STATUS_INVALID);
            sedimentationTrajectories=cellfun(@(x)(obj.calculateMotionStatus(x,baseMotionStatus)),...
                                                   obj.classifiedBeadTrajectories,...
                                                   'UniformOutput',false);
        end
        
        function sedimentationTrajectories=getValidSedimentationTrajectories(obj)
            sedimentationTrajectories=obj.getTrajectoriesWithMotionStatus();
            sedimentationTrajectories=obj.selectValidSedimentationTrajectories(sedimentationTrajectories);
        end
    end
    
    methods(Access=private)
        function y=getPlotY(~,map,i)
            y=nan(size(map));
            y(map)=i;
        end
        
        function boundTimesS=getTrajectoryBoundTimes(obj,trajectory,cat,immobilizedThresholdS)
            boundTimesS=cell(0);
            
            lastBound=[];
            for i=2:size(trajectory.motionStatus,1)
                if i < (size(trajectory.motionStatus,1)-immobilizedThresholdS) && ...
                   trajectory.motionStatus(i-1)==obj.MOTION_STATUS_FREE &&...
                   trajectory.motionStatus(i)==obj.MOTION_STATUS_FIXED
                    lastBound=i;
                elseif trajectory.motionStatus(i-1)==obj.MOTION_STATUS_FIXED &&...
                       trajectory.motionStatus(i)==obj.MOTION_STATUS_FREE && ...
                       all(trajectory.cat(lastBound:i)==cat)
                    if i-lastBound>1
                        boundTimesS{end+1,1}=i-lastBound;
                    end
                    lastBound=[];
                elseif i==length(trajectory.motionStatus) && trajectory.motionStatus(i)==obj.MOTION_STATUS_FIXED
                    if i-lastBound>immobilizedThresholdS
                        boundTimesS{end+1,1}=inf;
                    end
                end
            end
        end
        
        function unboundTimesS=getTrajectoryUnboundTimes(obj,trajectory,cat,immobilizedThresholdS)
            unboundTimesS=cell(0);
            
            lastUnbound=[];
            for i=2:size(trajectory.motionStatus,1)
                if i < (size(trajectory.motionStatus,1)-immobilizedThresholdS) && ...
                   trajectory.motionStatus(i-1)==obj.MOTION_STATUS_FIXED &&...
                   trajectory.motionStatus(i)==obj.MOTION_STATUS_FREE
                    lastUnbound=i;
                elseif trajectory.motionStatus(i-1)==obj.MOTION_STATUS_FREE &&...
                       trajectory.motionStatus(i)==obj.MOTION_STATUS_FIXED && ...
                       all(trajectory.cat(lastUnbound:i)==cat)
                    if i-lastUnbound>1
                        unboundTimesS{end+1,1}=i-lastUnbound;
                    end
                    lastUnbound=[];
                elseif i==length(trajectory.motionStatus) && trajectory.motionStatus(i)==obj.MOTION_STATUS_FREE
                    if i-lastUnbound>immobilizedThresholdS
                         unboundTimesS{end+1,1}=inf;
                    end
                end
            end
        end
        
        function [deltaCount,deltaTimeS]=getTrajectoryBindingRateParameters(obj,trajectory,cat,motionStatus)
            targetVect=trajectory.motionStatus(trajectory.cat==cat)==motionStatus;
            deltaCount=nansum(diff(targetVect)==-1);
            deltaTimeS=nansum(diff(obj.cctlResult.timesS(targetVect)));
        end
        
        function firstBindTime=getTrajectoryFirstBindTime(obj,trajectory)
            firstBindTime=find(trajectory.motionStatus==obj.MOTION_STATUS_FIXED,1,'first');
        end
        
        function sedimentationPhaseTrajectory=switchTimeToSedimentationTime(obj,trajectory)
            [~,~,ruptureStartFrame]=obj.measurementPhaseSegmenter.getPhaseStartFrames();
            inFrame=trajectory.motionStatus~=obj.MOTION_STATUS_INVALID & ...
                    trajectory.motionStatus~=obj.MOTION_STATUS_NOT_IN_FRAME & ...
                    obj.cctlResult.timesS < ruptureStartFrame ;
                
            sedimentationPhaseTrajectory=table();
            sedimentationPhaseTrajectory.timesS=obj.cctlResult.timesS(inFrame);
            sedimentationPhaseTrajectory.pos=trajectory.pos(inFrame,:);
            sedimentationPhaseTrajectory.cat=trajectory.cat(inFrame,:);
            sedimentationPhaseTrajectory.catScores=trajectory.catScores(inFrame,:);
            sedimentationPhaseTrajectory.currPosUm=trajectory.currPosUm(inFrame,:);
            sedimentationPhaseTrajectory.currVMedianUMS=trajectory.currVMedianUMS(inFrame,:);
            sedimentationPhaseTrajectory.motionStatus=trajectory.motionStatus(inFrame,:);
        end
        
        function contactTrajectories=switchTimeToContactTime(obj,trajectory,cat)
            trajectory=obj.switchTimeToSedimentationTime(trajectory);
            
            isCat=trajectory.cat==cat;
            isCat=medfilt1(double(isCat),3,'truncate')==1;
            startIdx=find(diff([0;isCat])~=0 & isCat==1);
            endIdx=find(diff([isCat;0])~=0 & isCat==1);
            
            if length(startIdx)~=length(endIdx)
                obj.logger.fatal('lengths not equal')
            end
            contactTrajectories=cell(0);
            for i=1:size(startIdx,1)
                if trajectory.motionStatus(startIdx(i))==obj.MOTION_STATUS_FREE
                    contactTrajectories{end+1}=table();
                    contactTrajectories{end}.timesS=obj.cctlResult.timesS(startIdx(i):endIdx(i));
                    contactTrajectories{end}.pos=trajectory.pos(startIdx(i):endIdx(i),:);
                    contactTrajectories{end}.cat=trajectory.cat(startIdx(i):endIdx(i),:);
                    contactTrajectories{end}.catScores=trajectory.catScores(startIdx(i):endIdx(i),:);
                    contactTrajectories{end}.currPosUm=trajectory.currPosUm(startIdx(i):endIdx(i),:);
                    contactTrajectories{end}.currVMedianUMS=trajectory.currVMedianUMS(startIdx(i):endIdx(i),:);
                    contactTrajectories{end}.motionStatus=trajectory.motionStatus(startIdx(i):endIdx(i),:);
                end
            end
        end
        
        function trajectory=calculateMotionStatus(obj,trajectory,baseMotionStatus)
            currPosUm=trajectory.pos.*obj.cctlResult.cameraSettings.pixelSizeUm;
            currVUMS=[sqrt(diff(currPosUm(:,1)).^2+diff(currPosUm(:,2)).^2)./diff(obj.cctlResult.timesS);NaN];
            currVMedianUMS=medfilt1(currVUMS,obj.vMedianFilterSizeFrames,'truncate','omitnan');
            currVMedianUMS(isnan(currVUMS))=nan;
            currVMedianUMS(find(isnan(currVUMS),1,'first'))=currVMedianUMS(2);
            
            
            % two tests because of nan values when not in frame
            % ~fixed~=moving!!!
            fixed=currVMedianUMS<obj.MAX_V_MEDIAN_FOR_FIXED_UMS;
            free=currVMedianUMS>=obj.MAX_V_MEDIAN_FOR_FIXED_UMS;

            trajectory.currPosUm=currPosUm;
            trajectory.currVMedianUMS=currVMedianUMS;
            trajectory.motionStatus=baseMotionStatus;
            trajectory.motionStatus(fixed)=obj.MOTION_STATUS_FIXED;
            trajectory.motionStatus(free)=obj.MOTION_STATUS_FREE;
            trajectory.motionStatus(trajectory.cat==CatBeads.CAT_NOT_IN_FRAME)=obj.MOTION_STATUS_NOT_IN_FRAME;
            trajectory.timesS=obj.cctlResult.timesS;
            trajectory.timesS(trajectory.cat==CatBeads.CAT_NOT_IN_FRAME)=NaN;
        end
        
        function validTrajectories=selectValidSedimentationTrajectories(obj,trajectories)
            [~,sedimentationStartFrame,ruptureStartFrame]=obj.measurementPhaseSegmenter.getPhaseStartFrames();
            firstValidFrame=cellfun(@obj.getFirstValidFrame,trajectories);
            lastValidFrame=cellfun(@obj.getLastValidFrame,trajectories);
            noFrameInvalid=cellfun(@obj.noFrameInvalid,trajectories);
            freeFirstFrame=cellfun(@obj.isFreeFirstFrame,trajectories);
            
            validTrajectories=trajectories(noFrameInvalid & ...
                                           freeFirstFrame & ...
                                           firstValidFrame < ruptureStartFrame & ...
                                           firstValidFrame > sedimentationStartFrame+30 & ...
                                           lastValidFrame  > ruptureStartFrame-5); %Wolfi: ruptureStartFrame-5
            
            validTrajectories=obj.removeClusterTrajectories(validTrajectories);
            validTrajectories=obj.removeTrackingErrors(validTrajectories);
        end
        
        function trajectories=removeTrackingErrors(obj, trajectories)
            isTrackingError=false(size(trajectories));
            secondDerivat=@(x)([diff([NaN;diff(x)]);NaN]);
            for i=1:size(trajectories,1)
                particleAcceleration=sqrt(secondDerivat(trajectories{i,1}.pos(:,1)).^2+...
                                          secondDerivat(trajectories{i,1}.pos(:,2)).^2);
                % detect matches trajectory parts
                constAccel=abs(diff(particleAcceleration))<1E-8;
                % increase range by 5 timepoints in each dir
                constAccel=conv(constAccel,ones(11,1),'same')>0;
                inframeI=trajectories{i,1}.motionStatus(1:end-1)~=SedimentationAnalysis.MOTION_STATUS_NOT_IN_FRAME;
                if any(constAccel & inframeI)
                    % if this or a nearby other trajectory change the motion
                    % status when accel=0, delete both trajectories
                    intervals=constAccel & inframeI;
                    [intervalsStart,intervalsEnd,~]=getVectorIslands(constAccel & inframeI);
                    for intervalId=1:size(intervalsStart,2)
                        interval=intervalsStart(intervalId):intervalsEnd(intervalId);
                        for j=1:size(trajectories,1)
                            distance=sqrt((trajectories{i,1}.pos(interval,1)-trajectories{j,1}.pos(interval,1)).^2+...
                                          (trajectories{i,1}.pos(interval,1)-trajectories{j,1}.pos(interval,1)).^2);
                            if any(distance<obj.clusterDistancePx)  && (trajectories{i,1}.motionStatus(intervalsStart(intervalId))~=trajectories{i,1}.motionStatus(intervalsEnd(intervalId)) ) %...
                                                                        %||  trajectories{i,1}.motionStatus(intervalsStart(intervalId))~=trajectories{i,1}.motionStatus(intervalsEnd(intervalId)))
                                isTrackingError([i,j])=true;
                            end
                            
                            if any(trajectories{i,1}.motionStatus(intervalsStart(intervalId):intervalsEnd(intervalId))~=trajectories{i,1}.motionStatus(intervalsStart(intervalId)))
                                isTrackingError(i)=true;
                            end
                        end
                    end
                end
            end
            obj.logger.warn(obj.filename, ': Removed ',sum(isTrackingError),' / ',  length(trajectories), ' trajectories with tracking errors.');
            trajectories=trajectories(~isTrackingError);
        end
        
        function trajectories=removeClusterTrajectories(obj,trajectories)            
            % two tracked particles have to stay together closer than obj.clusterDistancePx for
            % at least obj.clusterFilterIntervalFrames to be considered a
            % cluster.
            isCluster=false(size(trajectories));
            for i=1:size(trajectories,1)
                for j=i+1:size(trajectories,1)
                    [~,overlapI,overlapJ]=intersect(trajectories{i,1}.timesS,trajectories{j,1}.timesS);
                    if ~isempty(overlapI) && ~isempty(overlapJ)
                        distance=sqrt((trajectories{i,1}.pos(overlapI,1)-trajectories{j,1}.pos(overlapJ,1)).^2+...
                                      (trajectories{i,1}.pos(overlapI,2)-trajectories{j,1}.pos(overlapJ,2)).^2);
                        if any(movmean(distance<obj.clusterDistancePx,obj.clusterFilterIntervalFrames,'Endpoints','shrink')==1)
                            isCluster([i,j])=true;
                        end
                    end
                end
            end
            obj.logger.warn(obj.filename, ': Removed ',sum(isCluster),' of ',  length(trajectories), ' trajectories in clusters.');
            trajectories=trajectories(~isCluster);
        end
        
        function noFrameInvalid=noFrameInvalid(~,trajectory)
            noFrameInvalid=~any(trajectory.cat==CatBeads.CAT_INVALID);
        end
        
        function freeFirstFrame=isFreeFirstFrame(obj,trajectory)
            freeFirstFrame=trajectory.motionStatus(obj.getFirstValidFrame(trajectory))==obj.MOTION_STATUS_FREE;
        end
        
        function frame=getFirstValidFrame(~,trajectory)
            frame=find(~isnan(trajectory.pos(:,1)),1,'first');
        end
        
        function frame=getLastValidFrame(~,trajectory)
            frame=find(~isnan(trajectory.pos(:,1)),1,'last');
        end
    end
end

