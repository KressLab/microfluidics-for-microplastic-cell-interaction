classdef MeasurementPhaseSegmenter<handle
    properties(Access=private)
        logger;
        filename;
        forceFunction;
    end
    
    methods(Access=public)
        function obj=MeasurementPhaseSegmenter(filename)
            obj.filename=filename;
            obj.logger=Logger.getInstance();
        end
        
        function setForce(obj,force)
            obj.forceFunction=abs(force);
        end
        
        function [rinseStartFrame,sedimentationStartFrame,ruptureStartFrame]=getPhaseStartFrames(obj)
            [rinseInterval,sedimentationInterval,ruptureForceInterval]=obj.getPhaseIntervals();
            findFirst=@(interval)(find(interval,1));
            rinseStartFrame=findFirst(rinseInterval);
            sedimentationStartFrame=findFirst(sedimentationInterval);
            ruptureStartFrame=findFirst(ruptureForceInterval);
            
            if sedimentationStartFrame<rinseStartFrame
                obj.logger.fatal('force level detection failed');
            end
            if ruptureStartFrame<sedimentationStartFrame
                obj.logger.fatal('force level detection failed');
            end
            
            obj.logger.debug(obj.filename,': rinse start frame ',rinseStartFrame);
            obj.logger.debug(obj.filename,': sedimentation start frame ',sedimentationStartFrame);
            obj.logger.debug(obj.filename,': rupture start frame ',ruptureStartFrame);
        end
        
        function [rinseInterval,sedimentationInterval,ruptureForceInterval]=getPhaseIntervals(obj)
            force=obj.getForceAbs();
            
            dForceSign=diff(obj.getForceSign());
            dForceFiltSign=diff(obj.getForceFiltSign());
            MAX_RINSE_TIME=500;
            forceDrop=find(dForceSign==-1);
            sedimentationStart=max(forceDrop(forceDrop<MAX_RINSE_TIME))+1;
            sedimentationEnd=moveToNextStatusChange(sedimentationStart,dForceFiltSign==1);
            
            rinseStart=backtrackToStatusChange(sedimentationStart-1,obj.getForceSign())+1;
            if isnan(rinseStart)
                rinseStart=2;
            end
            rinseEnd=sedimentationStart-1;
            
            ruptureStart=sedimentationEnd+1;
            ruptureEnd=moveToNextStatusChange(sedimentationEnd+1,obj.getForceFiltSign())-1;
            if isnan(ruptureEnd)
                ruptureEnd=size(force,1);
            end
            % when motor started in the wrong direction
            if force(ruptureStart+1)==0
                ruptureStart=ruptureStart+2;
                sedimentationEnd=sedimentationEnd+2;
            end
            
            rinseInterval=false(size(force));
            rinseInterval(rinseStart:rinseEnd)=true;
            
            sedimentationInterval=false(size(force));
            sedimentationInterval(sedimentationStart:sedimentationEnd)=true;
            
            ruptureForceInterval=false(size(force));
            ruptureForceInterval(ruptureStart:ruptureEnd)=true;
            
            % plausibility checks
            if rinseStart>300
                obj.logger.warn(obj.filename,': Rinsing starts late');
            end
            if rinseEnd-rinseStart>200
                obj.logger.warn(obj.filename,': Rinse interval seems long');
            end
            
            if sedimentationEnd-sedimentationStart<550
                obj.logger.fatal(obj.filename,': Sedimenation phase is shorter than 550 frames: .',sedimentationEnd-sedimentationStart);
            end
            
            if any(force(sedimentationInterval)~=0)
                obj.logger.warn(obj.filename,': Sedimentation interval with force ~=0.');
            end
        end
        
        function plotPhaseIntervals(obj)
            force=obj.getForceAbs();
            t=(1:size(force,1))';
            [rinseInterval,sedimentationInterval,ruptureForceInterval]=obj.getPhaseIntervals();
            
            figure(10);
            clf;
            yyaxis('right');
            plot(t,obj.getForceFiltSign());
            yyaxis('left');
            hold on;
            plot(t,force,'k-','Linewidth',4);
            plot(t(rinseInterval),force(rinseInterval),'b-','Linewidth',2);
            plot(t(sedimentationInterval),force(sedimentationInterval),'c-','Linewidth',3);
            plot(t(ruptureForceInterval),force(ruptureForceInterval),'r-','Linewidth',2);
            fuAutosetPlotLimits(gca,0.05);
        end
    end
    
    methods(Access=private)
        function forceSign=getForceSign(obj)
            forceSign=sign(obj.getForceAbs());
        end
        
        function forceFiltSign=getForceFiltSign(obj)
            forceFiltSign=sign(medfilt1(obj.getForceAbs(),7,'truncate'));
        end
        
        function force=getForceAbs(obj)
            force=abs(obj.forceFunction);
        end
        
        function [noForceN,rinsingForceN,ruptureForceN]=getForceLevels(obj)
            force=obj.getForceAbs();
            forceLevels=sort(rmmissing(unique(force)));
            if size(forceLevels,1)~=3
                obj.logger.fatal(obj.filename,': Illegal force levels detected');
            end
            if forceLevels(1)~=0
                obj.logger.fatal('Illegal sedimentation force detected');
            end
            idxLvl2=find(force==forceLevels(2),1,'first');
            idxLvl3=find(force==forceLevels(3),1,'first');
            
            noForceN=forceLevels(1,1);
            % rinse first then rupture
            if idxLvl3>idxLvl2
                rinsingForceN=forceLevels(2,1);
                ruptureForceN=forceLevels(3,1);
            elseif idxLvl2>idxLvl3
                rinsingForceN=forceLevels(3,1);
                ruptureForceN=forceLevels(2,1);
            end
            
            obj.logger.debug(obj.filename,': noForce=',noForceN,'N');
            obj.logger.debug(obj.filename,': rinsingForce=',rinsingForceN,'N');
            obj.logger.debug(obj.filename,': ruptureForce=',ruptureForceN,'N');
        end
    end
end

