clear;
clc;
%% runCalibrationTracking
% Implements the analysis of high speed camera measurements to analyze
% the flow profile inside a microfluidics channel. Particles darker than
% the background are detected and tracked to measure the flow profile.
%
% Supports GPU and CPU processing (uses GPU if available). 

% Setup
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.INFO);
l.setLogLevel(Logger.INFO);

sourceFolder = append(char(currentProject().RootFolder),filesep,'data/Calibration');
files=getFilesByRegexName(sourceFolder,true,'.*\.mpt$','026_200128_cal_stu01');
pixelsizeM=0.1600E-6;

%% Image Processing
% Image processing parameters
bandpassLowPx=1; % lower bpass lengthscale
bandpassHighPx=1.7; % upper bpass lengthscale
detectionThreshold=10; % in units of the standard deviation of the bandpass filtered image
minDistPx=50; % minimum distance between particles.
scanRadiusPx=5; % the size of the local region to search for maxima
fitRegionRadiusPx=3; % the size of the region used to perform subpixel gaussian peak fitting

% Particle tracking parameters
maxDispPerFramePx=50;
memFrames=0; % Number of frames a particle can be lost
minTrackLengthFrameCount=20; % Trajectories shorter than this are discarded.

% To enable parallel analysis of many videos simultaneously: 
% 1) Exchange for loop with parfor loop.
% 2) Call mc.enableDebugPlots(false) to disable plotting.
% 3) On OOM-error (GPU VRAM or CPU RAM) reduce maximum thread size.

% safeParpool(min(6,size(files,1)));
tic;
for i=1:size(files,1)
    mc=MicrofluidicsCalibration(files{i,1});
    mc.enableDebugPlots(false);
    mc.detectParticles(bandpassLowPx,bandpassHighPx,detectionThreshold,minDistPx,scanRadiusPx,fitRegionRadiusPx);

    mc.trackBeads(maxDispPerFramePx,memFrames,minTrackLengthFrameCount);
    mc.saveResults();
end
toc;

%% Plot the measured flow profile
showPlot=true;
files=getFilesByRegexName(sourceFolder,true,'results\.mat$');
zRegex='(?<=ch1_alpha(\d+)_z)(\d+)(?=(um/))'; % regular expression to detect the z position in the foldername
[zM,velMS,vAvgMS,stdErrVelMS]=MicrofluidicsCalibration.getCalibrationSummaryVxOfZ(files,zRegex,pixelsizeM,showPlot);