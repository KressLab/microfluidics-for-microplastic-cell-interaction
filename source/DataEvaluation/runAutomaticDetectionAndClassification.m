%% Settings
clear all;
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);
%l.setLogLevel(Logger.INFO);


FILENAMES=getFilesByRegexName(append(char(currentProject().RootFolder),filesep,'data'),false,'mf240828_micromodNR3_50pN_Channel2_01_40min.tif');


%% Particle Detection
% safeParpool(12);
safeParpool(8);
for i=1:size(FILENAMES,1)
     try
        bl=BeadLocalization(FILENAMES{i,1}(1:(end-4)),false,false);
        bl.detectBeads();

        bl.saveBeadStatus();
     catch e
         l.error(FILENAMES{i,1}(end-4), ' COULD NOT BE PROCESSED. See log.',e);
     end
end

%% Particle Tracking
safeParpool(12);
parfor i=1:size(FILENAMES,1)
    try
        bl=BeadLocalization(FILENAMES{i,1}(1:(end-4)),true,false);

        if all(cellfun(@isempty,bl.beadIds))
            bl.trackBeadsUTrack(UTrackParametersMFCellEval());
            bl.saveBeadStatus();
        end
    catch e
        l.error(FILENAMES{i,1}(end-4), ' COULD NOT BE PROCESSED. See log.',e);
    end
end

%% Tracking Test
safeParpool(4);
parfor i=1:size(FILENAMES,1)
    try
        bl=BeadLocalization(FILENAMES{i,1}(1:(end-4)),true,false);

        if all(cellfun(@isempty,bl.beadIds))
            l.error(FILENAMES{i,1}(1:(end-4)), ' not tracked properly.');
        end
    catch e
        l.error(FILENAMES{i,1}(end-4), ' COULD NOT BE PROCESSED. See log.',e);
    end
end

%% Classify all frames automatically
tic;
safeParpool(4);
for i=1:size(FILENAMES,1)
    try
        cb=CatBeads(FILENAMES{i,1}(1:(end-4)),true,false);
        if ~all(cellfun(@isempty,cb.beadIds)) && all(vertcat(cb.beadCategories{:})==CatBeads.CAT_INVALID)
            cb.loadNetwork();
            if isa(cb.net, 'dlnetwork')
                cb.classifyAllFramesDlNetwork([string(CatBeads.CAT_TOUCHING_CELL), string(CatBeads.CAT_NOT_TOUCHING_CELL)]);
            else    
                cb.classifyAllFrames();
            end 
            cb.saveBeadStatus();
        end
    catch e
        l.error(FILENAMES{i,1}(1:(end-4)), ' COULD NOT BE PROCESSED. See log.',e);
    end
end
toc;

%% Classify Test
safeParpool(8);
for i=1:size(FILENAMES,1)
    try
        cb=CatBeads(FILENAMES{i,1}(1:(end-4)),true,false);
        if all(vertcat(cb.beadCategories{:})==CatBeads.CAT_INVALID)
            l.error(FILENAMES{i,1}(1:(end-4)), ' NOT classified properly.');
        else
            l.warn(FILENAMES{i,1}(1:(end-4)), ' classified properly.');
        end
    catch e
        l.error(FILENAMES{i,1}(end-4), ' COULD NOT BE PROCESSED. See log.',e);
    end
end

%% Calculate classified trajectories
%tic;
safeParpool(8);
tic;
parfor i=1:size(FILENAMES,1)
    try
        cb=CatBeads(FILENAMES{i,1}(1:(end-4)),true,false);
        if ~all(cellfun(@isempty,cb.beadIds)) && ~all(vertcat(cb.beadCategories{:})==CatBeads.CAT_INVALID)
            cb.calculateClassifiedTrajectories();
            cb.saveBeadStatus();
        end
    catch e
        l.error(FILENAMES{i,1}(1:(end-4)), ' COULD NOT BE PROCESSED. See log.',e);
    end
end
toc;

