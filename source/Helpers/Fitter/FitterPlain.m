% ########################
% Wolfgang Gross
% University of Bayreuth
% 04.04.17
% ########################
%
% FITTERPLAIN Convenience wrapper for matlabs nlinfit and lsqcurvefit interface.
% Supports automatic start parameter refinement, statistical error
% analysis for estimated fitting parameters, fixing parameters and
% filtering outliers.
%
% For error analysis, the algorithm randomly generates input data where all
% the single datapoints are offset statistically. The amount of offset
% follows a gaussian distribution with a standard deviation of the
% individual errors specified by the user. This process is carried out
% multiple times until enough result parameter statistics are gathered. The
% standard deviations of the result parameters of all fits are returned as
% errors.
%
% For detailed information on useage, see documentation of the properties and
% the public interface.
%
% WARNING:
% THIS CLASS IS NOT THREAD SAFE! DO NOT USE THIS CLASS IN PARALLEL CODE!
% THIS CLASS AND MAYBE OTHERS WILL PRODUCE WRONG RESULTS IF YOU DO SO!
% 
% Changelist
% 05.09.16 (WG)
%   -reworked behaviour of error analysis: now tries to refine start
%    parameters when fitting fails.
%   -added documentation
%   -basic code refactoring
% 16.09.16 (WG)
%   -fixed some issues with LSQCURVEFIT
%    HOWEVER: LSQCURVEFIT is still not implemented safely (parameter bounds
%    seem to be an issue during parameter refinement.
%   -resolved the problem that all errors were treated as fitting errors.
%    The routine only treats native matlab fitting warnings as errors
%    during the normal control flow and rethrows all other errors (e.g.
%    errors occuring in the user-defined model classes
%   -added warning that indicates that this class is not thread safe.
%   -updated logging system (verbosityLevel-option)
% 04.04.17 (WG)
%   -added outlier level to be able to remove outliers automatically (could
%    be moved to a new abstract class in the future)
%   -added support for new models which support fixing parameters
%   -added method that yields the fitted function with its parameters
% 28.11.17 (WG)
%   -added doc for errorAnalysisIterCount
classdef FitterPlain < handle
    properties (Access=private)
        % OPTION VARIABLES
        showHist=1; % displays a histogram of fit parameters after error analysis
        HISTOGRAM_FIGURE_NUMBER=2;  % Matlab figure number of the histogram
        verbosityLevel=0;   % 0 shows no output during processing
                            % 1 shows some output during processing
                            % (indicating
                            %   problems)
                            % 2 shows detailed output during processing
        fittingAlgorithm='NLINFIT'; % the native matlab fitting routine that is used. Valid
                                    % values are 'NLINFIT' and
                                    % 'LSQCURVEFIT'. The use of
                                    % 'LSQCURVEFIT is discuraged (not
                                    % debugged).
        errorAnalysisIterCount=1;   % Determines how many iterations are run to determine
                                    % the errors of the fit parameters using a
                                    % Monte-Carlo-Simulation (see The Art
                                    % of Scientific Computing, Third
                                    % Edition, William H. Press et al.
                                    % Cambridge University Press (2007))
                                    %
                                    % When set to <2, no error analyis is
                                    % run at all. When error analysis is
                                    % run, the mean parameters of all
                                    % iterations are returned by
                                    % getResultParameters() and
                                    % getModelFunWithParams().
                                    % To get the full distribution of
                                    % result parameters, call
                                    % obj.getAllResultParameters() or
                                    % obj.getAllModelFunsWParams().
        
        % STATUS VARIABLES
        fittingCompleted=0;         % This is set to 1 when output has been calculated.
                                    % This is set to 0 when input has
                                    % changed after last calculation of the
                                    % output. The variable is used to
                                    % minimize fitting calls and to ensure
                                    % data integrity within the local
                                    % class properties.
        
        % INPUT VARIABLES
        x;                          % The x datapoints to be fitted
        y;                          % The y datapoints to be fitted
        sx;                         % The errors of the x datapoints to be fitted
        sy;                         % The errors of the y datapoints to be fitted
        
        model;                      % The model to be fitted to the data (see Model.m)
        startParameterOptimizer=OptimizerNone(); % An optimizer can be set to
                                    % refine the start parameters returned by the
                                    % model automatically. The optimizer is
                                    % also used in statistical error
                                    % analysis mode to refine the starting
                                    % parameters during the iterations (see
                                    % StartParameterOptimizer.m).
                                    
        optimalStartParameters;     % The optimal start parameters as determined by the startParameterOptimizer
        lowerParameterBounds;       % The lower parameter bounds as specified in the model. lsqcurvefit uses these bounds.
        upperParameterBounds;       % The upper parameter bounds as specified in the model. lsqcurvefit uses these bounds.
        outlierDropLevel;           % When empty or <=0, fitting is performed normally. When larger than 0, fitting is
                                    % performed twice. After the first fit, all datapoints with residuals larger than
                                    % sqrt(var(residuals))*outlierDropLevel are removed and fitting is performed a
                                    % second time.
                
        % RESULT VARIABLES
        fittedPositions;            % The indices of x and y that were fitted are marked with 1, 0 otherwise.
        resultParameters;           % The determined result parameters that suit the modelfunction best.
        allResultParameters;        % All fit result parameters calculated during error analysis.
        resultParameterErrors;      % The errors of the result parameters. NaN when no error analysis is run.
        fitFunY;                    % Holds all the values of all the fitted funtions when error analysis is active.
        
        % logger
        logger=Logger.getInstance();
    end
    
    %############################
    % Public interface
    %############################
    methods (Access=public)
        function obj=FitterPlain()
            parpoolvars=gcp('nocreate');
            if ~isempty(parpoolvars)
                obj.logger.warn(['Detected running parpool. FitterPlain is not thread safe due to matlab global state manipulations. '...
                        '(Warning->Error conversion). Do not fit with multiple instances at the same time unless you know precisely what youre doing.']);
            end
        end
        
        function setFittingAlgorithm(obj, fittingAlgorithm)
            % Sets the native matlab fitting algorithm. Valid values are 'NLINFIT' and 'LSQCURVEFIT'.
            if strcmp(fittingAlgorithm, 'LSQCURVEFIT')
                obj.logger.info('The use of LSQCURVEFIT is discouraged in this version. Expect unexpected results.');
            elseif ~strcmp(fittingAlgorithm, 'NLINFIT')
                obj.logger.error('Fitting algorithm not supported');
                error('Fitting algorithm not supported');
            end
            obj.fittingAlgorithm=fittingAlgorithm;
            obj.fittingCompleted=0;
        end
        
        function setModel(obj, model)
            % Sets the model to be used for fitting (see Model.m).
            obj.model=model;
            obj.fittingCompleted=0;
        end
        
        function setStartParameterOptimizer(obj, startParamOptimizer)
            % Sets the startParameterOptimizer to be used for fitting (see StartParameterOptimizer.m).
            obj.fittingCompleted=0;
            obj.startParameterOptimizer=startParamOptimizer;
        end
        
        function setData(obj, x,y,sx,sy)
            % Sets the x and y data used for fitting. To use errors estimation,
            % specify non-empty sx and sy data for
            obj.fittingCompleted=0;
            obj.x=x;
            obj.y=y;
            
            if (isempty(sx))
                obj.sx=zeros(size(x));
            else
                obj.sx=sx;
            end
            if isempty(sy)
                obj.sy=zeros(size(y));
            else
                obj.sy=sy;
            end
        end
        
        function doRunErrorAnalysis=errorAnalysisActive(obj)
            doRunErrorAnalysis=(obj.errorAnalysisIterCount>1) & (obj.yErrorSpecified() || obj.xErrorSpecified());
        end
        
        function hasYErr=yErrorSpecified(obj)
            % returns wheter the specified sy is not empty.
            hasYErr=any(obj.sy~=0);
        end
        
        function hasXErr=xErrorSpecified(obj)
            % returns wheter the specified sx is not empty.
            hasXErr=any(obj.sy~=0);
        end
        
        function setErrorAnalysisIterCount(obj, iterCount)
            % Sets the error analysis iter count. When >1, error analysis
            % is run.
            obj.fittingCompleted=0;
            if iterCount>1 && iterCount<7
               obj.logger.warn('Itercount should be larger than 6 for proper statistics.'); 
            end
            obj.errorAnalysisIterCount=iterCount;
        end
        
        function setOutlierDropLevel(obj, level)
            obj.outlierDropLevel=level;
        end
        
        % Returns the x data that was fitted.
        function x=getX(obj)
            obj.fitToData();
            x=obj.x(obj.fittedPositions,:);
        end
        
        % Returns the y data that was fitted.
        function y=getY(obj)
            obj.fitToData();
            y=obj.y(obj.fittedPositions,1);
        end
        
        function sy = getSy(obj)
            % Returns the error of the y data of the fited curve.
            obj.fitToData();
            sy=obj.sy(obj.fittedPositions,1);
        end
        
        function sx = getSx(obj)
            % Returns the error of the x data of the fited curve.
            obj.fitToData();
            sx=obj.sx(obj.fittedPositions,:);
        end
        
        % Returns the positions of the outliers which were not fitted
        function pos=getOutlierPositions(obj)
            pos=~obj.fittedPositions;
        end
        
        % Retruns the positions that were fitted
        function pos=getFittedPositions(obj)
            pos=obj.fittedPositions;
        end
        
        % Returns the x data that was not fitted.
        function x=getOutlierX(obj)
            obj.fitToData();
            x=obj.x(~obj.fittedPositions,:);
        end
        
        % Returns the y data that was not fitted.
        function y=getOutlierY(obj)
            obj.fitToData();
            y=obj.y(~obj.fittedPositions,1);
        end
        
        function sy = getOutlierSy(obj)
            % Returns the error of the y data that was not fitted.
            obj.fitToData();
            sy=obj.sy(~obj.fittedPositions,1);
        end
        
        function sx = getOutlierSx(obj)
            % Returns the error of the x data that was not fitted.
            obj.fitToData();
            sx=obj.sx(~obj.fittedPositions,:);
        end
        
        % Returns the model.
        function model= getModel(obj)
            model=obj.model;
        end
        
        function fun=getModelFunWParams(obj)
            obj.fitToData();
            fun=functionPointerInsertParam(obj.model.getFun(), obj.getResultParameters());
        end
        
        function funs=getAllModelFunsWParams(obj)
            allParams=obj.getAllResultParameters();
            funs=cell(size(allParams,1),1);
            for i=1:size(allParams,1)
                funs{i}=functionPointerInsertParam(obj.model.getFun(), allParams(i,:));
            end
        end
        
        function resultParameters=getResultParameters(obj)
            % Returns the fitted result parameters.
            fitToData(obj);
            resultParameters=obj.resultParameters;
        end
        
        function paramErrors=getResultParameterErrors(obj)
            % Returns the estimated errors of the result parameters.
            obj.fitToData();
            paramErrors=obj.resultParameterErrors;
        end
        
        function fit = getFit(obj)
            % Returns the x and y data of the fited curve.
            fit=[obj.getX(), obj.getFitY()];
        end
        
        function fitY = getFitY(obj)
            % Returns the y data of the fited curve.
            obj.fitToData();
            fitY=obj.model.getY(obj.resultParameters, obj.getX());
        end
        
        function correlCoeff = getCorrelCoeff(obj)
            % Returns the correlation coefficient of the fitted y data and
            % the input y data.
            fitToData(obj);
            correlCoeff=corrcoef(obj.getFitY(),obj.getY());
            correlCoeff=correlCoeff(1,2);
        end
        
        function res = getResiduals(obj)
            % Returns the residuals of the fit.
            obj.fitToData();
            res=obj.getFitY()-obj.getY();
        end
        
        function chiSquared=getChiSquared(obj)
            % Returns the chi squared value.
            obj.fitToData();
            SSresid=sum(obj.getResiduals().^2);
            SStotal=(length(obj.getFitY())-1)*var(obj.getY());
            chiSquared=1-SSresid/SStotal;
        end
        
        function allparams=getAllResultParameters(obj)
             obj.fitToData();
            % Returns all result parameters obtained during statistical error analysis.
            allparams=obj.allResultParameters;
        end
        
        function setVerbosityLevel(obj, level)
            % Determines how much output is generated during processing.
            obj.verbosityLevel=level;
        end
        
        function showHistograms(obj, figureNumber)
            obj.fitToData();
            figure(figureNumber);
            clf;
            for i=1:obj.model.getParameterCount()
                hold on;
                subplot(1,obj.model.getParameterCount(),i);
                histfit(obj.allResultParameters(:,i),50);
            end
        end
        
        function yFitStd=getFitFunStd(obj)
            if ~obj.errorAnalysisActive()
                obj.logger.fatal('Error analysis has to be active.');
            end
            obj.fitToData();
            yFitStd=std(obj.fitFunY,[],2);
        end
        
        function yFitMean=getFitFunMean(obj)
            if ~obj.errorAnalysisActive()
                obj.logger.fatal('Error analysis has to be active.');
            end
            obj.fitToData();
            yFitMean=mean(obj.fitFunY,2);
        end
        
        function yFitMin=getFitFunMin(obj)
            if ~obj.errorAnalysisActive()
                obj.logger.fatal('Error analysis has to be active.');
            end
            obj.fitToData();
            yFitMin=min(obj.fitFunY,[],2);
        end
        
        function yFitMax=getFitFunMax(obj)
            if ~obj.errorAnalysisActive()
                obj.logger.fatal('Error analysis has to be active.');
            end
            obj.fitToData();
            yFitMax=max(obj.fitFunY,[],2);
        end
        
        function plots=plotFit(obj, axes, color,varargin)
            if length(varargin)==0
                doSort=true;
            elseif length(varargin)==1
                doSort=varargin{1,1};
            end
            hold(axes,'on');
            if doSort
                [xSort,idx]=sort(obj.getX());
            else
                xSort=obj.getX();
                idx=1:length(xSort);
            end           
            
            yClean=obj.getY();
            sxClean=obj.getSx();
            syClean=obj.getSy();
            fitYClean=obj.getFitY();
            if length(color)==1
               dataColor=color;
               fitColor=color; 
            elseif length(color)==2
               dataColor=color(1);
               fitColor=color(2);
            end
                
            
            if obj.xErrorSpecified() && obj.yErrorSpecified()
                p1=errorbar(axes, xSort, yClean(idx) , syClean(idx),syClean(idx),sxClean(idx),sxClean(idx), [dataColor,'+']);
                p2=plot(axes, xSort,fitYClean(idx),[fitColor,'-']);
                p3=plot(axes, obj.x,obj.getFitFunMin(),[fitColor,':']);
                p4=plot(axes, obj.x,obj.getFitFunMax(),[fitColor,':']);
                p5=plot(axes, obj.x,obj.getFitFunMean()+obj.getFitFunStd(),[fitColor,'-.']);
                p6=plot(axes, obj.x,obj.getFitFunMean()-obj.getFitFunStd(),[fitColor,'-.']);
                if nargout>0
                    plots=[p1,p2,p3,p4,p5,p6];
                end
            else
                p2=plot(axes, xSort,yClean(idx),[dataColor,'+']);
                p3=plot(axes, xSort,fitYClean(idx),[fitColor,'-']);
                if nargout>0
                    plots=[p2,p3];
                end
            end
            hold(axes,'off')
        end
        
        function plots=plotStartConditions(obj,axes,color)
            hold(axes,'on');
            [xSort,idx]=sort(obj.x);
            
            fun=obj.model.getFun();
            startY=fun(obj.model.getCalculatedInitializationParameters(xSort,obj.y(idx)),xSort);
            
            p1=plot(axes, xSort,obj.y(idx),[color,'+']);
            p2=plot(axes, xSort,startY,[color,'-']);
            if nargout>0
                plots=[p1,p2];
            end
            hold(axes,'off');
        end
    end
    
    %############################
    % Private interface
    %############################
    methods (Access = private)
        % Method executed whenever some of the result data is accessed.
        % This behaviour ensures integrity of the output variables of the class.
        function fitToData(obj)
            if (obj.fittingCompleted)
                % Were having a good day...nothing to do here, data is
                % valid.
                return;
            else
                obj.validateInput();
                
                obj.log(1, 'Fitting original data.');
                obj.performFitting();
                obj.log(1, 'Fitting original data done.');
                res=obj.getResiduals();
                stdDev=sqrt(var(res));
                obj.log(1, ['Standard deviation was ',num2str(stdDev),'.']);
                if ~isempty(obj.outlierDropLevel) && obj.outlierDropLevel>0
                    obj.fittedPositions=obj.fittedPositions & abs(res)<stdDev*obj.outlierDropLevel;
                    obj.fittingCompleted=0;
                    
                    obj.log(1, ['Rejected ',num2str(length(obj.fittedPositions)-sum(sum(obj.fittedPositions))),' datapoints.']);
                    obj.log(1, 'Fitting without rejected data.');
                    obj.performFitting();
                    obj.log(1, 'Fitting without rejected data done.');
                    res=obj.getResiduals();
                    stdDev=sqrt(var(res));
                    obj.log(1, ['Standard deviation was ',num2str(stdDev),'.']);
                end
            end
        end
        
        function performFitting(obj)
            obj.setParameterLimits();
            obj.optimalStartParameters=obj.startParameterOptimizer.getOptimalStartParameters(obj.x(obj.fittedPositions,:),obj.y(obj.fittedPositions,1),...
                    obj.model,obj.model.getInitializationParameters(obj.x(obj.fittedPositions,:),obj.y(obj.fittedPositions,1)),...
                    obj.fittingAlgorithm, obj.lowerParameterBounds,obj.upperParameterBounds);
            % These two functions set the result properties.
            if obj.errorAnalysisActive()
                obj.fitWithErrorAnalysis();
            else
                obj.fitWithoutErrorAnalysis();
            end
            obj.fittingCompleted=1;
        end
        
        function fitWithoutErrorAnalysis(obj)
            obj.fit(obj.x(obj.fittedPositions,:), obj.y(obj.fittedPositions,1));
            obj.resultParameterErrors=NaN(size(obj.resultParameters));
            obj.allResultParameters=obj.resultParameters;
        end
        
        
        function fitWithErrorAnalysis(obj)
            % All fit parameters generated during all iterations
            obj.allResultParameters=NaN(obj.errorAnalysisIterCount,obj.model.getParameterCount());
            retr=0;

            % keep track of all the used start parameters. When
            % analysis is run for multiple stacks, we start with
            % the mean value for all following iterations.
            successfullStartParams=obj.optimalStartParameters';
            fun=obj.model.getFun();

            obj.fitFunY=NaN(size(obj.x,1),obj.errorAnalysisIterCount);
            i=1;
            while i<=obj.errorAnalysisIterCount
                % save warning settings in s and turn matlab fitting routine warnings to errors
                s=obj.fittingWarningsAreErrors();
                
                obj.optimalStartParameters=mean(successfullStartParams,2);
                try
                    % randn returns normally distributed data with sigma=1
                    % and mean of 0. Generate a new dataset based on
                    % errors.
                    randX=randn(size(obj.x(obj.fittedPositions,:))).*obj.sx(obj.fittedPositions,:)+obj.x(obj.fittedPositions,:);
                    randY=randn(size(obj.y(obj.fittedPositions,1))).*obj.sy(obj.fittedPositions,1)+obj.y(obj.fittedPositions,1);

                    % Fit the dataset. This function can fail when errors
                    % are thrown (all native warnings of nlinfit are
                    % treated as errors here, see above).
                    obj.fit(randX, randY);

                    % Fitting was successful, store results.
                    obj.fitFunY(:,i)=fun(obj.resultParameters, obj.x);
                    obj.allResultParameters(i,:)=obj.resultParameters;
                    successfullStartParams(:,i)=obj.optimalStartParameters';
                    obj.log(2, ['Iteration ',num2str(i),': Successful.']);
                catch ex
                    % When fitting failed...
                    if(~obj.isFittingError(ex))
                        rethrow(ex);
                    else
                        obj.log(2, ['Iteration ',num2str(i),': Start parameter correction needed.']);
                    end
                    try
                        % try to find new start
                        % parameters for this dataset. This is not done
                        % permanently due to runtime considerations.
                        obj.log(2, ['Iteration ',num2str(i),': Refining start parameters.']);
                        obj.optimalStartParameters=obj.startParameterOptimizer.getOptimalStartParameters(randX,randY,...
                            obj.model,obj.optimalStartParameters,...
                            obj.fittingAlgorithm,obj.lowerParameterBounds,obj.upperParameterBounds);
                        
                        % Fit with new start parameter estimates. This step
                        % can fail (see above).
                        obj.fit(randX, randY);
                        
                        % Fitting was successful, store results
                        obj.fitFunY(:,i)=fun(obj.resultParameters, obj.x);
                        
                        obj.allResultParameters(i,:)=obj.resultParameters;
                        
                        successfullStartParams(:,i)=obj.optimalStartParameters;
                        obj.log(2, ['Iteration ',num2str(i),': Successful.']);
                    catch ex2
                        % When fitting failed again...
                        if(~obj.isFittingError(ex2))
                            rethrow(ex2);
                        end
                        % Fitting was not successful, even after parameter
                        % refinement. The currently used dataset is
                        % discarded (i=i-1) and the iteration is repeated.
                        obj.log(1, ['Iteration ',num2str(i),': Failure. Discarding data.']);
                        i=i-1;
                        retr=retr+1;
                        % If too many steps are repeated, something is
                        % wrong.
                        if i>10 && (retr / i) >0.1
                            warning('Problems with fitting: model not suitable for dataset OR dataset too noisy OR StartParameterOptimizer not well configured OR optimize model parameter init and bounds.');
                        end
                    end
                end
                i=i+1;

                %restore warning settings
                warning(s);
            end
            obj.log(1, ['Fits failed and discarded during error analysis: ',num2str(retr), '/',num2str(obj.errorAnalysisIterCount)]);
            obj.resultParameters=nanmean(obj.allResultParameters);
            obj.resultParameterErrors=sqrt(nanvar(obj.allResultParameters));
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
        
        function s=fittingWarningsAreErrors(~)
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
        
        function fit(obj, x, y)
            % routine to call the selected native matlab routines. Stores
            % the result parameters in obj.resultParameters.
            switch (obj.fittingAlgorithm)                
                case 'NLINFIT'
                    %options=statset('TolTypeFun','rel','TolTypeX','rel','TolX',1E-15,'UseParallel',true,'RobustWgtFun','cauchy');
                    options=statset('TolX',1E-15,'RobustWgtFun',[]);
                    [obj.resultParameters,~,~,~,~,~]=...
                        nlinfitFixedParams(obj.model.getFixedPositions(), x, y, obj.model.getFun(), obj.optimalStartParameters,options);
                case 'LSQCURVEFIT'
                    [obj.resultParameters,~,~,~,~,~,~]=...
                        lsqcurvefit(obj.model.getFun(),obj.optimalStartParameters, x, y,obj.lowerParameterBounds,obj.upperParameterBounds,optimset('Display','off'));
                otherwise
                    disp(strcat('Fitting Algorithm',obj.fittingAlgorithm,' not supported by StandardFitterPlain'));
            end
        end
        
        function validateInput(obj)
            % Validates whether or not the input parameters were set
            % correctly.
            if isempty(obj.model)
                obj.logger.fatal('Model has not been initialized properly. Initialize first!');
            end
            if isempty(obj.x)
                obj.logger.fatal('x has not been initialized. Initialize first!');
            end
            if isempty(obj.y)
                obj.logger.fatal('y has not been initialized. Initialize first!');
            end
            
            if size(obj.y,2)~=1
                obj.logger.fatal('y has to be 1 dimensional');
            end
            
            if ~isequal(size(obj.x,1),size(obj.y,1))
                % if this crashes, input vectors should be transposed
                % probably
                obj.logger.fatal('x and y data do not have the same size. Initialize correctly!');
            end
            
            if obj.xErrorSpecified()
                if ~isequal(size(obj.x),size(obj.sx))
                    obj.logger.fatal('SX has different size than x.');
                end
            end
            
            if obj.yErrorSpecified()
                if ~isequal(size(obj.y),size(obj.sy))
                    obj.logger.fatal('Sy has different size than y.');
                end
            end
            
            if obj.model.hasFixedParameters() && obj.errorAnalysisActive()
                obj.logger.warn('Fixing parameters may result in imprecise error estimation. Take care.');
            end
            
            if ~obj.xErrorSpecified() && ~obj.yErrorSpecified() && obj.errorAnalysisIterCount > 1
                obj.logger.fatal('No errors have been specified. Cannot run error analysis.');
            end
            % Start with all positions activated.
            obj.fittedPositions=boolean(ones(size(obj.x,1),1));
        end
        
        function setParameterLimits(obj)
            obj.lowerParameterBounds=obj.model.getLowerParameterBounds(obj.x(obj.fittedPositions,:), obj.y(obj.fittedPositions,1));
            obj.upperParameterBounds=obj.model.getUpperParameterBounds(obj.x(obj.fittedPositions,:), obj.y(obj.fittedPositions,1));
        end
        
        function log(obj, verb, x)
            if obj.verbosityLevel >= verb
               disp(['FitterPlain: ',x]); 
            end
        end
    end
end
