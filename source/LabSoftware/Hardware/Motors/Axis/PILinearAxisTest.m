classdef PILinearAxisTest < matlab.mock.TestCase
    properties(Access=private)
        logger=Logger.getInstance();
        axis;
        axisId='1';
        servoEnabled=1;
        
        % mocks for dependencies
        piGcsController;
        piGcsControllerBehaviour;
        minMotorPos=0;
        stageStartPos=10;
        maxMotorPos=20;
        currMotorPos;
        
        % constants for software limits
        minStagePosSoftwareLimit=5;
        maxStagePosSoftwareLimit=15;
        
        % for testing
        backlash=2;
        moveDistance=3;
    end
    
    methods(TestMethodSetup)
        function init(obj)
            import matlab.mock.actions.AssignOutputs;
            obj.currMotorPos=obj.stageStartPos;
            [obj.piGcsController,obj.piGcsControllerBehaviour]=...
                        obj.createMock('AddedMethods',{'SVO','FRF','VEL','qFRF','qPOS','MVR','MOV','HLT','qTMN','qTMX'});
            when(withAnyInputs(obj.piGcsControllerBehaviour.qPOS),then(AssignOutputs(obj.currMotorPos)));
            when(withAnyInputs(obj.piGcsControllerBehaviour.qTMN),then(AssignOutputs(obj.minMotorPos)));
            when(withAnyInputs(obj.piGcsControllerBehaviour.qTMX),then(AssignOutputs(obj.maxMotorPos)));
            
            obj.axis=PILinearAxis(obj.axisId, PICoordinateSystem.HARDWARE, obj.backlash);
            obj.axis.addController(obj.piGcsController);
        end
    end
    
    methods(Test)
        function shouldInitCenter(obj)  
            obj.axis.init('C');
            obj.fatalAssertCalled(obj.piGcsControllerBehaviour.FRF(obj.axisId));
            obj.assertFinishedMotorMovementRelative(-2*obj.backlash);
        end
        
        function shouldMoveLeftRight(obj)
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.stageStartPos-obj.moveDistance);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos-obj.moveDistance);
            obj.assertStagePosIs(obj.stageStartPos-obj.moveDistance);
            
            obj.axis.moveStageTo(obj.stageStartPos);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos);
        end
        
        function shouldMoveLeftRightRelative(obj)
            obj.axis.init('C');
            obj.axis.moveStageBy(-obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(-obj.moveDistance);
            obj.assertStagePosIs(obj.stageStartPos-obj.moveDistance);
            
            obj.axis.moveStageBy(obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(obj.moveDistance+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos);
        end
        
        function shouldMoveRightLeft(obj)
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.stageStartPos+obj.moveDistance);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos+obj.moveDistance+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
            
            obj.axis.moveStageTo(obj.stageStartPos);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos);
            obj.assertStagePosIs(obj.stageStartPos);
        end
        
        function shouldMoveRightLeftRelative(obj)
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(obj.moveDistance+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
            
            obj.axis.moveStageBy(-obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(-obj.moveDistance-obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos);
        end
        
        function shouldAccountForHaltDuringRightMovement(obj)
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.stageStartPos+obj.moveDistance);
            obj.axis.halt();
            obj.assertUnfinishedMotorMovementTo(obj.stageStartPos+obj.moveDistance+obj.backlash, obj.backlash/2);
            obj.assertStagePosIs(obj.stageStartPos);
            
            obj.axis.moveStageTo(obj.stageStartPos+obj.moveDistance);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos+obj.moveDistance+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
        end
        
        function shouldAccountForHaltDuringRightMovementRelative(obj)
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.moveDistance);
            obj.axis.halt();
            obj.assertUnfinishedMotorMovementRelative(obj.moveDistance+obj.backlash, obj.backlash/2);
            obj.assertStagePosIs(obj.stageStartPos);
            
            obj.axis.moveStageBy(obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(obj.moveDistance+obj.backlash/2);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
        end
        
        function shouldAccountForForHaltDuringLeftMovement(obj)
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(obj.moveDistance+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
            
            obj.axis.moveStageTo(obj.stageStartPos-obj.moveDistance);
            obj.axis.halt();
            obj.assertUnfinishedMotorMovementTo(obj.stageStartPos-obj.moveDistance, -obj.backlash/2);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
            
            obj.axis.moveStageTo(obj.stageStartPos-obj.moveDistance);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos-obj.moveDistance);
            obj.assertStagePosIs(obj.stageStartPos-obj.moveDistance);
        end
        
        function shouldAccountForForHaltDuringLeftMovementRelative(obj)
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(obj.moveDistance+obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
            
            obj.axis.moveStageBy(-obj.moveDistance);
            obj.axis.halt();
            obj.assertUnfinishedMotorMovementRelative(-obj.moveDistance-obj.backlash, -obj.backlash/2);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
            
            obj.axis.moveStageBy(-obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(-obj.moveDistance-obj.backlash/2);
            obj.assertStagePosIs(obj.stageStartPos);
        end
        
        function shouldMoveRightReverse(obj)
            obj.axis.setCoordinateSystem(PICoordinateSystem.REVERSED);
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.stageStartPos+obj.moveDistance);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos-obj.moveDistance-obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
        end
        
        function shouldMoveRightReverseRelative(obj)
            obj.axis.setCoordinateSystem(PICoordinateSystem.REVERSED);
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(-obj.moveDistance-obj.backlash);
            obj.assertStagePosIs(obj.stageStartPos+obj.moveDistance);
        end
        
        function shouldMoveLeftReverse(obj)
            obj.axis.setCoordinateSystem(PICoordinateSystem.REVERSED);
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.stageStartPos-obj.moveDistance);
            obj.assertFinishedMotorMovementTo(obj.stageStartPos+obj.moveDistance);
            obj.assertStagePosIs(obj.stageStartPos-obj.moveDistance);
        end
        
        function shouldMoveLeftReverseRelative(obj)
            obj.axis.setCoordinateSystem(PICoordinateSystem.REVERSED);
            obj.axis.init('C');
            obj.axis.moveStageBy(-obj.moveDistance);
            obj.assertFinishedMotorMovementRelative(obj.moveDistance);
            obj.assertStagePosIs(obj.stageStartPos-obj.moveDistance);
        end
        
        function shouldFetchMinMaxStagePosOnInit(obj)
            obj.axis.init('C');    
            obj.assertEqual(obj.axis.getMinStagePos(),obj.minMotorPos);
            obj.assertEqual(obj.axis.getMaxStagePos(),obj.maxMotorPos-obj.backlash);
        end
        
        function shouldMoveToMinStagePos(obj)
            obj.axis.init('C'); 
            obj.axis.moveStageTo(obj.axis.getMinStagePos());
            obj.assertFinishedMotorMovementTo(obj.minMotorPos);
        end
        
        function shouldMoveToMaxStagePos(obj)
            obj.axis.init('C'); 
            obj.axis.moveStageTo(obj.axis.getMaxStagePos());
            obj.assertFinishedMotorMovementTo(obj.maxMotorPos);
        end
        
        function shouldMoveToMinStagePosReversed(obj)
            obj.axis.setCoordinateSystem(PICoordinateSystem.REVERSED);
            obj.axis.init('C'); 
            obj.axis.moveStageTo(obj.axis.getMinStagePos());
            obj.assertFinishedMotorMovementTo(obj.maxMotorPos);
        end
        
        function shouldMoveToMaxStagePosReversed(obj)
            obj.axis.setCoordinateSystem(PICoordinateSystem.REVERSED);
            obj.axis.init('C'); 
            obj.axis.moveStageTo(obj.axis.getMaxStagePos());
            obj.assertFinishedMotorMovementTo(obj.minMotorPos);
        end
        
        function shouldMoveToLowerSoftwareStageLimit(obj)
            obj.axis.setMinStagePosSoftwareLimit(obj.minStagePosSoftwareLimit);
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.axis.getMinStagePos());
            obj.assertFinishedMotorMovementTo(obj.minStagePosSoftwareLimit);
        end
        
        function shouldMoveToUpperSoftwareStageLimit(obj)
            obj.axis.setMaxStagePosSoftwareLimit(obj.maxStagePosSoftwareLimit);
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.axis.getMaxStagePos());
            obj.assertFinishedMotorMovementTo(obj.maxStagePosSoftwareLimit+obj.backlash);
        end
        
        function shouldNotMoveBeyondLowerSoftwareStageLimitAbsolute(obj)
            obj.axis.setMinStagePosSoftwareLimit(obj.minStagePosSoftwareLimit);
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.minStagePosSoftwareLimit-.5);
            obj.assertNoMotorMovementTo(obj.minStagePosSoftwareLimit-.5);
        end
        
        function shouldNotMoveBeyondUpperSoftwareStageLimitAbsolute(obj)
            obj.axis.setMaxStagePosSoftwareLimit(obj.maxStagePosSoftwareLimit);
            obj.axis.init('C');
            obj.axis.moveStageTo(obj.maxStagePosSoftwareLimit+.5);
            obj.assertNoMotorMovementTo(obj.maxStagePosSoftwareLimit+.5);
        end
        
        function shouldNotMoveBeyondLowerSoftwareStageLimitRelative(obj)
            obj.axis.setMinStagePosSoftwareLimit(obj.minStagePosSoftwareLimit);
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.minStagePosSoftwareLimit-obj.currMotorPos-.5);
            obj.assertNoMotorMovementRelative(obj.minStagePosSoftwareLimit-obj.currMotorPos-.50);
        end
        
        function shouldNotMoveBeyondUpperSoftwareStageLimitRelative(obj)
            obj.axis.setMaxStagePosSoftwareLimit(obj.maxStagePosSoftwareLimit);
            obj.axis.init('C');
            obj.axis.moveStageBy(obj.maxStagePosSoftwareLimit-obj.currMotorPos+.5);
            obj.assertNoMotorMovementRelative(obj.maxStagePosSoftwareLimit-obj.currMotorPos+obj.backlash);
        end
    end
    
    methods(Access=private)
        function assertFinishedMotorMovementTo(obj, dest)
            import matlab.mock.actions.AssignOutputs;
            obj.currMotorPos=dest;
            obj.assertCalled(obj.piGcsControllerBehaviour.MOV(obj.axisId,dest));
            when(withAnyInputs(obj.piGcsControllerBehaviour.qPOS),then(AssignOutputs(obj.currMotorPos)));
        end
        
        function assertNoMotorMovementTo(obj,dest)
            import matlab.mock.actions.AssignOutputs;
            obj.assertNotCalled(obj.piGcsControllerBehaviour.MOV(obj.axisId,dest));
        end
        
        function assertFinishedMotorMovementRelative(obj, positionChange)
            import matlab.mock.actions.AssignOutputs;
            obj.currMotorPos=obj.currMotorPos+positionChange;
            obj.assertCalled(obj.piGcsControllerBehaviour.MVR(obj.axisId,positionChange));
            when(withAnyInputs(obj.piGcsControllerBehaviour.qPOS),then(AssignOutputs(obj.currMotorPos)));
        end
        
        function assertNoMotorMovementRelative(obj, positionChange)
            import matlab.mock.actions.AssignOutputs;
            obj.assertNotCalled(obj.piGcsControllerBehaviour.MVR(obj.axisId,positionChange));
        end
        
        function assertUnfinishedMotorMovementTo(obj, target, movedDst)
            import matlab.mock.actions.AssignOutputs;
            obj.currMotorPos=obj.currMotorPos+movedDst;
            obj.assertCalled(obj.piGcsControllerBehaviour.MOV(obj.axisId,target));
            when(withAnyInputs(obj.piGcsControllerBehaviour.qPOS),then(AssignOutputs(obj.currMotorPos)));
        end
        
        function assertUnfinishedMotorMovementRelative(obj, dst, movedDst)
            import matlab.mock.actions.AssignOutputs;
            obj.currMotorPos=obj.currMotorPos+movedDst;
            obj.assertCalled(obj.piGcsControllerBehaviour.MVR(obj.axisId,dst));
            when(withAnyInputs(obj.piGcsControllerBehaviour.qPOS),then(AssignOutputs(obj.currMotorPos)));
        end
        
        function assertStagePosIs(obj, position)
             obj.assertEqual(obj.axis.getCurrentStagePos(), position);
        end
    end
end