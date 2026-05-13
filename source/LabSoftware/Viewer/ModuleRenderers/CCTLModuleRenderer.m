classdef CCTLModuleRenderer<handle
    % ModuleDrawers can be used to draw module specific content into the
    % original viewer axes. ModuleDrawers are initialized after the viewer
    % is initialized.
    properties(Access=protected)
        cctlViewer;
        camera;
        controlAxesMain;
    end
    
    methods(Access=public)
        function obj = CCTLModuleRenderer(cctlViewer,camera)
            obj.cctlViewer=cctlViewer;
            obj.camera=camera;
            obj.cctlViewer.addModuleRenderer(obj);
        end
    end
    
    methods(Access=public,Abstract)
        init(obj);
        renderRun(obj);
        renderLive(obj);
    end
end

