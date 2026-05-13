classdef PI_GCS_ControllerMock < handle
    % PICONTROLLERDUMMY Reimplements the same functionality as the real
    % PI_GCS_Controller, however does not need hardware access. Yields
    % plausible values for multiple axes and thus, can be used to simulate
    % the real PI_GCS_Conroller behaviour in a test environment.
    properties
        availableAxes;
        
        logger;
        maxPosition;
        minPosition;
        servoMode=false;
        referenceStatus=false;
        onlineStatus;
        velocity;
        velocityControlMode;
        driftCompensationMode;
        
        % for movement emulation
        stillPosition; % the last still postion
        direction; % +1, 0 or -1
        target; % target postion
        startTime; % the time when movement started
        projectedTravelTime; % the estimated duration of the travel
    end
    
    methods(Access=public)
        function obj=PI_GCS_ControllerMock(availableAxes)
            obj.logger=Logger.getInstance();
            
            obj.availableAxes=availableAxes;
            
            
            obj.maxPosition=java.util.HashMap();
            obj.minPosition=java.util.HashMap();
            obj.servoMode=java.util.HashMap();
            obj.referenceStatus=java.util.HashMap();
            obj.onlineStatus=java.util.HashMap();
            obj.velocityControlMode=java.util.HashMap();
            obj.driftCompensationMode=java.util.HashMap();
            obj.velocity=java.util.HashMap();
            
            obj.stillPosition=java.util.HashMap();
            obj.direction=java.util.HashMap();
            obj.target=java.util.HashMap();
            obj.startTime=java.util.HashMap();
            obj.projectedTravelTime=java.util.HashMap();
            
            for i=obj.qSAI_ALL()
                obj.maxPosition.put(i{1},100);
                obj.minPosition.put(i{1},0);
                obj.servoMode.put(i{1},false);
                obj.referenceStatus.put(i{1},false);
                obj.velocity.put(i{1},1.25);
                obj.stillPosition.put(i{1},NaN);
                obj.direction.put(i{1},0);
                obj.target.put(i{1},NaN);
                obj.startTime.put(i{1},NaN);
                obj.projectedTravelTime.put(i{1},NaN);
            end
            
        end
        
        function FNL(obj, axisIDs)
            for axisID=obj.cleanAxisIds(axisIDs)
                obj.referenceStatus.put(axisIDs,true);
                obj.stillPosition.put(axisIDs,obj.minPosition.get(axisIDs));
            end
        end
        
        function FNP(obj, axisIDs)
            for axisID=obj.cleanAxisIds(axisIDs)
                obj.referenceStatus.put(axisID,true);
                obj.stillPosition.put(axisID,obj.maxPosition.get(axisID));
            end
        end
        
        function ONL(obj, axisIDs, onlineStatus)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                axisID=axisIDs(1,i);
                obj.onlineStatus.put(axisID,onlineStatus(i));
            end
        end
        
        function VCO(obj, axisIDs, velocityControlMode)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                axisID=axisIDs(1,i);
                obj.velocityControlMode.put(axisID(i,1),velocityControlMode(i));
                if velocityControlMode
                    obj.stillPosition.put(axisID,obj.minPosition.get(axisID)+(obj.minPosition.get(axisID)+obj.maxPosition.get(axisID))/2);
                end
            end
        end
        
        function DCO(obj, axisIDs, driftCompensationMode)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                obj.driftCompensationMode.put(axisIDs(1,i),driftCompensationMode(1,i));
            end
        end
        
        function FRF(obj, axisIDs)
            for axisID=obj.cleanAxisIds(axisIDs)
                obj.referenceStatus.put(axisID,true);
                obj.stillPosition.put(axisID,obj.minPosition.get(axisID)+(obj.minPosition.get(axisID)+obj.maxPosition.get(axisID))/2);
            end
        end
        
        function status=qFRF(obj, axisIDs)
            for axisID=obj.cleanAxisIds(axisIDs)
                % unsure about the real implementation of referencing status
                status=obj.referenceStatus.get(axisID);
            end
        end
        
        function VEL(obj, axisIDs, vel)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                obj.velocity.put(axisIDs(1,i),vel(1,i));
            end
        end
        
        function vel=qVEL(obj, axisIDs)
            axisIDs=obj.cleanAxisIds(axisIDs);
            vel=nan(size(axisIDs))';
            for i=1:size(axisIDs,2)
                axisID=axisIDs(1,i);
                vel(i,1)=obj.velocity.get(axisID);
            end
        end
        
        function MOV(obj, axisIDs, target)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                axisID=axisIDs(1,i);
                if obj.direction.get(axisID)~=0
                    obj.stillPosition.put(axisID,obj.projectCurrentPostion(axisID));
                end
                obj.initMovement(axisID,target(1,i));
            end
        end
        
        function MVR(obj, axisIDs, relTarget)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                axisID=axisIDs(1,i);
                if obj.direction.get(axisID)~=0
                    obj.stillPosition.put(axisID,obj.projectCurrentPostion(axisID));
                end
                obj.initMovement(axisID,obj.stillPosition.get(axisID)+relTarget(1,i));
            end
        end
        
        function pos=qPOS(obj, axisIDs)
            axisIDs=obj.cleanAxisIds(axisIDs);
            pos=nan(size(axisIDs,2),1);
            for i=1:size(axisIDs,2)
                pos(i,1)=obj.projectCurrentPostion(axisIDs(1,i));
            end
        end
        
        function pos=qTMN(obj,axisIDs)
            axisIDs=obj.cleanAxisIds(axisIDs);
            pos=nan(size(axisIDs));
            for i=1:size(axisIDs,2)
            	pos(1,i)=obj.minPosition.get(axisIDs(1,i));
            end
        end
        
        function pos=qTMX(obj,axisIDs)
            axisIDs=obj.cleanAxisIds(axisIDs);
            pos=nan(size(axisIDs));
            for i=1:size(axisIDs,2)
                pos(1,i)=obj.maxPosition.get(axisIDs(1,i));
            end
        end
        
        function HLT(obj, axisIDs)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                obj.stillPosition.put(axisIDs(1,i),obj.projectCurrentPostion(axisIDs(1,i)));
                obj.direction.put(axisIDs(1,i),0);
            end
        end
        
        function SVO(obj, axisIDs, enable)
            axisIDs=obj.cleanAxisIds(axisIDs);
            for i=1:size(axisIDs,2)
                obj.servoMode.put(axisIDs(1,i),enable(1,i));
            end
        end
        
        function STP(obj)
            for i=obj.qSAI_ALL()
                obj.direction.put(i{1},0);
            end
        end
        
        function idn=qIDN(~)
            idn='CGS Controller Dummy';
        end
        
        function moving=IsMoving(obj, axisIDs)
            axisIDs=obj.cleanAxisIds(axisIDs);
            moving=false(size(axisIDs));
            for i=1:size(axisIDs,2)
                obj.projectCurrentPostion(axisIDs(1,i));
                moving(1,i)=obj.direction.get(axisIDs(1,i))~=0;
            end
        end
        
        function obj=ConnectUSB(obj, ~)
        end
        
        function obj=InitializeController(obj)
        end
        
        function CloseConnection(~)
        end
        
        function Destroy(~) 
        end
        
        function SetErrorCheck(~, ~)
        end
        
        
        function stageName=qCST(~, id)
            stageName=['Virtual Stage ', id];
        end
        
        function availableAxes=qSAI_ALL(obj)
            availableAxes=obj.availableAxes;
        end
        
        function error=GetError(~)
            error=0;
        end
    end
    
    methods(Access=private)
        function currentPos=projectCurrentPostion(obj,axisID)
            if obj.direction.get(axisID)==0
                currentPos=obj.stillPosition.get(axisID);
            else
                timeTravelled=toc(uint64(obj.startTime.get(axisID)));
                if timeTravelled>obj.projectedTravelTime.get(axisID)
                    currentPos=obj.target.get(axisID);
                    obj.stillPosition.put(axisID,currentPos);
                    obj.direction.put(axisID,0);
                else
                    currentPos=obj.stillPosition.get(axisID)+obj.velocity.get(axisID)*obj.direction.get(axisID)*timeTravelled;
                end
            end
        end
        
        function initMovement(obj, axisID, target)
            if target>obj.stillPosition.get(axisID)
                obj.direction.put(axisID,1);
            elseif target<obj.stillPosition.get(axisID)
                obj.direction.put(axisID,-1);
            else
                obj.direction.put(axisID,0);
            end
            obj.target.put(axisID,target);
            obj.startTime.put(axisID,tic);
            if obj.velocity.get(axisID)==0
                obj.projectedTravelTime.put(axisID,0);
            else
                obj.projectedTravelTime.put(axisID,abs(target-obj.stillPosition.get(axisID))/obj.velocity.get(axisID));
            end
        end
        
        function ax=cleanAxisIds(~,axes)
            if isnumeric(axes)
                %for gcs ONL function
                ax=axes;
            else
                ax=cell2mat(strsplit(axes));
            end
        end
    end
end

