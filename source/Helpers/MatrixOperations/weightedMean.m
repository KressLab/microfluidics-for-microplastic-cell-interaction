function y = weightedMean(x,w)
    y=sum(w.*x)./sum(w);
end

