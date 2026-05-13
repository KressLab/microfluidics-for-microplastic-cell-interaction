% ########################
% Wolfgang Gross
% University of Bayreuth
% 08.11.16
% ########################

classdef OrcaFlashV2<Camera
    properties
        vid;
        src;
        binning=1;
        
        cameraLoaded=false;
        
        dataTimes;
        dataTimesArray;
        lastImage;
        
        % Increase the timeout if you encounter an error when
        % a lot of data is transferred.
        CAMERA_TIMEOUT_S=120; 
        
        BIN_1x1='MONO16_2048x2048_FastMode';
        BIN_2x2='MONO16_BIN2x2_1024x1024_FastMode';
        BIN_4x4='MONO16_BIN4x4_512x512_FastMode';
    end
    
    methods
        function obj=OrcaFlashV2()
            warning("This class requires the Hamamatsu OrcaFlashV2 connected to the PC via USB to work.");
            warning("This API uses the https://de.mathworks.com/products/image-acquisition.html library. " + ...
                    "Only small adaptations should be required to support different cameras:" + ...
                    "https://de.mathworks.com/hardware-support/image-acquisition-hardware.html" + ...
                    "If your camera is not supported, implement the Camera.m Interface for your camera.").
            obj.loadCamera(obj.BIN_1x1);
            obj.logger.info('OrcaFlashV2 loaded.');
        end
        
        function loadCamera(obj, binningID)
            try
                obj.vid = videoinput('hamamatsu', 1, binningID);
                obj.logger.debug('Camera loaded');
            catch e
                obj.cameraLoaded=false;
                obj.logger.error(e.message);
                obj.logger.fatal('OrcaFlashV2 could not be loaded. Connect via USB or switch on.');
            end
            obj.cameraLoaded=true; 
            obj.src = getselectedsource(obj.vid);
            obj.vid.LoggingMode = 'memory';
            triggerconfig(obj.vid,'manual');
            obj.vid.FramesPerTrigger = 1;
            % Fix for timeout errors during getData() calls when large image stacks were aquired 
            set(obj.vid,'Timeout',obj.CAMERA_TIMEOUT_S);
            obj.resetRoi();
        end
        
        function resetRoi(obj)
            if(obj.isStarted())
                obj.logger.error('Camera is started');
                error('Camera is started.');
            end
            resolution=get(obj.vid,'VideoResolution');
            % Matlab inconsistency, zeros are correct here according to
            % documentation.
            set(obj.vid,'ROIPosition', [0 0 resolution(1) resolution(2)]);
            obj.logger.trace('resetRoi()');
        end 
        
        function setRoi(obj, x,y,w,h)
            if(obj.isStarted())
                obj.logger.fatal('Camera is started');
            end
            obj.vid.ROIPosition=round(double([x,y,w,h]));
            obj.logger.trace('setRoi(', x,',',y,',',w,',',h,')');
        end
        
        % returns the sensor center position in image coordinates
        function coords= getSensorCenterImageCoordinates(obj)
            resolution=get(obj.vid,'VideoResolution');
            roi=get(obj.vid,'ROIPosition');
            coords=[roi(1),roi(2)]-0.5*[resolution(1), resolution(2)];
        end
        
        function setBinning(obj, bin)
            if(obj.isStarted())
                obj.logger.fatal('Camera is started');
            end
            obj.logger.trace('setBinning(',bin,')');
            switch bin
                case 1
                    obj.loadCamera(obj.BIN_1x1);
                    obj.binning=1;
                case 2
                    obj.loadCamera(obj.BIN_2x2);
                    obj.binning=2;
                case 4
                    obj.loadCamera(obj.BIN_4x4);
                    obj.binning=4;
                otherwise
                    obj.logger.fatal('Invalid binning: ', num2str(bin));
            end
        end
        
        function bin=getBinning(obj)
            bin=obj.binning;
        end
        
        function [grayRangeMin, grayRangeMax] = getGrayRange(~)
            grayRangeMin=1;
            grayRangeMax=2^16-1;
        end
        
        function setExposureTime(obj, exposureTime)
            if(obj.isStarted())
                obj.logger.fatal('Camera is started.');
            end
            obj.src.ExposureTimeControl='normal';
            obj.src.ExposureTime=exposureTime;
            obj.logger.trace('setExposureTime(', exposureTime,')');
        end
        
        function setFrameCount(obj, count)
            if(obj.isStarted())
                obj.logger.error('Camera is started');
                error('Camera is started.');
            end
            obj.vid.TriggerRepeat=count;
            obj.logger.trace('setFrameCount(', count,')');
        end
        
        function clear(obj)
            obj.dataTimes=[];
            obj.dataTimesArray=[];
            flushdata(obj.vid,'all');
            obj.logger.trace('Camera cleared.');
        end
        
        function start(obj)
            if ~obj.isStarted()
                obj.clear();
                start(obj.vid);
                obj.onStart();
                obj.logger.trace('Camera started.');
            end
        end
        
        function stop(obj)
            if obj.isStarted()
                obj.onStop();
                stop(obj.vid);
                obj.logger.trace('Camera stopped.');
            end
        end
        
        function started = isStarted(obj)
            if strcmp(obj.vid.Running,'on')
               started=1;
            elseif strcmp(obj.vid.Running,'off')
                started=0;
            end
        end
        
        function img = getImage(obj)
            obj.logger.debug('getImage() called');
            if(~obj.isStarted())
                obj.logger.fatal('Camera is not started.');
            end
            obj.onGetImage();
            obj.logger.trace('Image triggered.');
            wait(obj.vid,1,'logging');
            obj.logger.trace('Wait completed.');
            if obj.getEnableDataStorage()
                img=peekdata(obj.vid, 1);
            else
                img=getdata(obj.vid,1);
            end
            obj.lastImage=img;
            obj.logger.trace('Peeking data completed.');
            obj.dataTimes(end+1,1)=obj.getCurrentDataTime();
            obj.logger.trace('getImage() completed.');
            obj.postGetImage();
        end
        
        function img=getLastImage(obj)
            img=obj.lastImage;
        end
        
        function times=getDataTimes(obj)
            times=obj.dataTimes;
        end
        
        function data=getData(obj)
            obj.logger.debug('Get data called');
            try
                data=uint16(getdata(obj.vid,get(obj.vid,'FramesAcquired')));
            catch e
                obj.logger.error('Get Data failed (Possibly the timeout was too low?):', e.message);
                rethrow(e);
            end
            obj.logger.trace('Get data finished');
        end
        
        function num=getNumImages(obj)
              num=obj.vid.FramesAcquired;
        end
        
        function delete(obj)
            if obj.cameraLoaded
                stoppreview(obj.vid);
                stop(obj.vid);
                flushdata(obj.vid);
                obj.logger.info('OrcaFlashV2 closed.');
            end
        end
    end
    
    methods(Access=protected)
        % hook for subclass
        function onStart(~) 
        end
        
        % hook for subclass
        function onStop(~) 
        end
        
        % hook for subclasses
        function postGetImage(~)
        end
        
        % hook for subclasses
        function onGetImage(obj)
            trigger(obj.vid);
        end
    end
    
    methods(Access=private)
        function time=getCurrentDataTime(obj)
            currentImageIdx=obj.getNumImages();
            if currentImageIdx<1
                error('No images have been aquired so far');
            elseif currentImageIdx==1
                obj.dataTimesArray(1,:)=obj.getCurrentEventLogTimeVec();
                time=0;
            else
                obj.dataTimesArray(end+1,:)=obj.getCurrentEventLogTimeVec();
                %event log contains init stuff
                time=etime(obj.dataTimesArray(currentImageIdx,:),obj.dataTimesArray(1,:));
            end
        end
        
        
        function timeVec=getCurrentEventLogTimeVec(obj)
            el=obj.vid.eventLog;
            % matlab event log is limited to 1000 entries. 1.entry is
            % camera start, all other should be trigger events. After 999
            % images, the first entry is overridden.
            currentData=el(1,end);
            
            if ~strcmp(currentData.Type,'Trigger')
                msg=['Last event was no trigger but of type ' ,currentData.Type,' ?!. WTF?'];
                obj.logger.error(msg);
                error(msg);
            end
            
            if currentData.Data.TriggerIndex~=obj.getNumImages()
                msg=['Time log seems to be weird. Trigger index was ', num2str(currentData.Data.TriggerIndex) ,' but getNumImages returned ', num2str(obj.getNumImages())];
                obj.logger.error(msg);
                error(msg);
            end
            
            ts=currentData.Data.AbsTime;
            timeVec=[ts(1),ts(2),ts(3),ts(4),ts(5),ts(6)];
            obj.logger.trace('Time vec for frame ', obj.getNumImages(), ' requested. Current timeVec is ', timeVec);
        end
    end
end

