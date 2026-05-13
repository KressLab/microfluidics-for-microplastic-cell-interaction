% ########################
% Wolfgang Gross
% University of Bayreuth
% 24.09.15
% ########################

function fuAutosetPlotLimits(handle, spreadX, spreadY)
    % Verify correct number of input arguments
    narginchk(0,3);

    % If no handle is provided, use the current figure as default
    if nargin<1
        handle = gcf;
    end
    if nargin<2
        spreadX=0.0;
    end
    if nargin<3
        spreadY=spreadX;
    end
    
    if(ishandle(handle) && strcmp(get(handle,'type'),'figure'))
        hAllAxes = findobj(handle,'type','axes');
        hLeg = findobj(hAllAxes,'tag','legend');
        hAxes = setdiff(hAllAxes,hLeg); % All axes which are not legends

        for k=1:length(hAxes)
            currAxHandle=hAxes(k,1);
            [xlimit,ylimit]=fuGetPlotLimits(currAxHandle,spreadX,spreadY);
            xlim(currAxHandle,xlimit);
            ylim(currAxHandle,ylimit);
        end
    elseif(ishandle(handle) && strcmp(get(handle,'type'),'axes'))
        [xlimit,ylimit]=fuGetPlotLimits(handle,spreadX,spreadY);
        xlim(handle,xlimit);
        ylim(handle,ylimit);
    end
end

