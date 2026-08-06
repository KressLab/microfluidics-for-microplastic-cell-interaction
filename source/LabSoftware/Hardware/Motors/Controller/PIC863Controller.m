% Implements the C863 PI controller which can control 1 stage and is slower than
% the C884 controller.
classdef PIC863Controller < PILinearStageController
    methods
        function obj = PIC863Controller(piGcsController)
            obj@PILinearStageController(piGcsController,"enter Serial Number here");
        end
    end
end