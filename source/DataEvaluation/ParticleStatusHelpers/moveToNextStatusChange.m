% returns the indicex at which the status changes next from the current
% status. If the status does not change, return nan.
function nextIdx=moveToNextStatusChange(idx,status)
    nextIdx=nan(size(idx));
    for i=1:size(idx,1)
        j=0;
        while idx(i)+j<length(status) && status(idx(i))==status(idx(i)+j)
            j=j+1;
        end
        if idx(i)+j<length(status)
            nextIdx(i)=idx(i)+j;
        else
            nextIdx(i)=NaN;
        end
    end
end