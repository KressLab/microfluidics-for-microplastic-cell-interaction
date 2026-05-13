clear;
clf;

%% 05.09.2019: channel 1, Sarah, Alex
heightM=2.147E-4;
pistonVelocityMS=1.69E-6;
zMeasuredM=[20, 40, 60, 80, 100, 120, 140, 160]'.*1E-6;
vxMeasuredMS=[75, 212, 293.5, 302.4, 327.5, 349.9, 315.9, 282]'.*1E-6; 

fitAndPlotVXofZ(heightM,pistonVelocityMS,zMeasuredM,vxMeasuredMS,1,'Kanal 1');

%% 05.09.2019: channel 5, Sarah, Alex
heightM=2.110E-4;
pistonVelocityMS=1.69E-6;
zMeasuredM=[20, 40, 60, 80, 100, 120, 140]'.*1E-6;
vxMeasuredMS=[75, 212, 293.5, 327.5, 349.9, 315.9, 282]'.*1E-6;

%% mf015
clear;
clc;
close all;

par=struct();
alpha=0.5;
par.driftZM=0E-6;
par.pixelsizeM=0.171e-6;
par.heightM=232e-6;
par.widthM=5.006E-3;
par.yM=(alpha-0.5).*par.widthM;
par.yErrorM=0.25*1024*par.pixelsizeM;
par.widthErrorM=30E-6;
par.heightErrorM=2E-6;
par.zErrorM=3e-6;
par.syringeRadiusM=6.135E-3;
par.syringeRadiusErrorM=0.2E-3;
par.pistonVelocityMS=1.69E-6;
par.pistonVelocityErrorMS=0.05E-6;
    
zRegex='(?<=_z)(\d+)(?=(um))';
baseFolder='/ep1/home/wolfgang/Messdaten/mf/mf015_cal_1um_3um_stu01';
files=getFilesByRegexName(baseFolder,true,'results.mat$'); % exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);


figure(1);
clf;
ax=axes();
fitAndPlotVXofZ(ax,zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,true);

%% mf023-25
clear;
clc;
close all;

% mf023


alpha=[0.02,.1,.2,.3,.4,.5,.6,.7,.8,.9,.98];
zBodenMf023M=[2425,2424,2426,2426,2428,2427,2429,2429,2430,2430,2432]*1E-6;
zDeckeMf023M=[2597,2603,2613,2617,2620,2620,2622,2620,2618,2611,2604]*1E-6;

hMf023M=zDeckeMf023M-zBodenMf023M;
yMf023M=(alpha-0.5)*5E-3;

f=FitterPlain();
f.setModel(QuadraticModel());
f.setData(yMf023M',hMf023M',[],[]);

figure(1);clf;
ax=axes();
f.plotFit(ax,'k');

fitParamMf023=f.getResultParameters();

par=struct();
alpha=0.5;
par.driftZM=0E-6;
par.pixelsizeM=0.171e-6/1.5; % 1.5x Mag in light path
par.heightCenterM=fitParamMf023(1);
par.heightSlope=fitParamMf023(2);
par.heightCurvatureM=fitParamMf023(3);

par.widthM=5.006E-3;
par.yM=(alpha-0.5).*par.widthM;
par.yErrorM=0.25*1024*par.pixelsizeM;
par.widthErrorM=30E-6;
par.heightErrorM=2E-6;
par.zErrorM=3e-6;
par.syringeRadiusM=6.135E-3;
par.syringeRadiusErrorM=0.1E-3;
par.pistonVelocityMS=1.69E-6;
par.pistonVelocityErrorMS=0.05E-6;

zRegex='(?<=_z)(\d+)(?=(um))';
baseFolder='/ep1/home/wolfgang/Messdaten/mf/mf023_cal_1um_stu01';
files=getFilesByRegexName(baseFolder,true,'results.mat$','^(?!.*_z90um).*$');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);

figure(2);
clf;
ax1=subplot(1,3,1);
fitAndPlotVXofZ(ax1,zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,true);


