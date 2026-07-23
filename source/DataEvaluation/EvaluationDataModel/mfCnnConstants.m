classdef mfCnnConstants    
    methods(Access=public,Static)
        function base=getMfBaseFolder()
            if isfolder('~/_MessungenNeu/Mikrofluidik')
                base='~/_MessungenNeu/Mikrofluidik';
            elseif isfolder('E:/tmp/mf/')
                base='E:/tmp/mf/';
            end
        end
        
        function tdf=getTrainDataFolder()
            tdf=[char(currentProject().RootFolder),filesep,'data/beadClassification/learning'];
        end
        
        function tdsf=getTrainDataSourceFolder()
            tdsf=[char(currentProject().RootFolder),filesep,'data/beadClassification/source'];
        end

        function tf=getTestFolder()
            tf=[char(currentProject().RootFolder),filesep,'data/beadClassification/test'];
        end
        
        function tdsfn=getTrainDataSourceFolderNew()
            tdsfn=[mfCnnConstants.getTrainDataFolder,filesep,'new'];
        end
        
        function np=getNetworkPath()
            np=[char(currentProject().RootFolder),filesep,'data',filesep,...
                'testnet.mat'];
        end
     
        % 'googlenet_do05_mf007_3umCOOH_J774_detectionImages_ch1_m1_26_R2019b_mf016_mf018_mf019.mat'
        % 'testnet.mat'
        
        function res=getResultLoadString()
            %res='_result_test_accurate_detection_r430.mat';
            %res='_result_test_accurate_detection_r430.mat';
            %res='_result.mat';
            res = '_result_tracking.mat';
        end
        
        function res=getResultSaveString()
            res='_result_tracking.mat';
        end
        
        function [rpImage,rpScale]=getReferenceParticle()
            rpScale=3;
            rpPath=[mfCnnConstants.getCBPath(),filesep,'bead3UmSCALE3_tightCrop.mat'];
            
            rpImage=load(rpPath,'bead');
            rpImage=rpImage.bead;
        end
        
        function p=getCBPath()
            [p,~]=fileparts(which('CatBeads'));
        end
    end
    
    methods(Access=private,Static)
        function p=getClassPath()
            [p,~]=fileparts(mfilename('fullpath'));
        end
    end
end

