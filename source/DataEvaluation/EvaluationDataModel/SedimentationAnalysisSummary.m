classdef SedimentationAnalysisSummary<handle
    properties(Access=public)
        logger;
        filenames;
        groupRegexes;
        immobilizedThresholdS;
        
        deltaCountFixedCells;
        deltaTimeFixedCellsS;
        
        deltaCountFreeCells;
        deltaTimeFreeCellsS;
        
        deltaCountFixedCoverslips;
        deltaTimeFixedCoverslipsS;
        
        deltaCountFreeCoverslips;
        deltaTimeFreeCoverslipsS;
        
        sedimentationTrajectories;
        boundTimesCellsS;
        unboundTimesCellsS;
        boundTimesCoverslipsS;
        unboundTimesCoverslipsS;
    end
    
    methods
        function obj=SedimentationAnalysisSummary(groupRegexes,immobilizedThresholdS)
            obj.logger=Logger.getInstance();
            obj.groupRegexes=groupRegexes;
            obj.filenames=cell(0);
            for i=1:size(groupRegexes,2)
                obj.filenames=[obj.filenames,getFilesByRegexName('/ep1/home/matteo/Mikrofluidik/Messdaten/enb250725',false,...
                    ['mf2(.+)',groupRegexes{1,i},'.*(?<!(_result.*)).mat$'])'];
            end
            obj.immobilizedThresholdS=immobilizedThresholdS;
            obj.printGroups();
            obj.calcAllGroups();
        end
        
        function [relFixedOnCells,relFixedOnCoverslips,relFixedOnBoth,totalFixedOnCells,totalFreeOnCells,totalFixedOnCoverslips,totalFreeOnCoverslips]=getGroupRelCounts(obj,groupName)
            groupSedTraj=obj.getGroupTrajectories(groupName);
            maxLength=max(cellfun(@(x)(size(x,1)),groupSedTraj));
            beadCat=categorical(repmat({CatBeads.CAT_INVALID},maxLength,size(groupSedTraj,1)));
            motionStatus=categorical(repmat({SedimentationAnalysis.MOTION_STATUS_INVALID},maxLength,size(groupSedTraj,1)));
            
            for i=1:size(groupSedTraj,1)
                beadCat(1:size(groupSedTraj{i,1}.cat,1),i)=groupSedTraj{i,1}.cat;
                motionStatus(1:size(groupSedTraj{i,1}.motionStatus,1),i)=groupSedTraj{i,1}.motionStatus;
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
            totalFixedOnCoverslips=nansum(fixed.*notOnCells,2);
            totalFreeOnCoverslips=nansum(free.*notOnCells,2);
            
            relFixedOnCells=totalFixedOnCells./(totalFixedOnCells+totalFreeOnCells);
            relFixedOnCoverslips=totalFixedOnCoverslips./(totalFixedOnCoverslips+totalFreeOnCoverslips);
            
            relFixedOnBoth=(totalFixedOnCells+totalFixedOnCoverslips)./...
                (totalFixedOnCells+totalFreeOnCells+totalFixedOnCoverslips+totalFreeOnCoverslips);
        end
        
        function printGroups(obj)
            for group=obj.groupRegexes
                obj.logger.info(group{1,1});
                cellfun(@(x)(obj.logger.info(x)),obj.getGroupFileNames(group{1,1}));
            end
        end
        
        function fnames=getGroupFileNames(obj,groupName)
            fnames=filterByRegexName(obj.filenames,groupName);
        end
        
        function boundTimesCellsS=getGroupBoundTimesCellsS(obj,group)
            boundTimesCellsS=obj.getGroupTimesS(group,obj.boundTimesCellsS);
        end
        
        function unboundTimesCellsS=getGroupUnboundTimesCellsS(obj,group)
            unboundTimesCellsS=obj.getGroupTimesS(group,obj.unboundTimesCellsS);
        end
        
        function boundTimesCoverslipsS=getGroupBoundTimesCoverslipsS(obj,group)
            boundTimesCoverslipsS=obj.getGroupTimesS(group,obj.boundTimesCoverslipsS);
        end
        
        function unboundTimesCoverslipsS=getGroupUnboundTimesCoverslipsS(obj,group)
            unboundTimesCoverslipsS=obj.getGroupTimesS(group,obj.unboundTimesCoverslipsS);
        end
        
        function [groupFraction,groupFractionError,fraction]=getGroupImmobBindingEventFractCoverslips(obj,group)
            [groupFraction,groupFractionError,fraction]=obj.getGroupInfFraction(group,obj.boundTimesCoverslipsS);
        end
        
        function [groupFraction,groupFractionError,fraction]=getGroupImmobBindingEventFractCells(obj,group)
            [groupFraction,groupFractionError,fraction]=obj.getGroupInfFraction(group,obj.boundTimesCellsS);
        end
        
        function [groupFraction,groupFractionError,fraction]=getGroupUnstickUnbindEventFractCoverslip(obj,group)
            [groupFraction,groupFractionError,fraction]=obj.getGroupInfFraction(group,obj.unboundTimesCoverslipsS);
        end
        
        function [groupFraction,groupFractionError,fraction]=getGroupUnstickUnbindEventFractCells(obj,group)
            [groupFraction,groupFractionError,fraction]=obj.getGroupInfFraction(group,obj.unboundTimesCellsS);
        end
        
        function [groupKOnCellsS,groupKOnCellsErrorS,kOnCellsS]=getGroupKOnCellsS(obj,group)
            [groupKOnCellsS,groupKOnCellsErrorS,kOnCellsS]=obj.getGroupRate(group,obj.deltaCountFreeCells,obj.deltaTimeFreeCellsS);
        end
        
        function [groupKOffCellsS,groupKOffCellsErrorS,kOffCellsS]=getGroupKOffCellsS(obj,group)
            [groupKOffCellsS,groupKOffCellsErrorS,kOffCellsS]=obj.getGroupRate(group,obj.deltaCountFixedCells,obj.deltaTimeFixedCellsS);
        end
        
        function [groupKOnCoverslipsS,groupKOnCoverslipsErrorS,kOnCoverslipsS]=getGroupKOnCoverslipsS(obj,group)
            [groupKOnCoverslipsS,groupKOnCoverslipsErrorS,kOnCoverslipsS]=obj.getGroupRate(group,obj.deltaCountFreeCoverslips,obj.deltaTimeFreeCoverslipsS);
        end
        
        function [groupKOffCoverslipsS,groupKOffCoverslipsErrorS,kOffCoverslipsS]=getGroupKOffCoverslipsS(obj,group)
            [groupKOffCoverslipsS,groupKOffCoverslipsErrorS,kOffCoverslipsS]=obj.getGroupRate(group,obj.deltaCountFixedCoverslips,obj.deltaTimeFixedCoverslipsS);
        end
        
        function groupTrajectories=getGroupTrajectories(obj,group)
            groupTrajectories=cell(0);
            for fn=obj.getGroupFileNames(group)
                groupTrajectories=[groupTrajectories;obj.sedimentationTrajectories(fn{1,1})];
            end
        end
        
        function [fraction,error]=getExpectedGroupImmobBindingEventFractCells(obj,group)
            [kOffS,kOffErrorS]=obj.getGroupKOffCellsS(group);
            fraction=exp(-kOffS*obj.immobilizedThresholdS);
            error=abs(kOffErrorS*obj.immobilizedThresholdS*exp(-kOffS*obj.immobilizedThresholdS));
        end
        
        function [fraction,error]=getExpectedGroupImmobBindingEventFractCoverslips(obj,group)
            [kOffS,kOffErrorS]=obj.getGroupKOffCoverslipsS(group);
            fraction=exp(-kOffS*obj.immobilizedThresholdS);
            error=abs(kOffErrorS*obj.immobilizedThresholdS*exp(-kOffS*obj.immobilizedThresholdS));
        end
    end
    
    methods(Access=private)
        function [groupFraction,groupFractionError,fractions]=getGroupInfFraction(obj,group,timesMap)
            fractions=nan(0,1);
            weights=nan(0,1);
            for fn=obj.getGroupFileNames(group)
                fractions(end+1,1)=sum(isinf(timesMap(fn{1,1})))/length(timesMap(fn{1,1}));
                disp(fractions)
                weights(end+1,1)=length(timesMap(fn{1,1}));
                disp(weights);
            end
            groupFraction=weightedNanMean(fractions,weights);
            groupFractionError=weightedNanStderrorOfMean(fractions,weights);
        end
        
        function groupTimesS=getGroupTimesS(obj,group,timesMap)
            groupTimesS=[];
            for fn=obj.getGroupFileNames(group)
                groupTimesS=[groupTimesS;timesMap(fn{1,1})];
            end
        end
        
%       Error per file / measurement
        function [groupRateS,groupRateErrorS,ratesS]=getGroupRate(obj,group,countMap,timeMap)
            ratesS=nan(0,1);
            weights=nan(0,1);
            for fn=obj.getGroupFileNames(group)
                if ~isempty(countMap(fn{1,1}))
                    ratesS(end+1,1)=countMap(fn{1,1})./timeMap(fn{1,1});
                    weights(end+1,1)=countMap(fn{1,1});
                    disp(ratesS);
                    disp(weights);
                else
                    obj.logger.warn('Data for file ', fn{1,1}, ' not found.');
                end
            end
            groupRateS=weightedNanMean(ratesS,weights);
            groupRateErrorS=weightedNanStderrorOfMean(ratesS,weights);
        end
        
        function calcAllGroups(obj)
            deltaCountFixedCellsLocal=cell(size(obj.filenames,2));
            deltaTimeFixedCellsSLocal=cell(size(obj.filenames,2));
            deltaCountFreeCellsLocal=cell(size(obj.filenames,2));
            deltaTimeFreeCellsSLocal=cell(size(obj.filenames,2));
            deltaCountFixedCoverslipsLocal=cell(size(obj.filenames,2));
            deltaTimeFixedCoverslipsSLocal=cell(size(obj.filenames,2));
            deltaCountFreeCoverslipsLocal=cell(size(obj.filenames,2));
            deltaTimeFreeCoverslipsSLocal=cell(size(obj.filenames,2));
            
            sedimentationTrajectoriesLocal=cell(size(obj.filenames,2));
            boundTimesCoverslipsSLocal=cell(size(obj.filenames,2));
            unboundTimesCoverslipsSLocal=cell(size(obj.filenames,2));
            boundTimesCellsSLocal=cell(size(obj.filenames,2));
            unboundTimesCellsSLocal=cell(size(obj.filenames,2));
            
            filenamesLocal=obj.filenames;
            immobilizedThresholdSLocal=obj.immobilizedThresholdS;
            parfor i=1:size(filenamesLocal,2)
                try
                    sa=SedimentationAnalysis(filenamesLocal{1,i}(1:(end-4)),true,false);
                    l=Logger.getInstance();
                    l.warn(filenamesLocal{1,i}(1:(end-4)),' loaded.');
                    if ~isempty(sa.classifiedBeadTrajectories)
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 1.');
                        [deltaCountFixedCellsLocal{1,i},deltaTimeFixedCellsSLocal{1,i}]=sa.getBindingRateParameters(CatBeads.CAT_TOUCHING_CELL,sa.MOTION_STATUS_FIXED);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 2.');
                        [deltaCountFreeCellsLocal{1,i},deltaTimeFreeCellsSLocal{1,i}]=sa.getBindingRateParameters(CatBeads.CAT_TOUCHING_CELL,sa.MOTION_STATUS_FREE);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 3.');
                        [deltaCountFixedCoverslipsLocal{1,i},deltaTimeFixedCoverslipsSLocal{1,i}]=sa.getBindingRateParameters(CatBeads.CAT_NOT_TOUCHING_CELL,sa.MOTION_STATUS_FIXED);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 4.');
                        [deltaCountFreeCoverslipsLocal{1,i},deltaTimeFreeCoverslipsSLocal{1,i}]=sa.getBindingRateParameters(CatBeads.CAT_NOT_TOUCHING_CELL,sa.MOTION_STATUS_FREE);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 5.');
                        
                        sedimentationTrajectoriesLocal{1,i}=sa.getSedimentationTrajectoriesInContactTimeCells();
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 6.');
                        boundTimesCoverslipsSLocal{1,i}=sa.getBoundTimesS(CatBeads.CAT_NOT_TOUCHING_CELL,immobilizedThresholdSLocal);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 7.');
                        unboundTimesCoverslipsSLocal{1,i}=sa.getUnboundTimesS(CatBeads.CAT_NOT_TOUCHING_CELL,immobilizedThresholdSLocal);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 8.');
                        boundTimesCellsSLocal{1,i}=sa.getBoundTimesS(CatBeads.CAT_TOUCHING_CELL,immobilizedThresholdSLocal);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 9.');
                        unboundTimesCellsSLocal{1,i}=sa.getUnboundTimesS(CatBeads.CAT_TOUCHING_CELL,immobilizedThresholdSLocal);
                        l.warn(filenamesLocal{1,i}(1:(end-4)),' 10.');
                    end
                catch e
                    l=Logger.getInstance();
                    l.warn('File ',filenamesLocal{1,i}(1:(end-4)),' excluded. Error: ', e.message);
                    l.warn(e);
                end
            end
            obj.deltaCountFixedCells=obj.toMap(obj.filenames,deltaCountFixedCellsLocal);
            obj.deltaTimeFixedCellsS=obj.toMap(obj.filenames,deltaTimeFixedCellsSLocal);
            obj.deltaCountFreeCells=obj.toMap(obj.filenames,deltaCountFreeCellsLocal);
            obj.deltaTimeFreeCellsS=obj.toMap(obj.filenames,deltaTimeFreeCellsSLocal);
            obj.deltaCountFixedCoverslips=obj.toMap(obj.filenames,deltaCountFixedCoverslipsLocal);
            obj.deltaTimeFixedCoverslipsS=obj.toMap(obj.filenames,deltaTimeFixedCoverslipsSLocal);
            obj.deltaCountFreeCoverslips=obj.toMap(obj.filenames,deltaCountFreeCoverslipsLocal);
            obj.deltaTimeFreeCoverslipsS=obj.toMap(obj.filenames,deltaTimeFreeCoverslipsSLocal);
            
            obj.sedimentationTrajectories=obj.toMap(obj.filenames,sedimentationTrajectoriesLocal);
            obj.boundTimesCoverslipsS=obj.toMap(obj.filenames,boundTimesCoverslipsSLocal);
            obj.unboundTimesCoverslipsS=obj.toMap(obj.filenames,unboundTimesCoverslipsSLocal);
            obj.boundTimesCellsS=obj.toMap(obj.filenames,boundTimesCellsSLocal);
            obj.unboundTimesCellsS=obj.toMap(obj.filenames,unboundTimesCellsSLocal);
        end
        
        function map=toMap(~,keyCellArray,valueMapArray)
            map=containers.Map();
            for i=1:size(keyCellArray,2)
                map(keyCellArray{1,i})=valueMapArray{1,i};
            end
        end
    end
end