% mf025
zBodenMf025M=[2504,2503,2505,2504,2506,2505,2506,2505,2505,2504,2505]*1E-6;
zDeckeMf025M=[2660,2671,2679,2681,2684,2683,2684,2682,2679,2673,2666]*1E-6;


hMf025M=zDeckeMf025M-zBodenMf025M;
yMf025M=(alpha-0.5)*5E-3;

f=FitterPlain();
f.setModel(QuadraticModel());
f.setData(yMf025M',hMf025M',[],[]);

figure(3);clf;
ax=axes();
f.plotFit(ax,'k');

fitParamMf025=f.getResultParameters();


par.heightCenterM=fitParamMf023(1);
par.heightSlope=fitParamMf023(2);
par.heightCurvatureM=fitParamMf023(3);

par.widthM=5.0110E-3;
par.yM=(alpha-0.5).*par.widthM;

baseFolder='/ep1/home/wolfgang/Messdaten/mf/mf025_cal_1um_stu01';
files=getFilesByRegexName(baseFolder,true,'results.mat$');
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);

figure(2);
ax2=subplot(1,3,2);
fitAndPlotVXofZ(ax2,zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false);

% mf024
par.heightCenterM=fitParamMf023(1);
par.heightSlope=fitParamMf023(2);
par.heightCurvatureM=fitParamMf023(3);
par.widthM=5.020E-3;
par.yM=(alpha-0.5).*par.widthM;

baseFolder='/ep1/home/wolfgang/Messdaten/mf/mf024_cal_1um_stu01';
files=getFilesByRegexName(baseFolder,true,'results.mat$');
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);

ax2=subplot(1,3,3);
fitAndPlotVXofZ(ax2,zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false);


%% mf026
clear;
clc;
close all;

par=struct();
alpha=0.1;
par.driftZM=0E-6;
par.pixelsizeM=0.1600e-6; % blinking026_highSpeed_pixSize_cal
par.heightCenterM=201.12e-6;
par.heightSlope=954e-6;
par.heightCurvatureM=-3;
par.widthM=5.006E-3;
par.yM=(alpha-0.5).*par.widthM;
par.yErrorM=0.25*1024*par.pixelsizeM;
par.widthErrorM=30E-6;
par.heightErrorM=2E-6;
par.zErrorM=3e-6;
par.syringeRadiusM=6.135E-3; %% correct to 6.335E-3 explains residuals
par.syringeRadiusErrorM=0.2E-3;
par.pistonVelocityMS=1.69E-6;
par.pistonVelocityErrorMS=0.05E-6;

zRegex='(?<=_z)(\d+)(?=(um))';
baseFolder='/ep1/home/wolfgang/Messdaten/mf/mf026_cal_1um_stu01';
figure(1);
plotSpacing=[0.065,0.06];

alpha=0.1;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha01_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,1),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,true,'y = -0.4 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.2;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha02_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,2),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = -0.3 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.3;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha03_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,3),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = -0.2 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.4;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha04_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,4),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = -0.1 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.5;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha05_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,5),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = 0');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.6;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha06_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,6),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = 0.1 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.7;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha07_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,7),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = 0.2 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.8;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha08_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,8),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = 0.3 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

alpha=0.9;
par.yM=(alpha-0.5).*par.widthM;
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_02uls_ch1_alpha09_');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);
fitAndPlotVXofZ(subplot(3,3,9),zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,false,'y = 0.4 w');
set(gca,'XLim',[0, 2E-4],'YLim',[0, 4E-4]);

%exportgraphics(gcf, '/ep1/home/wolfgang/Auswertung/Mikrofluidik/AuswertungKalibrierung/mf026_flow_field_calibration_yz_dependence_Q02uls.pdf', 'Resolution', 300);
figure(2);
clf;
ax=axes();
files=getFilesByRegexName(baseFolder,true,'results.mat$','mf026_200128_cal_stu01umPlain_.+uls_ch1_alpha05_z100um');% exclude 90um
[zMeasuredM,vxMeasuredMS,svxMeasuredMS]=MicrofluidicsCalibration.getCalibrationSummary(files,zRegex,par.pixelsizeM);

