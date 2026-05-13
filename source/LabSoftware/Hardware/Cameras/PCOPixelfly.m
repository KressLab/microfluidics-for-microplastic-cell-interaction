% new image in PCOPixelfly is triggered right after getImage is called
classdef PCOPixelfly < Camera 
    properties(Access=public)
        % Setting this to 1 prints all the PCO function calls with input
        % and output arguments to the console.
        LOGGING=1;
        pixelPitch=6.45;
    end
    
    properties(Access=protected)
        imgStack;
        
        % camera properties
        camDesc;
        camType;
        bitPix;
        
        roiX=1; % x of the top position of roi
        roiY=1; % y of the top left position of roi
        roiW=1392; % width of the roi
        roiH=1040; % width of the roi
        actXSize; % width of the aquired image
        actYSize; % height of the aquired image
        
        centerSensorX=296; % (roiWidth-centerSensorW)/2 x pos of center sensor area without binning
        centerSensorY=220; % (roiHeight-centerSensorH)/2 y pos of center sensor area without binning
        
        % software roi, set when transferring sensor setup to camera
        % used to map user roi to aquired images
        % aquired images only support 1392x1040 or 800x600 (centered)
        % hardware roi is chosen accordingly, i.e. the smaller roi is
        % chosen when feasible
        softwareRoiX; 
        softwareRoiY;
        softwareRoiW;
        softwareRoiH;
        
        binningX;
        binningY;
        
        % driver interface
        outPtr;
        bufferCycle;
        sBufNr;
        buffList;
        buffImages;
        buffImagePtrs;
        buffImageEventPtrs;
        
        % camera status
        camOpen=0;
        
        % acquisition
        imageCount; % number of frames captured since last start call
        startTime;
        startTic;
        dataTimes;
        
        % default exposure time is 1ms
        exposureTime=0.001;
        % pixelrate
        %pixelrateId=1; % 12MHz
        pixelrateId=2; % 25MHz
        
        % the image that was aquired when getImage was called the last time
        lastImage;
    end
    
    properties(Access=private)
        SDK_LIB_NAME='PCO_CAM_SDK';
    end
    
    methods
        function obj=PCOPixelfly()
            % Crude implementation of the singleton pattern. The single
            % instance is in charge of the library which is loaded
            % globally.
            if (libisloaded(obj.SDK_LIB_NAME))
                % camOpenm akes sure the destructor does nothing when
                % the error is thrown during instantiation.
                obj.camOpen=false;
                unloadlibrary(obj.SDK_LIB_NAME);
                obj.log([obj.SDK_LIB_NAME,' unloadlibrary done.']);
            end
            warning("This class requires the PCO SC2 Cam API including the the MATLAB headers provided by PCO.");
            warning("The PCO Pixelfly camera has to be connected via USB for this class to work.");
            warning("If you do not own a PCO pixelfly camera, implement the Camera.m Interface for your camera.");
            loadlibrary('SC2_Cam','SC2_CamMatlab.h' ...
                    ,'addheader','SC2_CamExport.h' ...
                    ,'alias',obj.SDK_LIB_NAME);
            obj.log([obj.SDK_LIB_NAME,' library is loaded!']);
            obj.imageCount=0;
            obj.bufferCycle=Cycle(4);
            
            % instanciate camera handler (necessary for calllibPCO that
            % outPtr is of the correct datatype)
            obj.outPtr=libpointer('voidPtrPtr');
            obj.calllibPCO('PCO_OpenCamera', 0);
            obj.camOpen=true;
            if isStarted(obj)
                obj.calllibPCO('PCO_SetRecordingState', 0);
            end
            
            %size of structure from file structsize.txt
            ml_cam_desc.wSize=uint16(436);
            obj.camDesc=libstruct('PCO_Description',ml_cam_desc);
            obj.camDesc = obj.calllibPCO('PCO_GetCameraDescription',obj.camDesc);
            obj.bitPix=uint16(obj.camDesc.wDynResDESC);
            
            ml_cam_type.wSize=uint16(1364);
            obj.camType = obj.calllibPCO('PCO_GetCameraType',libstruct('PCO_CameraType',ml_cam_type));
            [obj.binningX, obj.binningY]=obj.calllibPCO('PCO_GetBinning', uint16(0), uint16(0));
            obj.resetRoi();
            obj.logger.info('Camera loaded');
            obj.logger.warn(['enableDataStorage is not properly implemented',...
                            'for this camera yet. The data is always saved to memory with PCO Pixelfly.']);
        end
        
        function resetRoi(obj)
            obj.logger.debug('reset roi');
            if(obj.isStarted())
                obj.logger.fatal('Camera is started.');
            end
            obj.roiX=1; % x of the top position of roi
            obj.roiY=1; % y of the top left position of roi
            obj.roiW=obj.camDesc.wMaxHorzResStdDESC/obj.binningX; % width of the roi
            obj.roiH=obj.camDesc.wMaxVertResStdDESC/obj.binningY; % width of the roi
        end
        
        function setRoi(obj, x,y,w,h)
            if(obj.isStarted())
                obj.logger.fatal('Camera is started.');
            end
            obj.logger.debug('Setting roi to x:',x, ' y:', y, ' w:', w, ' h:', h);
            if x<1 || w> obj.camDesc.wMaxHorzResStdDESC
                obj.logger.fatal(['x size out of range. x was ',num2str(x),' w was ', w]);
            elseif y<1 || h>obj.camDesc.wMaxVertResStdDESC
                obj.logger.fatal(['y size out of range. y was ',num2str(x),' h was ', w]);
            else
                obj.roiX=x;
                obj.roiY=y;
                obj.roiW=w;
                obj.roiH=h;
            end
        end
        
        function setBinning(obj, bin)
            obj.logger.debug('Setting binning to ', bin);
            % when implementing this note that the roi has to be updated as
            % well (see PCO documentation of setBinning)
            if(obj.isStarted())
                error('Camera is started.');
            end
            if bin<1 || bin >2
                error('Binning can only be set to 1 or 2');
            end
            if obj.binningX~=bin || obj.binningY~=bin
                obj.binningX=bin;
                obj.binningY=bin;

                obj.resetRoi();
            end
        end
        
        function bin=getBinning(obj)
            if obj.binningX~=obj.binningY
                obj.logger.fatal('x and y binning do not match');
            end
            bin=obj.binningX;
        end
   
        function [grayRangeMin, grayRangeMax] = getGrayRange(~)
            % TODO: Check if this is related to obj.bitPix and if so, use
            % obj.bitPix.
            grayRangeMin=0;
            grayRangeMax=2^16-1;
        end
        
        % exposure time as double in seconds
        function setExposureTime(obj, exposureTime)
            if(obj.isStarted())
                obj.logger.fatal('Camera is started.');
            end
            % check if exposure time is out of camera limits 
             if exposureTime < 0.000005 || exposureTime > 60
                errorString=['Exposure time out of limits: ', num2str(exposureTime),'s'];
                obj.logger.error(errorString);
                error(errorString);
            end
            obj.exposureTime=exposureTime;
        end
        
        % this function should be used to preallocate memory for the
        % getData().
        function setFrameCount(obj, count)
            if(obj.isStarted())
                obj.logger.fatal('Camera is started.');
            end
            if isinf(count)
                % images are automatically appended in getImage()
                obj.imgStack=cell(0);
            else
                obj.imgStack=cell(1,count);
            end
        end
        
        function start(obj)
            if obj.isStarted()
                return;
            end
            %set bitalignment LSB
            obj.calllibPCO('PCO_SetBitAlignment', uint16(0));
            %set RECORDER_SUBMODE_RING_BUFFER
            obj.calllibPCO('PCO_SetRecorderSubmode', 1);
            %set Pixelrate 25Mhz
            obj.calllibPCO('PCO_SetPixelRate', obj.camDesc.dwPixelRateDESC(obj.pixelrateId));
            %set TriggerMode Software triggered
            obj.calllibPCO('PCO_SetTriggerMode', 1);
            obj.startTime=clock;
            obj.startTic=tic;
            obj.calllibPCO('PCO_SetDateTime', obj.startTime(3), obj.startTime(2), obj.startTime(1), obj.startTime(4), obj.startTime(5), obj.startTime(6));
            obj.calllibPCO('PCO_SetTimestampMode', 0);
            
            obj.transferSensorSetup();
            obj.transferExposureTime();
            
            obj.calllibPCO('PCO_ArmCamera');
            
            %use PCO_GetSizes because this always returns the accurate image size for next recording
            [obj.actXSize, obj.actYSize, ~,~]  = obj.calllibPCO('PCO_GetSizes', uint16(0), uint16(0), uint16(0), uint16(0));            
            %calculate image size
            imas=(uint32(fix((double(obj.bitPix)+7)/8)))*uint32(obj.actXSize)* uint32(obj.actYSize);
            
            %only for firewire, this is maybe broken
            if(uint16(obj.camType.wInterfaceType)==1)
                strangeVar=(floor(double(imas)/4096)+1)*4096;
                lineadd=floor((strangeVar-double(imas))/double(uint32(fix((double(obj.bitPix)+7)/8))*uint32(obj.actXSize)))+1;
                obj.log(['imasize is: ',int2str(imas),' aligned: ',int2str(strangeVar)]);
                obj.log(lineadd,' additional lines must be allocated ');
            else
                lineadd=0;
            end
            
            % %Allocate SDK buffers and store address of buffers
            buffCount=obj.bufferCycle.getCount();
            obj.buffImages=ones(obj.actXSize,(obj.actYSize+lineadd),buffCount,'uint16');
            obj.sBufNr=zeros(1,buffCount,'int16');
            obj.bufferCycle.reset();
            obj.buffImagePtrs=cell(1,buffCount);
            obj.buffImageEventPtrs=cell(1,buffCount);
            for n=1:buffCount
                obj.buffImagePtrs{n} = libpointer('uint16Ptr',obj.buffImages(:,:,n));
                obj.buffImageEventPtrs{n} = libpointer('voidPtr');
                [obj.sBufNr(n),obj.buffImages(:,:,n)]  = obj.calllibPCO('PCO_AllocateBuffer',int16(-1),imas,obj.buffImagePtrs{n},obj.buffImageEventPtrs{n});
            end
            
            obj.calllibPCO('PCO_CamLinkSetImageParameters', obj.actXSize,obj.actYSize);
            obj.calllibPCO('PCO_SetRecordingState', 1);
            
            ml_buflist_1.sBufNr=uint16(obj.sBufNr(1));
            obj.buffList=libstruct('PCO_Buflist',ml_buflist_1);
            obj.buffList.sBufnr=uint16(obj.sBufNr(1));
            
            %add the allocated buffer
            for n=1:buffCount
                obj.calllibPCO('PCO_AddBufferEx', 0,0,obj.sBufNr(n),obj.actXSize,obj.actYSize,obj.bitPix);
            end
            obj.imageCount=0;
            obj.dataTimes=[];
            obj.onStart();
            obj.logger.debug('Started');
        end
        
        function transferSensorSetup(obj)
            obj.calllibPCO('PCO_SetBinning',uint16(obj.binningX),uint16(obj.binningY));
            if obj.roiInCenterSensorArea()
                obj.calllibPCO('PCO_SetSensorFormat',uint16(1));
                obj.calllibPCO('PCO_SetROI', uint16(1), uint16(1), uint16(obj.camDesc.wMaxHorzResExtDESC/obj.binningX), uint16(obj.camDesc.wMaxVertResExtDESC/obj.binningX));
                
                obj.softwareRoiX=obj.roiX-obj.centerSensorX/obj.binningX;
                obj.softwareRoiY=obj.roiY-obj.centerSensorY/obj.binningY;
            else
                obj.calllibPCO('PCO_SetSensorFormat',uint16(0));
                obj.calllibPCO('PCO_SetROI', uint16(1), uint16(1), uint16(obj.camDesc.wMaxHorzResStdDESC/obj.binningX), uint16(obj.camDesc.wMaxVertResStdDESC/obj.binningY));
                
                obj.softwareRoiX=obj.roiX;
                obj.softwareRoiY=obj.roiY;
            end
            obj.logger.debug('Transferred sensor setup. softwareRoiX:', obj.softwareRoiX,' softwareRoiY: ', obj.softwareRoiY, ' roiW', obj.roiW, ' roiH ', obj.roiH);
        end
        
        function inCenter=roiInCenterSensorArea(obj)
            if obj.roiX <= obj.centerSensorX /obj.binningX || (obj.roiX+obj.roiW) >= (obj.centerSensorX+obj.camDesc.wMaxHorzResExtDESC) / obj.binningX
                obj.logger.debug('ROI is not in center');
                inCenter=false;
            elseif obj.roiY<=obj.centerSensorY/obj.binningY || (obj.roiY+obj.roiH) >=(obj.centerSensorY+obj.camDesc.wMaxVertResExtDESC) / obj.binningY
                obj.logger.debug('ROI is not in center');
                inCenter=false;
            else
                obj.logger.debug('ROI is in center');
                inCenter=true;
            end
            return;
        end
        
        function timeMs=getBufferWaitTimeMs(obj)
            timeMs=uint16(obj.exposureTime*1000+10000);
        end
        
        function started=isStarted(obj)
            started=obj.calllibPCO('PCO_GetRecordingState',uint16(0));
        end
        
       % The way buffer images are treated in this function might be slower than
        % necessary (see matlab doc: libpointer)
        function img=getImage(obj)
            if(obj.isStarted())
                obj.logger.trace(['Get image number ',num2str(obj.imageCount+1), ' called.']);
                obj.onGetImage();
                n=obj.bufferCycle.getCurrent();
                if((bitand(obj.buffList.dwStatusDll,hex2dec('00008000')))&&(obj.buffList.dwStatusDrv==0))
                    obj.buffImages(:,:,n)=obj.calllibPCO('PCO_GetBuffer',obj.sBufNr(n),obj.buffImagePtrs{n},obj.buffImageEventPtrs{n});
                    obj.buffList.dwStatusDll=bitand(obj.buffList.dwStatusDll,hex2dec('FFFF7FFF'));
                    img=obj.buffImages(:,1:obj.actYSize,n);
                    
                    obj.calllibPCO('PCO_AddBufferEx', 0,0,obj.sBufNr(n),obj.actXSize,obj.actYSize,obj.bitPix);
                else
                    if obj.buffList.dwStatusDrv~=0
                        obj.logger.error('buffList.dwStatusDrv is 0x', dec2hex(obj.buffList.dwStatusDrv));
                    end
                    if bitand(obj.buffList.dwStatusDll,hex2dec('00008000'))
                        obj.logger.error('bitand(buffList.dwStatusDll,hex2dec(00008000)) is 0x', dec2hex(bitand(obj.buffList.dwStatusDll,hex2dec('00008000'))));
                    end
                end
                obj.bufferCycle.setNext();
                obj.imageCount=obj.imageCount+1;
            else
                error('Camera is not started. Start camera first.');
            end
            % apply software cropping and transposition
            % transposition since C and matlab use different row and
            % column interpretations
            img=img';
            img=img(obj.softwareRoiY:obj.softwareRoiY+obj.roiH-1,obj.softwareRoiX:obj.softwareRoiX+obj.roiW-1);
            
            obj.lastImage=img;
            if obj.getEnableDataStorage()
                obj.imgStack{1,obj.getNumImages()}=img;
            end
        end
        
        function img=getLastImage(obj)
            img=obj.lastImage;
        end
        
        function stop(obj)
            if ~obj.isStarted()
                return;
            end
