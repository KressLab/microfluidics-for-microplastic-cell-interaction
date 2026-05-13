function out = pkfndFast(inData, th,minDist, scanRadius, maxInt)
% ########################
% Wolfgang Gross
% University of Bayreuth
% 09.11.18
% ########################
%
% NAME      pkfndFast
% PURPOSE
%           Finds local maxima in a vector/image/volume to pixel level accuracy.   
%           This provides a rough guess of peak center positions to be used
%           by cntrd.m/findMaxPositionWith2DGaussianFit/...
%           Inspired by the pkfnd-Subroutine by Eric R. Dufresne, Yale University
%           (02/4/2016, last modified and updated 10/5/2006), however
%           optimized for runtime performance. Provides better anti-noise
%           stabilty than the original routine. In contrast to pkfnd.m,
%           sampled regions are always circles/spheres.
%           The main code is implemented in C (mex-file).
%
%           To compile and run the mex-routines, see compilePkfnd.m.
%
% INPUTS:
%  inData: Vector or matrix (1D, 2D or 3D) to be searched for local peaks.
%          Peaks should be high spots on low background with little noise.
%          It can be helpful to bandpass filter inData before calling this function.
%      th: The minimum brightness of a peak that might be a local maxima.
%          Make it big and the code runs faster but you might miss some 
%          peaks. Make it small and you'll get everything but it'll be slow. 
%          In the case of a very noisy image, use a relatively low th and 
%          high scanRadius.
%          th=mean(inData(:))+MULT*std(inData(:))
%          Probably, Otsu-Treshholding will work for your data: set th to
%          mult*graythresh(img).
% minDist: Defines how far two peaks have to be away from each other 
%          (euclidean distance). In case of a collision, only the brightest
%          center is kept.
%          If your data's noisy, (e.g. a single particle has multiple local
%          maxima), set minDist to a value slightly larger than the diameter
%          of your blob.
%          If multiple peaks are found withing a radius of sz then only the
%          brightest peak is kept.
%          The border of max(minDist,minDist) is not searched for maxima.
%          In order to mimic the behaviour of pkfnd.m, set minDist to
%          (sz(pkfnd.m)-1)/2.
%scanRadius:optional: Defines a radius around a maximum inside which all pixel values
%          have to be smaller or equal for the maximum to be returned. Make
%          this value large and your code is faster but you might miss some
%          peaks, especially in the case of overlapping peaks. In the
%          case of high background noise, set this value to a value close
%          to the radius of the peaks and the detection will be more
%          reliable than that in the pkfnd.m routine. In a sense this
%          option ensures that only maxima are found where ctrd.m converges
%          properly.
%          Example for 2D image scanRadius=1.5
%              OOOOOOO
%              OOOOOOO
%              OO---OO
%              OO-X-OO
%              OO---OO
%              OOOOOOO
%              OOOOOOO
%          Example scanRadius=2
%              OOOOOOO
%              OOO-OOO
%              OO---OO
%              O--X--O
%              OO---OO
%              OOO-OOO
%              OOOOOOO
%          To mimic the behaviour of pkfnd.m for a 2D image, set scanRadius to
%          ]sqrt(2),2[. (default is 1.5).
%  maxInt: optional: All local maxima must have an intensity lower
%          than maxInt to be considered. Can be used to remove
%          overilluminated parts of the image when called with
%          max(max(image)) or 2^bitdepth-1 depending on the used filtering.
%          
% OUTPUT:
%          A N x DIM array containing the coordinates of local maxima
%           out(:,1) are the coordinates of the maxima along the first
%                    dimension
%           out(:,2) are the coordinates of the maxima along the second
%                    dimension (if applicable)
%           out(:,3) are the coordinates of the maxima along the third
%                    dimension (if applicable)
%          Output has the same format as pkfnd.m.
%          
    if(nargin<4)
        % checks the 2 (1D), 8 (2D) or 26 pixels (3D) around the expected max.
        scanRadius=1.5;
    end
    if(nargin<5)
        if(scanRadius<1)
            error('szMax cannot be smaller than 1. You wont find anything!');
        end
        maxInt=realmax('double');
    end
    if(nargin>5 || nargin<3)
        error('invalid number of input args');
    end
    if isvector(inData)
        if isa(inData, 'uint16')
            fun=@pkfnd1DCUInt16;
        elseif isa(inData, 'double')
            fun=@pkfnd1DCDouble;
        else
            error('datatype not supported');
        end
        if size(inData,2)>size(inData,1)
            inData=inData';
        end
        out=double(fun(inData,th,minDist,scanRadius,maxInt)');
    elseif size(size(inData),2)==2 
        if isa(inData, 'uint16')
            fun=@pkfnd2DCUInt16;
        elseif isa(inData, 'double')
            fun=@pkfnd2DCDouble;
        else
            error('datatype not supported');
        end
        out=double(fun(inData,th,minDist,scanRadius,maxInt)');
    elseif size(size(inData),2)==3 
        if isa(inData, 'uint16')
            fun=@pkfnd3DCUInt16;
        elseif isa(inData, 'double')
            fun=@pkfnd3DCDouble;
        else
            error('datatype not supported');
        end
        out=double(fun(inData,int32(size(inData)),th,minDist,scanRadius,maxInt)');
    else
        error('Dimension of input data not supported.');
    end
end