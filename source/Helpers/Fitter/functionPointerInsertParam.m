function newFun = functionPointerInsertParam(oldFun, param)
    arguments
        oldFun (1,1) function_handle
        param (1,:) double
    end
    newFunString=func2str(oldFun);
    for i=1:size(param,2)
        paramString=['param.',num2str(i),'.'];
        paramValueString=num2str(param(i),'%10.10e');
        newFunString=regexprep(newFunString, paramString, paramValueString);
    end
    newFunString=regexprep(newFunString, 'param,','');
    newFun=str2func(newFunString);
end