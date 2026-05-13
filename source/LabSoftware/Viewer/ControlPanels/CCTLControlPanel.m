% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.18
% ########################
classdef (Abstract) CCTLControlPanel < handle
    %CCTRACKINGLIVECONTROLPANEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Access=protected)
        mainPanel;
        logger=Logger.getInstance();
        
        ITEM_SPACING_LEFT=0.05;
        ITEM_WIDTH=0.45;
        
        editableControls;
        textFields;
    end
    
    methods(Abstract=true,Access=protected)
        postEnableInput(obj,active);
    end
    
    methods(Abstract=true, Access=public)
        title=getTitle(obj);
        h=getRelativeHeight(obj);
    end
    
    methods(Access=public)
        function obj = CCTLControlPanel()
            obj.mainPanel=uipanel('Parent',[],'Position',[0,0,1,1],'Title',obj.getTitle());
            obj.editableControls=[];
            obj.textFields={};
        end
        
        function edCont=getEditableControls(obj)
            edCont=obj.editableControls;
        end
        
        function result=doAction(~,~,varargin)
            result=[];
        end
        
        function enableInput(obj, active)
            for uicont=obj.editableControls.values
                set(uicont{1},'Enable',active);
            end
            obj.postEnableInput(active);
        end
        
        function pnl= getMainPanel(obj)
            pnl=obj.mainPanel;
        end
        
        function uicont=getUiControl(obj,key)
            key=['edit',key];
            try
                uicont=obj.editableControls(key);
            catch
                uicont=[];
            end
        end
        
        function tags=getAllRestoreTags(obj)
            tags=cell(0,0);
            for key=obj.editableControls.keys
                uicont=obj.editableControls(key{1});
                if get(uicont,'UserData') % contains the info whether field is restored
                    tags{end+1,1}=key(5:end);
                end
            end
        end
    end
end

