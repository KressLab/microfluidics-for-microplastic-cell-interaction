% see Bruus, H. Theoretical Microfluidics 2006
function vxMS = flowProfileRectangularTubeMS(widthM, heightM, yM,zM,flowRateM3S)
    lengthM=1;
    dynamicViscosityPaS=1;
    pressureDifferencePa=flowResistanceRectangularTubePaSM3(widthM,heightM,lengthM,dynamicViscosityPaS)*flowRateM3S;
    vxMS=(4.*heightM.^2.*pressureDifferencePa)./(pi.^3.*dynamicViscosityPaS.*lengthM).*getAlphaRect(widthM, heightM, yM,zM);
end

