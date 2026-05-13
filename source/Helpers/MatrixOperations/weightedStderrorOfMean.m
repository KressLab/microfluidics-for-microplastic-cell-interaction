% THE STANDARD ERROR OF A WEIGHTED MEAN CONCENTRATION .1. BOOTSTRAPPING VS OTHER METHODS
% Gatz, Smith, 1995
% DOI: 10.1016/1352-2310(94)00210-C
%
%
function wsem = weightedStderrorOfMean(x,w)
    if ~all(size(x)==size(w))
        error('sized not identical');
    end
    if ~isvector(x)
        error('vect must be a vector');
    end
    xbar=weightedMean(x,w);
    wbar=mean(w);
    n=length(x);
    
    wsem=n/((n-1).*(sum(w).^2)).*(sum((w.*x-wbar*xbar).^2) -...
                                  2*xbar.*sum((w-wbar).*(w.*x-wbar*xbar))+...
                                  xbar.^2*sum((w-wbar).^2));
                            
 	wsem=sqrt(weightedNanvarCorrected(x,w)./n);
end

