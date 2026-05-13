classdef (Abstract) PIController < handle
    % PI_GCS_Controller-Wrapper class of PI Stage controllers. Used to
    % control multiple PI stages with one command, e.g. start the recording
    % function of all of them a the same time.
    properties(Access=protected)
        logger;
        piGcsController;
        macroExecutor;
        
        availableAxes;
        connectedAxes=cell(0);
        connectedAxesIds;
        
        defaultServoEnabled=1;
    end
    
    methods(Abstract,Access=protected)
        listAvailableAxes(obj);
    end
    
    methods(Access=public)
        function obj = PIController(piGcsController, controllerSerialNumber)
            obj.logger=Logger.getInstance();
            obj.piGcsController = piGcsController.ConnectUSB(controllerSerialNumber);
            obj.piGcsController = obj.piGcsController.InitializeController();
            
            obj.piGcsController.SetErrorCheck(1);
            obj.connectedAxesIds='';
        end
        
        function moveStagesTo(obj,stageTarget)
            currentHardwareMotorPositions=obj.getCurrentHardwarePositions();
            motorTargets=nan(size(obj.connectedAxes));
            for i=1:size(obj.connectedAxes,2)
                motorTargets(1,i)=obj.connectedAxes{1,i}.getMoveToMotorTarget(stageTarget(1,i),currentHardwareMotorPositions(1,i));
            end
            if any(isnan(motorTargets))
                obj.logger.warn('Ignoring move command: Target is nan.');
                return;
            else
                for i=1:size(obj.connectedAxes,2)
                    currentStagePos=obj.connectedAxes{1,i}.getCenterStagePos();
                    if stageTarget(1,i)>currentStagePos
                        obj.connectedAxes{1,i}.setStageMovementDirection(1);
                    elseif stageTarget(1,i)<currentStagePos
                        obj.connectedAxes{1,i}.setStageMovementDirection(-1);
                    else
                        obj.connectedAxes{1,i}.setStageMovementDirection(0);
                    end
                end
                
                obj.piGcsController.MOV(obj.connectedAxesIds, motorTargets);
                for i=1:size(obj.connectedAxes,2)
                    obj.connectedAxes{1,i}.setStartPositions(currentHardwareMotorPositions(1,i));
                end
            end
        end
        
        function moveStagesBy(obj,distance)
            for i = 1:size(distance,2)
                obj.connectedAxes{1,i}.moveStageBy(distance(1,i));
            end
        end
        
        % required for piezo stage
        function moveStagesFastAndDirtyBy(obj,distance)
            obj.piGcsController.MVR(obj.connectedAxesIds, distance);
        end
        
        function moveToCenter(obj)
            for i = 1:size(obj.connectedAxes,2)
                obj.connectedAxes{1,i}.moveToCenter();
            end
        end
        
        function moveStagesStraightTo(obj, point, velocity)
            distanceVector = point-obj.getCurrentStagePos();
            if sum(distanceVector)==0
                return;
            end
            
            obj.setStraightVelocity(distanceVector, velocity);
            for i = 1:size(point,2)
                obj.connectedAxes{1,i}.moveStageTo(point(1,i));
            end
        end
        
        function positions=getCurrentStagePos(obj)
            currentHardwareMotorPositions=obj.getCurrentHardwarePositions();
            positions=nan(1,size(obj.connectedAxes,2));
            for i = 1:size(obj.connectedAxes,2)
                positions(1,i)=obj.connectedAxes{1,i}.getCurrentStagePosByCurrentHardwareMotorPos(currentHardwareMotorPositions(1,i));
            end
        end
        
        function moveAxesStraightBy(obj, distance, velocity)
            obj.setStraightVelocity(distance, velocity);
            obj.moveStagesBy(distance);
        end
        
        function setStraightVelocity(obj, distance, velocity)
            obj.setVel(abs(velocity.*distance./norm(distance)));
        end
        
        function startExecuteMacro(obj, commandString)
            obj.macroExecutor=PIMacroExecutor(obj);
            obj.macroExecutor.startExecuteMacro(commandString);
        end
        
        function update(obj)
            if ~isempty(obj.macroExecutor)
                obj.macroExecutor.update();
            end
            currentHardwareMotorPositions=obj.getCurrentHardwarePositions();
            for i=1:size(obj.connectedAxes,2)
                obj.connectedAxes{1,i}.update(currentHardwareMotorPositions(1,i));
            end
        end
        
        function setVel(obj,velocities)
            obj.piGcsController.VEL(obj.connectedAxesIds, velocities);
        end
        
        function currentVel=getVel(obj)
            currentVel=obj.piGcsController.qVEL(obj.connectedAxesIds)';
        end
        
        function startRecording(obj)
            obj.checkErrors();
            currentHardwareMotorPositions=obj.getCurrentHardwarePositions();
            for i=1:size(obj.connectedAxes,2)
                obj.connectedAxes{1,i}.startRecording(currentHardwareMotorPositions(1,i));
            end
        end
        
        function pos=getCurrentHardwarePositions(obj)
            pos=obj.piGcsController.qPOS(obj.connectedAxesIds)';
        end
        
        function stopRecording(obj)
            for i=1:size(obj.connectedAxes,2)
                obj.connectedAxes{1,i}.stopRecording();
            end
            obj.checkErrors();
        end
        
        function stagePos=getRecordedStagePositions(obj)
            stagePos=cell(size(obj.connectedAxes));
            for i=1:size(obj.connectedAxes,2)
                stagePos{1,i}=obj.connectedAxes{1,i}.getRecordedStagePositions();
            end
        end
        
        function init=allInitialized(obj)
            for i=1:size(obj.connectedAxes,2)
                if ~obj.connectedAxes{1,i}.isInitialized()
                    init=false;
                    return;
                end
            end
            init=true;
        end
        
        function moving=isAnyMoving(obj)
            moving=sum(obj.piGcsController.IsMoving(obj.connectedAxesIds))>0;
        end
        
        function connectTo(obj, axis)
            axis.addController(obj.piGcsController);
            obj.connectedAxes{1,end+1}=axis;
            obj.connectedAxesIds=strtrim([obj.connectedAxesIds,' ',axis.getAxisId()]);
            
            obj.piGcsController.SVO(obj.connectedAxesIds, repmat(obj.defaultServoEnabled,1,size(obj.connectedAxes,2)));
        end
        
        function testConnectedAxes(obj)
            obj.availableAxes = obj.piGcsController.qSAI_ALL();
            if ~iscell(obj.availableAxes)
                obj.availableAxes={obj.availableAxes};
            end
            obj.listAvailableAxes();
            obj.checkErrors();
        end
        
        function checkErrors(obj)
            code=obj.piGcsController.GetError();
            if code==2
                obj.logger.fatal('Controller error: Unknown command issued in the recent past.');
            elseif code==10
                obj.logger.debug('A stop command was issued to the stage.');
            elseif code>0
                obj.logger.fatal('PI Error detected (code ', code,'). Check the PI manual.');
            else
                obj.logger.trace('No errors.');
            end
        end
        
        function haltAll(obj)
            if ~isempty(obj.macroExecutor)
                obj.macroExecutor.haltExecution();
            end
            for i=1:size(obj.connectedAxes,2)
                obj.connectedAxes{1,i}.setStageMovementDirection(0);
            end
            obj.piGcsController.HLT(obj.connectedAxesIds);
        end
        
        function axes=getConnectedAxes(obj)
            axes=obj.connectedAxes;
        end
        
        function delete(obj)
            obj.haltAll();
            obj.checkErrors();
            obj.piGcsController.CloseConnection();
            obj.piGcsController.Destroy();
        end
    end
end