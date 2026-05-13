classdef MicrofluidicsCalibration<handle
    % Implements the analysis of high speed camera measurements to analyze
    % the flow profile inside a microfluidics channel.
    % Particles are detected and tracked to measure the flow profile.
    properties(Access=public)
        showDebugPlots=false;
        logger Logger = Logger.empty(0);

        % Input variables
        filename (1,:) char;
        frameCount (1,1) double;
        imageSzPx (1,2) double;
        frameTimeS (1,1) double;
        
        % Result fields
        beads;
        trackedBeads;
        velMS; % velocities of all particles during each track
    end
    
    methods(Static,Access=public)
        function [zM,velMS,velAvgMS,velStdErrMS]=getCalibrationSummaryVxOfZ(resultFileNames,zRegex,pixelsizeM,showPlot)
            arguments
                resultFileNames cell % Filenames (incl. path) to result files saved by MicrofluidicsCalibration
                zRegex (1,:) char % Regex to extract the z position from the filename
                pixelsizeM (1,1) double % Size of one pixel in the image, i.e. the total length a particle travels in m when it moves by one pixel.
                showPlot (1,1) logical % Whether or not to show a plot of the velocity profile.
            end
            % This function analyzes many
            if contains(zRegex,'um')
                zUnit=1E-6;
            else
                error('Unit of z not detected.');
            end
            l=Logger.getInstance();
            resultCount=size(resultFileNames,1);
            zM=nan(resultCount,1); % z positions of all files
            velMS=cell(resultCount,1);
            for i=1:resultCount
                load(resultFileNames{i,1});
                zM(i,1)=str2double(cell2mat(regexp(resultFileNames{i,1},zRegex,'match'))).*zUnit;
                [velMS{i,1}]=microfluidicsCalibration.getFlowVelocityMS(pixelsizeM);
            end
            [~,sortIds]=sort(zM,'ascend');
            velMS=velMS(sortIds);
            zM=zM(sortIds);
            [velAvgMS,~,velStdErrMS]=cellfun(@(x)(getStatisticalErrorAnalysis(x)),velMS,'UniformOutput',true);

            if showPlot
                figure(1);
                clf;
                hold on;
                errorbar(velAvgMS,zM,zeros(size(zM)),zeros(size(zM)),velStdErrMS,velStdErrMS,'r+','MarkerSize',10,'LineWidth',2,'DisplayName','Mean \pm stderr');
                zPlot=nan(0,1);
                vPlot=nan(0,1);
                for i=1:size(velMS,1)
                    vPlot=[vPlot;velMS{i,1}];
                    zPlot=[zPlot;zM(i,1).*ones(size(velMS{i,1}))];
                end
                plot(vPlot,zPlot,'k.','DisplayName','Individual particles');
                xlabel('Measured velocity v_x / ms^{-1}');
                ylabel('z / m');
                legend('Location','northeast');
                title({"Result of flow profile analysis","via particle image velocimetry"});
                axis('padded');
                box('on');
            end
        end
    end
    
    methods(Access=public)
        function obj = MicrofluidicsCalibration(mptFilename)
            obj.logger=Logger.getInstance();
            obj.filename=mptFilename;
            iminfo=imfinfo(obj.filename);
            obj.frameCount=size(iminfo,1);
            
            obj.imageSzPx=[iminfo(1).Height,iminfo(2).Width];
            
            % load meta data
            frameRateHz=obj.getFrameRateHz();
            obj.frameTimeS=1./frameRateHz;
            obj.logger.info('File ',obj.filename, ': Frame time=',obj.frameTimeS,'s, rate: ',frameRateHz);
        end

        function enableDebugPlots(obj,show)
            obj.showDebugPlots=show;
        end
        
        function frameRate=getFrameRateHz(obj)
            % This function reads the frame rate of the video from the 
            % high speed camera data. For different data formats, implement this
            % function differently.
            rawFolder=fileparts(obj.filename);
            configFileID=fopen([rawFolder,filesep, '_config.xsv']);
            configFile=textscan(configFileID,'%q%q','Delimiter','=');
            fclose(configFileID);
            frameRate=str2double(configFile{1,2}{strcmp(configFile{1,1},'Rate'),1});
        end
        
        function detectParticles(obj,bandpassLowPx,bandpassHighPx,threshold,minDistPx,scanRadiusPx,fitRegionRadiusPx)
            arguments
                obj;
                bandpassLowPx (1,1) double;
                bandpassHighPx (1,1) double;
                threshold (1,1) double; % in units of the standard deviation of the bandpass filtered image
                minDistPx (1,1) double; % minimum distance between particles.
                scanRadiusPx (1,1) double; % the size of the local region to search for maxima
                fitRegionRadiusPx (1,1) double; % the size of the region used to perform subpixel gaussian peak fitting
            end
            obj.beads=cell(1,obj.frameCount);
            
            if obj.showDebugPlots
                figure(1);
                clf;
                ax1=subplot(1,2,1);
                axis(ax1,'image');
                
                ax2=subplot(1,2,2);
                axis(ax2,'image');
            end
            
            MOVING_MEDIAN_SZ=5;
            movMedFilt=MovingFilter(@(x,dim)(median(x,dim,"omitnan")),'gpuArrayDouble',obj.imageSzPx,MOVING_MEDIAN_SZ);
            for i=1:MOVING_MEDIAN_SZ
                movMedFilt.setNextImage(obj.getPreprocessedImg(i,bandpassLowPx,bandpassHighPx));
            end
            for i=1:obj.frameCount
                movMedFilt.setNextImage(obj.getPreprocessedImg(i+MOVING_MEDIAN_SZ,bandpassLowPx,bandpassHighPx));
                img=movMedFilt.getDiffImage();
                
                img=abs(img-median(img(:)));
                img=imgaussfilt(img,5);
                img=scaleMatToRange(img,0,1);
                img=safeGather(img);
                
                obj.beads{1,i}=pkfndFast(img,median(img(:))+threshold*std(img(:)),minDistPx,scanRadiusPx,max(img(:)));
                obj.beads{1,i}=findMaxPositionWith2DGaussianFit(img,obj.beads{1,i},fitRegionRadiusPx,true,false,0,1E-2);
                if obj.showDebugPlots && mod(i,1)==0
                    cla(ax1);
                    hold(ax1,'on');
                    imagesc(obj.getImage(i),'Parent',ax1);
                    plot(ax1,obj.beads{1,i}(:,1),obj.beads{1,i}(:,2),'g+');
                    colormap(ax1,gray);
                    title(['Original frame ',num2str(i),'/',num2str(obj.frameCount)]);
                    
                    cla(ax2);
                    hold(ax2,'on');
                    imagesc(img,'Parent',ax2);
                    axis(ax2,'image');
                    plot(ax2,obj.beads{1,i}(:,1),obj.beads{1,i}(:,2),'g+');
                    colormap(ax2,gray);
                    title(['Preprocessed frame ',num2str(i),'/',num2str(obj.frameCount)]);
                    drawnow;
                end
            end
        end
        
        function trackBeads(obj,maxDispPx,mem,minTrackLength)
            arguments
                obj;
                maxDispPx (1,1) double;
                mem (1,1) double = 0; % dont remember particles by default
                minTrackLength (1,1) double = 1; % minimum length of each track
            end
            cgt=CrockerGrierTracker();
            cgt.setSettings(maxDispPx,mem,minTrackLength);
            for i=1:obj.frameCount
                cgt.setPositionsInNewFrame(obj.beads{1,i});
            end
            obj.trackedBeads=cgt.getOutputXYZTI();
            
            if obj.showDebugPlots
                figure(1);
                clf;
                ax=axes();
                axis(ax,'image');
                for i=1:obj.frameCount
                    cla(ax);
                    hold(ax,'on');
                    
                    img=obj.getImage(i);
                    imagesc(img,'Parent',ax);
                    colormap(ax,gray);
                    
                    beadsInFrame=obj.trackedBeads(obj.trackedBeads(:,3)==i,:);
                
                    
                    plot(beadsInFrame(:,1),beadsInFrame(:,2),'g+');
                    title(['detecting particles frame',num2str(i),'/',num2str(obj.frameCount)]);
                    drawnow;
                end
            end
        end
        
        function velMS=getFlowVelocityMS(obj,pixelsizeM)
            arguments
                obj;
                pixelsizeM (1,1) double; % the pixelsize of the camera in meters
            end
            % Returns the averaged flow velocity in the frame as well as
            % the standard deviation of the particle velocities in the
            % frame.
            beadCount=size(unique(obj.trackedBeads(:,4)),1);
            velPixPerFrame=nan(beadCount,1);
            for beadId=unique(obj.trackedBeads(:,4))'
                beadXYT=obj.trackedBeads(obj.trackedBeads(:,4)==beadId,1:3);
                firstFrame=min(beadXYT(:,3));
                lastFrame=max(beadXYT(:,3));
                
                dxdyPx=beadXYT(beadXYT(:,3)==lastFrame,1:2)-beadXYT(beadXYT(:,3)==firstFrame,1:2);
                drPx=sqrt(sum(dxdyPx.^2));
                dtFrames=lastFrame-firstFrame;
                
                velPixPerFrame(beadId,1)=drPx/dtFrames;
            end
            velMS=velPixPerFrame.*pixelsizeM./obj.frameTimeS;
        end
        
        function img=getImage(obj,i)
            % Reads images from multipage tiff
            img=uint16(imread(obj.filename,i));
        end
        
        function img=getPreprocessedImg(obj,i,bandpassLowPx,bandpassHighPx)
            arguments
                obj
                i (1,1) double % frame index in video
                bandpassLowPx (1,1) double;
                bandpassHighPx (1,1) double;
            end
            % Returns a properly formatted image of the correct datatype.
            if i<1 || i>obj.frameCount
                img=nan(obj.imageSzPx);
            else
                img=obj.getImage(i);
            end
            % 
            img=safeGpuArray(img);
            img=fastBPass(img,bandpassLowPx,bandpassHighPx,-inf);
        end
        
        function saveResults(obj)
            % Saves the results for
            % MicrofluidicsCalibration.getCalibrationSummaryVxOfZ(...) or
            % other analysis.
            microfluidicsCalibration=obj;
            saveFilename=[fileparts(obj.filename),filesep,'results.mat'];
            save(saveFilename,'microfluidicsCalibration');
        end
    end
end

