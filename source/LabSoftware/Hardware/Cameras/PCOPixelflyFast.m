% new image in PCOPixelflyFast is triggered right after last getImage was called
classdef PCOPixelflyFast < PCOPixelfly
    methods(Access=protected)
        function onStart(obj)
            obj.triggerImage();
        end
        
        function onGetImage(obj)
            n=obj.bufferCycle.getCurrent();
            obj.buffList.sBufNr=obj.sBufNr(n);
            obj.buffList=obj.calllibPCO('PCO_WaitforBuffer', 1,obj.buffList,obj.getBufferWaitTimeMs());
            obj.triggerImage();
        end
        
        function onCancelImages(obj)
            obj.calllibPCO('PCO_WaitforBuffer',1,obj.buffList,obj.getBufferWaitTimeMs());
        end
    end
end