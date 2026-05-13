classdef MicrofluidicsModule < CCTLModule
    properties(Access=public)
        piController;
        axis;
        
        heightProfile;
        
        PISTON_MAX_VELOCITY_MMS=6;
        continuosFlowDirectionForward=true;
        MIN_STAGE_POS_SOFTWARE_LIMIT=6.79;
        MAX_STAGE_POS_SOFTWARE_LIMIT=51.99;
        
        FLOW_PROFILE_FIGURE_NUMBER=5;
        
        recordedFlowRateM3S;
    end
    
    methods(Access=public)
        function obj=MicrofluidicsModule(piGcsController)
            obj.piController=PIC863Controller(piGcsController);
            obj.heightProfile=HeightProfile();
        end
        
        function load(obj)
            obj.cctliveViewer.addModulePanel(CCTLControlPanelMicrofluidics());
        end
        
        function init(obj)
            obj.logger.debug('Initializing');
            
            obj.piController.testConnectedAxes();
            obj.axis=PILinearAxis('1', PICoordinateSystem.HARDWARE, 0.0008); % backlash 0.0008mm, L511 20DG10
            obj.axis.setKeyboardControl('Right','Left');
            obj.axis.setMinStagePosSoftwareLimit(obj.MIN_STAGE_POS_SOFTWARE_LIMIT);
            obj.axis.setMaxStagePosSoftwareLimit(obj.MAX_STAGE_POS_SOFTWARE_LIMIT);
            obj.axis.setRecordStageVelocity(true);
            obj.piController.connectTo(obj.axis);
            
            obj.cctliveViewer.setUiCallback('Init Stage',@obj.initStage);
            obj.cctliveViewer.setUiCallback('Channel Width/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Channel Width Error/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Channel Height/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Channel Height Error/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Channel Length/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('ShowHeightProfileFit',@obj.showHeightProfileFit);
            obj.cctliveViewer.setUiCallback('ChannelHeightProfileValues/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('y Error/um',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('z Error/um',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Viscosity/PaS',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Syringe Radius/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Syringe Radius Error/mm',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('ParticleRadius/um',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Position/mm',@obj.goToPosition);
            
            obj.cctliveViewer.setUiCallback('ForceOnParticle/pN',@obj.updateForce);
            obj.cctliveViewer.setUiCallback('Flow Rate/ul/s',@obj.updateFlowRate);
            obj.cctliveViewer.setUiCallback('Set Syringe Full',@obj.setSyringeFullPosition);
            obj.cctliveViewer.setUiCallback('Set Syringe Empty',@obj.setSyringeEmptyPosition);
            obj.cctliveViewer.setUiCallback('Go To Syringe Full Position',@obj.goToSyringeFull);
            obj.cctliveViewer.setUiCallback('Go To Syringe Empty Position',@obj.goToSyringeEmpty);
            obj.cctliveViewer.setUiCallback('Keyboard Control',@obj.toggleKeyboardControl);
            obj.cctliveViewer.setUiCallback('Continuous Flow',@obj.toggleContinuousFlow);
            obj.cctliveViewer.setUiCallback('ShowFlowProfile',@obj.showFlowProfile);
            obj.cctliveViewer.setUiCallback('Stop Pumping',@obj.stopPumping);
            
            obj.cctliveViewer.highlightControl('Stop Pumping','r');
            
            % guarantee force update
            obj.updateForceAndFlowRate();
        end
        
        function onStartLive(obj)
            if ~obj.piController.allInitialized()
                obj.logger.fatal('Initialize stages first!');
            end
        end
        
        function startLive(obj)
            obj.piController.startRecording();
        end
        
        function onUpdateLive(obj)
            obj.updateAxisControl();
        end
        
        function updateLive(obj)
            obj.updatePositionDisplay();
            obj.updateContinuosFlow();
        end
        
        function stopLive(obj)
            obj.piController.haltAll();
            obj.piController.stopRecording();
        end
        
        function onStartRun(obj)
             if ~obj.piController.allInitialized()
                obj.logger.fatal('Initialize stages first!');
             end
        end
        
        function startRun(obj)
            obj.piController.startRecording();
            obj.recordedFlowRateM3S=obj.getCurrentFlowRateM3S();
        end
        
        function onUpdateRun(obj)
            obj.updateAxisControl();
        end
        
        function updateRun(obj)
            obj.updatePositionDisplay();
            obj.updateContinuosFlow();
            obj.recordedFlowRateM3S(end+1,1)=obj.getCurrentFlowRateM3S();
        end
        
        function stopRun(obj)
            obj.piController.haltAll();
            obj.piController.stopRecording();
        end
        
        function onImageDimensionChange(~)
        end
        
        function onRenderLive(~)
        end
        
        function onRenderRun(~)
        end
        
        function cctlResult=appendToSave(obj,cctlResult)
            widthM=obj.cctliveViewer.getNumValue('Channel Width/mm')*1E-3;
            heightM=obj.cctliveViewer.getNumValue('Channel Height/mm')*1E-3;
            particleRadiusM=obj.cctliveViewer.getNumValue('ParticleRadius/um')*1E-6;
            viscosityPaS=obj.cctliveViewer.getNumValue('Viscosity/PaS');
            
            stagePositionM=obj.axis.getRecordedStagePositions()*1E-3;
            stageVelocityMS=obj.axis.getRecordedStageVelocities()*1E-3;
            stageMovementDirection=sign(stageVelocityMS);
            
            effectiveChannelHeightM=obj.getEffectiveHeigthtM();
            
            % estimate the force on a particle near the surface with the
            % average velocity of the flow far away from the particle at
            % z=R (stokes drag)
            yM=0; % middle of the channel
            zM=particleRadiusM;

            vxMS=flowProfileRectangularTubeMS(widthM,heightM,yM,zM,obj.recordedFlowRateM3S); 
            dragForceApproxXN=6.*pi.*viscosityPaS.*particleRadiusM.*vxMS.*stageMovementDirection;
            
            cFlat=0.00256.*(particleRadiusM./1E-6).^2+0.06962*particleRadiusM/1E-6+1.50757;
            cHeightCorr=heightM.^3./effectiveChannelHeightM.^3;
            dragForceSimLehmanXN=36.*pi.*cHeightCorr.*cFlat*viscosityPaS.*obj.recordedFlowRateM3S.*particleRadiusM.^2.*(heightM-particleRadiusM)./(heightM.^3*widthM);
            
            cctlResult.microfluidics.flowRateM3S=obj.recordedFlowRateM3S.*stageMovementDirection;
            cctlResult.microfluidics.positionM=stagePositionM;
            cctlResult.microfluidics.stageVelocityMS=stageVelocityMS;
            cctlResult.microfluidics.stageMovementDirection=stageMovementDirection;
            cctlResult.microfluidics.dragForceApproxXN=dragForceApproxXN;
            cctlResult.microfluidics.dragForceSimLehmanXN=dragForceSimLehmanXN.*stageMovementDirection;
            obj.logger.debug('Appending to save.');
        end
    end
    
    methods(Access=private)
        function frM3S=getCurrentFlowRateM3S(obj)
            frM3S=obj.cctliveViewer.getNumValue('Flow Rate/ul/s').*double(obj.axis.isMoving())/1.0e9;
        end
        
        function goToSyringeFull(obj,~,~)
            obj.logger.debug('Moving to syringe full position.');
            obj.axis.moveStageTo(obj.cctliveViewer.getNumValue('Syringe Full Position/mm'));
        end
        
        function goToSyringeEmpty(obj,~,~)
            obj.logger.debug('Moving to syringe empty position.');
            obj.axis.moveStageTo(obj.cctliveViewer.getNumValue('Syringe Empty Position/mm'));
        end
        
        function showHeightProfileFit(obj,~,~)
           success=obj.heightProfile.setProfileString(obj.cctliveViewer.getString('ChannelHeightProfileValues/mm'));
           if success
               obj.heightProfile.showFit(obj.cctliveViewer.getNumValue('Channel Width/mm')*1E-3);
           end
        end
        
        function stopPumping(obj,~,~)
            obj.piController.haltAll();
            obj.cctliveViewer.setValue('Keyboard Control', 0);
            obj.cctliveViewer.highlightControl('Keyboard Control','off');
            obj.cctliveViewer.setValue('Continuous Flow', 0);
            obj.cctliveViewer.highlightControl('Continuous Flow','off');
            obj.logger.debug('Stopping pump.');
        end
        
        function updateAxisControl(obj)
            obj.logger.trace('Updating axis control');
            obj.piController.update();
            obj.cctliveViewer.setString('Position/mm',num2str(obj.axis.getLastRecordedStagePosition()));
            obj.updateForceAndFlowRate();
        end
        
        function hEffM=getEffectiveHeigthtM(obj)
            if ~obj.runHeightProfileCorrection()
                hEffM=obj.cctliveViewer.getNumValue('Channel Height/mm')*1E-3;
                return;
            end
            success=obj.heightProfile.setProfileString(obj.cctliveViewer.getString('ChannelHeightProfileValues/mm'));
            if success
                obj.cctliveViewer.doAction('setHeightProfileWarning',0);
                hEffM=obj.heightProfile.getHEffM(obj.cctliveViewer.getNumValue('Channel Width/mm')*1E-3);
            else
                obj.cctliveViewer.doAction('setHeightProfileWarning',1);
                hEffM=NaN;
            end
        end
        
        function run=runHeightProfileCorrection(obj)
            profileString=obj.cctliveViewer.getString('ChannelHeightProfileValues/mm');
            run=~isempty(strtrim(profileString));
        end
        
        function updatePositionDisplay(obj)
            obj.logger.trace('Updating position display');
            obj.cctliveViewer.setString('Position/mm',num2str(obj.axis.getLastRecordedStagePosition()));
        end
            
        function initStage(obj,~,~)
            obj.logger.debug('Initializing axes control.');
            obj.cctliveViewer.doAction('microfluidicsStageInitialized');
            obj.axis.init('C');
            while ~obj.axis.isInitialized()
                pause(0.05);
            end
            obj.cctliveViewer.setString('Position/mm',obj.axis.getCurrentStagePos());
            
            obj.cctliveViewer.setString('Syringe Empty Position/mm',obj.axis.getMinStagePos());
            obj.cctliveViewer.setString('Syringe Full Position/mm',obj.axis.getMaxStagePos());
            obj.updateForceAndFlowRate();
        end
        
        function setSyringeFullPosition(obj,~,~)
            obj.cctliveViewer.setString('Syringe Full Position/mm',obj.axis.getCurrentStagePos());
        end
        
        function setSyringeEmptyPosition(obj,~,~)
            obj.cctliveViewer.setString('Syringe Empty Position/mm',obj.axis.getCurrentStagePos());
        end
        
        function updateForce(obj,~,evnt)
            if exist('evnt','var') && strcmp(evnt.EventName,'Action')
                % udpate flow rate only when user entered new force
                % value
                
                channelWidthM=obj.cctliveViewer.getNumValue('Channel Width/mm')*1E-3;
                channelHeightM=obj.cctliveViewer.getNumValue('Channel Height/mm')*1E-3;
                viscosityPaS=obj.cctliveViewer.getNumValue('Viscosity/PaS');
                particleRadiusM=obj.cctliveViewer.getNumValue('ParticleRadius/um')*1E-6;
                forceN=obj.cctliveViewer.getNumValue('ForceOnParticle/pN')*1E-12;

                effectiveChannelHeightM=obj.getEffectiveHeigthtM();
                cHeightCorr=effectiveChannelHeightM.^3./channelHeightM.^3;
                
                % model by Lehmann et al (Gekle Group)
                cFlat=0.00256.*(particleRadiusM./1E-6).^2+0.06962*particleRadiusM/1E-6+1.50757;
                flowRateM3S=cHeightCorr*(forceN.*channelHeightM.^3*channelWidthM)./(36.*pi.*cFlat*viscosityPaS.*particleRadiusM.^2.*(channelHeightM-particleRadiusM));
                obj.cctliveViewer.setString('Flow Rate/ul/s',round(flowRateM3S/1E-9,5,'significant'));
                obj.updateFlowRate();
            end
        end
        
        function updateFlowRate(obj,~,evnt)
            obj.logger.trace('Updating flow rate and axis velocity');
            newFlowRateUlS=obj.cctliveViewer.getNumValue('Flow Rate/ul/s');
            syringeRadiusMm=obj.cctliveViewer.getNumValue('Syringe Radius/mm');
            channelWidthM=obj.cctliveViewer.getNumValue('Channel Width/mm')*1E-3;
            channelHeightM=obj.cctliveViewer.getNumValue('Channel Height/mm')*1E-3;
            channelLengthM=obj.cctliveViewer.getNumValue('Channel Length/mm')*1E-3;
            viscosityPaS=obj.cctliveViewer.getNumValue('Viscosity/PaS');
            particleRadiusM=obj.cctliveViewer.getNumValue('ParticleRadius/um')*1E-6;
            
            newVelocityMmS=newFlowRateUlS/(syringeRadiusMm^2*pi);
            if newVelocityMmS>obj.PISTON_MAX_VELOCITY_MMS
                newVelocityMmS=obj.PISTON_MAX_VELOCITY_MMS;                
                newFlowRateUlS=newVelocityMmS.*syringeRadiusMm.^2*pi;
                obj.cctliveViewer.setString('Flow Rate/ul/s',round(newFlowRateUlS,5,'significant'));
            end
            obj.piController.setVel(newVelocityMmS);
            obj.cctliveViewer.setString('PistonVelocity/mm/s',round(newVelocityMmS,3,'significant'));
            
            effectiveChannelHeightM=obj.getEffectiveHeigthtM();
            pressureDropChannelBar=newFlowRateUlS*1E-9*flowResistanceRectangularTubePaSM3(channelWidthM,effectiveChannelHeightM,channelLengthM,viscosityPaS)/1E5;
            obj.cctliveViewer.setString('Pressure Drop Sample/Bar',round(pressureDropChannelBar,3,'significant'));
            
            if exist('evnt','var') && strcmp(evnt.EventName,'Action')
                % udpate force only when user entered new flow rate
                % model by Lehmann et al (Gekle Group)
                cFlat=0.00256.*(particleRadiusM./1E-6).^2+0.06962*particleRadiusM/1E-6+1.50757;
                cHeightCorr=channelHeightM.^3./effectiveChannelHeightM.^3;
                newForceN=36.*pi.*cHeightCorr*cFlat*viscosityPaS.*newFlowRateUlS.*1E-9.*particleRadiusM.^2.*(channelHeightM-particleRadiusM)./(channelHeightM.^3*channelWidthM);
                obj.cctliveViewer.setString('ForceOnParticle/pN',round(newForceN./1E-12,5,'significant'));
            end
        end
        
        function showFlowProfile(obj,~,~)
            obj.logger.debug('Showing flow profile.');
            widthM=obj.cctliveViewer.getNumValue('Channel Width/mm')*1E-3;
            heightM=obj.cctliveViewer.getNumValue('Channel Height/mm')*1E-3;
            flowRateM3S=obj.cctliveViewer.getNumValue('Flow Rate/ul/s')*1E-9;
            widthErrorM=obj.cctliveViewer.getNumValue('Channel Width Error/mm')*1E-3;
            heightErrorM=obj.cctliveViewer.getNumValue('Channel Height Error/mm')*1E-3;
            yErrorM=obj.cctliveViewer.getNumValue('y Error/um')*1E-6;
            zErrorM=obj.cctliveViewer.getNumValue('z Error/um')*1E-6;
            syringeRadiusM=obj.cctliveViewer.getNumValue('Syringe Radius/mm')*1E-3;
            syringeRadiusError=obj.cctliveViewer.getNumValue('Syringe Radius Error/mm')*1E-3;
            pistonVelocityMS=obj.cctliveViewer.getNumValue('PistonVelocity/mm/s')*1E-3;
            pistonVelocityErrorMS=obj.cctliveViewer.getNumValue('PistonVelocity Error/mm/s')*1E-3;
            
            yZDependenceM=0; % middle of the channel
            zZDependenceM=linspace(0,heightM,100);

            vxZDependenceMS=flowProfileRectangularTubeMS(widthM,heightM,yZDependenceM,zZDependenceM,flowRateM3S);
            vxErrorMS=flowProfileRectangularTubeSyringeErrorMS(widthM,widthErrorM, heightM,heightErrorM, yZDependenceM,yErrorM,zZDependenceM,zErrorM,syringeRadiusM,syringeRadiusError,pistonVelocityMS,pistonVelocityErrorMS);
            vxAvg=flowRateM3S./(widthM*heightM);
            
            yYDependenceM=linspace(-widthM/2,widthM/2,100);
            zYDependenceM=obj.cctliveViewer.getNumValue('ParticleRadius/um')*1E-6;
            vxYDependenceMS=flowProfileRectangularTubeMS(widthM,heightM,yYDependenceM,zYDependenceM,flowRateM3S);
            
            fxYDependenceMS=6.*pi.*obj.cctliveViewer.getNumValue('Viscosity/PaS').*obj.cctliveViewer.getNumValue('ParticleRadius/um')*1E-6.*vxYDependenceMS;
            
           
            f=figure(obj.FLOW_PROFILE_FIGURE_NUMBER);
            set(f,'WindowKeyPressFcn', @obj.nullfun,...
                  'WindowKeyReleaseFcn', @obj.nullfun);
            clf;
            ax1=subplot(1,3,1);
            hold(ax1,'on');
            title('vx(y=0,z)');
            plot(vxZDependenceMS,zZDependenceM,'k-');
            plot(vxZDependenceMS+vxErrorMS,zZDependenceM,'k.');
            plot(vxZDependenceMS-vxErrorMS,zZDependenceM,'k.');
            plot([vxAvg,vxAvg],[zZDependenceM(1),zZDependenceM(end)],'r-');
            xlabel('vx / m/s');
            ylabel('z / m');
            legend({'y=0','cross section average'});
            fuAutosetPlotLimits(f,0,0);
            
            ax2=subplot(1,3,2);
            hold(ax2,'on');
            title(['vx(y,z=',num2str(obj.cctliveViewer.getNumValue('ParticleRadius/um')),'um)']);
            plot(vxYDependenceMS,yYDependenceM,'k-');
            xlabel('vx / m/s');
            ylabel('y / m');
            
            ax3=subplot(1,3,3);
            hold(ax3,'on');
            title('Force Approximation');
            plot(fxYDependenceMS,yYDependenceM,'k-');
            xlabel('Fx / N');
            ylabel('y / m');
        end
        
        function goToPosition(obj,~,evnt)
            if exist('evnt','var') && strcmp(evnt.EventName,'Action')
                targetPos=obj.cctliveViewer.getNumValue('Position/mm');
                targetPos=clampMatrix(targetPos,obj.MIN_STAGE_POS_SOFTWARE_LIMIT,obj.MAX_STAGE_POS_SOFTWARE_LIMIT);
                obj.axis.moveStageTo(targetPos);
            end
        end
        
        function toggleContinuousFlow(obj,~,~)
            if obj.cctliveViewer.getNumValue('Continuous Flow')
                obj.cctliveViewer.highlightControl('Continuous Flow','g');
            else
                obj.piController.haltAll();
                obj.cctliveViewer.highlightControl('Continuous Flow','off');                
            end
        end
        
        function toggleKeyboardControl(obj,~,~)
            if obj.cctliveViewer.getNumValue('Keyboard Control')
                obj.piController.haltAll();
                obj.updateForceAndFlowRate();
                obj.axis.enableKeyboardControl();
                obj.cctliveViewer.highlightControl('Keyboard Control','g');
                obj.logger.debug('Keyboard control enabled');
            else
                obj.axis.disableKeyboardControl();
                obj.cctliveViewer.highlightControl('Keyboard Control','off');
                obj.logger.debug('Keyboard control disabled');
            end
        end
        
        function updateContinuosFlow(obj)
            if ~obj.cctliveViewer.getNumValue('Continuous Flow')
                return;
            end
            obj.logger.trace('Updating continuous flow');
            if obj.continuosFlowDirectionForward && ~obj.axis.isMoving()
                obj.axis.moveStageTo(obj.cctliveViewer.getNumValue('Syringe Full Position/mm'));
                obj.continuosFlowDirectionForward=false;
                obj.logger.debug('Updating continuous flow: moving to syringe full position');
            elseif ~obj.continuosFlowDirectionForward && ~obj.axis.isMoving()
                obj.axis.moveStageTo(obj.cctliveViewer.getNumValue('Syringe Empty Position/mm'));
                obj.continuosFlowDirectionForward=true;
                obj.logger.debug('Updating continuous flow: moving to syringe empty position');
            end
        end
        
        function nullfun(~,~,~)
        end
        
        function updateForceAndFlowRate(obj)
            evnt=struct();
            evnt.EventName='Action';
            obj.updateFlowRate([],evnt);
        end
    end
end