%             disp(['obj.imgStack ', int2str(uint8(size(obj.imgStack,4)))])
            obj.calllibPCO('PCO_CancelImages');
            obj.onCancelImages();
            obj.calllibPCO('PCO_SetRecordingState', 0);
            obj.calllibPCO('PCO_ArmCamera');
            for n=1:obj.bufferCycle.getCount()
                obj.buffImages(:,:,n) = obj.calllibPCO('PCO_GetBuffer',obj.sBufNr(n),obj.buffImagePtrs{n},obj.buffImageEventPtrs{n});                
                obj.calllibPCO('PCO_FreeBuffer',obj.sBufNr(n));
            end
            
            obj.bufferCycle.reset();
            obj.sBufNr=[];
            obj.buffList=[];
            obj.buffImages=[];
            obj.buffImagePtrs=[];
            obj.buffImageEventPtrs=[];
            obj.imgStack=[];
            obj.logger.debug('Stopped');
        end
        
        function times=getDataTimes(obj)
            % dataTimes may be larger since new values are appended when
            % new image is triggered (see PCO_PixelflyFast.m)
            % Range check ensures data integrity.
            times=obj.dataTimes(1:obj.imageCount);
        end
        
        function data=getData(obj)
            if obj.imageCount<1
                obj.logger.fatal('No images have been aquired so far.');
            end
            if ~obj.getEnableDataStorage()
                obj.logger.fatal('Data storage is not enabled.');
            end
            data=uint16(zeros(obj.roiH, obj.roiW, 1, obj.getNumImages()));
            for i=1:size(obj.imgStack,2)
                data(:,:,1,i)=obj.imgStack{1,i};
            end
        end
        
        function num=getNumImages(obj)
            num=obj.imageCount;
        end
         
        function delete(obj)
            if(obj.camOpen==1)
                obj.stop();
                obj.calllibPCO('PCO_CloseCamera');
                obj.camOpen=0;
                obj.outPtr=[];
                
                unloadlibrary(obj.SDK_LIB_NAME);
                obj.log([obj.SDK_LIB_NAME,' unloadlibrary done.']);
            end
        end
        
        function coords=getSensorCenterImageCoordinates(obj)
            coords=0.5*[obj.camDesc.wMaxHorzResStdDESC/double(obj.binningX),obj.camDesc.wMaxVertResStdDESC/double(obj.binningY)]-double([obj.roiX,obj.roiY]);
        end
    end
    
    methods(Access=protected)
        % hook for subclasses, called after start();
        function onStart(~)
        end
        % hook for subclasses, called after cancelImages in stop();
        function onCancelImages(~)
        end
        
        function onGetImage(obj)
            % trigger image is called exactly before getImage is called
            obj.triggerImage();
            n=obj.bufferCycle.getCurrent();
            obj.buffList.sBufNr=obj.sBufNr(n);
            obj.buffList=obj.calllibPCO('PCO_WaitforBuffer', 1,obj.buffList,obj.getBufferWaitTimeMs());
        end
        
        function triggerImage(obj)
            trigdone = obj.calllibPCO('PCO_ForceTrigger', int16(1));
            if ~trigdone
                error('PCO_ForceTrigger: Trigger failed.');
            end
            obj.dataTimes(end+1,1)=toc(obj.startTic);
        end
        
        function transferExposureTime(obj)
            if(obj.isStarted())
                error('Camera is started.');
            end
            % make sure uint16 does not overflow
            if obj.exposureTime>0.064
                % change to ms
                exposureTimeDigits=uint16(obj.exposureTime*1E3);
                exposureTimeBase=uint16(2);
                obj.logger.debug('setting exposure time to ', exposureTimeDigits, ' ms');
            elseif obj.exposureTime>0.000064
                exposureTimeDigits=uint16(obj.exposureTime*1E6);
                exposureTimeBase=uint16(1);
                % make exposure time fit camera limits (5us step size)
                exposureTimeDigits=exposureTimeDigits-mod(exposureTimeDigits,5);
                obj.logger.debug('setting exposure time to ', exposureTimeDigits, ' us');
            else 
                exposureTimeDigits=uint16(obj.exposureTime*1E9);
                exposureTimeBase=uint16(0);
                % make exposure time fit camera limits (5us step size)
                exposureTimeDigits=exposureTimeDigits-mod(exposureTimeDigits,5000);
                obj.logger.debug('setting exposure time to ', exposureTimeDigits, ' ns')
            end
            obj.calllibPCO('PCO_SetDelayExposureTime', uint16(0), exposureTimeDigits, uint16(1), exposureTimeBase);
        end
        
        function log(obj, message)
           obj.logger.trace(message); 
        end
        
        function errDisp(obj, functionString, errorCode)
            if(errorCode)
                errorStrig=[functionString,' failed with error 0x',num2str(4294967296+errorCode,'%08X')];
                obj.logger.error(errorStrig);
                error(errorStrig);
            end
        end
        
        % Convenience wrapper for matlabs calllib function. 
        % Automatically sets common in- and output arguments, checks the
        % error codes from the PCO API, and serves as a
        % hook to support logging in and output args of PCO API calls.
        %
        % Typical call of calllib:
        % [errorCode,obj.outPtr,trigdone]  = calllib(obj.SDK_LIB_NAME,'PCO_ForceTrigger',obj.outPtr,int16(1));
        %      1          1          0                     1                0              1             0
        % Parameters marked with 1 are always there and are set (input) and
        % removed (output) automatically when calling this function.
        function varargout=calllibPCO(obj, functionName, varargin)
            NARGOUT_OFFSET=2;
            [varargout{1:nargout+NARGOUT_OFFSET}]=calllib(obj.SDK_LIB_NAME, functionName, obj.outPtr, varargin{:});
            if(varargout{1})
                obj.errDisp(functionName,varargout{1});
                % It would be useful to be able to call stop() in the case of an error
                % to achieve a well-defined state. However, the method
                % is likely to crash as well when an error occurred...
                % obj.stop();
            else
                if nargout==0
                    varargout=cell(0);
                else
                    obj.outPtr=varargout{2};
                    % remove first two entries
                    varargout{1}=[];
                    varargout{2}=[];
                    varargout=varargout(~cellfun('isempty',varargout));
                end
                if obj.LOGGING
                    logString=[functionName,'('];
                    trailing=0;
                    for i=1:size(varargin,2)
                        if isnumeric(varargin{i}) && isscalar(varargin{i})
                            logString=[logString, num2str(varargin{i}),', '];
                            trailing=2;
                        end
                    end
                    logString=[logString(1:end-trailing), ')='];
                    trailing=1;
                    for i=1:nargout
                        if isnumeric(varargout{i}) && isscalar(varargout{i})
                            logString=[logString,num2str(varargout{i}), ', '];
                            trailing=2;
                        else
                            logString=[logString,'*, '];
                            trailing=2;
                        end
                    end
                    obj.log(logString(1:end-trailing));
                end
            end
        end
    end
end