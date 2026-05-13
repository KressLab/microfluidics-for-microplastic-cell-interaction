% nanvar uses N-Normalization instead of N-1 by default if weights are
% specified.
% see. https://www.itl.nist.gov/div898/software/dataplot/refman2/ch2/weighvar.pdf
function y=weightedVarCorrected(x,w)
    if ~all(size(x)==size(w))
        error('sized not identical');
    end
    if ~isvector(x)
        error('vect must be a vector');
    end
    N=length(w(w~=0));
    meany=sum(w.*x)./sum(w);
    y=sum(w.*(x-meany).^2)/(((N-1)*sum(w))/N);
end