flowRateULS=[0.1,0.2,0.4,0.6,0.8,1.5,1,2]';
par.pistonVelocityMS=flowRateULS*1E-9./pi./(par.syringeRadiusM.^2);

vxTheoryMS=flowProfileRectangularTubeParabolicTopSyringeMS(par.widthM,par.heightCenterM,par.heightSlope,par.heightCurvatureM,0,100E-6,par.syringeRadiusM,par.pistonVelocityMS);
vxTheoryLowMS=flowProfileRectangularTubeParabolicTopSyringeMS(par.widthM,par.heightCenterM,par.heightSlope,par.heightCurvatureM,0,100E-6,par.syringeRadiusM-par.syringeRadiusErrorM,par.pistonVelocityMS);
vxTheoryHighMS=flowProfileRectangularTubeParabolicTopSyringeMS(par.widthM,par.heightCenterM,par.heightSlope,par.heightCurvatureM,0,100E-6,par.syringeRadiusM+par.syringeRadiusErrorM,par.pistonVelocityMS);



fitter=FitterPlain();
fitter.setErrorAnalysisIterCount(1000);
fitter.setModel(SimpleDriftModel());
fitter.setData(flowRateULS,vxMeasuredMS,[],svxMeasuredMS);
fitter.plotFit(ax,'k');
%fuAutosetPlotLimits(ax,0.05,0.05);
hold(gca,'on');
plot(flowRateULS,vxTheoryMS,'g-');
plot(flowRateULS,vxTheoryLowMS,'g--');
plot(flowRateULS,vxTheoryHighMS,'g--');
xlabel('Q / ul/s');
ylabel('v_x(y=0,z=h/2) / m/s');
xlim([-0.1,2.1]);

originVXOfQ=[flowRateULS,vxMeasuredMS,vxTheoryMS,vxTheoryLowMS,vxTheoryHighMS];

params=fitter.getResultParameters();
%title(['v_{x,max}=',num2str(params(1)),' m/s + ',num2str(params(2)),' m/s Q / ul/s']);

exportgraphics(gcf,'/ep1/home/wolfgang/Auswertung/Mikrofluidik/AuswertungKalibrierung/mf026_flow_field_calibration_Q_dependence.pdf',"Resolution",300);

% Höhenmessung
alpha=[0.02,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,0.98];
zBodenMf026M=[2405,2405,2406,2407,2407,2409,2410,2411,2412,2413,2414]*1E-6;
zDeckeMf026M=[2588,2595,2600,2604,2608,2610,2611,2610,2609,2604,2604]*1E-6;


figure(3);
clf;
subplot(1,3,1);
hold on;
p1=plot(alpha,zBodenMf026M,'k+');
p2=plot(alpha,zDeckeMf026M,'r+');
xlabel('alpha');
ylabel('z-z(alpha=0.02)');
xlim([-0.1,1.1]);
%ylim([-1,25]);

legend([p1,p2],{'Kanalboden (Deckglas)','Kanaldecke (Ibidi)'},'Box',false,'Location','best');
title('mf026');

ax1=subplot(1,3,2);
hold(ax1,'on');
plot(alpha,zBodenMf023M-zBodenMf023M(1),'k+');
plot(alpha,zDeckeMf023M-zDeckeMf023M(1),'r+');
title('mf023');

ax2=subplot(1,3,3);
hold(ax2,'on');
plot(alpha,zBodenMf025M-zBodenMf025M(1),'k+');
plot(alpha,zDeckeMf025M-zDeckeMf025M(1),'r+');
title('mf024');

hMf026M=zDeckeMf026M-zBodenMf026M;
yMf026M=(alpha-0.5)*5E-3;

f=FitterPlain();
f.setModel(QuadraticModel());
f.setData(yMf026M',hMf026M',[],[]);

figure(4);clf;
ax=axes();
f.plotFit(ax,'k');

param=f.getResultParameters()


























