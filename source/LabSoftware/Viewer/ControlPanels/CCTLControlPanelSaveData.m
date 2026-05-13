classdef CCTLControlPanelSaveData < CCTLControlPanel
    properties(Access=private)
        chboxSaveData;
        chboxOverwrite;
        chboxSaveImages;
        chboxSaveImagesDirectlyToDrive;
        editSaveFolder;
        editSaveFileName;
        
        ITEM_SPACING_TOP=0.015;
    end
    
    methods(Access=public)
        function obj=CCTLControlPanelSaveData()
            obj=obj@CCTLControlPanel();
            saveItemHeight=0.20;
            obj.chboxSaveData=uicontrol('Style','checkbox',...
                                  'Parent',obj.mainPanel,...
                                  'String','Save Data',...
                                  'Value',0,...
                                  'Callback',@obj.chboxSaveCallback,...
                                  'UserData',true,... % restoreStatusOnLoad
                                  'Units','normal',...
                                  'Position',[obj.ITEM_SPACING_LEFT,1-obj.ITEM_SPACING_TOP-saveItemHeight,0.45,saveItemHeight]);
                              
            obj.chboxOverwrite=uicontrol('Style','checkbox',...
                                  'Parent',obj.mainPanel,...
                                  'String','Overwrite',...
                                  'Value',0,...
                                  'Callback',[],...
                                  'UserData',true,... % restoreStatusOnLoad
                                  'Units','normal',...
                                  'Position',[obj.ITEM_SPACING_LEFT+0.5,1-obj.ITEM_SPACING_TOP-saveItemHeight,0.45,saveItemHeight]);
                              
            obj.chboxSaveImages=uicontrol('Style','checkbox',...
                                  'Parent',obj.mainPanel,...
                                  'String','SaveImages',...
                                  'Value',1,...
                                  'Callback',@obj.chboxSaveImagesCallback,...
                                  'UserData',true,... % restoreStatusOnLoad
                                  'Units','normal',...
                                  'Position',[obj.ITEM_SPACING_LEFT,1-obj.ITEM_SPACING_TOP-saveItemHeight-(2-1)*(saveItemHeight+obj.ITEM_SPACING_TOP),0.45,saveItemHeight]);
                              
           obj.chboxSaveImagesDirectlyToDrive=uicontrol('Style','checkbox',...
                                  'Parent',obj.mainPanel,...
                                  'String','SaveImagesDirectlyToDrive',...
                                  'Value',0,...
                                  'Callback',[],...
                                  'UserData',true,... % restoreStatusOnLoad
                                  'Units','normal',...
                                  'Tooltip','Enable if you need to measure for a long time and run out of memory, disable if you need speed.',...
                                  'Position',[obj.ITEM_SPACING_LEFT+0.5,1-obj.ITEM_SPACING_TOP-saveItemHeight-(2-1)*(saveItemHeight+obj.ITEM_SPACING_TOP),0.45,saveItemHeight]);
                              
            obj.editSaveFolder=uicontrol('Style', 'edit',...
                                    'String', pwd,...
                                    'Parent',obj.mainPanel,...
                                    'Enable','Inactive',...
                                    'UserData',true,... % restoreStatusOnLoad
                                    'Units','normal',...
                                    'Position', [obj.ITEM_SPACING_LEFT, 1-obj.ITEM_SPACING_TOP-saveItemHeight-(3-1)*(saveItemHeight+obj.ITEM_SPACING_TOP), 1-2*obj.ITEM_SPACING_LEFT, saveItemHeight]);
            obj.editSaveFileName=uicontrol('Style', 'edit',...
                                    'String', 'measurement1',...
                                    'Parent',obj.mainPanel,...
                                    'Enable','On',...
                                    'UserData',true,... % restoreStatusOnLoad
                                    'Units','normal',...
                                    'Position', [obj.ITEM_SPACING_LEFT, 1-obj.ITEM_SPACING_TOP-saveItemHeight-(4-1)*(saveItemHeight+obj.ITEM_SPACING_TOP), 1-2*obj.ITEM_SPACING_LEFT, saveItemHeight]);
            

            editableControls={};
            editableControls{1}=obj.chboxSaveData;
            editableControls{2}=obj.chboxOverwrite;
            editableControls{3}=obj.chboxSaveImages;
            editableControls{4}=obj.chboxSaveImagesDirectlyToDrive;
            editableControls{5}=obj.editSaveFolder;
            editableControls{6}=obj.editSaveFileName;
            
            tags{1}=['edit','Save Data'];
            tags{2}=['edit','Overwrite'];
            tags{3}=['edit','SaveImages'];
            tags{4}=['edit','SaveImagesDirectlyToDrive'];
            tags{5}=['edit','SaveFolder'];
            tags{6}=['edit','SaveFileName'];
            
            obj.editableControls=containers.Map(tags,editableControls);
            
            obj.chboxSaveCallback();
            obj.chboxSaveImagesCallback();
        end
        
        function result=doAction(obj, actionCommand, varargin)
            switch actionCommand
                case 'getSavePath'
                    path=get(obj.getUiControl('SaveFolder'),'String');
                    name=get(obj.getUiControl('SaveFileName'),'String');
                    result=[path,filesep,name];
                otherwise
                    result=doAction@CCTLControlPanel(obj,actionCommand,varargin);
            end
        end
        
        function height=getRelativeHeight(~)
            height=0.13;
        end
        
        function title = getTitle(~)
            title='Save Data';
        end
        
        function names= getNames(~)
            names=cell(0);
        end
    end
    
    methods(Access=protected)
        function postEnableInput(obj,enable)
            if strcmp(enable,'on')
                obj.chboxSaveCallback();
                % otherwise keep off
            end
        end
    end
    
    methods(Access=private)
        function chboxSaveCallback(obj, ~,~)
            if(get(obj.chboxSaveData,'Value')==0)
                set(obj.editSaveFolder,'Enable','Off',...
                                        'ButtonDownFcn',[]);
                set(obj.editSaveFileName,'Enable','Off');
                set(obj.chboxOverwrite,'Enable','Off');
                set(obj.chboxSaveImages,'Enable','Off');
                set(obj.chboxSaveImagesDirectlyToDrive,'Enable','Off');
            else
                set(obj.editSaveFolder,'Enable','Inactive',...
                                        'ButtonDownFcn',@obj.selectNewFolder);
                set(obj.editSaveFileName,'Enable','On');
                set(obj.chboxOverwrite,'Enable','On');
                set(obj.chboxSaveImages,'Enable','On');
                if get(obj.chboxSaveImages,'Value')==1
                    set(obj.chboxSaveImagesDirectlyToDrive,'Enable','On');
                else
                    set(obj.chboxSaveImagesDirectlyToDrive,'Enable','Off');
                end
            end
        end
        
        function chboxSaveImagesCallback(obj,~,~)
            
            if get(obj.chboxSaveImages,'Value')==1
                set(obj.chboxSaveImagesDirectlyToDrive,'Enable','On');
            else
                set(obj.chboxSaveImagesDirectlyToDrive,'Enable','Off');
            end
        end
        
        function selectNewFolder(obj,~,~)
            newdir = uigetdir(get(obj.editSaveFolder,'String'));
            if newdir ~= 0
                set(obj.editSaveFolder,'String',newdir);
            end
        end
    end
end

