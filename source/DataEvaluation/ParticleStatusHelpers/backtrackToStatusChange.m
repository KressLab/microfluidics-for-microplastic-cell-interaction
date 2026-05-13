% returns the indices at which the status has changed to the current status
% at idx
function backtrackedIdx=backtrackToStatusChange(idx,status,varargin)
    if size(varargin)==0
        
    elseif length(varargin)==1
        
    end
    backtrackedIdx=nan(size(idx));
    for i=1:size(idx,1)
        j=0;
        while idx(i)+j>0 && status(idx(i))==status(idx(i)+j)
            j=j-1;
        end
        backtrackedIdx(i)=idx(i)+j;
    end
end