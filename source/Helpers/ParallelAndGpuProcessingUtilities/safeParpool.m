function p=safeParpool(num,numThreadsPerInstace)
    if nargin<2
        numThreadsPerInstace=1;
    end
    if nargin<1
        num=feature('numcores');
    else
        num=clampMatrix(num,1,feature('numcores'));
    end
    
    p=gcp('nocreate');
    if isempty(p)
        parpool(num);
    elseif p.NumWorkers ~=num
        delete(p);
        parpool(num);
    end

    parfor i=1:num
        maxNumCompThreads(numThreadsPerInstace);
    end
end

