classdef CCTLControlPanelVersion < CCTLControlPanelManaged     
    methods(Access=public)
        function names = getNames(~)
             names={'GITRevision',...
                    'GITCommitDate'};
        end
        
        function title=getTitle(~)
            title='Program Version';
        end
    end
    
    methods(Access=protected)
        function types = getDisplayTypes(~)
             types={CCTLViewerControlDisplayType.FULL_WIDTH_CONTROL,...
                    CCTLViewerControlDisplayType.FULL_WIDTH_CONTROL};
        end
        
        function strings=getStartStrings(~)
               strings={'',...
                        ''};
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
              tt={'GIT Revision'...
                  'Commit date and time'};
        end
        
        function restore=restoreStatusOnLoad(~)
            restore={false,...
                     false};
        end
        
        function postEnableInput(obj,~)
            set(obj.getUiControl('GITRevision'),'Enable','off');
            set(obj.getUiControl('GITCommitDate'),'Enable','off');
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

