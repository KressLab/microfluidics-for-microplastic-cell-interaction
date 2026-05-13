classdef FocusMeasureModuleRenderer < CCTLModuleRenderer
    properties(Access=private)
        mask;
    end
    
    methods(Access=public)
        function obj=FocusMeasureModuleRenderer(cctlViewer,camera)
            obj@CCTLModuleRenderer(cctlViewer,camera)
        end
        
        function init(obj)
        end
        
        function renderRun(~)
        end
        
        function renderLive(obj)
            if obj.cctlViewer.getNumValue('ShowFocusMeasureMaskInLiveMode')
                obj.cctlViewer.showImage(obj.mergeMask(obj.camera.getLastImage()));
            end
        end
        
        function setRenderedMask(obj,mask)
            obj.mask=mask;
        end
    end
    
    methods(Access=private)
        function mergedIm=mergeMask(obj,img)
            brightnessRatio=2;
            mergedIm=mergeColorChannels(img,[],0,obj.mask,brightnessRatio,[],0);
        end
        
        function nullfun(~,~,~)
        end
    end
end
