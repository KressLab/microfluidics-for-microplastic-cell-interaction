% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.18
% ########################
% 
% #########################################################################
% DO NOT ADD FUNCTIONALITY TO THIS CLASS (E.G. FURTHER HARDWARE SUPPORT)
% BY MODIFYING THIS CLASS! USE THE MODULE INTERFACE INSTEAD!
% 
% To add logic to CCTLCore, write a CCTLModule
% To add panels to the viewer, write a CCTLControlPanel which you add to
% the viewer with the module interface (e.g. see PIMtControlModule3D)
% Modules are added in the CCTrackingLive script before runtime.
% #########################################################################
classdef CCTLCore <handle
    properties
        logger=Logger.getInstance();	
        
        % core functionality
        cctliveViewer;
        camera;
        
        % for extensions
        modules;
        branch;
        revisionString;
        commitDate;
        
        % save filenames
        tiffFilename;
        tiffId;
        matFilename;
    end
    
    methods (Access=public)
        function obj=CCTLCore()
            obj.modules=cell(0);
            try
                [~, branchOutput] = system(['TERM=ansi git -C "', ...
                                                        char(currentProject().RootFolder), ...
                                                        '" rev-parse --abbrev-ref HEAD']);
                obj.branch = strtrim(branchOutput);

                [~, obj.revisionString] = system(['TERM=ansi git -C "', ...
                                                        char(currentProject().RootFolder), ...
                                                        '" describe --long --dirty --abbrev=10 --tags --always']);
                obj.revisionString = strtrim(obj.revisionString);

                [~, raw] = system(['TERM=ansi git -C "', ...
                                               char(currentProject().RootFolder), ...
                                               '" log -1 --format="%cd"']);
                obj.commitDate = strtrim(regexprep(raw, '.*?(\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4} \+\d{4}).*', '$1'));

                obj.logger.info('Loading version ',obj.revisionString,' (branch: ', obj.branch,') dated ',obj.commitDate);
            catch
                obj.branch='Unrecognized version. GIT command line client is not installed on the system.';
                obj.logger.warn(obj.branch);
            end
        end
        
        function setCamera(obj, camera)
            obj.logger.debug('Setting camera to ', class(camera));
            obj.camera=camera;
        end
        
        function loadAndInit(obj)
            obj.logger.debug('Loading.');
            obj.cctliveViewer=CCTLViewer();
            obj.cctliveViewer.setCamera(obj.camera);
            obj.loadCCTLModules();
            
            obj.logger.debug('Initializing.');
            obj.initViewer();
            obj.initCCTLModules();
            
            obj.resetRoi();
        end
        
        function initViewer(obj)
            obj.cctliveViewer.init();
            obj.cctliveViewer.setLiveCallback(@obj.live);
            obj.cctliveViewer.setRunCallback(@obj.run);
            obj.cctliveViewer.setLoadSettingsCallback(@obj.loadSettings);
            obj.cctliveViewer.setSaveSettingsCallback(@obj.saveSettings);
            
            obj.cctliveViewer.setUiCallback('Set ROI', @obj.setRoi);
            obj.cctliveViewer.setUiCallback('Reset ROI', @obj.resetRoi);
            obj.cctliveViewer.setUiCallback('Pixelsize/um',@obj.setPixelSize);
            obj.cctliveViewer.setUiCallback('ShowHistogram',@obj.showHistogram);
            
            obj.cctliveViewer.setString('GITRevision',append(obj.revisionString,' (',obj.branch,')'));
            obj.cctliveViewer.setString('GITCommitDate',obj.commitDate);
            
            obj.cctliveViewer.setString('CameraClass',class(obj.camera));
        end
        
        function onImageDimensionChange(obj)
            for i=1:size(obj.modules,1)
                 obj.modules{i,1}.onImageDimensionChange();
            end
            obj.renderCCTLModulesLive();
        end
        
        function setPixelSize(obj,~,~)
            obj.onImageDimensionChange();
        end
        
        function setRoi(obj, ~,~)
            obj.setCameraBinning();
            obj.cctliveViewer.setEnableInput('off');
            try
                obj.camera.selectRoi(obj.cctliveViewer.getControlAxesMain());
            catch
                obj.logger.info('Invalid ROI');
            end
            obj.cctliveViewer.setEnableInput('on');
            obj.cctliveViewer.showImage(obj.camera.getSingleImage());
            obj.onImageDimensionChange();
        end
        
        function resetRoi(obj,~,~)
            obj.cctliveViewer.setEnableInput('off');
            obj.setCameraBinning();
            obj.camera.resetRoi();
            
            obj.cctliveViewer.setEnableInput('on');
            obj.cctliveViewer.showImage(obj.camera.getSingleImage());
            obj.onImageDimensionChange();
        end
        
        function updateLive(obj)
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.onUpdateLive();
            end
            currentImage=obj.camera.getImage();
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.updateLive();
            end
            [grayRangeMin,grayRangeMax]=obj.camera.getGrayRange();
            
            obj.cctliveViewer.showImage(currentImage);
            obj.cctliveViewer.setFrameInfo(obj.camera.getNumImages(),obj.camera.getLastDataTime());
            try
                obj.cctliveViewer.showImageHistogram(currentImage, grayRangeMin, grayRangeMax+1);
            catch e
                obj.logger.warn('Figure 2 Error',e);
            end
            obj.renderCCTLModulesLive();
            drawnow;
        end
        
        function live(obj,~,~)
            try
                if obj.cctliveViewer.btnLiveDown()
                    obj.setCameraBinning();
                    obj.camera.setExposureTime(obj.cctliveViewer.getNumValue('ExposureTime/s'));
                    obj.camera.setFrameCount(Inf);
                    obj.camera.enableDataStorage(false);
                    obj.camera.restart();
                    for i=1:size(obj.modules,1)
                        obj.modules{i,1}.onStartLive();
                    end
                    obj.cctliveViewer.setLive(true);
                    
                    for i=1:size(obj.modules,1)
                        obj.modules{i,1}.startLive();
                    end

                    startTime=tic;
                    lastTime=toc(startTime);
                    cummulTime=0;
                    
                    framesCaptured=0;
                    while true
                        frameTime=obj.cctliveViewer.getNumValue('FrameTime/s');
                        framesCaptured=framesCaptured+1;
                        
                        obj.updateLive();
                        if ~obj.cctliveViewer.btnLiveDown()
                             break;
                        end
                        
                        % time loop update
                        currentTime=toc(startTime);
                        timeTaken=currentTime-lastTime;
                        cummulTime=cummulTime+frameTime-timeTaken;
                        
                        lastTime=currentTime;
                        
                        if(cummulTime>0)
                            java.lang.Thread.sleep(cummulTime*1000); % in ms
                            obj.cctliveViewer.doAction('setFrameTimeWarning',0);
                        else
                            obj.cctliveViewer.doAction('setFrameTimeWarning',1);
                        end
                    end
                    obj.camera.stop();
                    for i=1:size(obj.modules,1)
                        obj.modules{i,1}.stopLive();
                    end
                    obj.cctliveViewer.setLive(false);
                end
            catch e
                obj.logger.error('Error occured during live mode.',e);
                obj.camera.stop();
                for i=1:size(obj.modules,1)
                    obj.modules{i,1}.stopLive();
                end
                obj.cctliveViewer.setLive(false);
            end
            obj.cctliveViewer.doAction('setFrameTimeWarning',0);
        end
        
        function updateRun(obj)
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.onUpdateRun();
            end
            currentImage=obj.camera.getImage();
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.updateRun();
            end
            [grayRangeMin,grayRangeMax]=obj.camera.getGrayRange();
            if obj.cctliveViewer.getNumValue('UpdateImageInRunMode')
                obj.cctliveViewer.showImage(currentImage)
            end
            obj.cctliveViewer.setFrameInfo(obj.camera.getNumImages(),obj.camera.getLastDataTime());
            try
                obj.cctliveViewer.showImageHistogram(currentImage, grayRangeMin, grayRangeMax);
            catch e
                obj.logger.warn('Figure 2 has been closed',e);
            end
            if obj.cctliveViewer.getNumValue('Save Data') &&  ...
                obj.cctliveViewer.getNumValue('SaveImages') &&  ...
                obj.cctliveViewer.getNumValue('SaveImagesDirectlyToDrive') && ...
                ~isa(obj.camera,'FileCamera') && ...
                ~isa(obj.camera,'VoidCamera')
                try
                    imwrite(currentImage, obj.tiffFilename,'tif', 'writemode', 'append', 'compression', 'none');
                catch e
                    try
                        obj.tiffId=obj.tiffId+1;
                        obj.setFilenames();
                        imwrite(currentImage, obj.tiffFilename,'tif', 'writemode', 'append', 'compression', 'none');
                    catch
                        rethrow(e)
                    end
                end
            end
            obj.renderCCTLModulesRun();
            % makes sure the gui is properly updated and that the run
            % button can be clicked again
            drawnow;
        end
        
        function saveMeasurement(obj)
            if(obj.cctliveViewer.getNumValue('Save Data'))
                if ~obj.cctliveViewer.getNumValue('Overwrite') && exist(obj.matFilename,'file')
                    obj.logger.fatal('Mat filename ',obj.matFilename,' already exists. Choose another filename.');
                end 
                if ~obj.cctliveViewer.getNumValue('Overwrite') && exist(obj.tiffFilename,'file') && ~obj.cctliveViewer.getNumValue('SaveImagesDirectlyToDrive')
                    obj.logger.fatal('Tiff filename ',obj.tiffFilename,' already exists. Choose another filename.');
                end
                obj.logger.debug('Start exporting data to ', obj.matFilename);
                if ~exist(fileparts(obj.matFilename))
                    mkdir(fileparts(obj.matFilename));
                end
                if exist(obj.matFilename, 'file') && obj.cctliveViewer.getNumValue('Overwrite')
                    delete(obj.matFilename);
                end
                if exist(obj.tiffFilename, 'file') && obj.cctliveViewer.getNumValue('Overwrite') && ~obj.cctliveViewer.getNumValue('SaveImagesDirectlyToDrive')
                    delete(obj.tiffFilename);
                end
                cctlResult.info=obj.getInfo();
                cctlResult.cameraSettings=obj.getCameraSettings();
                cctlResult.timesS=obj.camera.getDataTimes();
                cctlResult.settings=obj.getSettings();
                
                for i=1:size(obj.modules,1)
                    try
                        cctlResult=obj.modules{i,1}.appendToSave(cctlResult);
                    catch e
                        obj.logger.error('Appending save data from module ', class(obj.modules{i,1}), ' failed. Expect missing data.',e);
                    end
                end
                save(obj.matFilename, 'cctlResult');
                obj.logger.debug('Exporting data to ', obj.matFilename, ' finished.');
                if ~isa(obj.camera,'FileCamera') && ...
                   ~isa(obj.camera,'VoidCamera') && ...
                   obj.cctliveViewer.getNumValue('SaveImages') && ...
                   ~obj.cctliveViewer.getNumValue('SaveImagesDirectlyToDrive')
                    try
                        obj.logger.debug('Start exporting images to ', obj.tiffFilename);
                        data=obj.camera.getData();
                        
                        for i=1:size(data,4)
                            try
                                imwrite(data(:,:,1,i), obj.tiffFilename,'tif', 'writemode', 'append', 'compression', 'none');
                            catch e
                                try
                                    obj.tiffId=obj.tiffId+1;
                                    obj.setFilenames();
                                    imwrite(data(:,:,1,i), obj.tiffFilename,'tif', 'writemode', 'append', 'compression', 'none');
                                catch
                                    rethrow(e)
                                end
                            end
                        end
                        obj.logger.debug('Exporting images to ', obj.tiffFilename, ' finished.');
                    catch e
                        obj.logger.error('An error occured when saving tiff. Failed to write tiff but saved .mat.',e);
                    end
                end
            end
        end
        
        function info=getInfo(obj)
            info.date=datestr(datetime('now'));
            info.camera=class(obj.camera);
            info.programVersion=obj.branch;
        end
        
        function camSet=getCameraSettings(obj)
            camSet.class=class(obj.camera);
            camSet.exposureTime=obj.cctliveViewer.getNumValue('ExposureTime/s');
            camSet.binning=obj.cctliveViewer.getNumValue('Binning (X*X)/(px*px)');
            camSet.pixelSizeUm=obj.cctliveViewer.getNumValue('Pixelsize/um');
            if isa(obj.camera,'FileCamera')
                camSet.firstFrame=obj.camera.getStartFrame();
                camSet.inputFilename=obj.camera.inputFilename;
            end
        end
        
        function startRun(obj)
            % camera first because tracker needs the image
            obj.setCameraBinning();
            obj.camera.setExposureTime(obj.cctliveViewer.getNumValue('ExposureTime/s'));
            obj.camera.setFrameCount(Inf);
            obj.camera.enableDataStorage(obj.cctliveViewer.getNumValue('SaveImagesDirectlyToDrive')==0);
            obj.camera.restart();
            
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.onStartRun();
            end
            obj.cctliveViewer.setRunning(true);
            
            currentImage=obj.camera.getImage();
            obj.cctliveViewer.showImage(currentImage);
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.startRun();
            end
            if (~obj.cctliveViewer.getNumValue('Overwrite') && obj.cctliveViewer.getNumValue('Save Data')) && exist(obj.tiffFilename,'file')
                obj.logger.fatal('Tiff file already exists. Choose another filename.');
            else
                if obj.cctliveViewer.getNumValue('SaveImages') &&  ...
                   obj.cctliveViewer.getNumValue('SaveImagesDirectlyToDrive') && ...
                   ~isa(obj.camera,'FileCamera') && ...
                   ~isa(obj.camera,'VoidCamera')
                        if exist(obj.tiffFilename,'file')
                            delete(obj.tiffFilename);
                        end
                        imwrite(currentImage, obj.tiffFilename,'tif', 'writemode', 'append', 'compression', 'none');
                end
            end
            obj.renderCCTLModulesRun();
        end
        
        function setCameraBinning(obj)
            newBinning=obj.cctliveViewer.getNumValue('Binning (X*X)/(px*px)');
            if obj.camera.getBinning~=newBinning
                obj.camera.setBinning(newBinning);
                obj.cctliveViewer.showImage(obj.camera.getSingleImage());
                obj.onImageDimensionChange();
            end
        end
        
        function stopRun(obj)
            obj.saveMeasurement();
            obj.camera.stop();
            obj.cctliveViewer.setRunning(false);
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.stopRun();
            end
        end
        
        function setFilenames(obj)
            filename=obj.cctliveViewer.doAction('getSavePath');
            obj.matFilename=[filename,'.mat'];
            if obj.tiffId==1
                obj.tiffFilename=[filename,'.tif'];
            else
                obj.tiffFilename=[filename,'_',num2str(obj.tiffId),'.tif'];
            end
        end
        
        function run(obj, ~, ~)
                %only run when button is pushed down
                %do not run when button is released
                obj.tiffId=1;
                obj.setFilenames();
                if (~obj.cctliveViewer.getNumValue('Overwrite') && obj.cctliveViewer.getNumValue('Save Data')) && (exist(obj.matFilename,'file')||exist(obj.tiffFilename,'file'))
                    obj.logger.error('One or more of the output files already exist. Choose another filename.');
                    obj.cctliveViewer.setBtnRunDown(0);
                elseif obj.cctliveViewer.btnRunDown()
                    try
                        obj.startRun();
                        
                        startTime=tic;
                        lastTime=toc(startTime);
                        cummulTime=0;
                        framesCaptured=0;
                        
                        while true
                            frameTime=obj.cctliveViewer.getNumValue('FrameTime/s');
                            framesCaptured=framesCaptured+1;
                            if(framesCaptured>=obj.cctliveViewer.getNumValue('NumberOfFrames') || ~obj.cctliveViewer.btnRunDown())
                                break;
                            end
                            obj.updateRun();
                            
                            % time loop update
                            currentTime=toc(startTime);
                            timeTaken=currentTime-lastTime;
                            cummulTime=cummulTime+frameTime-timeTaken;
                            lastTime=currentTime;
                            
                            if(cummulTime>0)
                                % wait for the rest of the time available
                                java.lang.Thread.sleep(cummulTime*1000); % in ms
                                obj.cctliveViewer.doAction('setFrameTimeWarning',0);
                            else
                                % frame took too long
                                obj.cctliveViewer.doAction('setFrameTimeWarning',1);
                            end
                        end
                        obj.stopRun();
                    catch e
                        obj.logger.warn('Trying to save your measurement. Check your files! Good luck.',e);
                        obj.stopRun();
                    end
                end
            
            obj.cctliveViewer.doAction('setFrameTimeWarning',0);
        end
        
        function showHistogram(obj,~,~)
            if ~obj.cctliveViewer.getNumValue('ShowHistogram')
                obj.cctliveViewer.closeHistogram();
            end
        end
        
        function addCCTLModule(obj, module)
            obj.modules{end+1,1}=module;
        end
        
        function initCCTLModules(obj)
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.init();
            end
        end
        
        function loadCCTLModules(obj)
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.setViewer(obj.cctliveViewer);
                obj.modules{i,1}.setCamera(obj.camera);
                obj.modules{i,1}.load();
            end
        end
        
        function renderCCTLModulesLive(obj)
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.onRenderLive();
            end
            for i=1:size(obj.modules,1)
                obj.cctliveViewer.renderModulesLive();
            end
        end
        
        function renderCCTLModulesRun(obj)
            for i=1:size(obj.modules,1)
                obj.modules{i,1}.onRenderRun();
            end
            for i=1:size(obj.modules,1)
                obj.cctliveViewer.renderModulesRun();
            end
        end
        
        function settings=getSettings(obj)
            allKeys=obj.cctliveViewer.getAllRestoreTags();
            settings=struct;
            settings.keys=allKeys;
            
            values=cell(size(settings.keys));
            strings=cell(size(settings.keys));
            
            for i=1:size(settings.keys,1)
                values{i,1}=obj.cctliveViewer.getValue(settings.keys{i,1});
                strings{i,1}=obj.cctliveViewer.getString(settings.keys{i,1});
