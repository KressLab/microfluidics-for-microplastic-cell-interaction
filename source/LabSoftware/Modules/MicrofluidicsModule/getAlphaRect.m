function alpha=getAlphaRect(widthM, heightM, yM,zM)
    ORDERS=10;
    alpha=0;
    for i=1:2:ORDERS
        alpha=alpha+sin(i.*pi.*zM./heightM)./(i.^3).*(1-(cosh(i.*pi.*yM./heightM)./(cosh(i.*pi.*widthM./2./heightM))));
    end
end