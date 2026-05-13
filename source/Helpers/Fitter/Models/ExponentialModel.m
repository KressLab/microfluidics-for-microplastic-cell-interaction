% ########################
% Wolfgang Gross
% University of Bayreuth
% 09.07.15
% ########################

classdef ExponentialModel < Model
    methods (Access=public)
        % does not work for amplitude <0
        function initParams=getCalculatedInitializationParameters(~, x,y)
            amplitude=max(y)-min(y);
            decay=-(max(x)-min(x)/5);
            yOffset=min(y);
            initParams=[amplitude,decay,yOffset];
        end
        
        function fun= getFun(~)
            fun=@(param,x)(param(3)+param(1).*exp((x)./param(2)));
        end
        function parameterNames=getParameterNames(~)
            parameterNames={'amplitude', 'decay','yOffset'};
        end
        
        function parameterUnits=getParameterUnits(~)
            parameterUnits={'','',''};
        end
        
        function parameterCount=getParameterCount(~)
            parameterCount=3;
        end
        
        function count= getDerivedParameterCount(~)
            count=0;
        end
        
        function derivedParameters=getDerivedParameters(obj, measurementParameters, singleEventResults)
            derivedParameters= [];
        end
        
        function parameterNames=getDerivedParameterNames(~)
            parameterNames=[];
         end
        
        function parameterUnits=getDerivedParameterUnits(~)
            parameterUnits=[];
        end
    end
end