function colormap=createDivergingColormap(startColor,centerColor,endColor,count)
    lowCount=floor(count/2);
    highCount=ceil(count/2);
    
    colormap=[linspace(startColor(1),centerColor(1),lowCount),linspace(centerColor(1),endColor(1),highCount);...
              linspace(startColor(2),centerColor(2),lowCount),linspace(centerColor(2),endColor(2),highCount);...
              linspace(startColor(3),centerColor(3),lowCount),linspace(centerColor(3),endColor(3),highCount)]';
end