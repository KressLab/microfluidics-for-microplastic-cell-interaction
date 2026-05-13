function fitAndPlotVXofZ(ax,zMeasuredM,vxMeasuredMS,svxMeasuredMS,par,baseFolder,showLegend,titleString)
    if nargin<8
        [~,baseFolder]=fileparts(baseFolder);
        titleString=[baseFolder,', drift correction:',num2str(par.driftZM/1E-6),'um'];
    end

    zMeasuredM=zMeasuredM+par.driftZM*(1-zMeasuredM/par.heightCenterM);
    zErrorMeasured=ones(size(zMeasuredM)).*par.zErrorM;

    hRealM=par.heightCenterM+par.heightSlope.*par.yM+par.heightCurvatureM*par.yM^2;
    
    fitter=FitterPlain();
    fitter.setErrorAnalysisIterCount(1000);
    fitter.setModel(VelocityProfileModel(par.widthM, hRealM, par.yM));
    fitter.setData(zMeasuredM, vxMeasuredMS, par.zErrorM*ones(size(zMeasuredM)), svxMeasuredMS);
    resParam=fitter.getResultParameters();

    zTheoryM=linspace(0,hRealM,100)';
    vxTheoryMS=flowProfileRectangularTubeParabolicTopSyringeMS(par.widthM,par.heightCenterM,par.heightSlope,par.heightCurvatureM,par.yM,zTheoryM,par.syringeRadiusM,par.pistonVelocityMS);
    %vxTheoryMS=flowProfileRectangularTubeSyringeMS(par.widthM,par.heightCenterM,par.yM,zTheoryM,par.syringeRadiusM,par.pistonVelocityMS);
    vxTheoryErrorMS=flowProfileRectangularTubeSyringeErrorMS(par.widthM,par.widthErrorM,par.heightCenterM,par.heightErrorM,par.yM,par.yErrorM,...
                                                             zTheoryM,par.zErrorM,par.syringeRadiusM,par.syringeRadiusErrorM,par.pistonVelocityMS,par.pistonVelocityErrorMS);
                                                         
    vxTheoryMSPlus=vxTheoryMS+vxTheoryErrorMS;
    vxTheoryMSMinus=vxTheoryMS-vxTheoryErrorMS;

    fp=fitter.plotFit(ax,'r');
    hold(ax,'on');
    p1=plot(zTheoryM, vxTheoryMS, 'k-');
    p2=plot(zTheoryM, vxTheoryMSPlus, 'k-.');
    p3=plot(zTheoryM, vxTheoryMSMinus, 'k-.');
    
    xlabel('z/m');
    ylabel('v_x / m/s');
    
    title(titleString,'interpreter','none');
    if showLegend
        legend([fp(1),fp(5),p1],{'measured velocity','fit','prediction from motor velocity'},'Box',false,'FontSize',9,'Location','best');
    end

    f=fitter.getModelFunWParams();
    

    % for origin plot
    vxFitMean=fitter.getFitFunMean();
    vxFitErrorPlus=vxFitMean+fitter.getFitFunStd();
    vxFitErrorMinus=vxFitMean-fitter.getFitFunStd();

    originFitTable=[zMeasuredM, vxFitMean, vxFitErrorPlus, vxFitErrorMinus];
    originMeasuredTable=[zMeasuredM, zErrorMeasured, vxMeasuredMS,  svxMeasuredMS];
    originTheoryTable=[zTheoryM,vxTheoryMS,vxTheoryMSPlus,vxTheoryMSMinus];
end