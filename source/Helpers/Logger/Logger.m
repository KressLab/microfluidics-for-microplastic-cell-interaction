classdef Logger < handle 
    % cat $(ls -Art | tail -n 1) | grep testLogger:
    %LOG4M This is a simple logger based on the idea of the popular log4j.
    %
    % Description: Log4m is designed to be relatively fast and very easy to
    % use. It has been designed to work well in a matlab environment.
    % Please contact me (info below) with any questions or suggestions!
    % 
    %
    % Author: 
    %       Luke Winslow <lawinslow@gmail.com>
    % Heavily modified version of 'Loggeratlab' which can be found here:
    %       http://www.mathworks.com/matlabcentral/fileexchange/33532-log4matlab
    %
    
    properties (Constant)
        ALL = 0;
        TRACE = 1;
        DEBUG = 2;
        INFO = 3;
        WARN = 4;
        ERROR = 5;
        FATAL = 6;
        OFF = 7;
    end
        
    properties(Access = private)
        outputFilePath; %Default file
        logger;
        lFile;
        includeFilterString='';
        excludeFilterString='';
    end
    
    properties(SetAccess = private)
        commandWindowLevel;
        logLevel;
        verbose=1;
    end
    
    methods (Static)
        function obj = getInstance()
            %GETLOGGER Returns instance unique logger object.
            %   PARAMS:
            %       logPath - Relative or absolute path to desired logfile.
            %   OUTPUT:
            %       obj - Reference to signular logger object.
            %
            if(nargin > 0)
                error('getLogger only accepts one parameter input');
            end
            
            persistent localObj;
            if isempty(localObj) || ~isvalid(localObj)
                localObj = Logger();
                localObj.commandWindowLevel=Logger.WARN;
                localObj.logLevel=Logger.OFF;
                localObj.newFile();
            end
            obj = localObj;
        end
    end
    
    
%% Public Methods Section %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods(Access=public)
        function newFile(obj)
            obj.outputFilePath=[datestr(now,'yyyymmddHHMMSS'),'_Matlab.log'];
        end
        
        function setVerbose(obj, verbose)
            obj.verbose=verbose;
        end
        
        function setCommandWindowLevel(obj,logLevel)
            obj.commandWindowLevel = logLevel;
        end
        
        function setLogLevel(obj,level)
            obj.logLevel = level;
        end
        
        function setOutputFilePath(obj, path)
            obj.outputFilePath=path;
        end
        
        function setIncludeFilter(obj,filterString)
            if isempty(filterString)
                filterString='';
            end
            if ~iscell(filterString)
                filterString={filterString};
            end
            obj.includeFilterString=filterString;
        end
        
        function setExcludeFilter(obj,filterString)
            if isempty(filterString)
                filterString='';
            end
            if ~iscell(filterString)
                filterString={filterString};
            end
            obj.excludeFilterString=filterString;
        end
        
        function testSpeed(obj)
            %TESTSPEED Gives a brief idea of the time required to log.
            %
            %   Description: One major concern with logging is the
            %   performance hit an application takes when heavy logging is
            %   introduced. This function does a quick speed test to give
            %   the user an idea of how various types of logging will
            %   perform on their system.
            %
            
            disp('1e5 logs when logging only to command window');
            
            obj.setCommandWindowLevel(Logger.TRACE);
            obj.setLogLevel(Logger.OFF);
            tic;
            for i=1:1e5
                obj.trace('test');
            end
            
            disp('1e5 logs when logging only to command window');
            toc;
            
            disp('1e6 logs when logging is off');
            
            obj.setCommandWindowLevel(Logger.OFF);
            obj.setLogLevel(Logger.OFF);
            tic;
            for i=1:1e6
                obj.trace('test');
            end
            toc;
            
            disp('1e4 logs when logging to file');
            
            obj.setCommandWindowLevel(Logger.OFF);
            obj.setLogLevel(Logger.TRACE);
            tic;
            for i=1:1e4
                obj.trace('test');
            end
            toc;
        end
        

