classdef FocusMeasureModule < CCTLModule
    properties(Access=public)
        renderer;
        recentImgs;
        medianSz=5;
        cycle;
    end
    
    methods(Access=public)
        function obj=FocusMeasureModule()
        end
        
        function load(obj)
            obj.cctliveViewer.addModulePanel(CCTLControlPanelFocusMeasure());
            obj.renderer=FocusMeasureModuleRenderer(obj.cctliveViewer, obj.camera);
        end
        
        function init(~)
        end
        
        function onStartLive(~)
        end
        
        function startLive(obj)
            obj.medianSz=3;
            obj.cycle=Cycle(obj.medianSz);
            im=double(obj.camera.getLastImage());
            obj.recentImgs=repmat(im,1,1,3);
        end
        
        function onUpdateLive(~)
        end
        
        function updateLive(obj)
            obj.recentImgs(:,:,obj.cycle.getCurrent())=obj.camera.getLastImage();
            obj.cycle.setNext();
            obj.updateFMeasure();
        end
        
        function stopLive(~)
        end
        
        function onStartRun(~)
        end
        
        function startRun(~)
        end
        
        function onUpdateRun(~)
        end
        
        function updateRun(obj)
            obj.updateFMeasure();
        end
        
        function stopRun(~)
        end
        
        function onImageDimensionChange(~)
        end
        
        function onRenderLive(obj)
            if obj.cctliveViewer.getNumValue('ShowFocusMeasureMaskInLiveMode')
                mask=obj.calcMask(obj.camera.getLastImage());
                obj.renderer.setRenderedMask(mask);
            end
        end
        
        function onRenderRun(~)
        end
        
        function cctlResult=appendToSave(~,cctlResult)
            
        end
    end
    
    methods(Access=private)
        function mask=calcMask(obj,image)
            image=double(image);
            lowTh=obj.cctliveViewer.getNumValue('FocusMeasureLowTh');
            highTh=obj.cctliveViewer.getNumValue('FocusMeasureHighTh');
            
            mask=image>lowTh & image<highTh;
        end
        
        function updateFMeasure(obj)
            crop=obj.cctliveViewer.getNumValue('FocusMeasureCrop/px');
            try
                im=obj.recentImgs(round(end/2-crop/2):round(end/2+crop/2),round(end/2-crop/2):round(end/2+crop/2),:);
            catch
                obj.logger.warn('Invalid crop. Using original image');
            end
            try
                im=median(im,3);
                fm=fmeasureGLVN(im(obj.calcMask(im)));
                obj.cctliveViewer.setString('FocusMeasure',num2str(fm));
            catch
                obj.cctliveViewer.setString('FocusMeasure','Invalid Method');
            end
        end
    end
end

