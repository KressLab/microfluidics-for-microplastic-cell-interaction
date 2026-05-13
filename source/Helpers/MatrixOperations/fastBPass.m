% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.16
% ########################
%
% REAL SPACE BANDPASS FILTER WITH HGIH PERFORMANCE
%
% Implements a real-space bandpass filter that suppresses 
%               pixel noise and long-wavelength image variations while 
%               retaining information of a characteristic size.
% 
% INPUT ARGUMENTS:
%           inputImage: The two-dimensional array to be filtered.
%               lnoise: Characteristic lengthscale of noise in pixels.
%                       Additive noise averaged over this length should
%                       vanish. May assume any positive floating value.
%                       May be set to 0 or false, in which case only the
%                       highpass "background subtraction" operation is 
%                       performed.
%               lobject:Integer length in pixels somewhat 
%                       larger than a typical object. Can also be set to 
%                       0 or false, in which case only the lowpass 
%                       "blurring" operation defined by lnoise is done,
%                       without the background subtraction defined by
%                       lobject.  Defaults to false.
%             threshold:By default, after the convolution,
%                       any negative pixels are reset to 0.  Threshold
%                       changes the threshhold for setting pixels to
%                       0.  Positive values may be useful for removing
%                       stray noise or small particles.  Alternatively, can
%                       be set to -Inf so that no threshholding is
%                       performed at all.
%
% OUTPUT ARGUMENTS:
%              filtered:filtered image.

function convo = fastBPass(inputImage,lnoise,lobject,threshold)
    if lnoise>0
        convl=imgaussfilt(inputImage, lnoise);
    else
        convl=inputImage;
    end
    convo=imgaussfilt(inputImage, lobject);
    convo=convl-convo;
    convo(convo<threshold)=0;
end