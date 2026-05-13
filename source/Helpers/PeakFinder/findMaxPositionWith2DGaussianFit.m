%  Wolfgang Gross, University of Bayreuth
%  03.04.2017
%  Subroutine to track 2D gaussian distribution
%  Input:
function [pksSubpix,pksAmp,pksBackground,pksSigma] = findMaxPositionWith2DGaussianFit(image, pks, fitRegionRadius, varargin) % oneSigma, fitRotation, plotFlag,tolerance)
   if size(varargin,2)>0
       oneSigma=varargin{1,1};
   else
       oneSigma=true;
   end
   if size(varargin,2)>1
       fitRotation=varargin{1,2};
   else
       fitRotation=false;
   end
   if size(varargin,2)>2
       plotFlag=varargin{1,3};
   else
       plotFlag=0;
   end
   if size(varargin,2)>3
       tolerance=varargin{1,4};
   else
       tolerance='DEFAULT';
   end
   
   if isempty(pks)
      pksSubpix=[];
      pksAmp=[];
      pksBackground=[];
      pksSigma=[];
      return;
   end
    if oneSigma && fitRotation
        error('Your input makes no sense.');
    end
    if plotFlag>0
        warning('Plotting not implemented yet!');
    end
    if size(pks,2)~=2
       error('You have to provide x and y data for pixelMaxPos. size(pixelMaxPos)!=(count,2)');
    end
    pksSubpix=NaN(size(pks,1),2);
    pksAmp=NaN(size(pks,1),1);
    pksBackground=NaN(size(pks,1),1);
    pksSigma=NaN(size(pks,1),2);
    
    opts = optimoptions('lsqcurvefit',...
                        'Display','off');
                    
	if ~strcmp(tolerance,'DEFAULT')
        opts.FunctionTolerance=tolerance;
        opts.StepTolerance=tolerance;
    end
	
	subimages=cell(size(pks,1));
    for i=1:size(pks,1)
        subimages{i,1}=image(pks(i,2)-fitRegionRadius:pks(i,2)+fitRegionRadius,...
                             pks(i,1)-fitRegionRadius:pks(i,1)+fitRegionRadius);
    end
                    
    for i=1:size(pks,1)   
        subimage=subimages{i,1};
        
        [X,Y] = meshgrid(-fitRegionRadius:fitRegionRadius);
        xdata = zeros(size(X,1),size(Y,2),2);
        xdata(:,:,1) = X;
        xdata(:,:,2) = Y;

        % +++ estimate start parameters for fit +++
        offs =min(min(subimage));
        amp = max(max(subimage))-min(min(subimage));
        x0 = pks(i,2);
        wx = fitRegionRadius/4;
        y0 = pks(i,1);
        wy = fitRegionRadius/4;
        phi=0;
        
        beta0 = [offs, amp, x0, wx, y0, wy, phi]; %Inital guess parameters
        
        % define lower and upper bounds [Amp,xo,wx,yo,wy,fi]
        lb = [offs-3*abs(amp),0,-fitRegionRadius,0,-fitRegionRadius,0,-pi/4];
        ub = [offs+3*abs(amp),10*abs(amp),fitRegionRadius,max([3,(fitRegionRadius)^2]),...
                fitRegionRadius,max([3,(fitRegionRadius)^2]),pi/4];
        if fitRotation
            [beta,~,~,exitflag] = lsqcurvefit(@gaussFunction2DRot,beta0,xdata,subimage,lb,ub,opts);
        else
            if oneSigma
                beta0=beta0(1:5);
                lb=lb(1:5);
                ub=ub(1:5);
                [beta,~,~,exitflag] = lsqcurvefit(@gaussFunction2DOneSigma,beta0,xdata,subimage,lb,ub,opts);
            else
                beta0=beta0(1:6);
                lb=lb(1:6);
                ub=ub(1:6);
                [beta,~,~,exitflag] = lsqcurvefit(@gaussFunction2D,beta0,xdata,subimage,lb,ub,opts);
            end
        end
        
        if exitflag<0
            error(['Something went horribly wrong here. Check your input. Is there a gauss at pixelMaxPos(',num2str(i),',:)?']);
        end
        
        pksSubpix(i,:)=[(beta(3))+pks(i,1),...
                  (beta(5))+pks(i,2)];
        pksBackground(i,1)=beta(1);
        pksAmp(i,1)=beta(2);
        pksSigma(i,1)=beta(4);
        if length(beta)>5
            pksSigma(i,2)=beta(6);
        else
            pksSigma(i,2)=beta(4);
        end
    end
end

function F = gaussFunction2DRot(param,xydata)
    % param = [offs, amp, x0, wx, y0, wy, phi]    
    if length(param)~=7
        error(['parameter size was not 7 but ',num2str(length(param)),'.']);
    end
    % transform xy data with 2D rot-matrix (rotation angle phi)
    xrot(:,:,1)= xydata(:,:,1)*cos(param(7)) - xydata(:,:,2)*sin(param(7));
    xrot(:,:,2)= xydata(:,:,1)*sin(param(7)) + xydata(:,:,2)*cos(param(7));
    % transform sigmas with 2D rot-matrix (rotation angle phi)
    x0rot = param(3)*cos(param(7)) - param(5)*sin(param(7));
    y0rot = param(3)*sin(param(7)) + param(5)*cos(param(7));
    % calc 2D transformed gaussian
    F =param(1) + param(2)*exp(-((xrot(:,:,1)-x0rot).^2/(2*param(4)^2) + (xrot(:,:,2)-y0rot).^2/(2*param(6)^2)));
end

function F = gaussFunction2D(param,xydata)
    % param = [offs, amp, x0, wx, y0, wy]    
    if length(param)~=6
        error(['parameter size was not 6 but ',num2str(length(param)),'.']);
    end
    % calc 2D transformed gaussian
    F =param(1) + param(2)*exp(-((xydata(:,:,1)-param(3)).^2/(2*param(4)^2) + (xydata(:,:,2)-param(5)).^2/(2*param(6)^2)));
end

function F = gaussFunction2DOneSigma(param,xydata)
    % param = [offs, amp, x0, w, y0]    
    if length(param)~=5
        error(['parameter size was not 6 but ',num2str(length(param)),'.']);
    end
    % calc 2D transformed gaussian
    F =param(1) + param(2)*exp(-((xydata(:,:,1)-param(3)).^2/(2*param(4)^2) + (xydata(:,:,2)-param(5)).^2/(2*param(4)^2)));
end