% ########################
% Wolfgang Gross
% University of Bayreuth
% 26.03.2019
% Run this on a windows machine without the actual hardware beeing
% connected to test the main functionality of the code. The hardware is not
% accessed.
% ########################
 
clear;
close all;
clc;
logger=Logger.getInstance();
logger.setCommandWindowLevel(Logger.DEBUG);
logger.setLogLevel(Logger.OFF);
logger.setIncludeFilter({'PI_GCS_ControllerDebugWrapper'});

core=CCTLCore();
core.setCamera(FileCameraTiff());
core.addCCTLModule(MicrofluidicsModule(PI_GCS_ControllerDebugWrapper(PI_GCS_ControllerMock({'1'}))));

core.loadAndInit();