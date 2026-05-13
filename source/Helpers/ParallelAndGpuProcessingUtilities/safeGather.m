% Gathers data from the gpu if it was offloaded. Use in conjunction with
% safeGpuArray()
function cpuArray=safeGather(gpuArr)
    if ~isa(gpuArr,'gpuArray')
        cpuArray=gpuArr();
        return;
    end
    try
        if gpuDeviceCount()>0 && existsOnGPU(gpuArr)
            cpuArray=gather(gpuArr);
        else
            cpuArray=gpuArr;
        end
    catch
        cpuArray=gpuArr;
    end 
end