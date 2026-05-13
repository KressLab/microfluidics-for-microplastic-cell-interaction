%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Evaluation of the classified microfluidics Results  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SW 20.02.20

classdef mfResults < handle

    properties(GetAccess=public,SetAccess=private)
        cctlResult;
        numberOfFrames;
        timesS;
        pixelSize;
        flowRate;
        force;
        beadCategories;
        beadCategoriesManually;
        tiffFilename;
        beadpositions;
        averageInterval;
    end

    methods(Access=public)

        function obj=mfResults(cctlResult,averageInterval,tiffFilename)
            obj.cctlResult = cctlResult;
            obj.beadpositions = cctlResult.evaluation.beads.positions;
            obj.numberOfFrames=length(cctlResult.timesS);
            obj.timesS=cctlResult.timesS;
            obj.pixelSize=cctlResult.cameraSettings.pixelSizeUm*cctlResult.cameraSettings.binning;
            obj.flowRate=abs(cctlResult.microfluidics.flowRateM3S);
            obj.force=abs(cctlResult.microfluidics.dragForceSimLehmanXN);
            obj.beadCategories = cctlResult.evaluation.beads.categories;
            obj.beadCategoriesManually = cell(obj.numberOfFrames,1);
            obj.tiffFilename = tiffFilename;
            obj.averageInterval = averageInterval;
        end

        function [classificationSuccess]=tryClassificationSucces(obj)
            if length(obj.timesS) ~= length(obj.beadCategories)
                %warning('Classification unsuccesful');
                classificationSuccess = 0;
            else
                classificationSuccess = 1;
            end
        end

        function [measurementLongEnough]=tryMeasurementLongEnough(obj,timepointAfterFlush)
            timepoint = timepointAfterFlush+obj.timesS(obj.getStartFrameFlush());
            frameAtTimepoint = obj.convertTimepointToFrame(timepoint);
            if length(obj.timesS) > frameAtTimepoint+round(obj.averageInterval/2)
                measurementLongEnough = 1;
            else
                measurementLongEnough = 0;
                %warning('Measuremement not long enough to evaluate at desired time');
            end
        end


        %Get Startframes
        function [startframe]=getStartFrameFlush(obj)
            flushFrames = find(obj.flowRate~=9e-9 & obj.flowRate~=0);
            startframeSedimentation = obj.getStartFrameSedimentation();
            startframe = min(flushFrames(flushFrames>startframeSedimentation));
        end

        function [startframe]=getStartFrameSedimentation(obj)
            startframe = find(obj.flowRate==9e-9,1,'last')+1;
        end


        %Get numbers attached
        function [rnaf,errna]=getRelNumberAttachedAtTimepointAfterFlush(obj,timepointAfterFlush)
            timepoint = timepointAfterFlush+obj.timesS(obj.getStartFrameFlush());
            [rnaf,errna] = obj.getRelNumberAttachedAtTimepoint(timepoint);
        end

        function [rna,errna]=getRelNumberAttachedAtTimepoint(obj,timepoint)
            frame = obj.convertTimepointToFrame(timepoint);
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = obj.getNumberAttachedAtFrame(frame-(i-round(obj.averageInterval/2))); %frames im Radius -av./2 bis + av./2 um Timepoint
            end
            [AttAfterSed,ErrAttAfterSed] = obj.getNumberAttachedAfterSedimentation();
            rna=(mean(numbers))/(AttAfterSed);
            errna = sqrt((std(numbers)/AttAfterSed)^2+(ErrAttAfterSed*mean(numbers)/AttAfterSed^2)^2);
        end

        function [naf,ernaf]=getNumberAttachedAtTimepointAfterFlush(obj,timepointAfterFlush)
            timepoint = timepointAfterFlush+obj.timesS(obj.getStartFrameFlush());
            frame = obj.convertTimepointToFrame(timepoint);
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = obj.getNumberAttachedAtFrame(frame-(i-round(obj.averageInterval/2))); %frames im Radius -av./2 bis + av./2 um Timepoint
            end
            naf = mean(numbers);
            ernaf = std(numbers);
        end

        function [nat]=getNumberAttachedAtTimepoint(obj,timepoint)
            frame = obj.convertTimepointToFrame(timepoint);
            nat = obj.getNumberAttachedAtFrame(frame);
        end

        function [naf]=getNumberAttachedAtFrame(obj,frame)
            categories=obj.beadCategories(frame);
            naf = sum(categories{1,1}=='touching');
        end


        %Get numbers not attached
        function [rnnaf,errnna]=getRelNumberNotAttachedAtTimepointAfterFlush(obj,timepointAfterFlush)
            timepoint = timepointAfterFlush+obj.timesS(obj.getStartFrameFlush());
            [rnnaf,errnna] = obj.getRelNumberNotAttachedAtTimepoint(timepoint);
        end

        function [rnna,errnna]=getRelNumberNotAttachedAtTimepoint(obj,timepoint)
            frame = obj.convertTimepointToFrame(timepoint);
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = obj.getNumberNotAttachedAtFrame(frame-(i-round(obj.averageInterval/2))); %frames im Radius -av./2 bis + av./2 um Timepoint
            end
            [NattAfterSed,ErrNattAfterSed] = obj.getNumberNotAttachedAfterSedimentation();
            rnna=(mean(numbers))/(NattAfterSed);
            errnna = sqrt((std(numbers)/NattAfterSed)^2+(ErrNattAfterSed*mean(numbers)/NattAfterSed^2)^2);
        end

        function [nnaf,ernnaf]=getNumberNotAttachedAtTimepointAfterFlush(obj,timepointAfterFlush)
            timepoint = timepointAfterFlush+obj.timesS(obj.getStartFrameFlush());
            frame = obj.convertTimepointToFrame(timepoint);
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = obj.getNumberNotAttachedAtFrame(frame-(i-round(obj.averageInterval/2))); %frames im Radius -av./2 bis + av./2 um Timepoint
            end
            nnaf = mean(numbers);
            ernnaf = std(numbers);
        end

        function [nnat]=getNumberNotAttachedAtTimepoint(obj,timepoint)
            frame = obj.convertTimepointToFrame(timepoint);
            nnat = obj.getNumberNotAttachedAtFrame(frame);
        end

        function [nnaf]=getNumberNotAttachedAtFrame(obj,frame)
            categories=obj.beadCategories(frame);
            nnaf = sum(categories{1,1}=='notTouching');
        end

        %Get total number of Beads in a timepoint after flush
        function [n,ern] = getTotalNumberAtTimepointAfterFlush(obj,timepointAfterFlush)
            timepoint = timepointAfterFlush+obj.timesS(obj.getStartFrameFlush());
            frame = obj.convertTimepointToFrame(timepoint);
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = length(obj.beadCategories{frame-(i-round(obj.averageInterval/2))}); %frames im Radius -av./2 bis + av./2 um Timepoint
            end
            n = mean(numbers);
            ern = std(numbers);
        end

        %Numbers before adn after sedimentation
        function [nas]=getNumberAttachedBeforeSedimentation(obj)
            frame = obj.getStartFrameSedimentation-1;
            nas = obj.getNumberAttachedAtFrame(frame);
        end

        function [nas]=getNumberNotAttachedBeforeSedimentation(obj)
            frame = obj.getStartFrameSedimentation-1;
            nas = obj.getNumberNotAttachedAtFrame(frame);
        end

        function [nas,ernas]=getNumberAttachedAfterSedimentation(obj)
            frames = obj.getStartFrameFlush()-obj.averageInterval-1:obj.getStartFrameFlush()-1;
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = obj.getNumberAttachedAtFrame(frames(i));
            end
            nas = mean(numbers);
            ernas = std(numbers);
        end

        function [nnas,ernnas]=getNumberNotAttachedAfterSedimentation(obj)
            frames = obj.getStartFrameFlush()-obj.averageInterval-1:obj.getStartFrameFlush()-1;
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = obj.getNumberNotAttachedAtFrame(frames(i));
            end
            nnas = mean(numbers);
            ernnas = std(numbers);
        end

        function [ns,erns]=getTotalNumberAfterSedimentation(obj)
            frames = obj.getStartFrameFlush()-obj.averageInterval-1:obj.getStartFrameFlush()-1;
            numbers = ones(obj.averageInterval,1);
            for i=1:obj.averageInterval
                numbers(i) = length(obj.beadCategories{frames(i)});
            end
            ns = mean(numbers);
            erns = std(numbers);
        end

        



        %Convert Timepoint to frame
        function [frame]=convertTimepointToFrame(obj,timepoint)
            differences = abs(obj.timesS-timepoint);
            frame = find(differences==min(differences));
        end




        %Classify Frames Manually
        function classifyMeasurementManually(obj,cropradius)
            for i = 1:obj.numberOfFrames
                obj.classifyFrameManually(i,cropradius)
            end
            obj.saveClassifiedMeasurement();
            disp('Measurement Calssified & Saved')
        end

        function [cats] = classifyFrameManually(obj,frameno,cropradius)
            frame = imread(obj.tiffFilename,frameno);
            beadpositionsFrame=obj.beadpositions{frameno};
            manualCategories=categorical();

            fig=figure('KeyPressFcn',@keypressfctClassification,'Position',[500 300 695 635]);
            %title(obj.tiffFilename);
            imAxes=axes('Units','normal','Position',[.05, .2, .6, .6]);
            hold on;

            imRightPanel = uipanel('Position',[0.70 0.05 0.23 0.90]);
            pTitle = uicontrol('Parent',imRightPanel,'Style','text','String','Press:','Units','normalized','Position',[0.05 0.85 0.9 0.1],'FontWeight','bold','HorizontalAlignment','left');
            pTouch = uicontrol('Parent',imRightPanel,'Style','text','String','"1" to classify as TOUCHING','Units','normalized','Position',[0.05 0.65 0.9 0.2],'HorizontalAlignment','left');
            pNotTouch = uicontrol('Parent',imRightPanel,'Style','text','String','"2" to classify as NOT TOUCHING','Units','normalized','Position',[0.05 0.45 0.9 0.2],'HorizontalAlignment','left');
            pGoback = uicontrol('Parent',imRightPanel,'Style','text','String','"C" to go back one frame','Units','normalized','Position',[0.05 0.25 0.9 0.2],'HorizontalAlignment','left');
            pExit = uicontrol('Parent',imRightPanel,'String','Abort','Units','normalized','Position',[0.05 0.05 0.9 0.1],'Callback',@buttonpressfctExitClassification);
            abortFlag = 0;
            hold on;

            imTopPanel = uipanel('Position',[0.05 0.85 0.6 0.1]);
            pTopTitle = uicontrol('Parent',imTopPanel,'Style','text','String',obj.tiffFilename,'Units','normalized','Position',[0.05 0.05 0.9 0.9],'FontWeight','bold','HorizontalAlignment','left');
            hold on;

            i=1;
            while i < length(beadpositionsFrame)+1
                keypressed = 0;
                if beadpositionsFrame(i,1)<cropradius+1 || beadpositionsFrame(i,1)>696-cropradius+1 || beadpositionsFrame(i,2)<cropradius+1 || beadpositionsFrame(i,2)>520-cropradius+1
                    manualCategories(i,1)='invalid';
                    keypressed=1;
                else
                    frameCropped = imcrop(frame,[beadpositionsFrame(i,1)-cropradius beadpositionsFrame(i,2)-cropradius 2*cropradius 2*cropradius]);
                    frameCroppedComplement = imcomplement(frameCropped);
                    str = strcat('Bead No.', num2str(i),'/',num2str(length(beadpositionsFrame)),'; Frame No.',num2str(frameno),'/',num2str(obj.numberOfFrames));
                    imshow(frameCroppedComplement,'DisplayRange',[35535 45535]);
                    xlabel(str);
                    hold on;
                    h = plot(cropradius+1,cropradius+1,'rx');
                    while keypressed==0
                        pause(0.1);
                        if abortFlag
                            disp('Classification aborted');
                            return;
                        end
                    end
                    delete(h);
                end
                i=i+1;
            end
            cats = manualCategories;
            obj.beadCategoriesManually{frameno}=cats;
            close(fig);

            function keypressfctClassification(~,event)
                if strcmpi(event.Key,'1')
                    manualCategories(i,1)='touching';
                    keypressed=1;
                elseif strcmpi(event.Key,'2')
                    manualCategories(i,1)='notTouching';
                    keypressed=1;
                elseif strcmpi(event.Key,'c')
                    i=i-2;
                    keypressed=1;
                end
            end

            function buttonpressfctExitClassification(~,~)
                close(fig);
                abortFlag = 1;
            end
        end

        function saveClassifiedMeasurement(obj)
            obj.cctlResult.evaluation.beads.categories = obj.beadCategoriesManually;
            filename = convertCharsToStrings(strcat(erase(obj.tiffFilename,'.tif'),'_result_no_tracking_classified.mat'));
            cctlResult = obj.cctlResult;
            save(filename,'cctlResult');
        end
    end


end