function [varargout] = nlinfitFixedParams(fixedParams, x, y, fun, beta0, varargin)
    arguments
        fixedParams (:,1) logical
        x
        y
        fun function_handle
        beta0 (:,1) double
        
    end
    arguments(Repeating)
        varargin;
    end

    % Extract values of parameters that will remain fixed
    fixedValues = beta0(fixedParams);
    
    % Extract initial guesses for free (non-fixed) parameters
    freeInitialValues = beta0(~fixedParams);
    
    % Call nlinfit with only the free parameters
    [varargout{1:max(1, nargout)}] = nlinfit(x, y, @wrappedModel, freeInitialValues, varargin{:});
    
    % Reconstruct full parameter vector with fixed and fitted values
    fullParamVector = zeros(size(beta0));
    fullParamVector(fixedParams) = fixedValues;
    fullParamVector(~fixedParams) = varargout{1};
    varargout{1} = fullParamVector;
    
    % Nested function: wraps original model with fixed parameters inserted
    function yPred = wrappedModel(freeParams, xData)
        fullParams = zeros(size(beta0));
        fullParams(~fixedParams) = freeParams;
        fullParams(fixedParams) = fixedValues;
        yPred = fun(fullParams, xData);
    end
end