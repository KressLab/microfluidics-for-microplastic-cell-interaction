classdef PI_GCS_ControllerDebugWrapper < handle
    % PI_GCS_ControllerDebugWrapper Wraps PI_GCS_Controller and tunnels the data
    % through, however, allows printing debug info for the original
    % controller whenever commands are issued to the controller.
    %
    % To use this class for debugging, init the PIC_GCSS_Controller in this way:
    % controller=PI_GCS_ControllerDebugWrapper(PI_GCS_Controller());
    % and call all controller methods just as you would on a
    % PI_GCS_Controller.
    properties
        logger;
        realController;
    end
    
    methods(Access=public)
        function obj=PI_GCS_ControllerDebugWrapper(realController)
            obj.logger=Logger.getInstance();
            obj.realController=realController;
        end
        
        function FNL(obj, axisID)
            obj.logger.debug(['Axis ',axisID,': Fast Reference Move To Negative Limit']);
            obj.realController.FNL(axisID);
        end
        
        function FPL(obj, axisID)
            obj.logger.debug(['Axis ',axisID,': Fast Reference Move To Positive Limit']);
            obj.realController.FNP(axisID);
        end
        
        function FRF(obj, axisID)
            obj.logger.debug('Axis ',axisID,': Fast Reference Move To Reference Switch ');
            obj.realController.FRF(axisID);
        end
        
        function status=qFRF(obj, axisID)
            status=obj.realController.qFRF(axisID);
            obj.logger.trace('Axis ',axisID,': Get Referencing Result (is ', status,')');
        end
        
        function VEL(obj, axisID, vel)
            obj.logger.debug('Axis ',axisID,': Set Closed-Loop Velocity ', vel,'mm/s.');
            obj.realController.VEL(axisID, vel);
        end
        
        function vel=qVEL(obj, axisID)
            vel=obj.realController.qVEL(axisID);
            obj.logger.trace('Axis ',axisID,': Get Closed-Loop Velocity ', vel,'mm/s.');
        end
        
        function MOV(obj, axisID, target)
            obj.logger.debug('Axis ',axisID,': Set Target Position (start absolute motion)  ', target,'mm.');
            obj.realController.MOV(axisID, target);
        end
        
        function ONL(obj, axisID, status)
            obj.logger.debug('Axis ',axisID,': Set online status to ',status);
            obj.realController.ONL(axisID,status);
        end
        
        function VCO(obj, axisID, velocityControlMode)
            obj.logger.debug('Axis ',axisID,': Set velocity control mode to ',velocityControlMode);
            obj.realController.VCO(axisID,velocityControlMode);
        end
        
        function DCO(obj, axisID, driftCompensationMode)
            obj.logger.debug('Axis ',axisID,': Set drift compensation mode to ',driftCompensationMode);
            obj.realController.DCO(axisID,driftCompensationMode);
        end
        
        function MVR(obj, axisID, relTarget)
            obj.logger.debug('Axis ',axisID,': Set Target Relative To Current Position (start relative motion)   ', relTarget,'mm.');
            obj.realController.MVR(axisID, relTarget);
        end
        
        function pos=qPOS(obj, axisID)
            pos=obj.realController.qPOS(axisID);
            obj.logger.trace('Axis ',axisID,': Get Real Motor Position ',pos,'mm.');
        end
        
        function pos=qTMN(obj,axisID)
            pos=obj.realController.qTMN(axisID);
            obj.logger.trace('Axis ',axisID,': Get Minimum Commandable Position ',pos,'mm.');
        end
        
        function pos=qTMX(obj,axisID)
            pos=obj.realController.qTMX(axisID);
            obj.logger.trace('Axis ',axisID,': Get Maximum Commandable Position ',pos,'mm.');
        end
        
        function HLT(obj, axisID)
            obj.realController.HLT(axisID);
            pos=obj.realController.qPOS(axisID);
            obj.logger.debug('Axis ',axisID,': Halt Motion Smoothly at ', pos,'mm.');
        end
        
        function SVO(obj, axisID, enable)
            obj.logger.debug('Axis ',axisID,': Set Servo Mode ', enable);
            obj.realController.SVO(axisID,enable);
        end
        
        function STP(obj)
            obj.logger.info('Stop All Axes');
            obj.realController.STP();
        end
        
        function idn=qIDN(obj)
            idn=obj.realController.qIDN();
            obj.logger.trace(['Get Device Identification: ',idn]);
        end
        
        function moving=IsMoving(obj, axisId)
            moving=obj.realController.IsMoving(axisId);
            obj.logger.trace('Axis ',axisId,': is moving: ',moving);
        end
        
        function obj=ConnectUSB(obj, serialNumber)
            obj.realController=obj.realController.ConnectUSB(serialNumber);
            obj.logger.info('Connecting via USB: ',strtrim(obj.realController.qIDN()));
        end
        
        function obj=InitializeController(obj)
            obj.realController=obj.realController.InitializeController();
            obj.logger.info('Initializing PI_GCS_Controller');
        end
        
        function obj=SetErrorCheck(obj,check)
            obj.realController.SetErrorCheck(check);
            obj.logger.debug('Setting error check to ', check);
        end
        
        function stageName=qCST(obj, id)
            stageName=obj.realController.qCST(id);
        end
        
        function availableAxes=qSAI_ALL(obj)
            availableAxes=obj.realController.qSAI_ALL();
        end
        
        function error=GetError(obj)
            error=obj.realController.GetError();
        end
        
        function CloseConnection(obj)
            obj.realController.CloseConnection();
            obj.logger.info('Connection to PI_GCS_Controller closed');
        end
        
        function Destroy(obj) 
             obj.logger.info('PI_GCS_Controller unloaded.');
        end
    end
end

