function FM = fmeasureGLVN(imgFlat)
    imgFlat=double(imgFlat);
    if isempty(imgFlat)
        FM=0;
    else
        FM = std(imgFlat)^2/mean(imgFlat);
    end
end

