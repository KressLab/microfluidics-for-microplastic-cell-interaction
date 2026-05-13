% Sends an array to the gpu if a gpu is available. If not, the data stays
% on the cpu. Does not throw any errors. 
function arrayOnGpu=safeGpuArray(cpuArray)  
    if isa(cpuArray,'gpuArray')
        arrayOnGpu=cpuArray;
        return;
    end
    try
        if gpuDeviceCount()>0
            arrayOnGpu=gpuArray(cpuArray);
            return;
        end
    end
    arrayOnGpu=cpuArray;
end