%  Wolfgang Gross, University of Bayreuth
%  03.04.2017
%  Subroutine to track 2D gaussian distribution
%  Input:
function out = findMaxPositionWith3DGaussianFit(image, pixelMaxPos, fitRegionRadius)
    logger=Logger.getInstance();
    logger.debug('Starting to find ', size(pixelMaxPos,1),' particles');
    subimages=cell(size(pixelMaxPos,1),1);
    for i=1:size(pixelMaxPos,1)
        subimages{i,1}=double(image(pixelMaxPos(i,1)-fitRegionRadius:pixelMaxPos(i,1)+fitRegionRadius,...
                          pixelMaxPos(i,2)-fitRegionRadius:pixelMaxPos(i,2)+fitRegionRadius,...
                          pixelMaxPos(i,3)-fitRegionRadius:pixelMaxPos(i,3)+fitRegionRadius));
    end
    if size(pixelMaxPos,2)~=3
       error('You have to provide x,y and z data for pixelMaxPos. size(pixelMaxPos)!=(count,3)');
    end
    out=NaN(size(pixelMaxPos,1),3);
    
    opts = optimset('Display','off');
    parfor i=1:size(pixelMaxPos,1)
        subimage=subimages{i,1};
        [X,Y,Z] = meshgrid(-fitRegionRadius:fitRegionRadius,-fitRegionRadius:fitRegionRadius,-fitRegionRadius:fitRegionRadius);
        xdata = zeros(size(X,1),size(Y,2),size(Z,3),3);
        xdata(:,:,:,1) = X;
        xdata(:,:,:,2) = Y;
        xdata(:,:,:,3) = Z;
        
        % +++ estimate start parameters for fit +++
        offs =min(min(min(subimage)));
        amp = max(max(max(subimage)))-min(min(min(subimage)));
        x0 = pixelMaxPos(i,1);
        wxy = fitRegionRadius/4;
        y0 = pixelMaxPos(i,2);
        z0 = pixelMaxPos(i,3);
        wz = fitRegionRadius/4;
        
        beta0 = [offs, amp, x0, wxy, y0, z0, wz]; %Inital guess parameters
        
        % define lower and upper bounds
        %    offs,              Amp,        xo,                wxy,                 yo,               z0,                 wz ]
        lb = [offs-3*abs(amp),  0,          -fitRegionRadius,  0,                   -fitRegionRadius, -fitRegionRadius,   0];
        ub = [offs+3*abs(amp),  10*abs(amp), fitRegionRadius,  (fitRegionRadius)^2,  fitRegionRadius,  fitRegionRadius,  (fitRegionRadius)^2];
        
        [beta,~,~,exitflag] = lsqcurvefit(@gaussFunction3DTwoSigmas,beta0,xdata,subimage,lb,ub,opts);
        
        if exitflag<0
            error(['Something went horribly wrong here. Check your input. Is there a gauss at pixelMaxPos(',num2str(i),',:)?']);
        end
        
        %wrapper for parallelization
%         out(i,1)=(beta(5))+pixelMaxPos(i,1);
%         out(i,2)=(beta(3))+pixelMaxPos(i,2);
%         out(i,3)=(beta(6))+pixelMaxPos(i,3);
        x=(beta(5))+pixelMaxPos(i,1);
        y=(beta(3))+pixelMaxPos(i,2);
        z=(beta(6))+pixelMaxPos(i,3);
        out(i,:)=[x,y,z];
    end
end



function F = gaussFunction3DTwoSigmas(param,xydata)
    % param = [offs, amp, x0, wxy, y0, z0, wz]    
    if length(param)~=7
        error(['parameter size was not 7 but ',num2str(length(param)),'.']);
    end
    % calc 2D transformed gaussian
    F =param(1) + param(2)*exp(-((xydata(:,:,:,1)-param(3)).^2/(2*param(4)^2)+ ...
                                 (xydata(:,:,:,2)-param(5)).^2/(2*param(4)^2)+ ...
                                 (xydata(:,:,:,3)-param(6)).^2/(2*param(7)^2)));
end