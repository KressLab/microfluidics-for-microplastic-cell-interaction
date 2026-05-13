classdef (Abstract) Camera < handle
    % Abstract camera implementation
    
    properties
        logger=Logger.getInstance();
        dataStorageEnabled=true;
    end
    
    methods(Abstract=true, Access=public)
        % ##################  SETTINGS  ###################################
        % All of the following methods are expected to fail with an error
        % when the camera is started and the methods are called.
        
        % Resets the ROI to the maximum ROI the camera supports.
        resetRoi(obj);
        % Sets the ROI to a new region.
        % Input arguments:
        % x:    x of the top left position
        % y:    y of the top left position
        % w:    the width (i.e. the size of the roi in x)
        % w:    the height (i.e. the size of the roi in y)
        setRoi(obj, x,y,w,h);
        % Sets the binning to bin*bin. This is expected to throw an error
        % when the binning size is not supported by the camera.
        % Input arguments:
        % bin:  The binning size in pixels (2->2x2, 4->4x4, ...)
        setBinning(obj, bin);
        bin=getBinning(obj);
        % Returns the gray range of the camera, i.e. the lowest and highest
        % gray value that are possibly returned.
        [grayRangeMin, grayRangeMax] = getGrayRange(obj);
        % Sets the exposure time of the camera.
        % Input arguments:
        % exposureTime: The exposure time in seconds.
        setExposureTime(obj, exposureTime);
        % Sets the number of frames that are to be aquired. This has to be
        % called before the camera is started.
        setFrameCount(obj, count);
        
        % ###########  IMAGE ACQUISITION AND DATA MANAGEMENT ##############
        % Starts the camera live aquisition. The method does nothing when
        % the camera is started already.
        start(obj);
        % Returns true when the camera is started.
        isStarted=isStarted(obj);
        % Stops the camera live aquisition. The method does nothing when
        % the camera is stopped already.
        stop(obj);
        % Returns a single image. If the camera has not been started,
        % the function may fail (depending on the implementation).
        img=getImage(obj);
        % Returns the last image that was aquired via getImage()
        img=getLastImage(obj);
        % Returns the number of seconds that have passed between  the first
        % image and the rest of the images. Returns 0 for the first image
        % and throws an error when no images have been aquired so far.
        times=getDataTimes(obj);
        % Returns an array that contains all the images that have been
        % aquired since the camera was started. Data is of dimension
        % (width,height,colorChannelCount,numberOfImagesAcquired)
        data=getData(obj);
        % Returns the number of images that have been aquired since the
        % camera was started.
        num=getNumImages(obj);
        coords=getSensorCenterImageCoordinates(obj);
    end
    
    methods(Access=public)
        function deltaTimes=getDeltaTimes(obj)
            obj.logger.trace('getDeltaTimes() called');
            % Returns the time in seconds that has passed between two
            % concurrent frames (i.e. i and i-1). The first element is always
            % NaN. Throws an error when no images have been acquired since the 
            % camera was started.
            if obj.getNumImages()<1
                error('No images have been aquired so far.');
            end
            times=obj.getDataTimes();
            deltaTimes=NaN(size(times));
            for i=2:size(deltaTimes,1)
                deltaTimes(i)=times(i)-times(i-1);
            end
        end
        
        function time=getLastDataTime(obj)
            dataTimes=obj.getDataTimes();
            time=dataTimes(obj.getNumImages());
        end
        
        function delta=getLastDeltaTime(obj)
            % Returns the time in seconds that has passed between the current
            % and the last frame. Returns NaN when only 1 image has been
            % aquired and throws an error when no images have been acquired
            % since the camera was started.
            if obj.getNumImages()<2
                error('Less than 2 images have been aquired so far.');
            end
            deltaTimes=obj.getDeltaTimes();
            delta=deltaTimes(end);
        end
        
        % determines whether the data is stored to the memory during
        % aquisition or not
        function enableDataStorage(obj, enable)
            obj.dataStorageEnabled=enable;
        end
        
        function enable=getEnableDataStorage(obj)
            enable=obj.dataStorageEnabled;
        end
        
        function restart(obj)
            % Guarantees that the camera is stopped and started.
            obj.stop();
            obj.start();
        end
        
        function selectRoi(obj,ax)
            % Allows the user to select an ROI. Therefore, an image is plotted
            % inside the axes specified in ax. The camera is stopped after roi
            % selction.
            if(obj.isStarted())
                error('Camera is started.');
            end
            obj.resetRoi();
            obj.setFrameCount(1);
            
            cla(ax);
            imagesc(obj.getSingleImage());
            axis equal;
            axis image;
            colormap('gray');
            
            [x,y]=(ginput(2));
            x=uint16(x);
            y=uint16(y);
            
            % Cast to double because matlab
            %obj.setRoi(y(1,1), x(1,1), y(2,1)-y(1,1), x(2,1)-x(1,1));
            obj.setRoi(x(1,1), y(1,1), x(2,1)-x(1,1), y(2,1)-y(1,1));
            imagesc(obj.getSingleImage());
            axis equal;
            axis image;
        end
        
        
        function img=getSingleImage(obj)
            obj.logger.trace('getSingleImage() called');
            % Returns a single image. This function does not require the camera
            % to be started and stops the camera after the function call.
            obj.setFrameCount(1);
            obj.start();
            img=obj.getImage();
            obj.stop();
        end
    end
end

