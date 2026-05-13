classdef MovingFilter   < handle
    properties(Access=private)
        logger;
        funcHandle;
        filterSz;
        images;
        cycle;
        totalImageCount;
    end
    
    methods(Access=public)
%         apply a moving filter to an image series (optimized for gpu, cpu
%         and memory efficient)
%         IDs:
%         filter sz: 2 (total of 9 filtered images)
%         temporal order of function calls
%         1 <-setNextImage(img1)
%         2 <-setNextImage(img2)
%         3 <-setNextImage(img3)
%             getFilteredImage -> returns filtered image centered around frame 1
%                                 base contains two nan frames (ids 0,-1)
%         4 <-setNextImage(img4)
%             getFilteredImage -> returns filtered image centered around frame 2
%                                 base contains one nan frame (id 0)
%         5 <-setNextImage(img5)
%             getFilteredImage -> returns filtered image centered around frame 3
%                                 base contains no nan frame
%         6 <-setNextImage(img6)
%             getFilteredImage -> returns filtered image centered around frame 4
%                                 base contains no nan frame
%         7 <-setNextImage(img7)
%             getFilteredImage -> returns filtered image centered around frame 5
%                                 base contains no nan frame
%         8 <-setNextImage(img8)
%             getFilteredImage -> returns filtered image centered around frame 6
%                                 base contains no nan frame
%         9 <-setNextImage(img9)
%             getFilteredImage -> returns filtered image centered around frame 7
%                                 base contains no nan frame
%         10 <-setNextImage(nanImg1)
%             getFilteredImage -> returns filtered image centered around frame 8
%                                 base contains one nan frame (nanImg1)
%         11 <-setNextImage(nanImg2)
%             getFilteredImage -> returns filtered image centered around frame 9
%                                 base contains tow nan frames (nanImg1,nanImg2)
%         
        function obj=MovingFilter(funcHandle,dataType,imageSz,filterSz)
            obj.logger=Logger.getInstance();
            obj.filterSz=filterSz;
            obj.cycle=Cycle(2*filterSz+1);
            obj.funcHandle=funcHandle;
            switch dataType
                case 'gpuArrayDouble'
                    obj.images=safeGpuArray(double(nan(imageSz(1),imageSz(2),2*filterSz+1)));
                case 'gpuArraySingle'
                    obj.images=safeGpuArray(single(nan(imageSz(1),imageSz(2),2*filterSz+1)));
                case 'double'
                    obj.images=nan(imageSz(1),imageSz(2),2*filterSz+1);
                otherwise
                    obj.logger.fatal('Datatype not supported');
            end
            obj.totalImageCount=0;
        end
        
        function setNextImage(obj,nextImage)
            obj.images(:,:,obj.cycle.getCurrent())=nextImage;
            obj.totalImageCount=obj.totalImageCount+1;
            obj.logger.debug('Wrote ',obj.totalImageCount,' to ',obj.cycle.getCurrent());
            obj.cycle.setNext();
        end
        
        % this returns the difference of the current center image and the
        % filtered Image
        function diffImg=getDiffImage(obj)
            centerId=obj.cycle.getNext(obj.filterSz-1);
            diffImg=obj.images(:,:,centerId)-obj.getFilteredImage();
            obj.logger.debug('Img: ',obj.totalImageCount,' Center Id: ', centerId);
        end
        
        function filteredImg=getFilteredImage(obj)
            filteredImg=obj.funcHandle(obj.images,3);
        end
    end
end

