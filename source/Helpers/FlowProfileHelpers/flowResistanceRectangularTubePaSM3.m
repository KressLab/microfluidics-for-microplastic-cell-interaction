%% 
% see Bruus, H. Theoretical Microfluidics 2006
% Flow resistance of a rectangular tube
% Q=dp / resistance
%
% Q flow rate / m^3/s
% dp applied pressure difference / Pa
function resistance = flowResistanceRectangularTubePaSM3(widthM, heightM, lengthM, dynamicViscosityPaS)
    if any(isnan([widthM,heightM,lengthM,dynamicViscosityPaS]))
        resistance=nan;
        return;
    end
    minM=min([widthM,heightM]);
    maxM=max([widthM,heightM]);
    resistance=(12.*dynamicViscosityPaS.*lengthM) /(getAlphaRect(minM,maxM).*minM.^3.*maxM);
end

function alpha=getAlphaRect(minM, maxM)
    ORDERS=5;
    alpha=1;
    for i=1:2:ORDERS
        alpha=alpha-(192.*minM.*tanh(i.*pi.*maxM/(2.*minM))) ./ (i.^5.*pi.^5*maxM);
    end
end