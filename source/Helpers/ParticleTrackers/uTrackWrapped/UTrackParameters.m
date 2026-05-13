classdef UTrackParameters < handle
    methods(Abstract,Access=public)
        gapCloseParam=getGapCloseParams(obj);
        linkingFuncName=getFrameLinkingFuncName(obj);
        linkingParameters=getFrameLinkingFuncParameters(obj);
        gapClosingFuncName=getGapClosingFuncName(obj);
        gapClosingFuncParameters=getClosingFuncParameters(obj);
        kalmanFunctionNames=getKalmanFunctionNames(obj);
        verbose=getVerboseState(obj);
    end
end

