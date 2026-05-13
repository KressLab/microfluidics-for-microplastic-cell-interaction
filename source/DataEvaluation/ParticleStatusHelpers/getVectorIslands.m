function [startIndex,endIndex,duration] = getVectorIslands(tsig)
    dsig = diff([0; tsig; 0]);
    startIndex = find(dsig > 0);
    endIndex = find(dsig < 0)-1;
    duration = endIndex-startIndex+1;
end