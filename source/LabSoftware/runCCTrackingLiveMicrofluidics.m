%Copyright 2026 Wolfgrang Gross, Matteo Kumar
%
%Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
%
%Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
%Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
%Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
%
%THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
%STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
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
