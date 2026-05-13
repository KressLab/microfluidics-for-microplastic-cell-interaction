%  Wolfgang Gross, University of Bayreuth
%  03.04.2017
%  Subroutine to track 2D gaussian distribution
%  Input:
function [pksSubpix,pksAmp,pksBackground,pksSigma] = findMaxPositionWith1DGaussianFit(vector, pks, fitRegionRadius)
   if isempty(pks)
      pksSubpix=[];
      pksAmp=[];
      pksBackground=[];
      pksSigma=[];
      return;
   end
    if size(pks,2)~=1
       error('You have to provide x data for pixelMaxPos. size(pixelMaxPos)!=(count,1)');
    end
    pksSubpix=NaN(size(pks,1),1);
    pksAmp=NaN(size(pks,1),1);
    pksBackground=NaN(size(pks,1),1);
    pksSigma=NaN(size(pks,1),1);
    
    opts = optimoptions('lsqcurvefit',...
                        'Display','off');
                
	subvectors=cell(size(pks,1));
    for i=1:size(pks,1)
        subvectors{i,1}=vector(pks(i,1)-fitRegionRadius:pks(i,1)+fitRegionRadius);
    end
                    
    for i=1:size(pks,1)   
        subvector=subvectors{i,1};
        xdata = (-fitRegionRadius:fitRegionRadius)';
        % +++ estimate start parameters for fit +++
        offs =min(subvector);
        amp = max(subvector)-min(subvector);
        x0 = 0;
        sigma = fitRegionRadius/4;
        
        beta0 = [offs, amp, x0, sigma]; %Inital guess parameters
        
        % define lower and upper bounds [Amp,xo,wx,yo,wy,fi]
        lb = [offs-3*abs(amp),0,-fitRegionRadius,0];
        ub = [offs+3*abs(amp),10*abs(amp),fitRegionRadius,max([3,(fitRegionRadius)^2])];

        [beta,~,~,exitflag] = lsqcurvefit(@gaussFunction1D,beta0,xdata,subvector,lb,ub,opts);
        
        if exitflag<0
            l=Logger.getInstance();
            l.fatal(['Something went horribly wrong here. Check your input. Is there a gauss at pixelMaxPos(',num2str(i),',:)?']);
        end
        
        pksSubpix(i,1)=(beta(3))+pks(i,1);
        pksBackground(i,1)=beta(1);
        pksAmp(i,1)=beta(2);
        pksSigma(i,1)=beta(4);
    end
end

function F = gaussFunction1D(param,xdata)
    % param = [offs, amp, x0, w, y0]    
    if length(param)~=4
        error(['parameter size was not 4 but ',num2str(length(param)),'.']);
    end
    % calc 2D transformed gaussian
    F =param(1) + param(2)*exp(-((xdata-param(3)).^2/(2*param(4)^2)));
end