classdef YScrollPanel<handle
    %SCROLLPANEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        basePanel;
        slider;
        
        contentElements;
        baseYPositions;
        spacing=0.003;
        currentY=0.995; %start on top
        
        ITEM_X=0;
        ITEM_W=0.95;
    end
    
    methods
        function obj = YScrollPanel(~,parent,~,units,~,position)
            obj.basePanel=uipanel('Parent',parent,...
                              'Units',units,...
                              'Position',position);
            obj.slider=uicontrol(obj.basePanel, 'Style','slider','Units','normalized','Position',[.95 0 .05 1],...
                         'Min',0,'Max',0.5,'Value',0,'SliderStep',[.1 1]);
            addlistener(obj.slider,'ContinuousValueChange',@obj.slide);
            obj.contentElements=cell(0);
            obj.baseYPositions=cell(0);
        end
        
        function setElementSpacing(obj, spacing)
            obj.spacing=spacing;
        end
        
        function addContentElement(obj,element,relYSize)
            set(element,'Parent',obj.basePanel);
            set(element,'Position',[obj.ITEM_X,obj.currentY-relYSize,obj.ITEM_W,relYSize]);
            obj.baseYPositions{1,end+1}=obj.currentY-relYSize;
            obj.contentElements{1,end+1}=element;
            
            obj.currentY=obj.currentY-relYSize-obj.spacing;
            obj.renewSlider();
        end
    end
    
    methods(Access=private)
        function renewSlider(obj)
            % display port of base panel is in range [0,1], we dont need to
            % slide there
            if(obj.currentY>0)
                % there is no need to slide, panel is not full
                sliderRange=0.001;
            else
                sliderRange=-obj.currentY;
            end
            set(obj.slider,'Max',sliderRange);
            set(obj.slider,'Value',sliderRange);
        end
        
        function slide(obj,slider,~)
            val = get(slider,'Max')-get(slider,'Value');
            for i=1:size(obj.contentElements,2)
                newPos=get(obj.contentElements{1,i},'Position');
                newPos(2)=obj.baseYPositions{1,i}+val;
                set(obj.contentElements{1,i},'Position',newPos);
            end
        end
    end
end

