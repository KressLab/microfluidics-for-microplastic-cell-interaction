% ########################
% Wolfgang Gross
% University of Bayreuth
% 15.09.15
% ########################
%
% scales the values of the matrix to the range between low and high

function res = scaleMatToRange(mat,low,high)
    minVal=nanmin(mat(:));
    maxVal=nanmax(mat(:));
    oldRange=maxVal-minVal;
    if oldRange>0
        mat=(mat-minVal)./oldRange;

        newRange=high-low;
        res=(mat*newRange)+low;
    else
        res=ones(size(mat)).*low;
    end
end