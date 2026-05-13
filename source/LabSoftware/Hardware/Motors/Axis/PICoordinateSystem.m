classdef (Sealed) PICoordinateSystem 
    %PICOORDINATESYSTEM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        HARDWARE=1;
        REVERSED=-1;
        logger=Logger.getInstance();
    end
    
    methods(Static)
        function string=toString(system)
            switch(system)
                case PICoordinateSystem.REVERSED
                    string='REVERSED';
                case PICoordinateSystem.HARDWARE
                    string='HARDWARE';
                otherwise
                    obj.logger.fatal('System ', system, ' unknown.');
            end
        end
    end
end