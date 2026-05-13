classdef (Abstract) PIAxis<handle
    % Custom implmentation of a single PIAxis
    % Supports keyboard control (multiple keys simultaneously, only for windows pc), position
    % logging, and backlash correction.
    %
    % Length unit is mm for linear stages and um for piezo stage
    % Time unit is s
    %
    % The axes have a backlash of a couple of um when switching direction. The reported motor
    % positions are therefore different than the stage coordinates. This implementation
    % keeps track of where the stage is in the deadzone and corrects the
    % missmatch.
    %
    % When the pysical stage has a noticable backlash, set the backlash to a value > 0.
    % To measure the backlash, set backlash to 0 and move the stage forwards and backwards while tracking the
    % absolute distance the stage moved (e.g. in CCTrackingLive MT configuration).
    %
    %
    % The coordinate system layouts are as follows:
    % GCS driver (HardwareMotor)
    % Init positions             N-------------------C-------------------P
    % Motor pos (0 min, 1 max)   0<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<1
    %
    % Stage (PICoordinateSystem.HARDWARE)
    % Stage init positions       N-------------------C-------------------P
    % Backlash blocked region    -------------------------------------xxxx
    % Stage pos wo software lim  0<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<1----
    % Stage pos software limits  ----x----------------------------x-------    
    % Stage pos w software lim   ----0<<<<<<<<<<<<<<<<<<<<<<<<<<<<1-------
    %
    % Stage (PICoordinateSystem.REVERSED)
    % Init positions             P-------------------C-------------------N
    % Backlash blocked region    xxxx-------------------------------------
    % Stage pos wo software lim  ----1>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>0
    % Stage pos software limits  -------x----------------------------x----  
    % Stage pos w software lim   -------1>>>>>>>>>>>>>>>>>>>>>>>>>>>>0----
    %
    % IMPORTANT
    % -Stage software limits are not checked during initialization, i.e.
    %  init positions may be outside of software limits!
    % -Stage position is limited by backlash and software limits.
    
    properties(Access=public)
        logger=Logger.getInstance();
        
        % holds a reference to the PI gcs controller
        % (the PI implementation)
        piGcsController;
        % the port at the controller at which the axis is connected
        axisId;
        defaultVelocity=1;
        
        % the motor coordinate system (can be set to PICoordinateSystem.HARDWARE or PICoordinateSystem.REVERSED)
        coordinateSystem;
        
        keyboard;
        keyboardControlEnabled=false;
        forwardKey;
        backwardKey;
        
        started; % bool
        initialized; % bool
        minMotorPos;
        minStagePos;
        minStagePosSoftwareLimit; % ignored if empty []
        maxMotorPos;
        maxStagePos;
        maxStagePosSoftwareLimit; % ignored if empty []
        recordedStagePositions;
        recordedStageVelocities;
        stageMovementDirection; % 1: pos gets larger, 0: no movement, -1: pos gets smaller
        recordStageVelocity;
        
        totalBacklash;
        % the backlash position at which the current movement started
        backlashStartPos;
        % the position of the motor (driver value) when the current movement started
        motorPositionStart;
    end
    
    methods(Access=protected,Abstract)
        preInit(obj);
        initMotorCoordinateSystem(obj,referencePositionMotorCOS);
        postInit(obj,referencePositionStageCOS);
    end
    
    methods(Access=public)
        % backlash: the backlash of the axis has to be measured externally
        function obj = PIAxis(axisId,coordinateSystem, backlash)
            obj.axisId=axisId;
            obj.setCoordinateSystem(coordinateSystem);
            obj.started=false;
            obj.initialized=false;
            obj.totalBacklash=backlash;
            obj.stageMovementDirection=0;
            obj.recordStageVelocity=false;
            obj.logger.debug('Axis: ', obj.axisId,': backlash ', backlash);
        end
        
        function id=getAxisId(obj)
            id=obj.axisId;
        end
        
        function setRecordStageVelocity(obj,record)
            % Class is updated slower when set to true
            obj.recordStageVelocity=record;
        end
        
        function setCoordinateSystem(obj, coordinateSystem)
            if obj.isInitialized()
                obj.logger.fatal('Axis ', obj.axisId,': Must not set coordinate system after initialization.');
            end
            if (coordinateSystem~=PICoordinateSystem.HARDWARE && ...
                coordinateSystem~=PICoordinateSystem.REVERSED)
                obj.logger.fatal('Axis ', obj.axisId,': Invalid coordinate system: ', coordinateSystem);
            end
            obj.coordinateSystem=coordinateSystem;
            obj.logger.debug('Axis: ', obj.axisId,' coordinate system: ', PICoordinateSystem.toString(coordinateSystem));
        end
        
        function setKeyboardControl(obj, forwardKey, backwardKey)
            if ispc()
                obj.keyboard=KeyboardInput();
                obj.forwardKey = forwardKey;
                obj.backwardKey = backwardKey;
                obj.logger.debug('Stage ', obj.axisId,': Keyboard forward:', forwardKey, ' keyboard backwards: ',backwardKey);
            else
                obj.logger.warn('Stage ', obj.axisId,': Keyboard is disabled on linux.');
            end
        end
        
        function enableKeyboardControl(obj)
            if ispc()
                if isempty(obj.forwardKey)||isempty(obj.backwardKey)
                    error('keys are not valid');
                end
                obj.keyboard.clear();
                obj.keyboard.mapKey(obj.backwardKey);
                obj.keyboard.mapKey(obj.forwardKey);
                obj.keyboard.addConflictGroup({obj.backwardKey,obj.forwardKey});
                obj.keyboardControlEnabled=true;
                obj.logger.debug('Axis ', obj.axisId,': Keyboard enabled.');
            else
                obj.keyboardControlEnabled=false;
                obj.logger.warn('Stage ', obj.axisId,': Keyboard is disabled on linux.');
            end
        end
        
        function disableKeyboardControl(obj)
            if ispc()
                obj.halt();
                obj.keyboard.unmapKey(obj.backwardKey);
                obj.keyboard.unmapKey(obj.forwardKey);
                obj.keyboard.removeConflictGroup({obj.backwardKey,obj.forwardKey});
                obj.keyboardControlEnabled=false;
                obj.logger.debug('Axis ', obj.axisId,': Keyboard disabled.');
            else
                obj.keyboardControlEnabled=false;
                obj.logger.warn('Stage ', obj.axisId,': Keyboard is disabled on linux.');
            end
        end
        
        function setMaxStagePosSoftwareLimit(obj, maxStagePosSoftware)
            if obj.isInitialized()
                obj.logger.fatal('Stage must not be initialized when setting stage software limit');
            end
            obj.maxStagePosSoftwareLimit=maxStagePosSoftware;
            obj.logger.debug('Axis ', obj.axisId,': Set max stage pos software limit to ',maxStagePosSoftware);
        end
        
        function maxLimit=getMaxStagePosSoftwareLimit(obj)
            maxLimit=obj.maxStagePosSoftwareLimit;
        end
        
        function setMinStagePosSoftwareLimit(obj, minStagePosSoftware)
            if obj.isInitialized()
                obj.logger.fatal('Stage must not be initialized when setting stage software limit');
            end
            obj.minStagePosSoftwareLimit=minStagePosSoftware;
            obj.logger.debug('Axis ', obj.axisId,': Set min stage pos software limit to ',minStagePosSoftware);
        end
        
        function minLimit=getMinStagePosSoftwareLimit(obj)
            minLimit=obj.minStagePosSoftwareLimit;
        end
        
        function startRecording(obj,currentHardwareMotorPos)
            obj.started=true;
            obj.recordedStagePositions=obj.getCurrentStagePosByCurrentHardwareMotorPos(currentHardwareMotorPos);
            if obj.recordStageVelocity
                obj.recordedStageVelocities=obj.getStageVel();
            end
            obj.logger.debug('Axis ', obj.axisId,': Started recording.');
        end
        
        function stopRecording(obj)
            obj.started=false;
            obj.logger.debug('Axis ', obj.axisId,': Stopped recording.');
        end
        
        function started=isRecordingStarted(obj)
            started=obj.started;
        end
        
        function vel=getRecordedStageVelocities(obj)
            vel=obj.recordedStageVelocities;
        end
        
        function pos=getRecordedStagePositions(obj)
            pos=obj.recordedStagePositions;
        end
        
        function pos=getLastRecordedStagePosition(obj)
            pos=obj.recordedStagePositions(end,1);
        end
        
        % For PIController when all axes are moved with the same command
        function setStageMovementDirection(obj,dir)
            if ~ismember(dir,[-1,0,1])
                obj.logger.fatal('Invalid direction...only call this method if you know the implications',...
                                  '(i.e. you gave a direct move command to the PI_GCS_Controller).');
            end
            obj.stageMovementDirection=dir;
        end
        
        % Updates the keybard control and records the current stage
        % position.
        function update(obj,currentHardwareMotorPos)
            if ~obj.started
                obj.logger.fatal('Axis ',obj.axisId, ': Start stage first!');
            end
            obj.logger.trace('Axis ',obj.axisId, ': Updating.');
            obj.recordedStagePositions(end+1,1)=obj.getCurrentStagePosByCurrentHardwareMotorPos(currentHardwareMotorPos);
            if obj.recordStageVelocity
                obj.recordedStageVelocities(end+1,1)=obj.getStageVel();
            end
            if obj.keyboardControlEnabled
                obj.keyboard.update();
                if(obj.keyboard.isKeyPressed(obj.backwardKey))
                    obj.logger.debug('Axis ',obj.axisId, ': backward key ', obj.backwardKey, ' pressed');
                    obj.moveStageTo(obj.getMinStagePos());
                end
                if(obj.keyboard.isKeyReleased(obj.backwardKey))
                    obj.logger.debug('Axis ',obj.axisId, ': backward key ', obj.backwardKey, ' released');
                    obj.halt();
                end
                if(obj.keyboard.isKeyPressed(obj.forwardKey))
                    obj.logger.debug('Axis ',obj.axisId, ': forward key ', obj.forwardKey, ' pressed');
                    obj.moveStageTo(obj.getMaxStagePos());
                end
                if(obj.keyboard.isKeyReleased(obj.forwardKey))
                    obj.logger.debug('Axis ',obj.axisId, ': forward key ', obj.forwardKey, ' released');
                    obj.halt();
                end
            end
        end
        
        function setVel(obj, velocity)
            obj.piGcsController.VEL(obj.axisId, velocity);
        end
        
        function currentVel=getStageVel(obj)
            if obj.isMoving()
                currentVel=obj.stageMovementDirection.*double(obj.getVel());
            else
                currentVel=0;
            end
        end
        
        function currentVel=getVel(obj)
            currentVel=obj.piGcsController.qVEL(obj.axisId);
        end
        
        function isMoving=isMoving(obj)
            isMoving=obj.piGcsController.IsMoving(obj.axisId);
        end
        
        function halt(obj)
            obj.logger.info('DEPRECATED. Use controller.haltAll()');
            obj.piGcsController.HLT(obj.axisId);
            obj.stageMovementDirection=0;
        end
        
        % Do not call this method directly. Call PIController.connectTo(axis).
        % addController() gets called by the PIController then.
        function addController(obj, piGcsController)
            obj.piGcsController=piGcsController;
        end
        
        function isEnabled = isKeyboardEnabled(obj)            
            isEnabled = obj.keyboardControlEnabled;            
        end
        
        % Position parameter
        %   'N': negative, hardware min motor position
        %   'P': positive, hardware max motor position
        %   'C': center, hardware center position
        function init(obj, referencePositionStageCOS)
            referencePositionMotorCOS=obj.refPosToMotorCoordinateSystem(referencePositionStageCOS);
            obj.setVel(obj.defaultVelocity);
            obj.preInit();
            obj.initMotorCoordinateSystem(referencePositionMotorCOS);
            obj.initStageCoordinateSystem();
            obj.postInit(referencePositionStageCOS);
            obj.initialized=true;
            obj.logger.info('Axis ',obj.axisId,': Fully initialized.');
        end
        
        function initStageCoordinateSystem(obj)
            obj.minMotorPos=obj.fetchMinMotorPos();
            obj.maxMotorPos=obj.fetchMaxMotorPos();
            obj.minStagePos=obj.fetchMinStagePos();
            obj.maxStagePos=obj.fetchMaxStagePos();
            
            obj.backlashStartPos = 0;
            obj.motorPositionStart = obj.getCurrentMotorPos();
            obj.logger.trace('Axis ',obj.axisId, ' Piezo starting position: x=', obj.motorPositionStart(1));
            obj.moveStageBy(-obj.totalBacklash*2);
            % hardware and software are lined up now
            % physicalBacklashPos=0;
            % softwareBacklashPos=0;
            % -> backlashPos=0 <-> the motor and stage positions are equal
        end
        
        function init=isInitialized(obj)
           init=obj.initialized;
        end
        
        function moveStageTo(obj, newStageTarget)
            currentHardwareMotorPosition=obj.getCurrentHardwareMotorPosition();
            motorTarget=obj.getMoveToMotorTarget(newStageTarget,currentHardwareMotorPosition);
            if isnan(motorTarget)
                obj.logger.warn('Axis ',obj.axisId,': Ignoring move command');
                return;
            else
                currentStagePos=obj.getCurrentStagePos();
                if newStageTarget>currentStagePos
                    obj.stageMovementDirection=1;
                elseif newStageTarget<currentStagePos
                    obj.stageMovementDirection=-1;
                else
                    obj.stageMovementDirection=0;
                end
                obj.piGcsController.MOV(obj.axisId, motorTarget);
                obj.setStartPositions(currentHardwareMotorPosition);
            end
        end
        
        function motorTarget=getMoveToMotorTarget(obj, stageTarget,currentHardwareMotorPosition)
            if ~obj.stagePositionWithinStageLimits(stageTarget)
                motorTarget=nan;
                return;
            end
            stagePositionChange=stageTarget-obj.getCurrentStagePosByCurrentHardwareMotorPos(currentHardwareMotorPosition);
            if stagePositionChange < 0
                motorTarget=stageTarget;
            else
                motorTarget=stageTarget + obj.totalBacklash;
            end
            
            if obj.coordinateSystem==PICoordinateSystem.REVERSED
                motorTarget=obj.getMaxMotorPos()-motorTarget;
            end
        end
        
        function centerPos=getCenterStagePos(obj)
            centerPos=(obj.getMaxStagePos()-obj.getMinStagePos())/2+obj.getMinStagePos();
        end
        
        function moveToCenter(obj)
            obj.moveStageTo(obj.getCenterStagePos());
        end
        
        function moveStageBy(obj, stagePositionChange)
            currentMotorPos=obj.getCurrentMotorPos();
            if ~obj.stagePositionWithinStageLimits(obj.getCurrentStagePos()+stagePositionChange)
                obj.logger.warn('Axis ',obj.axisId,': Ignoring move command');
                return;
            end
            if stagePositionChange < 0
                obj.stageMovementDirection=-1;
                obj.piGcsController.MVR(obj.axisId, obj.coordinateSystem*(stagePositionChange - obj.getCurrentBacklashPos(currentMotorPos)));
            else
                obj.stageMovementDirection=1;
                obj.piGcsController.MVR(obj.axisId, obj.coordinateSystem*(stagePositionChange + obj.totalBacklash - obj.getCurrentBacklashPos(currentMotorPos)));
            end
            obj.setStartPositions(obj.getCurrentHardwareMotorPosition());
        end
        
        function pos=getCurrentStagePos(obj)
            pos=obj.getCurrentStagePosByCurrentHardwareMotorPos(obj.getCurrentHardwareMotorPosition());
        end
        
        function minPos=getMinStagePos(obj)
             minPos=obj.minStagePos;
        end
        
        function maxPos=getMaxStagePos(obj)
            maxPos=obj.maxStagePos;
        end
        
        function setStartPositions(obj,currentHardwareMotorPos)
            currentMotorPos=obj.hardwareMotorPosToCoSystem(currentHardwareMotorPos);
            % The backlashPos from the last move command is the new start
            % backlashPosition
            obj.backlashStartPos = obj.getCurrentBacklashPos(currentMotorPos);
            obj.motorPositionStart = currentMotorPos;
        end
        
        function pos=getCurrentStagePosByCurrentHardwareMotorPos(obj,currentHardwareMotorPos)
            currentMotorPos=obj.hardwareMotorPosToCoSystem(currentHardwareMotorPos);
            pos=currentMotorPos-obj.getCurrentBacklashPos(currentMotorPos);
        end
    end
    
    methods(Access=protected)
        function position=refPosToMotorCoordinateSystem(obj,position)
           if obj.coordinateSystem==PICoordinateSystem.HARDWARE
               return;
           end
           switch(position)
                case 'N'
                   position='P';
                case 'P'
                   position='N';
                case 'C'
                   return;
                otherwise
                    obj.logger.fatal('Axis: ',obj.axisId, ': ',position,' is not a valid init position');
            end
        end
        
        function inLimits=stagePositionWithinStageLimits(obj,stagePosition)
            if isempty(stagePosition)
                obj.logger.fatal('Axis: ',obj.axisId, ': Target position is empty');
            elseif isnan(stagePosition)
                obj.logger.fatal('Axis: ',obj.axisId, ': Target position is nan');
            elseif stagePosition<obj.getMinStagePos()
                obj.logger.warn('Axis: ',obj.axisId, ': Stage target position ',stagePosition,' is below stage limit: ',obj.getMinStagePos());
                inLimits=false;
                return;
            elseif stagePosition>obj.getMaxStagePos()
                obj.logger.warn('Axis: ',obj.axisId, ': Stage target position ',stagePosition,' is above stage limit: ',obj.getMaxStagePos());
                inLimits=false;
                return;
            end
            inLimits=true;
        end
        
        function minPos=fetchMinStagePos(obj)
            minPos=max([obj.fetchMinMotorPos(),obj.minStagePosSoftwareLimit]);
        end 
        
        function maxPos=fetchMaxStagePos(obj)
            maxPos=min([obj.fetchMaxMotorPos()-obj.totalBacklash,obj.maxStagePosSoftwareLimit]);
        end
        
        function pos=getCurrentHardwareMotorPosition(obj)
            pos=obj.piGcsController.qPOS(obj.axisId);
        end
        
        function pos=getCurrentMotorPos(obj)
            pos=obj.hardwareMotorPosToCoSystem(obj.getCurrentHardwareMotorPosition());
        end
        
        function pos=hardwareMotorPosToCoSystem(obj, hardwareMotorPos)
            if obj.coordinateSystem == PICoordinateSystem.HARDWARE
                pos=hardwareMotorPos;
            elseif obj.coordinateSystem == PICoordinateSystem.REVERSED
                pos=obj.maxMotorPos-hardwareMotorPos;
            end
        end
        
        function minPos=fetchMinMotorPos(obj)
            minPos=obj.piGcsController.qTMN(obj.axisId);
        end
        
        function maxPos=fetchMaxMotorPos(obj)
            maxPos=obj.piGcsController.qTMX(obj.axisId);
        end
        
        function minPos=getMinMotorPos(obj)
            minPos=obj.minMotorPos;
        end
        
        function maxPos=getMaxMotorPos(obj)
            maxPos=obj.maxMotorPos;
        end
        
        % currentMotorPos is passed in since obj.getCurrentMotorPos() is
        % slow on C863
        function currentBacklashPos = getCurrentBacklashPos(obj, currentMotorPos)
            currentBacklashPos = obj.backlashStartPos + currentMotorPos - obj.motorPositionStart;
            currentBacklashPos = clampMatrix(currentBacklashPos,0,obj.totalBacklash);
        end
    end
end