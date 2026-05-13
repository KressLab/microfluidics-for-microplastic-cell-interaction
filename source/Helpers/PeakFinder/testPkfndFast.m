% 
clear;
close all;
clc;

%compilePkfnd;

THRESH=50;
MIN_DIST=5;
SZ_MAX=6;
MAX_INT=2000;

beadSz=3;
beadSzNoise=0;
beadCount=500;
shape='gaussian';
beadIntensity=160;
beadIntensityNoise=20;
bgNoise=160;
velocity=0.4;
velNoise=0;
tklength=1;
imSZ=500;
motionMode='diffusion';

STACK_SZ=15;

im2D=generateGaussionDistBeadsFlipping(imSZ,...
                                       beadSz,...
                                       beadSzNoise,...
                                       beadCount,...
                                       shape,...
                                       beadIntensity,...
                                       beadIntensityNoise,...
                                       bgNoise,...
                                       velocity,...
                                       velNoise,...
                                       tklength,...
                                       0,...
                                       motionMode);

tic;
%im2D=im2D{1};
THRESH=getPkfndAutothresh(im2D,MIN_DIST,SZ_MAX,MAX_INT,beadCount*1.5,beadCount/2);
peaksDouble=pkfndFast(im2D{1}, THRESH, MIN_DIST, SZ_MAX, MAX_INT);
sum(sum(uint16(im2D)==101));
peaksUint16=pkfndFast(uint16(im2D), uint16(THRESH), MIN_DIST, SZ_MAX, uint16(MAX_INT));
toc;



[fig,ax,imPlots]= initImagePlot(1,{im2D,im2DFiltered});
plot(ax(1),peaksDouble(:,1),peaksDouble(:,2),'g+','MarkerSize',20);
plot(ax(1),peaksUint16(:,1),peaksUint16(:,2),'r+');

plot(ax(2),peaksUint16(:,1),peaksUint16(:,2),'g+','MarkerSize',20);
plot(ax(2),peaksDouble(:,1),peaksDouble(:,2),'r+');