%% The public Logging methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function trace(obj, varargin)
            %TRACE Log a message with the TRACE level
            %
            %   PARAMETERS:
            %       message - Text of message to log.
            % 
            obj.writeLog(obj.TRACE,varargin{:});
        end
        
        function debug(obj, varargin)
            %TRACE Log a message with the DEBUG level
            %
            %   PARAMETERS:
            %       message - Text of message to log.
            % 
            obj.writeLog(obj.DEBUG,varargin{:});
        end
        
 
        function info(obj, varargin)
            %TRACE Log a message with the INFO level
            %
            %   PARAMETERS:
            %       message - Text of message to log.
            % 
            obj.writeLog(obj.INFO,varargin{:});
        end
        

        function warn(obj, varargin)
            %TRACE Log a message with the WARN level
            %
            %   PARAMETERS:
            %       message - Text of message to log.
            % 
            obj.writeLog(obj.WARN,varargin{:});
        end
        

        function error(obj, varargin)
            %TRACE Log a message with the ERROR level
            %
            %   PARAMETERS:
            %       message - Text of message to log.
            % 
            obj.writeLog(obj.ERROR,varargin{:});
        end
        

        function fatal(obj,  varargin)
            %TRACE Log a message with the FATAL level
            %
            %   PARAMETERS:
            %       message - Text of message to log.
            % 
            obj.writeLog(obj.FATAL,varargin{:});
            error('Program terminated. See logs.');
        end
        
    end

%% Private Methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Unless you're modifying this, these should be of little concern to you.
    methods (Access = private)
        
        function obj = Logger()
            obj.setIncludeFilter('');
            obj.setExcludeFilter('');
        end
        
