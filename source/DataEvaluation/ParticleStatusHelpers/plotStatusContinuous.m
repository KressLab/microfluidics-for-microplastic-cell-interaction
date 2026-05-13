function plotStatusContinuous(ax,x,y,values,resolution,lineWidth,colormap,colormapLowValue,colormapHighValue)
    x=x(1:resolution:end);
    y=y+zeros(size(x));
    values=values(1:resolution:end);
    values=clampMatrix(values,colormapLowValue,colormapHighValue);
    
    status=~isnan(values);
    
    if ~any(status)
        return;
    end
    if ~any(values)
        return;
    end
    
    dStat=diff([false;status]);
    startId=[];
    endId=[];
    
    for i=1:(length(status)-1)
        if isStartOfPatch(dStat,i)
            startId=i;
        end
        if isEndOfPatch(dStat,i)
            endId=i;
            
            addPatch(ax,x(startId:endId),y(startId:endId),values(startId:endId),...
                              lineWidth,colormap,colormapHighValue,colormapLowValue);
        end
    end
    if patchEndsAtEndOfStatusVector(startId,endId)
        addPatch(ax,x(startId:end),y(startId:end),values(startId:end),...
                          lineWidth,colormap,colormapHighValue,colormapLowValue);
    end
end

function [v,f,c]=addPatch(ax,x,y,values,lineWidth,colormap,colormapHighValue,colormapLowValue)
    v=[x,y-lineWidth/2;flip(x),flip(y)+lineWidth/2];
    f=1:2*length(x);
    colorId=floor((values-colormapLowValue)./(colormapHighValue-colormapLowValue)*(size(colormap,1)-1))+1;
    c=colormap(colorId,:);
    c=[c;flip(c,1)];
    patch(ax,'Faces',f,...
             'Vertices',v,...
             'FaceVertexCData',c,...
             'FaceColor','interp',...
             'LineStyle','none',...
             'Hittest','off',...
             'HandleVisibility','off',...
             'FaceLighting','none',...
             'AlphaDataMapping','none',...
             'BackFaceLighting','unlit');
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