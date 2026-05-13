function y = weighedNanMean(x,w)
    if ~all(size(x)==size(w))
        error('sized not identical');
    end
    if ~isvector(x)
        error('vect must be a vector');
    end
    omit=isnan(x)|isnan(x);
    y=weightedMean(x(~omit),w(~omit));
end

