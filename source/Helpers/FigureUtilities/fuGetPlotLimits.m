% ########################
% Wolfgang Gross
% University of Bayreuth
% 09.07.15
% ########################
%
% returns the x and y limis of the specified axis handle

function [xlim, ylim ] = fuGetPlotLimits(axis_handle,spreadx, spready)
    narginchk(0,3);
    if(nargin<1)
        axis_handle=gca;
    end
    if(nargin<2) 
        spreadx=0.;
    end
    if(nargin<3)
        spready=spreadx;
    end

    %also supports error range in y-direction
    %plots
    children=get(axis_handle,'children');
    
    xIsLogarithmic=strcmp(get(axis_handle,'XScale'),'log');
    yIsLogarithmic=strcmp(get(axis_handle,'YScale'),'log');
    
    % standard data
    %x=get(children,'XData');
    %y=get(children,'YData');
    x=get(findobj(children,'-property','XData','Visible','on'),'XData');
    y=get(findobj(children,'-property','YData','Visible','on'),'YData');
    
    if isempty(x) && isempty(y)
       xlim(1)=0.;
       xlim(2)=1.;
       
       ylim(1)=0.;
       ylim(2)=1.;
       return;
    end
    
    % because matlab return types are guaranteed to be random...
    if ~iscell(x)
       x={x}; 
    end
    
    if ~iscell(y)
       y={y}; 
    end
    % remove empty entries
    x=x(~cellfun('isempty',x));  
    y=y(~cellfun('isempty',y)); 
    
    childrenWithErrorBarsY=children(isprop(children,'LData') & isprop(children,'UData'));
    % error range
    ey=get(childrenWithErrorBarsY,'LData');
    ey2=get(childrenWithErrorBarsY,'UData');
    
    % because matlab return types are guaranteed to be random...
    if ~isempty(ey) && ~isempty(ey2)
        for i=1:length(y)
            correctErrorBar=0;
            for k=1:length(childrenWithErrorBarsY)
                if children(i)==childrenWithErrorBarsY(k)
                    correctErrorBar=k;
                end
            end
            if (correctErrorBar~=0)
                ytemp=y{i};
                y{i}=ytemp-ey{correctErrorBar};
                y{i}=[y{i};ytemp+ey2{correctErrorBar}];
            end
        end
    end
    
    x{1}(x{1}==Inf)=[];
    x{1}(x{1}==-Inf)=[];
    y{1}(y{1}==Inf)=[];
    y{1}(y{1}==-Inf)=[];
    
    % might be empty now
    if isempty(x{1})
        x{1}=NaN;
    end
    if isempty(y{1})
        y{1}=NaN;
    end
    
    xlim=[nanmin(double(cellfun(@nanmin, x))) nanmax(double(cellfun(@nanmax, x)))];
    ylim=[nanmin(cellfun(@nanmin, y)) nanmax(cellfun(@nanmax, y))];
    
    [xlim(1),xlim(2)]=checkNan(xlim(1),xlim(2));
    [ylim(1),ylim(2)]=checkNan(ylim(1),ylim(2));
    
    
    % add a little bit of spread to make the plot look nice
    if xIsLogarithmic
        xlim(1)=xlim(1)*(1-spreadx);
        xlim(2)=xlim(2)*(1+spreadx);
    else
        spreadX=abs(xlim(2)-xlim(1))*spreadx;
        xlim(1)=xlim(1)-spreadX;
        xlim(2)=xlim(2)+spreadX;
    end
    
    if yIsLogarithmic
        ylim(1)=ylim(1)*(1-spready);
        ylim(2)=ylim(2)*(1+spready);
    else
        spreadY=abs(ylim(2)-ylim(1))*spready;
        ylim(1)=ylim(1)-spreadY;
        ylim(2)=ylim(2)+spreadY;
    end
    
    % test if the same
    SPREAD_IF_IDENTICAL=0.001;
    if xlim(1)==xlim(2)
        xlim(1)=xlim(1)-SPREAD_IF_IDENTICAL;
        xlim(2)=xlim(2)+SPREAD_IF_IDENTICAL;
    end
    if ylim(1)==ylim(2)
        ylim(1)=ylim(1)-SPREAD_IF_IDENTICAL;
        ylim(2)=ylim(2)+SPREAD_IF_IDENTICAL;
    end
end

function [val1,val2]=checkNan(val1, val2)
    if isnan(val1) || isnan(val2)
        val1=0;
        val2=1;
    end
end

