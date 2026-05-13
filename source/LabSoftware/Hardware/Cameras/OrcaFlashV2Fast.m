classdef OrcaFlashV2Fast < OrcaFlashV2
    
    methods(Access=public)
        function obj = OrcaFlashV2Fast()
        end
        
        function num=getNumImages(obj)
             num=obj.getNumImages@OrcaFlashV2()-1;
        end
        
        function data=getData(obj)
            data=obj.getData@OrcaFlashV2();
            % delete last frame
            data(:,:,:,end)=[];
        end
    end
    
    methods(Access=protected)
        
        function onStart(obj)
            trigger(obj.vid);
        end
        
        function onGetImage(~)
        end
        
        function postGetImage(obj)
            trigger(obj.vid);
        end
        
        function onStop(obj)
             wait(obj.vid,1,'logging');
        end
    end
end

