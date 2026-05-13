classdef (Abstract) PILinearStageController < PIController
    methods(Access=public)
        function obj = PILinearStageController(piGcsController, serialNumber)
                obj@PIController(piGcsController,serialNumber);
        end
    end
       
    methods(Access=protected)        
        function listAvailableAxes(obj)
            for idx = 1 : size(obj.availableAxes,2)
                stageName = obj.piGcsController.qCST(obj.availableAxes{idx});
                obj.logger.debug('Axis ',obj.availableAxes{idx},': ',stageName(1:end-1));
            end
        end
    end
end