%                 obj.logger.trace('Setting: ',settings.keys{i,1},': Value: ',values{i,1},' String: ',strings{i,1});
            end
            
            settings.values=containers.Map(settings.keys,values);
            settings.strings=containers.Map(settings.keys,strings);
        end
        
        function setSettings(obj,settings)
            currentSettings=obj.getSettings();
            currentKeys=currentSettings.keys;
            
            % settings that existed when the settings were saved
            stillExists=ismember(settings.keys,currentKeys);
            for key=settings.keys(~stillExists,1)'
                if size(key,1)>0
                    obj.logger.warn('Key could not be restored since it is not part of the current configuration: ',key{1,1});
                end
            end
            
            didNotExist=~ismember(currentKeys,settings.keys);
            for key=currentKeys(didNotExist,1)'
                if size(key,1)>0
                    obj.logger.warn('Key is not present in the loaded settings and thus not set: ',key{1,1});
                end
            end
            
            % Execute twice, once with and once without calling cb funs
            % because settings might be valid, however, intermediate
            % configurations might be invalid. This is a workaround, not a
            % fix.
            for key=settings.keys(stillExists)'
                obj.cctliveViewer.setValue(key{1,1},settings.values(key{1,1}),false);
                if ~strcmp(get(obj.cctliveViewer.getUiControl(key{1,1}),'Style'),'popupmenu')
                    obj.cctliveViewer.setString(key{1,1},settings.strings(key{1,1}),false);
                else
                    disp('bla')
                end
            end
            
            for key=settings.keys(stillExists)'
                obj.cctliveViewer.setValue(key{1,1},settings.values(key{1,1}),true);
                if ~strcmp(get(obj.cctliveViewer.getUiControl(key{1,1}),'Style'),'popupmenu')
                    obj.cctliveViewer.setString(key{1,1},settings.strings(key{1,1}),false);
                end
            end
            
            if sum(~stillExists)>0 || sum(didNotExist)>0
                obj.logger.error('Settings were not properly restored. Maybe the settings file ',...
                                 'is deprecated or was saved with another CCTL configuration?');
            end
            obj.logger.info('Settings loaded.');
        end
        
        function saveSettings(obj,~,~)
            settings=obj.getSettings();
            [file,path]=uiputfile('*.mset');
            if ~isnumeric(file)
                filename=[path,file];
                save(filename,'settings');
                obj.logger.info('Settings saved to file ',filename,'.');
            end
        end
        
        function loadSettings(obj,~,~)
            [file,path]=uigetfile({'*','All files'});
            obj.loadSettingsFromFile([path,file]);
        end
        
        function loadSettingsFromFile(obj, pathToFile)
            if isnumeric(pathToFile) && all(pathToFile==0)
                return;
            end
            try
                variableInfo = who('-file', pathToFile);
                if ismember('cctlResult', variableInfo)
                    load(pathToFile,'cctlResult');
                    obj.setSettings(cctlResult.settings);
                elseif ismember('settings', variableInfo)
                    load(pathToFile,'-mat','settings');
                    obj.setSettings(settings);
                else
                    obj.logger.error('File ',pathToFile,' is not a valid settings file and could not be loaded.');
                end
                obj.logger.info('Settings loaded from file ',pathToFile,'.');
            catch e
                obj.logger.error('Settings could not be loaded from file ',pathToFile,'.', e);
            end
        end
    end
end
