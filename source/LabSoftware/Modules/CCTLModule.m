classdef(Abstract) CCTLModule < handle
    % Abstract class to extend the CCTrackingLive with further features
    % aside from Camera and LiveTracking support that can be turned on and
    % off (by adding an instance of the module to the core) without
    % polluting the core too much. Can also add ModulePanels to the
    % viewer since Core.addModulePanel is exposed (see obj.load()).
    %
    % The viewer is fully exposed to CCTLModule.
    %
    % Module functions are called by CCTLCore in the same order they
    % are added to CCTLCore i.e.
    % module1.startLive() is called before
    % module2.startLive()
    % if module1 was added to the core before module 2 was added.
    properties(Access=protected)
        logger;
        cctliveViewer;
        camera;
    end
    
    methods(Access=public)
        function obj=CCTLModule()
            obj.logger=Logger.getInstance();
        end
        
        function setViewer(obj, cctliveViewer)
            obj.cctliveViewer=cctliveViewer;
        end
        
        function setCamera(obj, camera)
            obj.camera=camera;
        end
    end
    
    methods(Abstract,Access=public)
        % Use load to add module panels to the viewer. This is called
        % before the module is initialized(). cctliveViewer
        % is already initialized at this stage.
        load(obj);
        % Called directly after the viewer is initialized.
        init(obj);
        
        % Called when start live is pressed (after camera and tracker start)
        onStartLive(obj);
        startLive(obj);
        % Called before the camera and the tracker process the timestep
        onUpdateLive(obj);
        % Called after the camera and the tracker process the timestep
        updateLive(obj);
        % Called when live stops (after camera and tracker stop)
        stopLive(obj);
        
        % Called when start run is pressed (after camera and tracker start)
        onStartRun(obj);
        startRun(obj);
        % Called before the camera and the tracker process the timestep
        onUpdateRun(obj);
        % Called after the camera and the tracker process the timestep
        updateRun(obj);
        % Called when run stops (after camera and tracker stop)
        stopRun(obj);
        
        % Called when dimensions of image change
        onImageDimensionChange(obj);
        
        % Called after the image and tracker information are plotted
        % and after setRoi and resetRoi are called
        onRenderLive(obj);
        onRenderRun(obj);
        
        % Allows to add custom data fields to the result structure (or
        % modify the result structure) after the tracker results were
        % written (when save is pressed).
        cctlResult=appendToSave(obj,cctlResult);
    end
end

