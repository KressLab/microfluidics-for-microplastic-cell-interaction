function [intensCount,centers,pksLow,pksHigh,pksLowInt,pksHighInt] = getPkFeatures(imgs,minDist,scanRadius)
    intens=getPeakIntensities(imgs,minDist,scanRadius);
    
    [intensCount,intensEdges]=histcounts(intens,'BinMethod','fd');
    centers = intensEdges(1:end-1) + diff(intensEdges) / 2;
    sz=sqrt(size(intensCount,2))/2.0;

    pksHigh=pkfndFast(intensCount,-inf,sz,sz/2);
    pksLow=pkfndFast(-intensCount,-inf,sz,sz/2);
    
    pksHigh=pksHigh(pksHigh>min(pksLow)); % sort out median high
    pksLow=pksLow(pksLow<max(pksHigh)); % sort out median low
    
    pksHighInt=centers(pksHigh);
    pksLowInt=centers(pksLow);
    
    DEBUG=true;
    if DEBUG
        figure(5);
        clf;
        hold on;
        bar(centers,intensCount);
        plot(centers(pksLow),intensCount(pksLow),'ro','MarkerSize',10,'MarkerFaceColor','r');
        plot(centers(pksHigh),intensCount(pksHigh),'go','MarkerSize',10,'MarkerFaceColor','g');
    end
end

function intens=getPeakIntensities(imgs,minDist,scanRadius)
    intens=nan(0);
    th=min(cellfun(@(x)median(x(:)),imgs));
    for i=1:length(imgs)
        pks=pkfndFast(imgs{i},th,minDist,scanRadius);
        if size(pks,2)==2
            intens=[intens;imgs{i}(sub2ind(size(imgs{i}),pks(:,2),pks(:,1)))];
        elseif size(pks,2)==1
            intens=[intens;imgs{i}(pks)];
        end
    end
end