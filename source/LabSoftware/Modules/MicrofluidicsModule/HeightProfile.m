classdef HeightProfile<handle
    properties(Access=private)
        logger;
        string;
        yM;
        hM;
        fitter;
        
        heightCenterM;
        heightSlope;
        heightCurvatureM;
    end
    
    methods(Access=public)
        function obj=HeightProfile()
            obj.logger=Logger.getInstance();
        end
        
        function success=setProfileString(obj,string)
            success=obj.parseProfileString(string);
        end
        
        function setHeightProfile(obj,yM,hM)
            obj.yM=yM;
            obj.hM=hM;
            obj.calculateHeightProfileFitParameters();
        end
        
        function success=parseProfileString(obj,profileStringMM)
            rawLines=cellstr(profileStringMM);
            pointCount=size(rawLines,1);
            obj.yM=nan(pointCount,1);
            obj.hM=nan(pointCount,1);
            try
                for i=1:pointCount
                    trimmed=strtrim(rawLines{i,1});
                    split=obj.getLineSplit(trimmed);
                    if size(split,2)~=2
                        obj.logger.fatal('size of split must be 2 (2 numbers / line)!');
                    end
                    obj.yM(i,1)=str2double(split{1,1})*1e-3;
                    obj.hM(i,1)=str2double(split{1,2})*1e-3;
                end
                obj.calculateHeightProfileFitParameters();
            catch
                obj.yM=[];
                obj.hM=[];
                success=false;
                return;
            end
            success=true;
        end
        
            % (integral_(-w/2)^(w/2) 1/w (a+bx+cx^2)^3 dx)^(1/3)
        function hEffM=getHEffM(obj,widthM)
            hEffM=(...
                    1./widthM.*( ...
                         obj.heightCenterM.^3*widthM+...
                         1./4.*obj.heightCenterM^2*obj.heightCurvatureM*widthM^3+...
                         1./4.*obj.heightCenterM.*obj.heightSlope^2.*widthM^3+...
                         3./80.*obj.heightCenterM.*obj.heightCurvatureM.^2.*widthM.^5+...
                         3./80.*obj.heightSlope.^2.*obj.heightCurvatureM.*widthM.^5+...
                         1./448.*obj.heightCurvatureM.^3.*widthM.^7 ...
                               ) ...
                   ).^(1./3);
        end
        
        function showFit(obj,widthM)
            f=figure(6);
            clf;
            ax=axes();
            fitfun=obj.fitter.getModelFunWParams();
            hold(ax,'on');
            plot(obj.yM,obj.hM,'k+');
            yfit=linspace(min(obj.yM),max(obj.yM),100);
            plot(yfit,fitfun(yfit),'k-');
            
            title(['hEff=',num2str(obj.getHEffM(widthM)/1E-3),'mm']);
            ylabel('h/m');
            xlabel('y/m');
            fuAutosetPlotLimits(f,0.05);
        end
    end
    
    methods(Access=private)
        function calculateHeightProfileFitParameters(obj)
            obj.fitter=FitterPlain();
            obj.fitter.setModel(QuadraticModel());
            obj.fitter.setData(obj.yM,obj.hM,[],[]);
            resultParams=obj.fitter.getResultParameters();

            obj.heightCenterM=resultParams(1);
            obj.heightSlope=resultParams(2);
            obj.heightCurvatureM=resultParams(3);
        end
        
        function lineSplit=getLineSplit(~, commandLine)
            lineSplit=regexp(strtrim(commandLine),'[\s,]+','split');
        end
    end
end

