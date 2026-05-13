% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.16
% ########################
% CYCLE Class to cycle through a set of indices starting from 1 to count
% When the end is reached, start from the beginning.
classdef Cycle<handle
    properties(Access=private)
        count;
        current;
    end
    
    methods(Access=public)
        function obj=Cycle(count)
            obj.count=count;
            obj.reset();
        end
        
        function reset(obj)
            obj.setCurrent(1);
        end
        
        function current=getCurrent(obj)
            current=obj.current;
        end
        
        function setCurrent(obj,current)
            if(current>=1 && current<=obj.count)
                obj.current=current;
            else
                error('current value out of range')
            end
        end
        
        function next=getNext(obj,diff)
            next=1+mod(obj.getCurrent()+diff,obj.getCount());
        end
        
        function next=setNext(obj)
            next=obj.current+1;
            if next>obj.count
                next=1;
            end
            obj.setCurrent(next);
        end
        
        function previous=setPrevious(obj)
            previous=obj.current-1;
            if previous<1
                previous=obj.count;
            end
            obj.setCurrent(previous);
        end
        
        function count=getCount(obj)
            count=obj.count;
        end
    end
end

