function [wm] = nanwmean(X,w)

    X0 = X;
    X = X(~isnan(X0));
    w = w(~isnan(X0));
    wX = X.*w;
    wm = nansum(wX)/sum(w);

end