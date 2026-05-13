classdef PILinearAxis < PIAxis
    properties(Access=private)
        DEFAULT_VELOCITY=1;
    end
    
    methods(Access=public)
        function obj=PILinearAxis(axisId,coordinateSystem, backlash)
            obj@PIAxis(axisId,coordinateSystem, backlash);
        end
    end
    
    methods(Access=protected)
        function preInit(obj)
            obj.setVel(obj.DEFAULT_VELOCITY);
        end
        
        function initMotorCoordinateSystem(obj,referencePositionMotorCOS)
            switch(referencePositionMotorCOS)
                case 'N'
                   obj.piGcsController.FNL(obj.axisId);
                case 'P'
                   obj.piGcsController.FPL(obj.axisId);
                case 'C'
                    obj.piGcsController.FRF(obj.axisId);
                otherwise
                    obj.logger.fatal('Axis: ',obj.axisId, ': ',position,' is not a valid init position');
            end
            while(0 ~= obj.piGcsController.qFRF(obj.axisId) == 0 )
                pause(0.05);
            end
        end
        
        function postInit(~, ~)
        end
    end
end

