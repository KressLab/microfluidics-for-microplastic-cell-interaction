% see Bruus, H. Theoretical Microfluidics 2006
function vxMS = flowProfileRectangularTubeParabolicTopSyringeMS(widthM, heightCenterM,heightSlope,heightCurvatureM, yM,zM,syringeRadiusM,pistonVelocityMS)
    vxMS=flowProfileRectangularTubeParabolicTopMS(widthM, heightCenterM,heightSlope,heightCurvatureM, yM,zM,syringeRadiusM.^2.*pi.*pistonVelocityMS);
end