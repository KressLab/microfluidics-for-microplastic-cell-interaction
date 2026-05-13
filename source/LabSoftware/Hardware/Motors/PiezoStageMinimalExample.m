% A minimal example of how to implement the PI axis matlab interface.

clear;
l=Logger.getInstance();
l.setCommandWindowLevel(Logger.ALL);


%controller=PIE545Controller(PI_GCS_ControllerDebugWrapper(PI_GCS_Controller()));
controller=PIE545Controller(PI_GCS_ControllerDebugWrapper(PI_GCS_ControllerMock({'A','B','C'})));
axisX=PIPiezoAxis('A',PICoordinateSystem.HARDWARE,0.000);
axisX.setKeyboardControl('Right','Left');

axisY=PIPiezoAxis('B',PICoordinateSystem.REVERSED,0.000);
axisY.setKeyboardControl('Up','Down');

axisZ=PIPiezoAxis('C',PICoordinateSystem.REVERSED,0.000);
axisZ.setKeyboardControl('Up','Down');

controller.connectTo(axisX);
controller.connectTo(axisY);
controller.connectTo(axisZ);
axisX.init('C');
axisY.init('C');
axisZ.init('C');
axisZ.moveStageTo(axisZ.getMaxStagePos());

while controller.isAnyMoving()
    pause(0.1);
end

%%
t=tic;
N=100;
axisY.moveStageBy(10);
axisZ.moveStageBy(-5);
for i=1:N
    pos=axisX.getCurrentStagePos();
    controller.setVel([i/100,i/200,i/300]);
    l.info('XPos: ',axisX.getCurrentStagePos());
    l.info('YPos: ',axisY.getCurrentStagePos());
    l.info('ZPos: ',axisZ.getCurrentStagePos());
    pause(0.05);
end
disp(toc(t));