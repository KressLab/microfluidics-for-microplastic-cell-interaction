classdef PIMoveGUI<handle
    %BUTTONDOWNTEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        logger;
        fig;
        btnRun;
        btnInit;
        btnStop;
        editVel;
        
        tweezerController;
        tweezerAxisX;
        tweezerAxisY;
        tweezerAxisZ;
    end
    
    methods
        function obj=PIMoveGUI()
            close all;
            obj.logger=Logger.getInstance();
            obj.logger.setCommandWindowLevel(Logger.DEBUG);
            obj.logger.setLogLevel(Logger.OFF);
            obj.logger.setExcludeFilter([]);
            obj.logger.setIncludeFilter([]);
            
            %obj.tweezerController=PIC884Controller(PI_GCS_ControllerDebugWrapper(PI_GCS_Controller()));
            obj.tweezerController=PIC884Controller(PI_GCS_ControllerDebugWrapper(PI_GCS_ControllerMock({'1','2','3'})));
            obj.tweezerController.testConnectedAxes();
            obj.tweezerAxisX=PILinearAxis('1', PICoordinateSystem.HARDWARE, 0.0008); % backlash 0.00mm, High Quality Stage
            obj.tweezerAxisY=PILinearAxis('2', PICoordinateSystem.HARDWARE, 0.0008); % backlash 0.00mm, High Quality Stage
            obj.tweezerAxisZ=PILinearAxis('3', PICoordinateSystem.REVERSED, 0.0075); % backlash 0.0075mm
            obj.tweezerAxisX.setKeyboardControl('Right','Left');
            obj.tweezerAxisY.setKeyboardControl('Down','Up');
            obj.tweezerAxisZ.setKeyboardControl('PageUp','PageDown');
            obj.tweezerController.connectTo(obj.tweezerAxisX);
            obj.tweezerController.connectTo(obj.tweezerAxisY);
            obj.tweezerController.connectTo(obj.tweezerAxisZ);
            
            obj.fig=figure('MenuBar', 'none', 'ToolBar', 'none','Name','PI Move GUI');
            
            set(obj.fig,'WindowKeyPressFcn', @obj.nullfun,...
                        'WindowKeyReleaseFcn', @obj.nullfun);
            
            uicontrol('Parent',obj.fig,...
                              'Style','text',...
                              'String','velocity/um/s',...
                              'Units','normalized',...
                              'Position',[0.05 0.50 0.40 0.1],...
                              'Visible','on');
            obj.editVel=uicontrol('Parent',obj.fig,...
                              'Style','edit',...
                              'String','2',...
                              'Units','normalized',...
                              'Position',[0.55 0.50 0.40 0.2],...
                              'Visible','on',...
                              'Callback',@obj.tweezerSetVel);
            obj.btnStop=uicontrol('Parent',obj.fig,...
                              'Style','pushbutton',...
                              'String','STOP',...
                              'Units','normalized',...
                              'Position',[0.05 0.75 0.9 0.2],...
                              'Visible','on',...
                              'Callback',@obj.stopAllTweezerStageMovement);
            obj.btnRun=uicontrol('Parent',obj.fig,...
                              'Style','togglebutton',...
                              'String','Click to enable Keyboard',...
                              'Units','normalized',...
                              'Position',[0.05 0.03 0.9 0.2],...
                              'Visible','on',...
                              'Callback',@obj.buttonDown);
            obj.btnInit=uicontrol('Parent',obj.fig,...
                              'Style','pushbutton',...
                              'String','Init',...
                              'Units','normalized',...
                              'Position',[0.05 0.25 0.9 0.2],...
                              'Visible','on',...
                              'Callback',@obj.initTweezerAxes);
        end
        
        function nullfun(~,~,~)
        end
        
        function initTweezerAxes(obj,~,~)
            obj.logger.debug('Initializing tweezer axis control.');
            obj.tweezerAxisX.init('C');
            obj.tweezerAxisY.init('C');
            obj.tweezerAxisZ.init('C');
            obj.tweezerAxisZ.moveStageTo(obj.tweezerAxisZ.getMaxStagePos());
            obj.tweezerController.startRecording();
            obj.setVelUmS(obj.tweezerAxisY.getVel());
            obj.tweezerController.stopRecording();
            set(obj.btnRun,'Value',0);
        end
        
        function vel=getVelUmS(obj)
            vel=str2double(get(obj.editVel,'String'))/1000;
            if vel>1.450
                error('Velocity too fast for M403');
            end
        end
        
        function setVelUmS(obj, vel)
            set(obj.editVel,'String',num2str(vel*1000));
        end
        
        function tweezerSetVel(obj,~,~)
            obj.tweezerController.setVel([obj.getVelUmS(),...
                                          obj.getVelUmS(),...
                                          obj.getVelUmS()]);
        end
        
        function stopAllTweezerStageMovement(obj, ~, ~)
            obj.logger.debug('Stopping all tweezer movement.');
            obj.tweezerController.haltAll();
            set(obj.btnRun,'Value',0);
        end
        
        function updateTweezerAxisControl(obj)
            if ~obj.tweezerAxisX.isKeyboardEnabled()
                obj.tweezerController.setVel([obj.getVelUmS(),...
                                          obj.getVelUmS(),...
                                          obj.getVelUmS()]);
                obj.tweezerAxisX.enableKeyboardControl();
                obj.tweezerAxisY.enableKeyboardControl();
                obj.tweezerAxisZ.enableKeyboardControl();
            end
            obj.tweezerController.update();
            obj.setVelUmS(obj.tweezerAxisX.getVel());
        end
        
        function buttonDown(obj,~,~)
            if get(obj.btnRun,'Value')==1
                obj.tweezerController.startRecording();
                try
                    while get(obj.btnRun,'Value')==1
                        obj.updateTweezerAxisControl();
                        pause(0.01);
                    end
                catch e
                    disp(e.message);
                    obj.stopAllTweezerStageMovement();
                    set(obj.btnRun,'Value',1);
                    rethrow(e);
                end
            else
                obj.stopAllTweezerStageMovement();
                set(obj.btnRun,'Value',0);
            end
        end
    end
end

