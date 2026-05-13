function [avgVal,stdVal,stdErrVal] = getStatisticalErrorAnalysis(quantity)
    arguments
        quantity (:,:) double
    end
    avgVal=mean(quantity);
    stdVal=std(quantity);
    stdErrVal=stdVal./sqrt(size(quantity,1));
end