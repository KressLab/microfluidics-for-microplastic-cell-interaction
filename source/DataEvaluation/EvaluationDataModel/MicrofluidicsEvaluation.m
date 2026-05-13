classdef MicrofluidicsEvaluation < handle
    properties(Access=public)
        logger;
        filename;
        matFilename;
        resultMatFilename;
        tifFilenames;
        tifFirstFrame;
        imageSz;
        
        PLOT_TRACKS=false;
        
        cctlResult;
        beadPositions;
        detectedBeadPositions;
        beadIds;
        beadCategories;
        beadCategoryScores;
        beadMotionStatus;
        classifiedBeadTrajectories;
        
        fig;
        figureTitle;
        
        activeFrame;
        activeBead;
        
        ax;
        imPlot;
        activeBeadPlot;
        invalidBeadPlot;
        touchingCellBeadPlot;
        notTouchingCellBeadPlot;
        motionStatusFreePlot;
        motionStatusFixedPlot;
        differencePlot;
        trackPlots;
        
        ax2;
        imPlot2;
        activeBeadPlot2;
        invalidBeadPlot2;
        touchingCellBeadPlot2;
        notTouchingCellBeadPlot2;
        motionStatusFreePlot2;
        motionStatusFixedPlot2;
        differencePlot2;
        
        ax3;
        imPlot3;
        activeBeadPlot3;
        invalidBeadPlot3;
        touchingCellBeadPlot3;
        notTouchingCellBeadPlot3;
        motionStatusFreePlot3;
        motionStatusFixedPlot3;
        differencePlot3;
        
        ax4;
        imPlot4;
        activeBeadPlot4;
        invalidBeadPlot4;
        touchingCellBeadPlot4;
        notTouchingCellBeadPlot4;
        motionStatusFreePlot4;
        motionStatusFixedPlot4;
        differencePlot4;
        enableFastMode=true;
        ROI_SZ=70;
        
        measurementPhaseSegmenter;
    end
    
    methods(Access=public)
        function shortFilename=getShortFilename(obj)
            [~,shortFilename]=fileparts(obj.filename);
        end
        
        function lrs=getLoadResultFileName(obj)
            lrs=[obj.filename,mfCnnConstants.getResultLoadString()];
        end
        
        function srs=getSaveResultFileName(obj)
            srs=[obj.filename,mfCnnConstants.getResultSaveString()];
        end
        
        function obj=MicrofluidicsEvaluation(filename,loadResults,initFigure)
            obj.logger=Logger.getInstance();
            obj.filename=filename;
            obj.matFilename=[filename,'.mat'];
            [baseFolder,baseFilename]=fileparts(filename);
            obj.tifFilenames=getFilesByRegexName(baseFolder,false,[baseFilename,'(_\d+)?.tif']);
            
            obj.tifFirstFrame=ones(size(obj.tifFilenames));
            for i=2:size(obj.tifFilenames,1)
                obj.tifFirstFrame(i,1)=obj.tifFirstFrame(i-1,1)+obj.getFrameCountInFile(i-1);
            end
            
            if loadResults
                load(obj.getLoadResultFileName(),'cctlResult');
                obj.logger.info(obj.getShortFilename(),': Result file loaded.');
            else
                load(obj.matFilename,'cctlResult');
                obj.logger.info(obj.getShortFilename(),': Result file not loaded.');
            end
            obj.cctlResult=cctlResult;
            
            if isfield(cctlResult,'evaluation') && isfield(cctlResult.evaluation,'beads')
                obj.beadPositions=obj.cctlResult.evaluation.beads.positions;
                if isfield(cctlResult.evaluation.beads,'ids')
                    obj.beadIds=obj.cctlResult.evaluation.beads.ids;
                end
                if isfield(cctlResult.evaluation.beads,'detectedBeadPositions')
                    obj.detectedBeadPositions=obj.cctlResult.evaluation.beads.detectedBeadPositions;
                end
                if isfield(cctlResult.evaluation.beads,'categories')
                    obj.beadCategories=obj.cctlResult.evaluation.beads.categories;
                end
                if isfield(cctlResult.evaluation.beads,'categoryScores')
                    obj.beadCategoryScores=obj.cctlResult.evaluation.beads.categoryScores;
                end
                if isfield(cctlResult.evaluation.beads,'classifiedTrajectories')
                    obj.classifiedBeadTrajectories=obj.cctlResult.evaluation.beads.classifiedTrajectories;
                end
                obj.logger.info(obj.getShortFilename(),': Version of results is correct. ');
            else
                obj.clearBeads();
                obj.logger.info(obj.getShortFilename(),': Version of results is not correct. Neglecting results');
            end
            
            obj.measurementPhaseSegmenter=MeasurementPhaseSegmenter(filename);
            obj.measurementPhaseSegmenter.setForce(obj.getForceN());
            
            if initFigure
                iminfo=imfinfo(obj.tifFilenames{1,1});
                obj.imageSz=[iminfo(1).Height,iminfo(1).Width];
                
                
                obj.activeBead=1;
                obj.activeFrame=1;
                obj.enableFastMode=true;
                
                obj.initFigure();
            end
        end
        
        function loadDetectedBeadPositions(obj)
            obj.beadPositions=obj.detectedBeadPositions();
            obj.clearClassification();
        end
        
        function [attachedFrameCount,resilientFrameCount]=getTouchingTimeDependence(obj)
            [~,sedimentationStartFrame,ruptureStartFrame]=obj.measurementPhaseSegmenter.getPhaseStartFrames();
            % beads=classifyBeadTrajectories(obj);
            attachedFrameCount=nan(0,1);
            resilientFrameCount=nan(0,1);
            for i=1:obj.getTrajectoryCount()
                touching=beads{i,1}.cat==CatBeads.CAT_TOUCHING_CELL;
                notInFrame=beads{i,1}.cat==CatBeads.CAT_NOT_IN_FRAME;
                
                % neglect classification errors of at max 3 consecutive
                % frames
                touching=medfilt1(touching.*1.,5)>0;
                
                onlyBindsOnce=sum(diff(touching)>0)==1;
                if onlyBindsOnce
                    touchingStartFrame=backtrackToStatusChange(ruptureStartFrame-1,touching);
                    detachmentFrame=moveToNextStatusChange(ruptureStartFrame-2,notInFrame);
                    attachedFrames=ruptureStartFrame-touchingStartFrame;
                    resilientFrames=detachmentFrame-ruptureStartFrame;
                    if touchingStartFrame>sedimentationStartFrame && ~isnan(detachmentFrame)
                        obj.logger.info(obj.getShortFilename(),': Bead ', i,': Attached at ',touchingStartFrame, ', detached at ', detachmentFrame,' (total ',attachedFrames,'/',resilientFrames,').');
                    elseif touchingStartFrame>sedimentationStartFrame && isnan(detachmentFrame)
                        obj.logger.info(obj.getShortFilename(),'Bead ', i,': Attached at ',touchingStartFrame, ', not detached (total ',attachedFrames,').');
                    end
                    
                    if touchingStartFrame>sedimentationStartFrame
                        attachedFrameCount(end+1,1)=attachedFrames;
                        resilientFrameCount(end+1,1)=resilientFrames;
                    end
                else
                    obj.logger.info(obj.getShortFilename(),': Bead ', i,' binds more than once (',sum(diff(beads{i,1}.cat==obj.CAT_TOUCHING_CELL)>0),' times).');
                end
            end
        end
        
        function count=getTrajectoryCount(obj)
            count=size(obj.classifiedBeadTrajectories,1);
        end
        
        function count=getFrameCount(obj)
            count=0;
            for i=1:size(obj.tifFilenames,1)
                count=count+obj.getFrameCountInFile(i);
            end
        end
        
        function count=getFrameCountInFile(obj,fileIndex)
            inf=imfinfo(obj.tifFilenames{fileIndex,1});
            count=size(inf,1);
        end
        
        function saveBeadStatus(obj)
            obj.logger.info(obj.getShortFilename(),': Saving results to file ',obj.getSaveResultFileName());
            obj.cctlResult.evaluation.beads.positions=obj.beadPositions;
            obj.cctlResult.evaluation.beads.detectedBeadPositions=obj.detectedBeadPositions;
            obj.cctlResult.evaluation.beads.ids=obj.beadIds;
            obj.cctlResult.evaluation.beads.categories=obj.beadCategories;
            obj.cctlResult.evaluation.beads.categoryScores=obj.beadCategoryScores;
            obj.cctlResult.evaluation.beads.classifiedTrajectories=obj.classifiedBeadTrajectories;
            cctlResult=obj.cctlResult;
            save(obj.getSaveResultFileName(),'cctlResult');
            obj.logger.info(obj.getShortFilename(),': Saved results to file ',obj.getSaveResultFileName());
        end
        
        function copyFrameToLearningSourceFolderNew(obj,frame)
            learningFolder=mfCnnConstants.getTrainDataSourceFolderNew();
            if length(frame)~=1
                obj.logger.fatal('Only one frame supported');
            end
            if ~exist(learningFolder,'file')
                mkdir(learningFolder);
            end
            [~,baseFilename]=fileparts(obj.filename);
            outFilename=[learningFolder,filesep,baseFilename,'_f',num2str(frame)];
            outMatFilename=[outFilename,'.mat'];
            outTifFilename=[outFilename,'.tif'];
            if exist(outMatFilename,'file')
                delete(outMatFilename);
            end
            if exist(outTifFilename,'file')
                delete(outTifFilename);
            end
            imwrite(uint16(obj.getImage(frame)),outTifFilename,'WriteMode','append');
            copyfile(obj.matFilename,outMatFilename);
        end
        
        function force=getForceN(obj)
            try
                force=obj.cctlResult.microfluidics.dragForceSimLehmanXN;
            catch
                obj.logger.warn('Drag force not calculated with Lehmann theory');
                force=obj.cctlResult.microfluidics.dragForceApproxXN;
            end
        end
        
        function clearClassification(obj)
            obj.beadCategories=cell(obj.getFrameCount(),1);
            obj.beadCategoryScores=cell(obj.getFrameCount(),1);
            for i=1:obj.getFrameCount()
                obj.beadCategories{i,1}=categorical(zeros(size(obj.beadPositions{i,1},1),1),0,CatBeads.CAT_INVALID);
                obj.beadCategoryScores{i,1}=nan(size(obj.beadPositions{i,1},1),2);
            end
            obj.classifiedBeadTrajectories=[];
            obj.logger.info(obj.getShortFilename(),': Cleared all bead classification information.');
        end
        
        function plotResults(obj)
            [sumTouch,sumNotTouch]=obj.getSum();
            [onCells,notOnCells]=obj.getRupturedBeadCountRelative();
            
            figure(3);
            clf;
            hold on;
            p1=plot(obj.getTimeS(),sumTouch,'g-');
            p2=plot(obj.getTimeS(),sumNotTouch,'b-');
            ylabel('Anzahl Partikel');
            xlabel('Zeit / s');
            
            yyaxis('right');
            p3=plot(obj.getTimeS(),abs(obj.getForceN()/1E-9));
            
            legend({'An Zelle','Nicht an Zelle','Kraft'},'Box',false,'Location','northwest');
            
            ylabel('Kraft (Stokes Naeherung) /nN');
            fuAutosetPlotLimits(gcf,0.05);
            
            exportgraphics(gcf, [obj.filename,'_absolut.pdf'], 'Resolution', 800);
            savefig(gcf, [obj.filename,'_absolut.fig']);
            
            figure(4);
            clf;
            hold on;
            p1=plot(obj.getTimeS(),onCells,'g-');
            p2=plot(obj.getTimeS(),notOnCells,'b-');
            ylabel('Anteil abgelöster Partikel');
            xlabel('Zeit / s');
            
            yyaxis('right');
            p3=plot(obj.getTimeS(),abs(obj.getForceN()/1E-9));
            legend({'An Zelle','Nicht an Zelle','Kraft'},'Box',false,'Location','northeast');
            ylabel('Kraft (Stokes Naeherung) /nN');
            fuAutosetPlotLimits(gcf,0.05);
            
            exportgraphics(gcf,[obj.filename,'_relative.pdf'],"Resolution",800);
            savefig(gcf,[obj.filename,'_relative.fig']);
        end
        
        function toVideo(obj)
            obj.logger.info(obj.getShortFilename(),': Converting to Video');
            rc=load(obj.matFilename);
            
            [sumTouch,sumNotTouch]=obj.getSum();
            
            f2=figure(2);
            clf;
            axL=subplot(1,2,2);
            hold(axL,'on');
            p1=plot(rc.cctlResult.timesS,sumTouch,'g-');
            p2=plot(rc.cctlResult.timesS,sumNotTouch,'b-');
            pCurrTouch=plot(NaN,NaN,'go','MarkerSize',10,'MarkerFaceColor','g');
            pCurrNotTouch=plot(NaN,NaN,'bo','MarkerSize',10,'MarkerFaceColor','b');
            ylabel('particle count');
            
            yyaxis(axL,'right');
            hold on;
            p3=plot(rc.cctlResult.timesS,abs(obj.cctlResult.microfluidics.dragForceSimLehmanXN/1E-9),'k-');
            pCurrForce=plot(NaN,NaN,'ko','MarkerSize',10,'MarkerFaceColor','k');
            set(gca,'ycolor','k');
            xlabel('time / s');
            ylabel('dragForce / nN');
            title(obj.filename,'interpreter','none');
            legend([p1,p2,p3],{'touching','notTouching','force'},'Box',false,'Location','northwest');
            fuAutosetPlotLimits(gcf,0.05);
            
            vw=VideoWriter([obj.filename,'.avi'],'Motion JPEG AVI');
            vw.open();
            
            axR=subplot(1,2,1);
            frameCount=obj.getFrameCount();
            for i=1:frameCount
                cla(axR);
                imagesc(obj.getImage(i));
                hold on;
                peaks=obj.beadPositions{i,1};
                plot(peaks(obj.beadCategories{i,1}==CatBeads.CAT_INVALID,1),...
                    peaks(obj.beadCategories{i,1}==CatBeads.CAT_INVALID,2),'r+');
                plot(peaks(obj.beadCategories{i,1}==CatBeads.CAT_TOUCHING_CELL,1),...
                    peaks(obj.beadCategories{i,1}==CatBeads.CAT_TOUCHING_CELL,2),'g+');
                plot(peaks(obj.beadCategories{i,1}==CatBeads.CAT_NOT_TOUCHING_CELL,1),...
                    peaks(obj.beadCategories{i,1}==CatBeads.CAT_NOT_TOUCHING_CELL,2),'b+');
                axis image;
                colormap gray;
                title(['t=',num2str(rc.cctlResult.timesS(i)),'s']);
                
                set(pCurrTouch,'XData',rc.cctlResult.timesS(i),'YData',sumTouch(i));
                set(pCurrNotTouch,'XData',rc.cctlResult.timesS(i),'YData',sumNotTouch(i));
                set(pCurrForce,'XData',rc.cctlResult.timesS(i),'YData',abs(obj.cctlResult.microfluidics.dragForceSimLehmanXN(i)/1E-9));
                fuAddScalebar(axR,[0.95,0.95],0.1,100,str2double(obj.cctlResult.settings.strings('Pixelsize/um')),'um','w',15);
                vw.writeVideo(getframe(f2));
                pause(0.001);
            end
            vw.close();
        end
        
        function exportOverviewGraphics(obj)
            for i=1:100:obj.getFrameCount()
                obj.setActiveFrame(i);
                f2=figure(2);
                clf;
                set(copyobj(obj.ax,f2),'Position',[0.05,0.05,0.93,0.93]);
                set(f2,'Position',[1,1,1920,1070]);
                
                if ~isempty(obj.detectedBeadPositions{i,1})
                    detectedBeadPlot=plot(obj.detectedBeadPositions{i,1}(:,1),obj.detectedBeadPositions{i,1}(:,2),'g+');
                    set(detectedBeadPlot,'MarkerSize',6,'LineWidth',0.1,'MarkerFaceColor','gr');
                    uistack(detectedBeadPlot,'bottom');
                    uistack(detectedBeadPlot,'up');
                end
                
                colormap gray;
                title([obj.filename,'  Frame: ', num2str(i)],'Interpreter','none');
                print(gcf, [obj.filename,'overview_frame',num2str(i),'.jpg'], '-djpeg');
            end
        end
        
        function img=getImage(obj,frameId)
            for i=1:(size(obj.tifFilenames,1))
                if i==size(obj.tifFilenames,1)
                    fileId=i;
                else
                    if obj.tifFirstFrame(i+1,1)>frameId
                        fileId=i;
                        break;
                    end
                end
            end
            frameInFileId=frameId-obj.tifFirstFrame(fileId)+1;
            obj.logger.trace(obj.getShortFilename(), ': FrameId ', frameId,' in file: ',fileId,' id in frame: ',frameInFileId);
            img=double(imread(obj.tifFilenames{fileId,1},frameInFileId));
        end

        function [onCells,notOnCells]=getRupturedBeadCountRelative(obj)
            [sumTouch,sumNotTouch]=getSum(obj);
            onCells=1-sumTouch./max(sumTouch);
            notOnCells=1-sumNotTouch./max(sumNotTouch);
        end
        
        function time=getTimeS(obj)
            time=obj.cctlResult.timesS;
        end
        
        function [sumTouch,sumNotTouch]=getSum(obj)
            sumTouch=cellfun(@(x)(sum(CatBeads.CAT_TOUCHING_CELL==x)),obj.beadCategories);
            sumNotTouch=cellfun(@(x)(sum(CatBeads.CAT_NOT_TOUCHING_CELL==x)),obj.beadCategories);
        end
        
        function [sumMotorOnTouchingRelative, sumMotorOnNotTouchingRelative,timeMotorOnS]=getSumMotorOnRelative(obj)
            [~,~,startFrameId]=obj.measurementPhaseSegmenter.getPhaseStartFrames();
            startFrameId=startFrameId-1;
            [sumTouch,sumNotTouch]=getSum(obj);
            sumMotorOnTouching=sumTouch(startFrameId:end);
            sumMotorOnNotTouching=sumNotTouch(startFrameId:end);
            
            AVG_INTERVAL=60;
            sumMotorOnTouchingRelative=sumMotorOnTouching./mean(sumTouch(startFrameId-AVG_INTERVAL:startFrameId));
            sumMotorOnNotTouchingRelative=sumMotorOnNotTouching./mean(sumNotTouch(startFrameId-AVG_INTERVAL:startFrameId));
            
            timeMotorOnS=obj.getTimeS();
            timeMotorOnS=timeMotorOnS(startFrameId:end);
        end
        
        function cropped=cropImageAroundPosition(obj,imageId,pos,sz)
            if all(~isnan(pos))
                img=obj.getImage(imageId);
                xlow=max(1,pos(2)-sz);
                xhigh=min(obj.imageSz(1),pos(2)+sz);
                ylow=max(1,pos(1)-sz);
                yhigh=min(obj.imageSz(2),pos(1)+sz);
                cropped=img(xlow:xhigh,ylow:yhigh);
            else
                cropped=[];
            end
        end
    end
    
    methods(Access=protected)
        function clearBeads(obj)
            obj.beadPositions=cell(obj.getFrameCount(),1);
            obj.beadIds=cell(obj.getFrameCount(),1);
            obj.logger.info('Cleared all bead position information.');
            obj.clearClassification();
        end        
    end
    
    methods(Access=public)
        function initFigure(obj)
            obj.fig=figure(1);
            set(obj.fig,'Name',obj.filename);
            clf(obj.fig);
            image=-obj.getImage(obj.activeFrame);
            set(obj.fig,'KeyPressFcn',@obj.windowKeyPressFcn)
            
            obj.ax=subplot(2,2,1);
            hold('on');
            obj.imPlot=imagesc(image);
            axis image;
            colormap gray;
            obj.activeBeadPlot=plot(NaN,NaN,'wo');
            set(obj.activeBeadPlot,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w');
            obj.invalidBeadPlot=plot(NaN,NaN,'wo');
            set(obj.invalidBeadPlot,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w');
            obj.touchingCellBeadPlot=plot(NaN,NaN,'go');
            set(obj.touchingCellBeadPlot,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','g');
            obj.notTouchingCellBeadPlot=plot(NaN,NaN,'ro');
            set(obj.notTouchingCellBeadPlot,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','y');
            obj.motionStatusFreePlot=plot(NaN,NaN,'yd');
            set(obj.motionStatusFreePlot,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','y');
            obj.motionStatusFixedPlot=plot(NaN,NaN,'bd');
            set(obj.motionStatusFixedPlot,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','b');
            obj.differencePlot=plot(NaN,NaN,'go');
            obj.trackPlots=cell(0);
            
            obj.ax2=subplot(2,2,2);
            hold('on');
            obj.imPlot2=imagesc(image);
            axis image;
            colormap gray;
            obj.activeBeadPlot2=plot(NaN,NaN,'wo');
            set(obj.activeBeadPlot2,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w');
            obj.invalidBeadPlot2=plot(NaN,NaN,'wo');
            set(obj.invalidBeadPlot2,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w');
            obj.touchingCellBeadPlot2=plot(NaN,NaN,'go');
            set(obj.touchingCellBeadPlot2,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','g');
            obj.notTouchingCellBeadPlot2=plot(NaN,NaN,'ro');
            set(obj.notTouchingCellBeadPlot2,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','r');
            obj.motionStatusFreePlot2=plot(NaN,NaN,'yd');
            set(obj.motionStatusFreePlot2,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','y');
            obj.motionStatusFixedPlot2=plot(NaN,NaN,'bd');
            set(obj.motionStatusFixedPlot2,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','b');
            obj.differencePlot2=plot(NaN,NaN,'g+');
            
            obj.ax3=subplot(2,2,3);
            hold('on');
            obj.imPlot3=imagesc(image);
            axis image;
            colormap gray;
            obj.activeBeadPlot3=plot(NaN,NaN,'wo');
            set(obj.activeBeadPlot3,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w');
            obj.invalidBeadPlot3=plot(NaN,NaN,'wo');
            set(obj.invalidBeadPlot3,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w');
            obj.touchingCellBeadPlot3=plot(NaN,NaN,'go');
            set(obj.touchingCellBeadPlot3,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','g');
            obj.notTouchingCellBeadPlot3=plot(NaN,NaN,'ro');
            set(obj.notTouchingCellBeadPlot3,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','r');
            obj.motionStatusFreePlot3=plot(NaN,NaN,'yd');
            set(obj.motionStatusFreePlot3,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','y');
            obj.motionStatusFixedPlot3=plot(NaN,NaN,'bd');
            set(obj.motionStatusFixedPlot3,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','b');
            obj.differencePlot3=plot(NaN,NaN,'go');
            
            obj.ax4=subplot(2,2,4);
            hold('on');
            obj.imPlot4=imagesc(image);
            axis image;
            colormap gray;
            obj.activeBeadPlot4=plot(NaN,NaN,'wo');
            set(obj.activeBeadPlot4,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w','LineWidth',4);
            obj.invalidBeadPlot4=plot(NaN,NaN,'wo');
            set(obj.invalidBeadPlot4,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','w','LineWidth',4);
            obj.touchingCellBeadPlot4=plot(NaN,NaN,'go');
            set(obj.touchingCellBeadPlot4,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','g','LineWidth',4);
            obj.notTouchingCellBeadPlot4=plot(NaN,NaN,'ro');
            set(obj.notTouchingCellBeadPlot4,'MarkerSize',3,'LineWidth',0.1,'MarkerFaceColor','r','LineWidth',4);
            obj.motionStatusFreePlot4=plot(NaN,NaN,'yd');
            set(obj.motionStatusFreePlot4,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','y');
            obj.motionStatusFixedPlot4=plot(NaN,NaN,'bd');
            set(obj.motionStatusFixedPlot4,'MarkerSize',15,'LineWidth',0.1,'MarkerEdgeColor','b');
            obj.differencePlot4=plot(NaN,NaN,'go');
            
            obj.figureTitle=title('');
            
            obj.updateImagePlots();
            obj.updateBeadPlots();
        end
        
        function updateBeadPlots(obj)
            image=-obj.getImage(obj.activeFrame);
            currBeadPos=obj.beadPositions{obj.activeFrame,1};
            currIds=obj.beadIds{obj.activeFrame,1};
            currCats=obj.beadCategories{obj.activeFrame,1};
            if size(currBeadPos,1)>0
                actX=currBeadPos(obj.activeBead,1);
                actY=currBeadPos(obj.activeBead,2);
                
                %                 difference=obj.beadCategories{1,1}~=obj.beadCategories{2,1};
                
                set(obj.activeBeadPlot,'XData',actX,...
                    'YData',actY);
                set(obj.invalidBeadPlot,'XData',currBeadPos(currCats==CatBeads.CAT_INVALID,1),...
                                        'YData',currBeadPos(currCats==CatBeads.CAT_INVALID,2));
                set(obj.touchingCellBeadPlot,'XData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,1),...
                                             'YData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,2));
                set(obj.notTouchingCellBeadPlot,'XData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,1),...
                                                'YData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,2));
                %                 set(obj.differencePlot,'XData',peaks(difference,1),...
                %                                        'YData',peaks(difference,2));
                if ~isempty(obj.beadMotionStatus)
                    currMotionStatus=obj.beadMotionStatus{obj.activeFrame,1};
                    set(obj.motionStatusFreePlot,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,1),...
                                                 'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,2));
                    
                    set(obj.motionStatusFixedPlot,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,1),...
                                                  'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,2));
                    
                    set(obj.motionStatusFreePlot2,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,1),...
                                                 'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,2));
                    
                    set(obj.motionStatusFixedPlot2,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,1),...
                                                  'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,2));
                                              
                    set(obj.motionStatusFreePlot3,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,1),...
                                                 'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,2));
                    
                    set(obj.motionStatusFixedPlot3,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,1),...
                                                  'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,2));
                                              
                    set(obj.motionStatusFreePlot4,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,1),...
                                                 'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FREE,2));
                    
                    set(obj.motionStatusFixedPlot4,'XData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,1),...
                                                  'YData',currBeadPos(currMotionStatus==SedimentationAnalysis.MOTION_STATUS_FIXED,2));
                end
                if obj.PLOT_TRACKS
                    if ~isempty(obj.trackPlots)
                        cellfun(@delete,obj.trackPlots);
                        obj.trackPlots=cell(0);
                    end
                    colorCount=20;
                    colors=jet(colorCount);
                    xl=get(obj.ax,'xlim');
                    yl=get(obj.ax,'ylim');
                    for i=1:size(currBeadPos,1)
                        currX=currBeadPos(i,1);
                        currY=currBeadPos(i,2);
                        if isInRange(currX,xl) && isInRange(currY,yl)
                            obj.trackPlots{end+1,1}=plot(obj.ax,...
                                                         currX,...
                                                         currY,...
                                                         'o',...
                                                         'MarkerSize',8,...
                                                         'LineWidth',1,...
                                                         'MarkerEdgeColor',colors(mod(currIds(i,1),colorCount)+1,:));
                            if obj.activeFrame<obj.getFrameCount() && ~ismember(currIds(i,1),obj.beadIds{obj.activeFrame+1,1})
                                obj.trackPlots{end+1,1}=plot(obj.ax,...
                                                            currX,...
                                                            currY,...
                                                            'd',...
                                                            'MarkerSize',20,...
                                                            'LineWidth',1,...
                                                            'MarkerEdgeColor','r');
                            end
                            if obj.activeFrame>1 && ~ismember(currIds(i,1),obj.beadIds{obj.activeFrame-1,1})
                                obj.trackPlots{end+1,1}=plot(obj.ax,...
                                                            currX,...
                                                            currY,...
                                                            'd',...
                                                            'MarkerSize',22,...
                                                            'LineWidth',1,...
                                                            'MarkerEdgeColor','g');
                            end
                        end
                    end
                end
                
                set(obj.activeBeadPlot2,'XData',actX,...
                    'YData',actY);
                set(obj.invalidBeadPlot2,'XData',currBeadPos(currCats==CatBeads.CAT_INVALID,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_INVALID,2));
                set(obj.touchingCellBeadPlot2,'XData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,2));
                set(obj.notTouchingCellBeadPlot2,'XData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,2));
                %                 set(obj.differencePlot2,'XData',peaks(difference,1),...
                %                                         'YData',peaks(difference,2));
                
                set(obj.activeBeadPlot3,'XData',actX,...
                    'YData',actY);
                set(obj.invalidBeadPlot3,'XData',currBeadPos(currCats==CatBeads.CAT_INVALID,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_INVALID,2));
                set(obj.touchingCellBeadPlot3,'XData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,2));
                set(obj.notTouchingCellBeadPlot3,'XData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,2));
                %                 set(obj.differencePlot3,'XData',peaks(difference,1),...
                %                                         'YData',peaks(difference,2));
                
                set(obj.activeBeadPlot4,'XData',actX,...
                    'YData',actY);
                set(obj.invalidBeadPlot4,'XData',currBeadPos(currCats==CatBeads.CAT_INVALID,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_INVALID,2));
                set(obj.touchingCellBeadPlot4,'XData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_TOUCHING_CELL,2));
                set(obj.notTouchingCellBeadPlot4,'XData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,1),...
                    'YData',currBeadPos(currCats==CatBeads.CAT_NOT_TOUCHING_CELL,2));
                %                 set(obj.differencePlot4,'XData',peaks(difference,1),...
                %                                         'YData',peaks(difference,2));
                
                
                xlow=max(1,actX-obj.ROI_SZ);
                xhigh=min(size(image,2),actX+obj.ROI_SZ);
                ylow=max(1,actY-obj.ROI_SZ);
                yhigh=min(size(image,2),actY+obj.ROI_SZ);
                set(obj.ax2,'xlim',[xlow,xhigh],'ylim',[ylow,yhigh]);
                set(obj.ax3,'xlim',[xlow,xhigh],'ylim',[ylow,yhigh]);
                set(obj.ax4,'xlim',[xlow,xhigh],'ylim',[ylow,yhigh]);
                set(obj.figureTitle,'String',['Frame: ',num2str(obj.activeFrame),' ,Bead: ',num2str(obj.activeBead)]);
            else
                set(obj.activeBeadPlot,'XData',nan,'YData',nan);
                set(obj.invalidBeadPlot,'XData',nan,'YData',nan);
                set(obj.touchingCellBeadPlot,'XData',nan,'YData',nan);
                set(obj.notTouchingCellBeadPlot,'XData',nan,'YData',nan);
                set(obj.motionStatusFreePlot,'XData',nan,'YData',nan);
                set(obj.motionStatusFixedPlot,'XData',nan,'YData',nan);
                
                set(obj.activeBeadPlot2,'XData',nan,'YData',nan);
                set(obj.invalidBeadPlot2,'XData',nan,'YData',nan);
                set(obj.touchingCellBeadPlot2,'XData',nan,'YData',nan);
                set(obj.notTouchingCellBeadPlot2,'XData',nan,'YData',nan);
                set(obj.motionStatusFreePlot2,'XData',nan,'YData',nan);
                set(obj.motionStatusFixedPlot2,'XData',nan,'YData',nan);
                
                set(obj.activeBeadPlot3,'XData',nan,'YData',nan);
                set(obj.invalidBeadPlot3,'XData',nan,'YData',nan);
                set(obj.touchingCellBeadPlot3,'XData',nan,'YData',nan);
                set(obj.notTouchingCellBeadPlot3,'XData',nan,'YData',nan);
                set(obj.motionStatusFreePlot3,'XData',nan,'YData',nan);
                set(obj.motionStatusFixedPlot3,'XData',nan,'YData',nan);
                
                set(obj.activeBeadPlot4,'XData',nan,'YData',nan);
                set(obj.invalidBeadPlot4,'XData',nan,'YData',nan);
                set(obj.touchingCellBeadPlot4,'XData',nan,'YData',nan);
                set(obj.notTouchingCellBeadPlot4,'XData',nan,'YData',nan);
                set(obj.motionStatusFreePlot4,'XData',nan,'YData',nan);
                set(obj.motionStatusFixedPlot4,'XData',nan,'YData',nan);
                
                set(obj.figureTitle,'String',['Frame: ',num2str(obj.activeFrame),' ,no Beads']);
            end
                obj.logger.info(obj.getShortFilename(),': Loading figure.');
        end
        
        function sumSedimentation=getSumSedimentation(obj)
            [sumTouch,sumNotTouch]=getSum(obj);
            [~,sedimentationInterval,~]=obj.measurementPhaseSegmenter.getPhaseIntervals();
            sumSedimentation=sumNotTouch(sedimentationInterval)+sumTouch(sedimentationInterval);
        end
        
        function setActiveFrame(obj,activeFrame)
            obj.activeFrame=activeFrame;
            obj.updateImagePlots();
            obj.updateBeadPlots();
        end
        
        function updateImagePlots(obj)
            image=-obj.getImage(obj.activeFrame);
            
            set(obj.imPlot,'CData',image);
            if obj.enableFastMode
                set(obj.imPlot2,'CData',image);
                set(obj.imPlot3,'CData',-image);
                set(obj.imPlot4,'CData',nan(size(image)));
            else
                [bpassedImg,quantileImage,localContrastQuantileImg]=obj.getDetectionImages(obj.activeFrame);
                set(obj.imPlot2,'CData',bpassedImg);
                set(obj.imPlot3,'CData',quantileImage);
                set(obj.imPlot4,'CData',localContrastQuantileImg);
            end
            set(obj.figureTitle,'String',['Frame: ',num2str(obj.activeFrame),' ,Bead: ',num2str(obj.activeBead)]);
        end
        
        function windowKeyPressFcn(obj, ~, eventdata)
            switch eventdata.Key
                case '1'
                    obj.beadCategories{obj.activeFrame,1}(obj.activeBead,1)=obj.CAT_INVALID;
                case '2'
                    obj.beadCategories{obj.activeFrame,1}(obj.activeBead,1)=obj.CAT_TOUCHING_CELL;
                case '3'
                    obj.beadCategories{obj.activeFrame,1}(obj.activeBead,1)=obj.CAT_NOT_TOUCHING_CELL;
                case 'uparrow'
                    obj.activeBead=min(obj.activeBead+1,size(obj.beadCategories{obj.activeFrame,1},1));
                case 'downarrow'
                    obj.activeBead=max(1,obj.activeBead-1);
                case 'rightarrow'
                    obj.activeFrame=min(obj.activeFrame+1,obj.getFrameCount());
                    obj.activeBead=max([1,min(obj.activeBead,size(obj.beadCategories{obj.activeFrame,1},1))]);
                    obj.updateImagePlots();
                case 'leftarrow'
                    obj.activeFrame=max(1,obj.activeFrame-1);
                    obj.activeBead=max([1,min(obj.activeBead,size(obj.beadCategories{obj.activeFrame,1},1))]);
                    obj.updateImagePlots();
                otherwise
                    disp('nothing happened');
            end
            obj.updateBeadPlots();
        end
    end
end

