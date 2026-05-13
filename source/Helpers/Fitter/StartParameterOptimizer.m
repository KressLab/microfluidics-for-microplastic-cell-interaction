% ########################
% Wolfgang Gross
% University of Bayreuth
% 16.09.16
%
% Abstract class that optimizes start parameters for fitting. Matlabs main
% fitting function nlinfit and lsqcurvefit are supported.
% The class tries to minimize the residual sum of squares of the output
% fit.
%
% WARNING:
% THIS CLASS IS NOT THREAD SAFE! DO NOT USE THIS CLASS IN PARALLEL CODE!
% THIS CLASS AND MAYBE OTHERS WILL PRODUCE WRONG RESULTS IF YOU DO SO!
%
% ########################
% 01.09.16 (WG)
%   -first implementation
% 16.09.16 (WG)
%   -fixed issues with LSQCURVEFIT
%   -resolved the problem that all errors were treated as fitting errors.
%    The routine only treats native matlab fitting warnings as errors
%    during the normal control flow and rethrows all other errors (e.g.
%    errors occuring in the user-defined model classes
%   -added warning that indicates


classdef StartParameterOptimizer<handle
    % Abstract class for determining the the best start parameters for
    % fitting a model function to a given dataset
    
    methods(Access=public, Abstract=true)
        optimalStartParameters=calcOptimalStartParameters(obj, x, y, model, initalParams, fittingAlgorithm, lb, ub);
    end
    
    methods(Access=public)
        %wrapper function for abstract subclass interface. Ensures that all
        %fitting warnings are treated as errors during
        %calculation->try-catch construct can be used to detect whether
        %fitting was successful.
        function optimalStartParameters=getOptimalStartParameters(obj, x, y, model, initalParams, fittingAlgorithm, lb, ub)
            s=obj.fittingWarningsAreErrors();
            optimalStartParameters=obj.calcOptimalStartParameters(x, y, model, initalParams, fittingAlgorithm, lb, ub);
            warning(s);
        end
    end
    
    methods(Access=protected)
        function residual_sum_squared = objective(initialParams,obj, x, y, modelFun, fittingAlgorithm,lb,ub, fixed)
            %   objective used for initialization of start parameters.
            %   residual_sum_squared of the resulting fit is the value that
            %   is minimized
            try
                switch (fittingAlgorithm)
                    case 'NLINFIT'
                        [~,res,~,~,~,~]=nlinfitFixedParams(fixed, x, y, modelFun,initialParams);
                    case 'LSQCURVEFIT'
                        [~,~,res,~,~,~,~]=...
                                lsqcurvefit(modelFun,initialParams,x, y,lb,ub,optimset('Display','off'));
                    otherwise
                        disp(strcat('Fitting Algorithmx ',fittingAlgorithm,' not supported by StartParameterOptimizer'));
                end
                residual_sum_squared=sum(res.*res);
            catch e
                if obj.isFittingError(e)
                    residual_sum_squared=realmax('double');
                else
                    rethrow(e);
                end
            end
        end
        
        function isFitError = isFittingError(~, ME)
            isFitError=strcmp(ME.identifier,'MATLAB:nearlySingularMatrix')||...
                strcmp(ME.identifier,'MATLAB:rankDeficientMatrix')||...
                strcmp(ME.identifier,'stats:nlinfit:IterationLimitExceeded')||...
                strcmp(ME.identifier,'stats:nlinfit:IllConditionedJacobian')||...
                strcmp(ME.identifier,'stats:nlinfit:NonFiniteFunOutput')||...
                strcmp(ME.identifier,'stats:nlinfit:Overparameterized')||...
                strcmp(ME.identifier,'stats:nlinfit:ModelConstantWRTParam');
        end
        
        function s=fittingWarningsAreErrors(obj)
            s=warning;
            % throw errors instead of warnings during fitting. Used for
            % control flow.
            warning('error','MATLAB:nearlySingularMatrix');
            warning('error','MATLAB:rankDeficientMatrix');
            warning('error','stats:nlinfit:IterationLimitExceeded');
            warning('error','stats:nlinfit:IllConditionedJacobian');
            warning('error','stats:nlinfit:NonFiniteFunOutput');
            warning('error','stats:nlinfit:Overparameterized');
            warning('error','stats:nlinfit:ModelConstantWRTParam');
        end
    end
end