%% WriteToFile        
        function writeLog(obj,level,varargin)
            % set up our level string
            if(obj.logLevel > level && obj.commandWindowLevel > level)
                return;
            end
            
            [ST,~]=dbstack();
            try
                scriptName=[ST(3,1).name,':', num2str(ST(3,1).line)];
            catch
                scriptName='';
            end
            
            message='';
            for i=1:size(varargin,2)
                if isnumeric(varargin{i})
                    if size(varargin{i},1)> size(varargin{i},2)
                        varargin{i}=varargin{i}';
                    end
                    message=[message,num2str(varargin{i})];
                elseif islogical(varargin{i})
                    if varargin{i}
                        message=[message,'true'];
                    else
                        message=[message,'false'];
                    end
                elseif istable(varargin{i})
                    c=table2cell(varargin{i});
                    for j=1:size(c,1)
                        for k=1:size(c,2)
                            if isnumeric(c{j,k})
                                tableEntry=num2str(c{j,k});
                            elseif islogical(c{j,k})
                                if c{j,k}
                                    tableEntry='true';
                                else
                                    tableEntry='false';
                                end
                            elseif iscategorical(c{j,k})
                                tableEntry=char(c{j,k});
                            else
                                tableEntry=c{j,k};
                            end 
                            message=[message,' ',tableEntry];
                        end
                        message=[message,' ',];
                    end
                elseif isa(varargin{i},'MException')
                    obj.writeLogToFile(level,scriptName,['EXCEPTION: ',class(varargin{i}),' Message: ',varargin{i}.message]);
                    obj.writeLogToConsole(level,scriptName,['EXCEPTION: ',class(varargin{i}),' Message: ',varargin{i}.message]);
                    for j=1:size(varargin{i}.stack,1)
                        obj.writeLogToFile(level,scriptName,['CALL STACK ',num2str(j),':',varargin{i}.stack(j).file,': ',varargin{i}.stack(j).name,' (Line ',num2str(varargin{i}.stack(j).line),')']);
                        obj.writeLogToConsole(level,scriptName,['CALL STACK ',obj.getScriptLink(varargin{i}.stack,j)]);
                    end
                elseif isa(varargin{i},'cell')
                    for j=1:length(varargin{i})
                        obj.writeLog(level,j,': ',varargin{i}{j});
                    end
                else
                    message=append(message,varargin{i});
                end
            end
            
            if ~isempty(strtrim(message))
                obj.writeLogToConsole(level,scriptName,message);
                obj.writeLogToFile(level,scriptName,message);
            end
        end
        
        function writeLogToConsole(obj,level,scriptName,message)
            levelStr=obj.levelToString(level);
            [STfull,~]=dbstack('-completenames');
            if obj.commandWindowLevel <= level && (obj.checkFilters(level,[scriptName,levelStr,message]) || obj.commandWindowLevel==Logger.ALL)
                scriptLink=obj.getScriptLink(STfull,4);
                if obj.verbose
                    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS')), ' ', levelStr,' ',scriptLink, ' ',message]);
                else
                    disp(message);
                end
            end
        end
        
        function scriptLink=getScriptLink(obj,stack,depth)
            try
                scriptLink=['<a href="matlab:opentoline(''',stack(depth,1).file ,''',', num2str(stack(depth,1).line),',0)">', stack(depth,1).name,':', num2str(stack(depth,1).line),'</a>'];
            catch
                scriptLink='';
            end

            if ispc
                scriptLink=strrep(scriptLink, '\','\\');
            end
        end
        
        function writeLogToFile(obj,level,scriptName,message)
            levelStr=obj.levelToString(level);
             if obj.logLevel <= level && (obj.checkFilters(level,[scriptName,levelStr,message]) || obj.logLevel==Logger.ALL)
                % Append new log to log file
                try
                    fid = fopen(obj.outputFilePath,'a');
                    if obj.verbose
                        fprintf(fid,'%s %s %s - %s\r\n' ...
                            , char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS')) ...
                            , levelStr ...
                            , scriptName ... % Have left this one with the '.' if it is passed
                            , message);
                    else
                        fprintf(fid,'%s\r\n', message);
                    end
                    fclose(fid);
                catch ME_1
                    display(ME_1);
                end
            end
        end
        
        function doPrint=checkFilters(obj,level,string)
            % always print fatal, warning and error
            doPrint= level>=obj.WARN || (obj.satisfiesIncludeFilter(string) && obj.satisfiesExcludeFilter(string));
        end
        
        function satisfies=satisfiesExcludeFilter(obj, string)
            if strcmp(obj.excludeFilterString{1},'')
                satisfies=true;
                return;
            end
            for j=1:length(obj.excludeFilterString)
                if isempty(obj.excludeFilterString{j}) || contains(string,obj.excludeFilterString{j})
                    satisfies=false;
                    return
                end
            end
            satisfies=true;
            return;
        end
        
        function satisfies=satisfiesIncludeFilter(obj, string)
            if strcmp(obj.includeFilterString{1},'')
                satisfies=true;
                return;
            end
            for j=1:length(obj.includeFilterString)
                if isempty(obj.includeFilterString{j}) || contains(string,obj.includeFilterString{j})
                    satisfies=true;
                    return;
                end
            end
            satisfies=false;
            return;
        end
        
        function levelStr=levelToString(obj, level)
             switch level
                case{obj.ALL}
                    levelStr = 'ALL';
                case{obj.TRACE}
                    levelStr = 'TRACE';
                case{obj.DEBUG}
                    levelStr = 'DEBUG';
                case{obj.INFO}
                    levelStr = 'INFO';
                case{obj.WARN}
                    levelStr = 'WARN';
                case{obj.ERROR}
                    levelStr = 'ERROR';
                case{obj.FATAL}
                    levelStr = 'FATAL';
                case{obj.OFF}
                    levelStr = 'OFF';
                otherwise
                    levelStr = 'UNKNOWN';
            end
        end
        
        function color=levelToColor(obj, level)
             switch level
                case{obj.ALL}
                    error('invalid call');
                case{obj.TRACE}
                    color = [0.1,0.3,0.1];
                case{obj.DEBUG}
                    color = [0.1,0.5,0.1];
                case{obj.INFO}
                    color = [0.1,0.7,0.1];
                case{obj.WARN}
                    color = [0.4,0.4,0.1];
                case{obj.ERROR}
                    color = [0.7,0.1,0.1];
                case{obj.FATAL}
                    color = [1,0.1,0.1];
                case{obj.OFF}
                    error('invalid call');
                otherwise
                    color = 'UNKNOWN';
            end
        end
    end
end
