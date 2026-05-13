% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.18
% ########################

classdef CCTLViewer < handle
    properties(Access=private)
        FIGURE_NUMBER_CONTROL=1;
        FIGURE_NUMBER_HISTOGRAM=2;
        logger=Logger.getInstance();
        
        camera;
        
        controlTitle;
        figControl;
        controlAxesMain; 
        imgPlot;
        
        scrollPanelControl;
        % control panels are used during runtime
        controlPanels;
        % module panels are set at the load stage
        % copied to control panels at init stage and used at runtime
        modulePanels;
        moduleRenderers;
        
        editableControls;
        
        figureHistogram;
        axisHistogram;
        histogramPlot;
        histSteps=0;
        
        btnSaveSettings;
        btnLoadSettings;
        btnRun;
        btnLive;
    end
    
    methods
        function obj=CCTLViewer()
            obj.controlPanels={};
            obj.moduleRenderers={};
        end
        
        function nullfun(~,~,~)
        end
        
        function init(obj)
            obj.initControlFigure();
        end
        
        function initControlFigure(obj)
            obj.figControl=figure(obj.FIGURE_NUMBER_CONTROL);
            clf(obj.figControl);
            % fix input fallthrough to console when pressing buttons when the
            % figure is active
            set(obj.figControl,'WindowKeyPressFcn', @obj.nullfun,...
                               'WindowKeyReleaseFcn', @obj.nullfun);
            try
                set(obj.figControl,'WindowState','maximized');
            catch
                % will not work on R2017
            end
            % Create push button
            obj.controlAxesMain=axes('Units','normal',...
                                     'Position',[.05, .05, .68, .90]);%'Position',[.05, .05, .65, .9]);
            
            
            obj.scrollPanelControl=YScrollPanel('Parent',obj.figControl,...
                                                'Units','normal',...
                                                'Position',[0.75,0.085,0.24,0.865]);
            
            % Add control panels to scroll panel
            obj.editableControls=containers.Map('KeyType','char','ValueType','any');
            obj.addControlPanel(CCTLControlPanelVersion());
            obj.addControlPanel(CCTLControlPanelTiming());
            obj.addControlPanel(CCTLControlPanelCamera());
            for i=1:size(obj.modulePanels,1)
                obj.addControlPanel(obj.modulePanels{i,1});
            end
            obj.addControlPanel(CCTLControlPanelSaveData());
            
            obj.btnLoadSettings=uicontrol('Style','pushbutton',...
                                          'Tag','loadSettings',...
                                          'Parent',obj.figControl,...
                                          'String','LoadSettings',...
                                          'Units','normal',...
                                          'Position',[0.75,0.05,0.05,0.03]);
            
            obj.btnSaveSettings=uicontrol('Style','pushbutton',...
                                          'Tag','saveSettings',...
                                          'Parent',obj.figControl,...
                                          'String','SaveSettings',...
                                          'Units','normal',...
                                          'Position',[0.81,0.05,0.05,0.03]);
            
            obj.btnLive=uicontrol('Style','togglebutton',...
                                  'Tag','toggleLive',...
                                  'Parent',obj.figControl,...
                                  'String','LiveView',...
                                  'Units','normal',...
                                  'Position',[0.87,0.05,0.05,0.03]);
                              
            obj.btnRun=uicontrol('Style','togglebutton',...
                                  'Tag','toggleRun',...
                                  'Parent',obj.figControl,...
                                  'String','Run',...
                                  'Units','normal',...
                                  'Position',[0.93,0.05,0.05,0.03]);
                              
            obj.initImagePlot();
        end
        
        function addModulePanel(obj, panel)
            obj.modulePanels{end+1,1}=panel;
        end
        
        function setCamera(obj,camera)
            obj.camera=camera;
        end
        
        function addModuleRenderer(obj, renderer)
            obj.moduleRenderers{end+1,1}=renderer;
        end
        
        function initImagePlot(obj)
            cla(obj.controlAxesMain);
            obj.imgPlot=imagesc(NaN,'Parent',obj.controlAxesMain);
            hold(obj.controlAxesMain,'on');
            colormap('gray');
            axis(obj.controlAxesMain,'image');
            hold(obj.controlAxesMain,'off');
            for i=1:size(obj.moduleRenderers,1)
                obj.moduleRenderers{i,1}.init();
            end
            obj.controlTitle=title('');
        end
        
        function renderModulesLive(obj)
            for i=1:size(obj.moduleRenderers,1)
                obj.moduleRenderers{i,1}.renderLive();
            end
        end
        
        function renderModulesRun(obj)
            for i=1:size(obj.moduleRenderers,1)
                obj.moduleRenderers{i,1}.renderRun();
            end
        end
        
        function initHistogramFigure(obj)
            obj.figureHistogram=figure(obj.FIGURE_NUMBER_HISTOGRAM);
            clf(obj.figureHistogram);
            % fix fallthrough to console when pressing buttons when the
            % figure is active
            set(obj.figureHistogram,'WindowKeyPressFcn', @obj.nullfun,...
                                    'WindowKeyReleaseFcn', @obj.nullfun);
            obj.axisHistogram=axes();
        end
        
        function showImageHistogram(obj, image,xmin,xmax)
            xstep=(xmax-xmin)/obj.getNumValue('HistogramSteps');
            x=xmin:xstep:xmax;
            histSamplePoints=100000;
            
            imas=size(image,1)*size(image,2);
            step=ceil(sqrt(imas/histSamplePoints));
            subimage=image(1:step:end,1:step:end);
            if obj.getNumValue('ShowHistogram')
                if isempty(obj.histogramPlot) || ~isvalid(obj.figureHistogram) || ~isvalid(obj.histogramPlot)
                    obj.initHistogramFigure();
                    obj.histogramPlot=histogram(subimage,x,'Parent',obj.axisHistogram,'BinCountsMode','auto');
                    xlim(obj.axisHistogram, [xmin,xmax]);
                else
                    set(obj.histogramPlot,'Data',subimage,'NumBins',size(x,2),'BinEdges',x);
                end
            else
                obj.closeHistogram();
            end
        end
        
        function closeHistogram(obj)
            if ~isempty(obj.figureHistogram) && isvalid(obj.figureHistogram)
                close(obj.figureHistogram);
            end
        end
        
        function setLive(obj,live)
            if live
                obj.initImagePlot();
                set(obj.btnLive, 'String', 'Stop');
                set(obj.btnRun, 'Enable', 'Off');
                obj.setEnableInput('off');
                set(obj.btnLive,'Enable','On');
            else
                set(obj.btnLive, 'String', 'Live');
                set(obj.btnRun, 'Enable', 'On');
                obj.setEnableInput('on');
                obj.resetToggleButtons();
            end
        end
        
        function setRunning(obj, running)
            if running
                obj.initImagePlot();
                obj.setEnableInput('off');
                set(obj.btnRun, 'String', 'Stop');
                set(obj.btnLive, 'Enable', 'Off');
                set(obj.btnRun,'Enable','On');
            else
                obj.setEnableInput('on');
                set(obj.btnRun, 'String', 'Run');
                set(obj.btnLive, 'Enable', 'On');
                obj.resetToggleButtons();
            end
        end
        
        function setBtnRunDown(obj, value)
            set(obj.btnLive, 'Value', value);
        end
        
        %sets input text fields to 'on', 'off' or 'inactive'
        function setEnableInput(obj, active)
            for i=1:size(obj.controlPanels,2)
                obj.controlPanels{i}.enableInput(active);
            end
            set(obj.btnRun,'Enable',active);
            set(obj.btnLive,'Enable',active);
            set(obj.btnSaveSettings,'Enable',active);
            set(obj.btnLoadSettings,'Enable',active);
        end
        
        function value=getValue(obj,key)
            uicont=obj.getUiControl(key);
            if ~isempty(uicont)
                value=get(uicont,'Value');
            else
                obj.logger.fatal(['Unexpected exception: key ',key,' not found in any control panel']);
            end
        end
        
        function value=getNumValue(obj, key)
            uicont=obj.getUiControl(key);
            if ~isempty(uicont)
                if strcmp('edit',get(uicont,'Style'))
                    value=str2double(get(uicont,'String'));
                    return;
                elseif strcmp('text',get(uicont,'Style'))
                    value=str2double(get(uicont,'String'));
                    return;
                elseif strcmp(get(uicont,'Style'),'checkbox')
                     value=get(uicont,'Value');
                     return;
                elseif strcmp(get(uicont,'Style'),'togglebutton') || strcmp(get(uicont,'Style'),'pushbutton')
                     value=get(uicont,'Value');
                     return;
                else
                    error(['Unexpected exception: key ',key,' found but unhandled style case: ',get(uicont,'Style')]);
                end
            else
                obj.logger.fatal(['Unexpected exception: key ',key,' not found in any control panel']);
            end
        end
        
        function string=getString(obj, key)
            uicont=obj.getUiControl(key);
            if ~isempty(uicont)
                string=get(uicont,'String');
                if strcmp(get(uicont,'Style'),'popupmenu')
                    string=string{get(uicont,'Value')};
                end
            else
                % if matlab allows this nonsense why not!
                string=false;
            end
        end
        
        % generic method to pass calls to the control panels
        function result=doAction(obj,actionCommand, varargin)
            for i=1:size(obj.controlPanels,2)
                result=obj.controlPanels{i}.doAction(actionCommand, varargin{:});
                if ~isempty(result)
                    return;
                end
            end
            if ~nargout==0
                obj.logger.fatal(['Unexpected exception: key ',key,' not found in any control panel']);
            end
        end
        
        function highlightControl(obj, key, color)
            uicontrol=obj.getUiControl(key);
            if ~isempty(uicontrol)
                switch color
                    case 'off'
                        set(uicontrol,'BackgroundColor',[0.94,0.94,0.94]);
                    case 'g'
                        set(uicontrol,'BackgroundColor',[0.4,0.9,0.4]);
                    case 'r'
                        set(uicontrol,'BackgroundColor',[0.9,0.3,0.3]);
                    otherwise
                        obj.logger.fatal('Color ',color,' is not a valid highlight color.');
                end
            else
                obj.logger.fatal('Key not found in any attached control panel');
            end
        end
        
        
        function setString(obj, key, string, varargin)
            if size(varargin,1)>0
                executeCb=varargin{1};
            else
                executeCb=false;
            end
            uicontrol=obj.getUiControl(key);
            if ~isempty(uicontrol)
                set(uicontrol,'String',string);
                if ismember(get(uicontrol,'style'),{'edit'}) && get(uicontrol,'UserData')
                    cb=get(uicontrol,'Callback');
                    if executeCb && ~isempty(cb)
                        cb();
                    end
                end
            else
                obj.logger.fatal('Key not found in any attached control panel');
            end
        end
        
        function setValue(obj, key, val,varargin)
            if size(varargin,1)>0
                executeCb=varargin{1};
            else
                executeCb=false;
            end
            uicontrol=obj.getUiControl(key);
            if ~isempty(uicontrol)
                set(uicontrol,'Value',val);
                
                if ismember(get(uicontrol,'style'),{'checkbox'}) && get(uicontrol,'UserData')
                    cb=get(uicontrol,'Callback');
                    if executeCb && ~isempty(cb)
                        cb();
                    end
                end
            else
                obj.logger.fatal('Key not found in any attached control panel');
            end
        end
        
        function setUiCallback(obj, key, fcn)
            uicontrol=obj.getUiControl(key);
            if ~isempty(uicontrol)
                set(uicontrol,'Callback',fcn);
            else
                obj.logger.fatal('Key not found in any attached control panel');
            end
        end
        
        function contains=containsUiControl(obj, key)
            try
                obj.editableControls(['edit',key]);
                contains=true;
            catch
                contains=false;
            end
        end
        
        function uicont=getUiControl(obj,key)
            try
                uicont=obj.editableControls(['edit',key]);
            catch
                obj.logger.fatal('Key ', key, ' not found in class Viewer');
            end
        end
        
        function showImage(obj,image)
            if ~all(isvalid([obj.imgPlot]))
                obj.initImagePlot();
            end
            if obj.getValue('ShowOverilluminationWarning')
                set(obj.imgPlot,'CData',obj.getOverilluminationImage(image));
            else
                set(obj.imgPlot,'CData',image);
            end
            set(obj.imgPlot,'XData',[1,size(image,2)]);
            set(obj.imgPlot,'YData',[1,size(image,1)]);
        end
        
        function setFrameInfo(obj,frameId,dataTime)
            set(obj.controlTitle,'String',['t=',num2str(dataTime,'% 5.3f'),' s  (Frame ',num2str(frameId),')']);
        end
        
        function mergedIm=getOverilluminationImage(obj, img)
            [grayRangeMin, grayRangeMax] = obj.camera.getGrayRange();
            overIlluminatedPixels=img>=grayRangeMax-5;
            img=uint16(scaleMatToRange(double(img),grayRangeMin,grayRangeMax));           
            redChannelImg=img;
            greenChannelImg=img;
            blueChannelImg=img;
            greenChannelImg(overIlluminatedPixels)=grayRangeMin;
            blueChannelImg(overIlluminatedPixels)=min(img(:));
            mergedIm=cat(3,uint16(redChannelImg), uint16(greenChannelImg),uint16(blueChannelImg));
        end
        
        function addControlPanel(obj,pnl)
            names=pnl.getNames();
            for i=1:size(names,1)
                if obj.containsUiControl(names{i})
                    obj.logger.fatal('Error adding panel ', pnl.getTitle(),...
                                     ': Scroll panel already contains a uicontrol named ',names{i},'.'); 
                end
            end
            obj.controlPanels{end+1}=pnl;
            obj.scrollPanelControl.addContentElement(pnl.getMainPanel(), pnl.getRelativeHeight());
            obj.editableControls=[obj.editableControls;pnl.getEditableControls()];
        end
        
        function [x,y] = getClickedPositionsInControlAxes(obj, count)
            axes(obj.controlAxesMain);
            [x,y]=ginput(count);
        end
        
        function [x,y] = getMultipleClickedPositionsInControlAxes(obj)
            axes(obj.controlAxesMain);
            x=[];
            y=[];
            button=1;
            while button==1
                [xNew,yNew,button]=ginput(1);
                x(end+1,1)=xNew;
                y(end+1,1)=yNew;
            end
        end
        
        function resetToggleButtons(obj)
            set(obj.btnRun,'Value',0);
            set(obj.btnLive,'Value',0);
        end
        
        function down=btnRunDown(obj)
            down=get(obj.btnRun,'Value');
        end
        
        function down=btnLiveDown(obj)
            down=get(obj.btnLive,'Value');
        end
        
        function ax=getControlAxesMain(obj)
            ax=obj.controlAxesMain; 
        end
        
        function imgPlot=getMainImagePlot(obj)
            imgPlot=obj.imgPlot;
        end
        
        function setRunCallback(obj, cbFun)
            set(obj.btnRun,'Callback',cbFun);
        end
        
        function setLiveCallback(obj, cbFun)
            set(obj.btnLive,'Callback',cbFun);
        end
        
        function setLoadSettingsCallback(obj,cbFun)
            set(obj.btnLoadSettings,'Callback',cbFun);
        end
        
        function setSaveSettingsCallback(obj,cbFun)
            set(obj.btnSaveSettings,'Callback',cbFun);
        end
        
        function tags=getAllRestoreTags(obj)
            allTags=obj.editableControls.keys;
            tags=cell(0,1);
            for tag=allTags
                tag=tag{1};
                tag=tag(5:end);
                if get(obj.getUiControl(tag),'UserData')
                    tags{end+1,1}=tag;
                end
            end
        end
    end
end

