% 
clear;
close all;
clc;

compilePkfnd;

THRESH=99.5;
SZ_MAX=1;
MAX_INT=300;

IM_SZ=500;
BEAD_SZ=3;
BEAD_COUNT=700;
bgNoise=5;

im=generateGaussionDistBeads3D(IM_SZ, BEAD_SZ,BEAD_COUNT,MAX_INT, MAX_INT/4);

tic;
peaksDouble=pkfndFast(im, THRESH, BEAD_SZ*3, SZ_MAX, MAX_INT);
peaksUint16=pkfndFast(uint16(im), uint16(THRESH), BEAD_SZ*3, SZ_MAX, uint16(MAX_INT));
toc;

figure(1);
for i=1:size(im,3)
    clf;
    hold on;colormap gray;axis image;
    imagesc(im(:,:,i));
    currPlanePeaksDouble=peaksDouble(peaksDouble(:,3)==i,:);
    plot(currPlanePeaksDouble(:,2),currPlanePeaksDouble(:,1),'r+','MarkerSize',15);
    currPlanePeaksUint16=peaksUint16(peaksUint16(:,3)==i,:);
    plot(currPlanePeaksUint16(:,2),currPlanePeaksUint16(:,1),'g+');
    pause;
end


function mat = gauss3d(mat, sigma, center)
    gsize = size(mat);
    for a=1:gsize(1)
        for b=1:gsize(2)
            for c=1:gsize(3)
                mat(a,b,c) = gaussC(a,b,c, sigma, center);
            end
        end
    end
end

function val = gaussC(x, y,z, sigma, center)
    ac = center(1);
    bc = center(2);
    cc = center(3);
    exponent = ((x-ac).^2 + (y-bc).^2 + (z-cc).^2)./(2*sigma.^2);
    val       = (exp(-exponent));
end