classdef (Sealed) KeyboardInput < handle
    % works as follows for all mapped keys
    % (every column represents one update cycle)
    % physical key status   0000000011111111111100000110000
    % key down              0000000011111111111100000110000
    % key pressed           0000000010000000000000000100000 
    % key released          0000000000000000000010000001000
    
    % conflict groups
    % physical key status 1 0000000011111111111100000110000
    % physical key status 2 0000000011100000111100000001100
    % key down 1            0000000000011111000000000110000
    % key down 2            0000000000000000000000000001100
    % key pressed 1         0000000000010000000000000100000
    % key pressed 2         0000000000000000000000000001000
    % key released 1        0000000000000000100000000001000
    % key released 2        0000000000000000000000000000010
    
    properties
        logger;
        keys;
        keynames;
        keyValid;
        keyDown;
        keyPressed;
        keyReleased;
        
        keyMappingEnabled;
        mappedKeySet;
        
        % contains all keys present in all groups
        conflictKeys;
        % holds the mapping for the keys
        conflictGroups;
        
        isRunning;
        timerObj;
    end
    
    methods(Access=public)
        function obj=KeyboardInput()
            obj.logger=Logger.getInstance();
            if ~ispc()
                obj.logger.fatal('KeyboardInput requires a windows machine.');
            end
            NET.addAssembly('PresentationCore');
            obj.isRunning=false;
            
            akey = System.Windows.Input.Key.A;  %use any key to get the enum type
            obj.keys = System.Enum.GetValues(akey.GetType);  %get all members of enumeration
            obj.keynames = cell(System.Enum.GetNames(akey.GetType))';
            
            obj.clear();
        end
        
        function clear(obj)
            obj.mappedKeySet=java.util.HashSet();
            obj.conflictKeys=java.util.HashSet();
            obj.conflictGroups=java.util.HashMap();
            
            obj.keyValid = true(obj.keys.Length, 1);
            obj.keyDown = false(obj.keys.Length, 1);
            obj.keyPressed = false(obj.keys.Length, 1);
            obj.keyReleased = false(obj.keys.Length, 1);
        end
        
        function update(obj,~,~)
            % get new key status
            newKeyDown=false(obj.keys.Length, 1);
            for keyidx = obj.getMappedKeys()'
                try
                    newKeyDown(keyidx) = System.Windows.Input.Keyboard.IsKeyDown(obj.keys(keyidx));
                catch e
                    disp(e)
                    obj.keyValid(keyidx) = false;
                end
            end
            
            % resolve conflicts
            entrySet = obj.conflictGroups.entrySet();
            iterator = entrySet.iterator();
            while iterator.hasNext()
                pair = iterator.next();
                conflictGroupKeyIds=pair.getValue();
                % if more than one key is pressed per conflict group
                if sum(newKeyDown(conflictGroupKeyIds))>1
                    % set all key such that they are not pressed
                    newKeyDown(conflictGroupKeyIds)=0;
                end
            end
            
            % write new status
            for keyidx = obj.getMappedKeys()'
                if ~obj.keyDown(keyidx) && newKeyDown(keyidx)
                    obj.keyPressed(keyidx)=true;
                    obj.keyReleased(keyidx)=false;
                elseif obj.keyDown(keyidx) && ~newKeyDown(keyidx)
                    obj.keyPressed(keyidx)=false;
                    obj.keyReleased(keyidx)=true;
                else
                    obj.keyPressed(keyidx)=false;
                    obj.keyReleased(keyidx)=false;
                end
                obj.keyDown(keyidx)=newKeyDown(keyidx);
            end
        end
        
        function down=isKeyDown(obj,key)
            down=obj.keyDown(strcmp(obj.keynames,key));
        end
        
        function down=isKeyPressed(obj,key)
            down=obj.keyPressed(strcmp(obj.keynames,key));
        end
        
        function down=isKeyReleased(obj,key)
            down=obj.keyReleased(strcmp(obj.keynames,key));
        end
        
        function mapKey(obj, charKey)
            idx=find(strcmp(obj.keynames,charKey));
            if isempty(idx)
                error([charKey, ' is not a valid key identifier']);
            elseif obj.mappedKeySet.contains(idx)
                error([charKey, ' is already mapped. Choose a different key.']);
            else
                obj.mappedKeySet.add(idx);
            end
        end
        
        function unmapKey(obj, charKey)
            idx=find(strcmp(obj.keynames,charKey));
            if isempty(idx)
                error([charKey, ' is not a valid key identifier']);
            end
            obj.mappedKeySet.remove(idx);
        end
        
        function addConflictGroup(obj, cellCharKeys)
            idx=NaN(size(cellCharKeys));
            for i=1:size(cellCharKeys,2)
                idx(1,i)=find(strcmp(obj.keynames,cellCharKeys(1,i)));
                if obj.conflictKeys.contains(idx(1,i))
                    keyname=obj.keynames(idx(1,i));
                    error(['Key ', keyname{1}, ' is already mapped in another conflict group']);
                end
            end
            % add the new keys to the conflicting keys
            for i=1:size(cellCharKeys,2)
                obj.conflictKeys.add(idx(1,i));
            end
            obj.conflictGroups.put(obj.conflictGroupHash(idx), idx);
        end
        
        function removeConflictGroup(obj, cellCharKeys)
            idx=NaN(size(cellCharKeys));
            for i=1:size(cellCharKeys,2)
                idx(1,i)=find(strcmp(obj.keynames,cellCharKeys(1,i)));
            end
            % add the new keys to the conflicting keys
            for i=1:size(cellCharKeys,2)
                obj.conflictKeys.remove(idx(1,i));
            end
            obj.conflictGroups.remove(obj.conflictGroupHash(idx));
        end
        
        function hash=conflictGroupHash(~, idx)
            prime=31;
            hash=1;
            % sort in ascending order
            idx=sortrows(idx')';
            for i=1:size(idx,2)
                hash=hash*prime+idx(i);
            end
        end
        
        function matlabArray=getMappedKeys(obj)
             javaArray=obj.mappedKeySet.toArray();
             matlabArray=NaN(size(javaArray));
             for i=1:size(javaArray,1)
                    matlabArray(i,1)=int32(javaArray(i));
             end
        end
    end
end

