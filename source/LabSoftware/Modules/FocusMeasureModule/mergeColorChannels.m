function mergedImage = mergeColorChannels(grayscaleImg,redChannelImg,redBrightnessRatio,greenChannelImg,greenBrightnessRatio,blueChannelImg,blueBrightnessRatio)
    % input: grayscaleImg
    % channelImgs can be [] if no merge is desired
    % ouput: 16 bit merged channel
    maxBrightnessRatio=max([redBrightnessRatio,greenBrightnessRatio,blueBrightnessRatio]);
    
    grayscaleImg=scaleMatToRange(double(grayscaleImg),1,(2^16-1)/maxBrightnessRatio);
    
    redChannelImg=getScaledImage(grayscaleImg,redChannelImg,redBrightnessRatio);
    greenChannelImg=getScaledImage(grayscaleImg,greenChannelImg,greenBrightnessRatio);
    blueChannelImg=getScaledImage(grayscaleImg,blueChannelImg,blueBrightnessRatio);
    
    mergedImage=cat(3,uint16(redChannelImg), uint16(greenChannelImg),uint16(blueChannelImg));
end

function scaledImg=getScaledImage(grayscaleImg,colorChannelImg,scale)
    if ~isempty(colorChannelImg)
        scaledImg=grayscaleImg+scaleMatToRange((double(colorChannelImg)),1,(2^16-1)/scale*(scale-1));
    else
        scaledImg=grayscaleImg;
    end
end

