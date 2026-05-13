classdef PIMacroExecutor<handle
    %PIMacroExecutor
    % Useage:
    % ########## PRECOMPILER COMMANDS ###############
    % DEF VEL 0.4 // replaces all subsequent occurances of VEL in the macro
    %                with 0.4
    %
    % ########## CONTROL FLOW ###############
    % for 3
    %    ...
    % end  // executes all lines in between for and next 'end' line for 3 times
    %      // (loops must not be nested)
    %
    % ########## COMMAND LIST ###############
    % wait // waits until all movement stops
    % wait 3 // waits for 3 seconds
    % movx 1 (movy, movz) //move stage to 1mm (absolute position)
    % movxw 1 (movyw, movzw) // move stage to 1mm (absolute position) and
    %                        // issues wait command (see above)
    % mvrx 1 (mvry, mvrz) //move stage by 1mm (relative to current position)
    % mvrxw 1 (mvryw, mvrzw) // move stage by 1mm (relative to current position) and
    %                        // issues wait command (see above)
    % vel 0.004 // set x, y, and z velocity to 0.004 mm/s
    % velx 0.1 (vely, velz) // set stage velocity to 0.1 mm/s
    % hlt // stop all stage movement (combine with wait N)
    %
    % ########## EXAMPLE ###############
    % moves all 3 stages back and forth for 5 times with 50um/s
    % (movement of all axes starts simultaneously) and waits 5s in between.
    %
    % DEF DSTX 0.250
    % DEF DSTY 0.100
    % DEF DSTZ 0.050
    % vel 0.05
    % for 5
    %   mvrx DSTX
    %   mvry DSTY
    %   mvrzw DSTZ
    %   wait 5
    %   mvrx -DSTX
    %   mvry -DSTY
    %   mvrzw -DSTZ
    %   wait 5
    % end
    properties(Access=private)
        logger;
        
        controller;
        axisX;
        axisY;
        axisZ;
        attachedAxisCount;
        
        commands;
        currentCommandId;
        
        waitStartTime;
        waitTime;
        waitUntilMovementFinishes; 
    end
    
    methods(Access=public)
        function obj = PIMacroExecutor(controller)
            obj.logger=Logger.getInstance();
            obj.controller=controller;
            axes=controller.getConnectedAxes();
            obj.axisX=axes{1,1};
            obj.attachedAxisCount=1;
            obj.logger.debug('Connected to 1 axis.');
            if size(axes,2)>1
                obj.axisY=axes{1,2};
                obj.attachedAxisCount=2;
                obj.logger.debug('Connected to 2 axes.');
            end
            if size(axes,2)>2
                obj.axisZ=axes{1,3};
                obj.attachedAxisCount=3;
                obj.logger.debug('Connected to 3 axes.');
            end
            if size(axes,2)>3
                obj.logger.fatal('PIMacroExecutor does not support more than 3 axes.');
            end
        end
        
        function startExecuteMacro(obj, macroString)
            obj.compileMacro(macroString);
            obj.currentCommandId=1;
            obj.waitUntilMovementFinishes=false;
            obj.waitStartTime=tic;
            obj.waitTime=0;
            obj.logger.debug('Started macro execution.');
            % Commands are executed in the update function.
        end
        
        function haltExecution(obj)
            obj.currentCommandId=0;
            obj.logger.debug('Stopped/finished macro execution.');
        end
        
        % Executes new commands (e.g. to the stages) if necessary.
        % If the executor is not started or the executor is waiting for the
        % stage to stop moving or time to pass, the function does nothing.
        function update(obj)
            obj.updateWaitUntilMovementFinishes();
            % When a new command triggers
            % waitUntilMovementFinished=true, the next command is
            % guaranteed not to be executed in the current update cycle,
            % even if the command does not trigger any movement
            % (eg. mvrxw 0) because obj.isAnyStageMoving() is only
            % checked in obj.updateWaitUntilMovementFinishes().
            while obj.isExecuting() && obj.isNotWaiting()
                if obj.hasMoreCommands()
                    obj.executeNewCommand();
                else
                    obj.haltExecution();
                end
            end
        end
    end
    
    methods(Access=private)
        function executing=isExecuting(obj)
            executing=obj.currentCommandId>0;
        end
        
        function updateWaitUntilMovementFinishes(obj)
            if obj.waitUntilMovementFinishes && ~obj.controller.isAnyMoving()
                obj.waitUntilMovementFinishes=false;
                obj.logger.trace('Waited for movement finished.');
            end
        end
        
        function execute=isNotWaiting(obj)
            execute=~obj.waitUntilMovementFinishes && obj.waitTimePassed();
        end
        
        function passed=waitTimePassed(obj)
            passed=toc(obj.waitStartTime)>obj.waitTime;
        end
        
        function allExecuted=hasMoreCommands(obj)
            allExecuted=obj.currentCommandId>0 && obj.currentCommandId<=size(obj.commands,1);
        end
        
        function compileMacro(obj, macroString)
            rawLines=cellstr(macroString);
            obj.commands=cell(0);
            i=1;
            while i<= size(rawLines,1)
                trimmed=strtrim(rawLines{i,1});
                if isempty(trimmed)
                    % do nothing in empty line
                    i=i+1;
                elseif startsWith(trimmed,'DEF')
                    % replace all proceeding occurances of first argument
                    % with second argument, e.g.
                    % DEF VEL 0.003
                    % ...
                    % velx VEL // sets velx to 0.003
                    % vely VEL // sets vely to 0.003
                    split=obj.getCommandSplit(trimmed);
                    obj.logger.debug('Replacing ', split{1,2}, ' with ', split{1,3});
                    for j=i+1:size(rawLines,1)
                        rawLines{j,1}=strrep(rawLines{j,1},split{1,2},split{1,3});
                    end
                    i=i+1;
                elseif startsWith(trimmed,'for')
                    % resolve for loop (no nesting is supported)
                    obj.logger.trace('for in line ',i);
                    split=obj.getCommandSplit(trimmed);
                    try
                        iterations=floor(str2double(split{1,2}));
                    catch
                        obj.logger.fatal('For must be followed by a numeric value.');
                    end
                    endLine=obj.getNextEnd(rawLines, i+1);
                    obj.logger.trace('end in line ',endLine);
                    for j=1:iterations
                        % i-line contains for endline contains end
                        for k=i+1:endLine-1
                            obj.commands{end+1,1}=rawLines{k,1};
                        end
                    end
                    i=endLine+1;
                else
                    % normal command
                    obj.commands{end+1,1}=rawLines{i,1};
                    i=i+1;
                end
            end
        end
        
        function lineId=getNextEnd(obj, rawCommandLines, startLine)
            for i=startLine:size(rawCommandLines,1)
                trim=strtrim(rawCommandLines{i,1});
                if startsWith(trim,'for')
                    obj.logger.fatal('You must not nest for loops!');
                elseif startsWith(trim,'end')
                    lineId=i;
                    return;
                end
            end
            obj.logger.fatal('Could not find next end corresponding to for in line ',num2str(startLine));
        end
        
        function executeNewCommand(obj)
            obj.logger.debug('Executing ', strtrim(obj.commands{obj.currentCommandId,1}));
            commandSplit=obj.getCommandSplit(obj.commands{obj.currentCommandId,1});
            switch commandSplit{1,1}
                case 'wait'
                    if size(commandSplit,2)==1
                        obj.waitUntilMovementFinishes=true;
                    elseif size(commandSplit,2)==2
                        obj.startWaitTime(str2double(commandSplit{1,2}));
                    else
                        obj.logger.fatal('Unknown command: ',obj.commands{obj.currentCommandId,1});
                    end
                case 'movx'
                    obj.axisX.moveStageTo(str2double(commandSplit{1,2}));
                case 'movxw'
                    obj.axisX.moveStageTo(str2double(commandSplit{1,2}));
                    obj.waitUntilMovementFinishes=true;
                case 'mvrx'
                    obj.axisX.moveStageBy(str2double(commandSplit{1,2}));
                case 'mvrxw'
                    obj.axisX.moveStageBy(str2double(commandSplit{1,2}));
                    obj.waitUntilMovementFinishes=true;
                case 'movy'
                    obj.axisY.moveStageTo(str2double(commandSplit{1,2}));
                case 'movyw'
                    obj.axisY.moveStageTo(str2double(commandSplit{1,2}));
                    obj.waitUntilMovementFinishes=true;
                case 'mvry'
                    obj.axisY.moveStageBy(str2double(commandSplit{1,2}));
                case 'mvryw'
                    obj.axisY.moveStageBy(str2double(commandSplit{1,2}));
                    obj.waitUntilMovementFinishes=true;
                case 'movz'
                    obj.axisZ.moveStageTo(str2double(commandSplit{1,2}));
                case 'movzw'
                    obj.axisZ.moveStageTo(str2double(commandSplit{1,2}));
                    obj.waitUntilMovementFinishes=true;
                case 'mvrz'
                    obj.axisZ.moveStageBy(str2double(commandSplit{1,2}));
                case 'mvrzw'
                    obj.axisZ.moveStageBy(str2double(commandSplit{1,2}));
                    obj.waitUntilMovementFinishes=true;
                case 'mvrqd'
                    dx=str2double(commandSplit{1,2});
                    dy=str2double(commandSplit{1,3});
                    dz=str2double(commandSplit{1,4});
                    obj.controller.moveStagesFastAndDirtyBy([dx,dy,dz]);
                case 'vel'
                    vel=str2double(commandSplit{1,2});
                    obj.controller.setVel([vel,vel,vel]);
                case 'velx'
                    obj.axisX.setVel(str2double(commandSplit{1,2}));
                case 'vely'
                    obj.axisY.setVel(str2double(commandSplit{1,2}));
                case 'velz'
                    obj.axisZ.setVel(str2double(commandSplit{1,2}));
                case 'hlt'
                    obj.controller.haltAll();
                otherwise
                    obj.logger.fatal('Unknown command: ',commandSplit{1,1});
            end
            obj.currentCommandId=obj.currentCommandId+1;
        end
        
        function commandSplit=getCommandSplit(~, commandLine)
            commandSplit=regexp(strtrim(commandLine),'\s+','split');
        end
        
        function startWaitTime(obj,time)
            obj.waitStartTime=tic;
            obj.waitTime=time;
        end
    end
end