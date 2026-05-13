% ########################
% Wolfgang Gross
% University of Bayreuth
% 09.07.15
% ########################

classdef Model < handle
    %MODEL Blueprint container class implementing a model used for fitting in the Fitter class.
    %   Can be extended and reused by subclasses. Does not implement logic aside from parameter
    %   estimation. To fix parameters
    
    properties (Access=private)
        %double
        boundSpread=.5;
        
        fixedParamPositions;        % Boolean of the positions that are fixed during fitting.
        fixedParamValues;           % Values of the parameters that are fixed. NaN for non-fixed parameters.
    end
   
    properties(Access=protected)
        logger=Logger.getInstance();
    end
    
    methods (Access=public, Sealed)
        function initializationParameters=getInitializationParameters(obj,xToFit,yToFit)
            initializationParameters=obj.getCalculatedInitializationParameters(xToFit, yToFit);
            initializationParameters(obj.fixedParamPositions)=obj.fixedParamValues(obj.fixedParamPositions);
        end
    end
    
    methods(Access=public)
        function count=getCalculatedInitializationParameters(obj, xToFit,yToFit)
            % x,y are the variables used for fitting to determine a rough
            % estimate of the parameter set for the fitting function. Ignored here, 
            % but can be useful in more difficult models
            % (subclasses should use the same interface and not deviate
            % from this calling sequence, deviation will cause the Fitter to fail!).
            error(strcat('MethodNotImplementedException: getParameterCount(obj) has to be implemented in subclass',class(obj)));
            count=[];
        end
    end
    
    methods (Access=public)
        function fun=getFun(obj)
            error(strcat('MethodNotImplementedException: getFun(obj) has to be implemented in subclass',class(obj)));
            fun=[];
        end
        
        
        function count=getParameterCount(obj)
            error(strcat('MethodNotImplementedException: getParameterCount(obj) has to be implemented in subclass',class(obj)));
            count=[];
        end
        
        function parameterNames=getParameterNames(obj)
            error(strcat('MethodNotImplementedException: getParameterNames(obj) has to be implemented in subclass',class(obj)));
            parameterNames=[];
        end
        
        function parameterUnits=getParameterUnits(obj)
            error(strcat('MethodNotImplementedException: getParameterUnits(obj) has to be implemented in subclass',class(obj)));
            parameterUnits=[];
        end
        
        
        function derivedParameters=getDerivedParameters(obj, measurementParameters, singleEventResults)
            % measurementParameters are the parameters specified for the
            % input dataset
            % singleEvent results wraps all the results of the fitting of
            % one single event as specified by
            % getSingleEventFittingResults(...) in measurement.
            error(strcat('MethodNotImplementedException: getDerivedParameters(obj, measurementParameters, singleEventResults) has to be implemented in subclass',class(obj)));
            derivedParameters=[];
        end
        
        function count= getDerivedParameterCount(obj)
            error(strcat('MethodNotImplementedException: getDerivedParameterCount(obj) has to be implemented in subclass',class(obj)));
            count=[];
        end
        
        function parameterNames=getDerivedParameterNames(obj)
            error(strcat('MethodNotImplementedException: getDerivedParameterNames(obj) has to be implemented in subclass',class(obj)));
            parameterNames=[];
         end
        
        function parameterUnits=getDerivedParameterUnits(obj)
            error(strcat('MethodNotImplementedException: getDerivedParameterUnits(obj) has to be implemented in subclass',class(obj)));
            parameterUnits=[];
        end
        
        function lb= getLowerParameterBounds(obj,xToFit,yToFit)
            lb=obj.getInitializationParameters(xToFit,yToFit);
            lb=lb-abs(lb)*obj.boundSpread;
        end
        
        function ub= getUpperParameterBounds(obj,xToFit,yToFit)
            ub=obj.getInitializationParameters(xToFit,yToFit);
            ub=ub+abs(ub)*obj.boundSpread;
        end
        
        function setFixedParameters(obj, fixedParams)
            if size(fixedParams,2)~=obj.getParameterCount() || size(fixedParams,1)~=1
                error('invalid parameter count or format');
            end
            obj.fixedParamPositions=~isnan(fixedParams);
            obj.fixedParamValues=fixedParams;
        end
        
        function fixed=hasFixedParameters(obj)
            fixed=any(obj.getFixedPositions());
        end
        
        function fixedPos=getFixedPositions(obj)
            if isempty(obj.fixedParamPositions)
                fixedPos=boolean(zeros(1, obj.getParameterCount()));
            else
                fixedPos=obj.fixedParamPositions;
            end
        end
        
        function params=getFixedParameters(obj)
            if isempty(obj.fixedParamPositions)
                params=NaN(1, obj.getParameterCount());
            else
                params=obj.fixedParamValues;
            end
        end
        
        function y=getY(obj,param,x)
            fun=obj.getFun();
            y=fun(param,x);
        end
    end
end

