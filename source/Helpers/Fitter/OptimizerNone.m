% ########################
% Wolfgang Gross
% University of Bayreuth
% 01.09.16
% ########################
% 01.09.16 (WG)
% Initial version
%
% 16.09.16 (WG)
% Updated for new startparameter optimizer class

classdef OptimizerNone<StartParameterOptimizer
    % Just returns the start parameters specified by the model
    methods(Access=public)
        function optimalStartParameters=calcOptimalStartParameters(obj, ~,~,~,initalParams,~,~,~)
            optimalStartParameters=initalParams;
        end
    end
end

