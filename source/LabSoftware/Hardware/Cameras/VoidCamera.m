classdef VoidCamera<Camera
    % serves to yield proper time data, does return empty images    
    properties
        started;
        startTime;
        startTic;
        numImages=0;
        times;
    end
    
    methods(Access=public)
        function setExposureTime(~, ~)
        end
        
        function setBinning(~, ~)
        end
        
        function bin=getBinning(~)
            bin=1;
        end
        
        function start(obj)
            obj.logger.debug('Camera started.');
            obj.started=true;
            obj.startTime=datetime('now');
            obj.startTic=tic();
            obj.numImages=0;
            obj.times=[];
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
        
        function resetRoi(obj)
            obj.logger.debug('Resetting roi: void');
        end
        
        function setRoi(obj, ~, ~, ~, ~)
            obj.logger.debug('Setting roi: void');
        end
        
        function [grayRangeMin,grayRangeMax]=getGrayRange(obj)
            grayRangeMin=0;
            grayRangeMax=1;
            obj.logger.trace('Get Gray Range called: [0,1]');
        end
        
        function setFrameCount(obj, ~)
            obj.logger.debug('Setting frame count: void');
        end        
        
        function image=getImage(obj)
            obj.times(end+1,1)=toc(obj.startTic);
            image=[];
        end
        
        function data=getData(obj)
            data=rand(0,0,0,obj.numImages);
        end
        
        function times=getDataTimes(obj)
            obj.logger.trace('Get data times called.');
            times=obj.times;
        end
        
        function coords=getSensorCenterImageCoordinates(~)
            coords=[0,0];
        end
    end
end

