classdef UTrackParametersMFCellEval < UTrackParameters
    % For an explanation of the parameters, see scriptTrackGeneral of
    % u-track 2.3
    methods(Access=public)
        function gapCloseParameters=getGapCloseParams(~)
            gapCloseParameters.timeWindow = 50;
            gapCloseParameters.mergeSplit = 0;
            gapCloseParameters.minTrackLen = 1;
            
            %optional input:
            gapCloseParameters.diagnostics = 0;
        end
        
        function linkingFuncName=getFrameLinkingFuncName(~)
            linkingFuncName='costMatRandomDirectedSwitchingMotionLink';
        end
        
        function linkingParameters=getFrameLinkingFuncParameters(obj)
            gapCloseParam=obj.getGapCloseParams();
            linkingParameters.linearMotion = 1;
            linkingParameters.minSearchRadius = 8;
            linkingParameters.maxSearchRadius = 8;
            linkingParameters.brownStdMult = 3;
            linkingParameters.useLocalDensity = 0;
            linkingParameters.nnWindow = gapCloseParam.timeWindow;
            linkingParameters.kalmanInitParam = [];
            linkingParameters.diagnostics = 0;
        end
        
        function gapClosingFuncName=getGapClosingFuncName(~)
            gapClosingFuncName='costMatRandomDirectedSwitchingMotionCloseGaps';
        end
        
        function gapClosingFuncParameters=getClosingFuncParameters(obj)
            gapCloseParameters=obj.getGapCloseParams();
            gapClosingFuncParameters.linearMotion = 1;
            gapClosingFuncParameters.minSearchRadius = 11;
            gapClosingFuncParameters.maxSearchRadius = 11;
            gapClosingFuncParameters.brownStdMult = 3*ones(gapCloseParameters.timeWindow,1);
            
            gapClosingFuncParameters.brownScaling = [0.25 0.01];
            gapClosingFuncParameters.timeReachConfB = gapCloseParameters.timeWindow;
            gapClosingFuncParameters.ampRatioLimit = [];
            gapClosingFuncParameters.lenForClassify = 1;
            
            gapClosingFuncParameters.useLocalDensity = 0;
            gapClosingFuncParameters.nnWindow = gapCloseParameters.timeWindow;
            
            gapClosingFuncParameters.linStdMult = 3*ones(gapCloseParameters.timeWindow,1);
            gapClosingFuncParameters.linScaling = [1 0.01];
            gapClosingFuncParameters.timeReachConfL = gapCloseParameters.timeWindow;
            gapClosingFuncParameters.maxAngleVV = 50;
            
            %optional; if not input, 1 will be used (i.e. no penalty)
            gapClosingFuncParameters.gapPenalty = 1.005;
            gapClosingFuncParameters.resLimit = 5;
            gapClosingFuncParameters.gapExcludeMS = 1;
            gapClosingFuncParameters.strategyBD = 100;
        end
        
        function kalmanFunctionNames=getKalmanFunctionNames(~)
            kalmanFunctionNames.reserveMem  = 'kalmanResMemLM';
            kalmanFunctionNames.initialize  = 'kalmanInitLinearMotion';
            kalmanFunctionNames.calcGain    = 'kalmanGainLinearMotion';
            kalmanFunctionNames.timeReverse = 'kalmanReverseLinearMotion';
        end
        
        function verbose=getVerboseState(~)
            verbose=1;
        end
    end
end

