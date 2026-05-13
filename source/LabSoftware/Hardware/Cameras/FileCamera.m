classdef (Abstract) FileCamera<Camera
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        inputFilename;
        startFrame=2;
        INFINITE_LOOP=true;
        exposureTime;
        numImages=0;
        started=false;
        lastImage;
        
        bitDepth;
        
        fullResW;
        fullResH;
        
        bin=1;
        
        roiX;
        roiY;
        roiH;
        roiW;
        fileImageCount;
    end
    
    methods(Access=public)
        function frw=getFullResWidth(obj)
            frw=obj.fullResW;
        end
        
        function frh=getFullResHeight(obj)
            frh=obj.fullResH;
        end
        
        function fileImageCount=getFileImageCount(obj)
            fileImageCount=obj.fileImageCount;
        end
        
        function setExposureTime(obj, exposureTime)
            obj.logger.debug(' to: ', exposureTime);
            obj.exposureTime=exposureTime;
        end
        
        function setBinning(obj, bin)
            obj.bin=bin;
            obj.logger.debug('Setting binning to: ', bin);
        end
        
        function bin=getBinning(obj)
            bin=obj.bin;
        end
        
        function start(obj)
            obj.logger.debug('Camera started.');
            obj.started=true;
            obj.numImages=0;
        end
        
        function started=isStarted(obj)
            started=obj.started;
        end
        
        function stop(obj)
            obj.logger.debug('Camera stopped.');
            obj.started=false;
        end
        
        function img=getLastImage(obj)
            img=obj.lastImage;
        end
        
        function frameId=getStartFrame(obj)
            frameId=obj.startFrame;
        end
        
        function setStartFrame(obj, frameId)
            obj.startFrame=frameId;
        end
        
        function num=getNumImages(obj)
            obj.logger.trace('Aquired images: ',obj.numImages);
            num=obj.numImages;
        end
       
        function getImageCount(obj)
            
        end
        
        function resetRoi(obj)
            obj.logger.debug('Resetting roi:');
            obj.setRoi(1,1,obj.fullResW, obj.fullResH);
        end
        
        function setRoi(obj, roiX, roiY, roiW, roiH)
            obj.roiX=roiX;
            obj.roiY=roiY;
            obj.roiW=roiW;
            obj.roiH=roiH;
            
            obj.logger.debug('Setting roi to roiX: ',roiX,' roiY: ',roiY,' roiW: ',roiW,' roiH: ',roiH);
        end
        
        function [grayRangeMin,grayRangeMax]=getGrayRange(obj)
            grayRangeMin=0;
            grayRangeMax=(2^obj.bitDepth)-1;
            obj.logger.trace('Get Gray Range called: min ', grayRangeMin, ' max: ',grayRangeMax);
        end
        
        function inputFilename=getInputFilename(obj)
            inputFilename=obj.inputFilename;
        end
        
        function coords=getSensorCenterImageCoordinates(obj)
            coords=(0.5*[obj.fullResW,obj.fullResH]-double([obj.roiX,obj.roiY]))/obj.bin;
        end
    end
end

