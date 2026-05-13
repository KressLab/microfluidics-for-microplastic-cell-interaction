function plotStatus(ax,x,y,status,lineWidth,color)
    if ~any(status)
        return;
    end
    dStat=diff([false;status]);
    v=[];
    f=[];
    startId=[];
    endId=[];
    for i=1:(length(status)-1)
        if isStartOfPatch(dStat,i)
            startId=i;
        end
        if isEndOfPatch(dStat,i)
            endId=i;
            
            xLow=getXLow(x,startId);
            xHigh=getXHigh(x,endId);
            [v,f]=addSquare(v,f,xLow,xHigh,y,lineWidth);
        end
    end
    if patchEndsAtEndOfStatusVector(startId,endId)
        xLow=getXLow(x,startId);
        xHigh=x(end);
        [v,f]=addSquare(v,f,xLow,xHigh,y,lineWidth);
    end
    patch(ax,'Faces',f,...
             'Vertices',v,...
             'FaceColor',color,...
             'LineStyle','none',...
             'Hittest','off',...
             'HandleVisibility','off',...
             'FaceLighting','none',...
             'AlphaDataMapping','none',...
             'BackFaceLighting','unlit');
end

function [v,f]=addSquare(v,f,xLow,xHigh,y,lineWidth)
    v=[v;xLow y-lineWidth/2; xHigh y-lineWidth/2 ; xHigh y+lineWidth/2 ; xLow y+lineWidth/2];
    f=[f;size(v,1)-3:size(v,1)];
end

function ends=patchEndsAtEndOfStatusVector(startId,endId)
    ends=~isempty(startId) && (isempty(endId) || startId>endId);
end

function isEnd=isEndOfPatch(dStat,i)
    isEnd=dStat(i+1)==-1;
end

function isStart=isStartOfPatch(dStat,i)
    isStart=dStat(i)==1;
end

function xLow=getXLow(x,startId)
    if startId==1
        xLow=x(startId);
    else
        xLow=(x(startId)+x(startId-1))/2;
    end
end

function xHigh=getXHigh(x,endId)
    xHigh=(x(endId)+x(endId+1))/2;
end