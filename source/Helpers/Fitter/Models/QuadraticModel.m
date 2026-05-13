% ########################
% Wolfgang Gross
% University of Bayreuth
% 09.07.15
% ########################

classdef QuadraticModel < Model
    methods (Access=public)
        function initParams=getCalculatedInitializationParameters(~, x,y)
            yOffset=min(y);
            
            dx=(max(x)-min(x))/2;
            y1=mean(y(x==min(x)));
            y2=mean(y(y==min(y)));
            y3=mean(y(x==max(x)));
            curvature=(-y1-y3+2.*y2)/(dx.^2);
            
            xOffset=mean(x(y==min(y)));
            
            initParams=[yOffset,curvature,xOffset];
        end
        
        function fun= getFun(~)
            fun=@(param,x)(param(1)+param(2).*x+param(3).*x.^2);
        end
        
        function parameterNames=getParameterNames(~)
            parameterNames={'yOffset', 'slope','curvature'};
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