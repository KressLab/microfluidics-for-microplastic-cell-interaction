classdef TestPkfnd < matlab.unittest.TestCase
    %TESTPKFND Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        testImg;
        
        testBeads;
               
        DEFAULT_BEAD_BRIGHTNESS=1000;
        DEFAULT_DETECTION_THRESH=500;
        DEFAULT_MAX_DIST=5;
        DEFAULT_SZ_MAX=2;
        DEFAULT_MAX_INT=2000;
    end
    
    methods(TestMethodSetup)
        function setup(obj)
            obj.testImg=zeros(50,60);
            obj.testBeads=[25,30;...
                           40,20;...
                           obj.DEFAULT_MAX_DIST+1,40;...
                           40,obj.DEFAULT_MAX_DIST+1;...
                           size(obj.testImg,2)-obj.DEFAULT_MAX_DIST,40;...
                           40,size(obj.testImg,1)-obj.DEFAULT_MAX_DIST;...
                           10,10];
            
            obj.initTestBeads();
        end
    end
    
    methods(Test)
        function testSimple(obj)
           obj.detectTestBeads(obj.DEFAULT_DETECTION_THRESH);
        end
        
        function testBrightnessUpperThresh(obj)
            obj.testImg(25,10)=obj.DEFAULT_MAX_INT+1;
            obj.detectTestBeads(obj.DEFAULT_DETECTION_THRESH);
        end
        
        function testBrightnessLowerThresh(obj)
            obj.testImg(25,10)=obj.DEFAULT_DETECTION_THRESH-2;
            obj.detectTestBeads(obj.DEFAULT_DETECTION_THRESH);
        end
        
        function testParticleDistance(obj)
            obj.initEdges(1,obj.DEFAULT_MAX_DIST,-1);
            obj.detectTestBeads(obj.DEFAULT_DETECTION_THRESH);
        end
        
        function testParticleSize(obj)
            obj.initEdges(1,obj.DEFAULT_SZ_MAX,-1);
            obj.detectTestBeads(obj.DEFAULT_DETECTION_THRESH);
        end
        
        function testNoise(obj)
            obj.testImg=rand(size(obj.testImg))*(obj.DEFAULT_BEAD_BRIGHTNESS-1);
            obj.initTestBeads();
            obj.detectTestBeads(obj.DEFAULT_BEAD_BRIGHTNESS-1);
        end
        
        function testCircle(obj)
            obj.initCircle(1,obj.DEFAULT_SZ_MAX);
            obj.detectTestBeads(obj.DEFAULT_BEAD_BRIGHTNESS-1);
        end
        
        function edgeWithCorrectSizeIsIgnored(obj)
            obj.testImg(1:obj.DEFAULT_MAX_DIST,:)=obj.DEFAULT_BEAD_BRIGHTNESS;
            obj.testImg(end-obj.DEFAULT_MAX_DIST+1:end,:)=obj.DEFAULT_BEAD_BRIGHTNESS;
            obj.testImg(:,1:obj.DEFAULT_MAX_DIST)=obj.DEFAULT_BEAD_BRIGHTNESS;
            obj.testImg(:,end-obj.DEFAULT_MAX_DIST+1:end)=obj.DEFAULT_BEAD_BRIGHTNESS;
            obj.detectTestBeads(obj.DEFAULT_BEAD_BRIGHTNESS-1);
        end
        
        function testTranspose(obj)
            detectedBeads=pkfndFast(obj.testImg, obj.DEFAULT_BEAD_BRIGHTNESS-1, obj.DEFAULT_MAX_DIST, obj.DEFAULT_SZ_MAX, obj.DEFAULT_MAX_INT);
            detectedBeadsTransposed=pkfndFast(obj.testImg', obj.DEFAULT_BEAD_BRIGHTNESS-1, obj.DEFAULT_MAX_DIST, obj.DEFAULT_SZ_MAX, obj.DEFAULT_MAX_INT);
            detectedBeadsTemp=detectedBeads(:,2);
            detectedBeadsTemp(:,2)=detectedBeads(:,1);
            obj.assumeTrue(obj.areEqual(detectedBeadsTransposed,detectedBeadsTemp));
        end
    end
    
    methods(Access=private)
        function initCircle(obj, testParticleId, radius)
            x=obj.testBeads(testParticleId,2);
            y=obj.testBeads(testParticleId,1);
            for i=x-radius:x+radius
                maxJ=floor(sqrt(radius^2-(i-x)^2));
                for j=y-maxJ:y+maxJ
                    obj.testImg(i,j)=obj.DEFAULT_BEAD_BRIGHTNESS-2;
                end
            end
            obj.testImg(x,y)=obj.DEFAULT_BEAD_BRIGHTNESS;
        end
        
        function initTestBeads(obj)
            for i=1:size(obj.testBeads,1)
                obj.testImg(int32(obj.testBeads(i,2)),int32(obj.testBeads(i,1)))=obj.DEFAULT_BEAD_BRIGHTNESS;
            end
        end
        
        function initEdges(obj,testParticleId, size, brightnessOffset)
            obj.testImg(obj.testBeads(testParticleId,2),obj.testBeads(testParticleId,1)+size)=obj.DEFAULT_BEAD_BRIGHTNESS+brightnessOffset;
            obj.testImg(obj.testBeads(testParticleId,2),obj.testBeads(testParticleId,1)-size)=obj.DEFAULT_BEAD_BRIGHTNESS+brightnessOffset;
            obj.testImg(obj.testBeads(testParticleId,2)+size,obj.testBeads(testParticleId,1))=obj.DEFAULT_BEAD_BRIGHTNESS+brightnessOffset;
            obj.testImg(obj.testBeads(testParticleId,2)-size,obj.testBeads(testParticleId,1))=obj.DEFAULT_BEAD_BRIGHTNESS+brightnessOffset;
        end
        
        function detectTestBeads(obj,thresh)
            detectedBeads=pkfndFast(obj.testImg, thresh, obj.DEFAULT_MAX_DIST, obj.DEFAULT_SZ_MAX, obj.DEFAULT_MAX_INT);
            obj.assumeTrue(obj.areEqual(detectedBeads,obj.testBeads));
        end
        
        function equ = areEqual(~, beads1, beads2)
            table1=table(beads1(:,1),beads1(:,2));
            table2=table(beads2(:,1),beads2(:,2));
            intersectBeads=intersect(table1, table2);
            if isequal(size(beads1),size(beads2)) && isequal(size(beads1),size(intersectBeads))
                equ=true;
            else
                equ=false;
            end
        end
    end
    
end

