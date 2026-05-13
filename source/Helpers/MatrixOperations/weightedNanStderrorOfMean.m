% THE STANDARD ERROR OF A WEIGHTED MEAN CONCENTRATION .1. BOOTSTRAPPING VS OTHER METHODS
% Gatz, Smith, 1995
% DOI: 10.1016/1352-2310(94)00210-C 
%
% 
function err = weightedNanStderrorOfMean(x,w)
    omit=isnan(x)|isnan(x);
    err=weightedStderrorOfMean(x(~omit),w(~omit));
end

