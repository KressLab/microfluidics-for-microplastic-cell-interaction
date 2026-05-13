% ########################
% Wolfgang Gross
% University of Bayreuth
% 09.07.15
% ########################

classdef VelocityProfileModel < Model
    properties(Access=private)
        widthM;
        heightM;
        yM;
    end
    methods(Access=public)
        function obj=VelocityProfileModel(widthM,heightM,yM)
            obj.widthM=widthM;
            obj.heightM=heightM;
            obj.yM=yM;
        end
        
        function initParams=getCalculatedInitializationParameters(obj, x,y)
            % rough estimation of the exponent for cells
            % solution
            amplitude=max(y);
            initParams=[amplitude];
        end
        
        function fun= getFun(obj)
            fun=@(param,x)(param(1)*getAlphaRect(obj.widthM, obj.heightM, obj.yM, x));
        end
         function parameterNames=getParameterNames(~)
            parameterNames={'vx'};
        end
        
        function parameterUnits=getParameterUnits(~)
            parameterUnits={'m/s'};
        end
        
        function parameterCount=getParameterCount(~)
            parameterCount=1;
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