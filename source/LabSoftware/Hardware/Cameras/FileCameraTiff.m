% ########################
% Wolfgang Gross
% University of Bayreuth
% 08.11.16
% ########################

classdef FileCameraTiff< FileCamera
    methods(Access=public)
        function obj=FileCameraTiff()
            obj.inputFilename='~/data/mf240828_micromodNR3_50pN_Channel2_01_40min.tif';
            % obj.inputFilename='~/Documents/Ausbildung/Uniprofil/Messdaten/diffusion/3um_Plain_inWater1/3um_inWater_MT_20x_1_5x_2x2_bin_5Hz_OrcaFlash.tif';
            %obj.inputFilename='C:\Users\Installateur\Desktop\simon\messung1.tif';
            obj.logger.info('File camera tiff instantiated.');
            img=imread(obj.inputFilename,1);
            obj.fullResW=size(img,2);
            obj.fullResH=size(img,1);
            
            imageinfo=imfinfo(obj.inputFilename);
            obj.bitDepth=imageinfo(1).BitDepth;
            obj.fileImageCount=size(imageinfo,1);
            obj.resetRoi();
        end
        
        function setFrameCount(obj, frameCount)
            info=imfinfo(obj.inputFilename);
            obj.logger.debug(' to: ', frameCount);
            if frameCount==Inf
            elseif frameCount>size(info,1)
                obj.logger.error('actual frame count is ', size(info,1), '. Requested: ', frameCount);
            elseif frameCount<size(info,1)
                obj.logger.info('file size is larger than requested: ', size(info,1));
            end
        end        
        
        function image=getImage(obj)
            obj.logger.trace('Get image called ');
            obj.numImages=obj.numImages+1;
            if obj.INFINITE_LOOP
                nextId=mod(obj.numImages,obj.fileImageCount);
                image=imread(obj.inputFilename,max(1,nextId));
            else
                image=imread(obj.inputFilename,obj.startFrame+obj.numImages);
            end
            obj.lastImage=image(obj.roiY:obj.bin:obj.roiY+obj.roiH-1,obj.roiX:obj.bin:obj.roiX+obj.roiW-1);
            image=obj.lastImage;
        end
        
        function data=getData(obj)
            obj.logger.trace('Get data called.');
            data=rand(4,4,4,obj.numImages);
        end
        
        function times=getDataTimes(obj)
            obj.logger.trace('Get data times called.');
            times=0:obj.exposureTime:(obj.numImages-1)*obj.exposureTime;
            times=times';
        end
    end
end

