Copyright 2026 Wolfgrang Gross, Matteo Kumar

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


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
% make sure to adjust the network path in mfCnnConstants.getNetworkPath()
% to lead to the network you want to use for classification
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


