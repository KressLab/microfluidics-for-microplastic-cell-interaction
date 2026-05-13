classdef CCTLControlPanelTiming < CCTLControlPanelManaged 
    methods(Access=public)
        function result=doAction(obj, actionCommand,varargin)
            switch actionCommand
                case 'setFrameTimeWarning'
                    obj.setFrameTimeWarning(varargin{1});
            end
            result=doAction@CCTLControlPanel(obj,actionCommand,varargin);
        end
        
        function title = getTitle(~)
            title='Timing';
        end
        
        function names = getNames(~)
             names={'FrameTime/s',...
                    'NumberOfFrames'};
        end
    end
    
    methods(Access=protected)
        function types = getDisplayTypes(~)
             types={CCTLViewerControlDisplayType.TXT_AND_CONTROL,...
                    CCTLViewerControlDisplayType.TXT_AND_CONTROL};
        end
        
        function strings=getStartStrings(~)
               strings={0.05,...
                        'inf'};
        end
        
        function values=getStartValues(~)
            values={NaN,...
                    NaN};
        end
        
        function styles=getStyles(~)
             styles={'edit',...
                     'edit'};
        end
        
        function tt=getTooltips(~)
              tt={'The time between the start of 2 frames in seconds. If the real frame time is slower than the set frame time, this field turns red.'...
                  'The total number of frames to be aquired. The frames are stored in RAM during execution.'};
        end
        
        function restore=restoreStatusOnLoad(~)
            restore={true,...
                     true};
        end
        
        function postEnableInput(obj,~)
            set(obj.getUiControl('FrameTime/s'),'Enable','on');
        end
        
        function setFrameTimeWarning(obj,warnOn)
            if warnOn
                set(obj.textFields{1},'BackgroundColor',[.8 .2 .2]);
            else
                set(obj.textFields{1},'BackgroundColor',[.94 .94 .94]);
            end
        end
    end
end