% %% To Video and Plot
% for i=1:size(FILENAMES,2)
%     mfe=MicrofluidicsEvaluation(FILENAMES{1,i}(1:(end-4)),true,true);
%     mfe.toVideo();
%     mfe.plotResults();
% end
% 
% %% Overview touchingTimeDependence
% 
% FILENAMES_SW={...
%            '/ep1/home/wolfgang/Messdaten/mf/mf012_3umPLAIN_SW_J774/channel1_measurement1_100_ul_s',...
%            '/ep1/home/wolfgang/Messdaten/mf/mf012_3umPLAIN_SW_J774/channel2_measurement1_100_ul_s',...
%            '/ep1/home/wolfgang/Messdaten/mf/mf012_3umPLAIN_SW_J774/channel3_measurement1_100_ul_s',...
%            '/ep1/home/wolfgang/Messdaten/mf/mf012_3umPLAIN_SW_J774/channel4_measurement1_100_ul_s',...
%            '/ep1/home/wolfgang/Messdaten/mf/mf012_3umPLAIN_SW_J774/channel5_measurement1_100_ul_s',...
%            '/ep1/home/wolfgang/Messdaten/mf/mf012_3umPLAIN_SW_J774/channel6_measurement2_100_ul_s'};
%        
%        % ch4
% FILENAMES_PLAIN={'/ep1/home/wolfgang/Messdaten/mf/mf011_3umPLAIN_J774/Daten_2019_10_16/channel5_measurement1_100_ul_s',...
%                  '/ep1/home/wolfgang/Messdaten/mf/mf011_3umPLAIN_J774/Daten_2019_10_16/channel6_measurement1_100_ul_s'};
%        
% FILENAMES_COOH={'/ep1/home/wolfgang/Messdaten/mf/mf009_3umCOOH_J774/Daten_2019_09_06/channel3_measurement1_100_ul_s',...
%                 '/ep1/home/wolfgang/Messdaten/mf/mf009_3umCOOH_J774/Daten_2019_09_06/channel4_measurement1_100_ul_s',...
%                 '/ep1/home/wolfgang/Messdaten/mf/mf009_3umCOOH_J774/Daten_2019_09_06/channel5_measurement1_100_ul_s'};
%        
% figure(2);
% clf;
% ax1=subplot(1,3,1);
% hold(ax1,'on');
% 
% ax2=subplot(1,3,2);
% hold(ax2,'on');
% 
% ax3=subplot(1,3,3);
% hold(ax3,'on');
% 
% touchingTimeDependenceAnalysis(FILENAMES_PLAIN,'Plain 3um',ax1);
% touchingTimeDependenceAnalysis(FILENAMES_SW,'Saltwater 3um',ax2);
% touchingTimeDependenceAnalysis(FILENAMES_COOH,'COOH 3um',ax3);
% 
% set(ax1,'ylim',[0,1]);
% set(ax2,'ylim',[0,1]);
% set(ax3,'ylim',[0,1]);
% 
% function touchingTimeDependenceAnalysis(filenames,titleString,ax)
%     attachedFrameCount=nan(0,1);
%     resilientFrameCount=nan(0,1);
%     for i=1:size(filenames,2)
%         mfe=MicrofluidicsEvaluation(filenames{1,i},true,false);
%         [newAttachedFrameCount,newResilientFrameCount]=mfe.getTouchingTimeDependence();
%         attachedFrameCount=[attachedFrameCount;newAttachedFrameCount];
%         resilientFrameCount=[resilientFrameCount;newResilientFrameCount];
%     end
% 
%     attachedFrameCountEdges=0:200:700;
%     attachedFrameCountCenters=conv(attachedFrameCountEdges,[0.5,0.5],'valid');
%     
%     %
%     resil=attachedFrameCount(isnan(resilientFrameCount));
%     [countsResil,~,binId]=histcounts(resil,attachedFrameCountEdges);
%     ids=unique(binId)';
%     attachedFrameCountPerBin=cell(size(attachedFrameCountCenters));
%     for id=ids
%         attachedFrameCountPerBin{id}=resil(binId==id);
%     end
%     %
%     countsDetached=histcounts(attachedFrameCount(~isnan(resilientFrameCount)),attachedFrameCountEdges);
%     
%     sumCount=countsResil+countsDetached;
%     
%     hold(ax, 'on');
%     
%     % errorbar(attachedFrameCountCenters,countsDetached./sumCount,sumCount.^(-0.5),'r-','Parent',ax);
%     errorbar(cellfun(@mean,attachedFrameCountPerBin),countsResil./sumCount,sumCount.^(-0.5),sumCount.^(-0.5),cellfun(@(x)(sqrt(var(x))),attachedFrameCountPerBin),cellfun(@(x)(sqrt(var(x))),attachedFrameCountPerBin),'g','Parent',ax);
%     hold(ax, 'off');
%     title(ax,titleString);
% end

