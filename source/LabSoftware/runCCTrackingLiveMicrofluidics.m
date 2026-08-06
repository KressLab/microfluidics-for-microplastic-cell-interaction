% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.2019
% Run this on a windows machine with the actual hardware beeing
% connected (PI C863)
% ########################
 
clear;
close all;
clc;
logger=Logger.getInstance();
logger.setCommandWindowLevel(Logger.INFO);
logger.setLogLevel(Logger.OFF);
logger.setIncludeFilter({''});

core=CCTLCore();
core.addCCTLModule(FocusMeasureModule());
core.setCamera(PCOPixelfly());
logger.warn('You might need to add the path to the folder which is installed by the PI software. In our case this was C:\Users\Public\PI')
core.addCCTLModule(MicrofluidicsModule(PI_GCS_ControllerDebugWrapper(PI_GCS_Controller())));

core.loadAndInit();
core.loadSettingsFromFile('C:\Users\Installateur\Desktop\Wolfgang\MatlabRepo\CCTrackingLive\MainConfigurations\standard_settings_cell_measurements10x.mset');