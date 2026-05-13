% ########################
% Wolfgang Gross
% University of Bayreuth
% 15.09.15
% ########################

% STEP1: get mex -setup going in matlab

% STEP2: compile
% #######################################################################################
% Linux gcc
% #######################################################################################
if isunix()
    mex -O CFLAGS="\$CFLAGS -std=c99 -O2 -DDATATYPE=0" pkfnd1DC.c -output pkfnd1DCDouble.mexa64
    mex -O CFLAGS="\$CFLAGS -std=c99 -O2 -DDATATYPE=1" pkfnd1DC.c -output pkfnd1DCUInt16.mexa64
    mex -O CFLAGS="\$CFLAGS -std=c99 -O2 -DDATATYPE=0" pkfnd2DC.c -output pkfnd2DCDouble.mexa64
    mex -O CFLAGS="\$CFLAGS -std=c99 -O2 -DDATATYPE=1" pkfnd2DC.c -output pkfnd2DCUInt16.mexa64
    mex -O CFLAGS="\$CFLAGS -std=c99 -O2 -DDATATYPE=0" pkfnd3DC.c -output pkfnd3DCDouble.mexa64
    mex -O CFLAGS="\$CFLAGS -std=c99 -O2 -DDATATYPE=1" pkfnd3DC.c -output pkfnd3DCUInt16.mexa64
end
% #######################################################################################
% Intel compiler (ICL 2011) with VisualStudio 2013 Linker on Win7 64bit (32bit unchecked)
% #######################################################################################
% FLAGS:
% /O2                         optimization level
% /Qstd=c99                   c99-standard
% /Qvec-report2               vectorization report
% /Qopt-report-phase:ipo_inl  shows inlining
% mex COMPFLAGS='$COMPFLAGS /arch:SSE4.2 /O2 /Qstd=c99 /Qvec-report2 /Qopt-report-phase:ipo_inl' pkfndC.c -output pkfndC.mexw64 

% #######################################################################################
% 'Microsoft Visual C++ 2013 Professional (C)' on Win7 64bit (32bit unchecked)
% #######################################################################################
% FLAGS:
if ispc()
    mex COMPFLAGS='/DDATATYPE=0' pkfnd1DC.c -output pkfnd1DCDouble.mexw64 
    mex COMPFLAGS='/DDATATYPE=1' pkfnd1DC.c -output pkfnd1DCUInt16.mexw64 
    mex COMPFLAGS='/DDATATYPE=0' pkfnd2DC.c -output pkfnd2DCDouble.mexw64 
    mex COMPFLAGS='/DDATATYPE=1' pkfnd2DC.c -output pkfnd2DCUInt16.mexw64 
    mex COMPFLAGS='/DDATATYPE=0' pkfnd3DC.c -output pkfnd3DCDouble.mexw64 
    mex COMPFLAGS='/DDATATYPE=1' pkfnd3DC.c -output pkfnd3DCUInt16.mexw64 
end


% Mac Experimental
% #######################################################################################
if ismac()
    mex -O CFLAGS="\$CFLAGS -std=c99 -DDATATYPE=0" pkfnd1DC.c -output pkfnd1DCDouble.mexmaci64
    mex -O CFLAGS="\$CFLAGS -std=c99 -DDATATYPE=1" pkfnd1DC.c -output pkfnd1DCUInt16.mexmaci64
    mex -O CFLAGS="\$CFLAGS -std=c99 -DDATATYPE=0" pkfnd2DC.c -output pkfnd2DCDouble.mexmaci64
    mex -O CFLAGS="\$CFLAGS -std=c99 -DDATATYPE=1" pkfnd2DC.c -output pkfnd2DCUInt16.mexmaci64
    mex -O CFLAGS="\$CFLAGS -std=c99 -DDATATYPE=0" pkfnd3DC.c -output pkfnd3DCDouble.mexmaci64
    mex -O CFLAGS="\$CFLAGS -std=c99 -DDATATYPE=1" pkfnd3DC.c -output pkfnd3DCUInt16.mexmaci64
end