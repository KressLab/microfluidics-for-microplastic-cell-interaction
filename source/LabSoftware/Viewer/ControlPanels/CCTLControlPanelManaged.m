classdef (Abstract) CCTLControlPanelManaged < CCTLControlPanel
    % Manages the position of the individual control items automatically.
    properties(Access=private)        
        controlCount=0;
        currentY=1;
        
        % size of spacing relative to size of control
        REL_ITEM_SPACING_TOP=0.15;
    end
    
    methods(Abstract=true,Access=protected)
        strings=getStartStrings(obj);
        styles=getStyles(obj);
        tooltips=getTooltips(obj);
        vals=getStartValues(obj);
        displayTypes=getDisplayTypes(obj);
        % restore should be true for all fields the user sets that are
        % supposed to be restored (e.g. edit box content or checkboxes)
        % restore should be false for all fields that are only set by the
        % module and for fields for which a value/string change leads to unwanted
        % behaviour (e.g. a moving stage)
        restore=restoreStatusOnLoad(obj);
    end
    
    methods(Abstract=true,Access=public)
        names=getNames(obj);
    end
    
    methods(Access=public)
        function obj = CCTLControlPanelManaged()
            obj.addAll();
            obj.postAddAll();
        end
        
        function height=getRelativeHeight(obj)
            height=0.025+sum(obj.getItemLineCounts())*0.022;
        end
    end
    
    methods(Access=protected)
        function lineCounts=getItemLineCounts(obj)
            % default behaviour: every item uses one line
            lineCounts=ones(size(obj.getNames(),2),1);
        end
        
        function postAddAll(~)
        end
    end
    
    methods(Access=private)        
        function addAll(obj)
            names=obj.getNames();
            strings=obj.getStartStrings();
            values=obj.getStartValues();
            styles=obj.getStyles();
            tooltips=obj.getTooltips();
            restoreStatusOnLoad=obj.restoreStatusOnLoad();
            displayType=obj.getDisplayTypes();
            lineCounts=obj.getItemLineCounts();
            tags=cell(size(names));
            for i=1:size(obj.getNames(),2)
                obj.addControl(displayType{i},lineCounts(i,1),names{i},strings{i},values{i},styles{i},tooltips{i},restoreStatusOnLoad{i});
                tags{i}=['edit',names{i}];
            end
            obj.editableControls=containers.Map(tags,obj.editableControls);
        end
        
        function addControl(obj,displayType,currentLineCount,name,startString,startValue,style,tooltip,restoreStatusOnLoad)
            obj.controlCount=obj.controlCount+1;
            newHeight=obj.getItemHeight(currentLineCount);
            obj.currentY=obj.currentY-newHeight-obj.getItemSpacingTop();
            if strcmp(displayType,CCTLViewerControlDisplayType.HALF_WIDTH_CONTROL)
                obj.textFields{obj.controlCount} = [];
                obj.editableControls{obj.controlCount} = ...
                        uicontrol('Style', style,...
                                  'String', num2str(name),...
                                  'Parent',obj.mainPanel,...
                                  'Units','normal',...
                                  'Tooltip',tooltip,...
                                  'UserData',restoreStatusOnLoad,...
                                  'Value',startValue,...
                                  'Position', [0.5-obj.ITEM_WIDTH/2, obj.currentY, obj.ITEM_WIDTH, newHeight]);
            elseif strcmp(displayType,CCTLViewerControlDisplayType.TXT_AND_CONTROL)
                obj.textFields{obj.controlCount}=...
                        uicontrol('Style', 'text',...
                                 'String', num2str(name),...
                                 'Tag',['text',name],...
                                 'Parent',obj.mainPanel,...
                                 'Units','normal',...
                                 'Tooltip',tooltip,...
                                 'UserData',restoreStatusOnLoad,...
                                 'Position', [obj.ITEM_SPACING_LEFT, obj.currentY, obj.ITEM_WIDTH, newHeight]);

                obj.editableControls{obj.controlCount} =...
                        uicontrol('Style', style,...
                                 'String', startString,...
                                 'UserData',restoreStatusOnLoad,...
                                 'Parent',obj.mainPanel,...
                                 'Units','normal',...
                                 'Value',startValue,...
                                 'Position', [2*obj.ITEM_SPACING_LEFT+obj.ITEM_WIDTH, obj.currentY, obj.ITEM_WIDTH, newHeight]);
            elseif strcmp(displayType,CCTLViewerControlDisplayType.FULL_WIDTH_CONTROL)
                obj.textFields{obj.controlCount} = [];
                obj.editableControls{obj.controlCount} = ...
                        uicontrol('Style', style,...
                                  'String', name,...
                                  'Parent',obj.mainPanel,...
                                  'Units','normal',...
                                  'Tooltip',tooltip,...
                                  'UserData',restoreStatusOnLoad,...
                                  'Value',startValue,...
                                  'Position', [obj.ITEM_SPACING_LEFT, obj.currentY, 2*obj.ITEM_WIDTH, newHeight]);
            end
        end
        
        function height=getItemHeight(obj,lineCount)
            totalCount=sum(obj.getItemLineCounts());
            height=(lineCount+obj.REL_ITEM_SPACING_TOP*(lineCount-1))/(totalCount+(totalCount+1)*obj.REL_ITEM_SPACING_TOP);
        end
        
        function itemSpacingTop=getItemSpacingTop(obj)
            totalCount=sum(obj.getItemLineCounts());
            itemSpacingTop=obj.REL_ITEM_SPACING_TOP./(totalCount+obj.REL_ITEM_SPACING_TOP.*(totalCount+1));
        end
    end
end

