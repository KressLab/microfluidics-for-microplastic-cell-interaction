function th = getPkfndAutothresh(imgs,minDist,scanRadius,highCutoffPerc,peakNum)
    l=Logger.getInstance();
    l.error('UNTESTED');

    if nargin<4
        highCutoffPerc=0;
    end
    if nargin<5
        peakNum=1;
    end

    [intensCount,centers,pksLow,pksHigh] = getPkFeatures(imgs,minDist,scanRadius);
    
    i=0;
    range=intensCount(pksHigh(peakNum))-intensCount(pksLow(peakNum));
    while intensCount(pksLow(peakNum)+i+1)<intensCount(pksLow(peakNum))+highCutoffPerc*range
        i=i+1;
    end
    th=centers(pksLow(peakNum)+i);
end