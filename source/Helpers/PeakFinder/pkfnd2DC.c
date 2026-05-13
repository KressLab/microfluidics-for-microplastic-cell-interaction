#include <math.h>
#include "mex.h"
#include "matrix.h"
#include <inttypes.h>

// Input Arguments Shortcuts

#define	IM_IN	prhs[0]
#define	TH_IN	prhs[1]
#define	MIN_DIST_IN	prhs[2]
#define	SCAN_RAD_IN	prhs[3]
#define	MAX_PEAK_INTENSITY_IN prhs[4]

// Output Argument Shortcuts

#define	POS_OUT	plhs[0]

#if !defined(TRUE)
#define TRUE 1
#endif


#if !defined(FALSE)
#define FALSE 0
#endif


// compiler args
#if DATATYPE==0
    typedef double inputDatatype;
#elif DATATYPE==1
    typedef uint16_t inputDatatype;
#else
    #error datatype DATATYPE undefined
#endif


/*
 *  copies count array items from source to target
 */
static void cpyCont(int* source, int* target, mwSize count){
    for(mwSize i=0;i<count;i++)
        target[i]=source[i];
}

/*
 *  Tests whether the point k,l is larger than the four points along the axis that are
 *  dist away.
 */
static bool testMaxAtDist(inputDatatype* im,mwSize m,mwSize k,mwSize l,mwSize dist){
    if(im[(l+dist)*m+(k)]>im[l*m+k] ||
       im[(l-dist)*m+(k)]>im[l*m+k] ||
       im[(l)*m+(k+dist)]>im[l*m+k] ||
       im[(l)*m+(k-dist)]>im[l*m+k])
        return FALSE;
    return TRUE;
}

/*
 *  Checks whether the position k,l is a local maximum in im[m*n]
 *  therefore, checks all the pixels within radius scanRadiusD around the point
 *  k,l. Also checks if the pixel is brigther than maxInt.
*/
static bool isLocalMax(inputDatatype* im,mwSize m,mwSize k,mwSize l,double scanRadiusD){
    mwSize scanRadius=(mwSize)scanRadiusD;
    // considerable speed up at large scanRadius, especially when blobs are dense
    if(!testMaxAtDist(im,m,k,l,scanRadius)){
        return FALSE;
    }
    //check if any of the pixels within range of scanRadiusD is brighter than the
    //pixel in the middle
    for(mwSize i=-scanRadius;i<scanRadius+1;i++){
        //iterate over circle
        mwSize jLim=(mwSize)(sqrt(scanRadiusD*scanRadiusD-i*i));
        //save loop condition evals for j<=0
        //case j=0
        if(im[(l)*m+(k+i)]>im[l*m+k])
            return FALSE;
        //other cases
        for(mwSize j=1;j<jLim+1;j++){
            //check 2nd component, both directions at the same time
            if(im[(l+j)*m+(k+i)]>im[l*m+k]||
               im[(l-j)*m+(k+i)]>im[l*m+k])
                    return FALSE;
        }
    }
    //if we havent found any pixel brighter than the pixel, we have a max
    //this makes overilluminated areas a bunch of maximas
    //those are filtered using detectCollision later
    return TRUE;
}

/*
 * Marks the intensity of two positions within a range of minDist with
 * -1.
 */
static void detectCollisions(int* pos,mwSize count,inputDatatype* intensities, inputDatatype minDist, bool* collisions){
    mwSize posI1,posI2,posJ1,posJ2,dPos1,dPos2;
    //performance...factor mult. out of loops.
    double minDistDSqr=minDist*minDist;
    
    //for every pair of maxima within a distance of minDist, check which one is brighter
    //mark the intensity of the darker one
    for(mwSize i=0;i<count;i++){
        for(mwSize j=0;j<i;j++){
            // commenting this one out might improve performance on older cpus
            // with bad jump prediction
            if(collisions[j]){
                continue;
            }
            posI1=pos[2*i];
            posI2=pos[2*i+1];
            posJ1=pos[2*j];
            posJ2=pos[2*j+1];
            dPos1=posI1-posJ1;
            dPos2=posI2-posJ2;
            if((dPos1*dPos1)+(dPos2*dPos2)<=minDistDSqr){
                //mark the position with the lower intensity
                // = case ensures that only one maxima is kept  in
                //overilluminated regions
                if(intensities[i]<=intensities[j]){
                    collisions[i]=TRUE;
                    break;
                }else{
                    collisions[j]=TRUE;
                }
            }
        }
    }
}

static int removeCollisions(int* pos, int count, bool* collisions){
    int* newPos=(int*)malloc(2*count*sizeof(int));
    if(!newPos)
        mexErrMsgTxt( "pkfndC.c: Failed to allocate memory for new peak positions!"); 
    mwSize i;
    mwSize newCount=0;
    
    for(i=0;i<count;i++){
        if(!collisions[i]){
            newPos[2*newCount]=pos[2*i];
            newPos[2*newCount+1]=pos[2*i+1];
            newCount=newCount+1;
        }
    }
    
    for(i=0;i<2*newCount;i++){
        pos[i]=newPos[i];
    }
    free(newPos);
    return newCount;
}

static int findMax(int* pos,int maxParticleCount,int m,int n,inputDatatype* im,inputDatatype th,double minDistD,double scanRadiusD, int border, inputDatatype maxInt){
    //detect maxima with size scanRadiusD
    mwSize scanRadius=(mwSize)scanRadiusD;
    //allocate space for intensity
    //to optimize for older machines or extremely large datasets, moving this
    //array into pos might improve locality of reference in detectCollisions(...)
    //and thus, performance.
    inputDatatype* intensities=(inputDatatype*)malloc(maxParticleCount*sizeof(inputDatatype));
    if(!intensities)
        mexErrMsgTxt( "pkfndC.c: Failed to allocate memory for peak intensities!"); 
//  find maxima
    int count=0;
    for(mwSize i=border;i<m-border;i++){
        for(mwSize j=border;j<n-border;j++){
            inputDatatype currIntensity=im[j*m+i];
            if(currIntensity<=th || currIntensity>= maxInt){
                continue;
            }
            if(isLocalMax(im,m,i,j,scanRadiusD)){
                //convert directly to matlab coordinates
                pos[2*count]=j+1;
                pos[2*count+1]=i+1;
                intensities[count]=currIntensity;
                count=count+1;
            }
            if(count==maxParticleCount)
                return count;
        }
    }
    
    //remove lower local maxima within size of minDistD
    if(minDistD>0){
        //for count*count>m*n, the original implementation of ERD should be faster
        //since it has linear runtime
        bool* collisions = (bool*)malloc(count * sizeof(bool));
        for(mwSize i=0;i<count;i++){
            collisions[i]=FALSE;
        }
        detectCollisions(pos,count,intensities,minDistD,collisions);
        //printf("before count: %d\n", count);
        count=removeCollisions(pos,count,collisions);
        //printf("after count: %d\n", count);
        free(collisions);
    }
    //not necessary anymore
    free(intensities);
    
    return count;
}

/*
 *  Main mex function to be called by by matlab
 */
void mexFunction(int nlhs, mxArray *plhs[], 
		  int nrhs, const mxArray*prhs[] )
{
    int *posOut,*pos;
    mwSize maxNumParticles;
    mwSize count;
    inputDatatype *im;
    inputDatatype *th,*maxInt;
    double *minDist,*scanRadius;
    mwSize m,n;
    
    //Check for proper number of arguments
    if (nrhs != 5) { 
	    mexErrMsgIdAndTxt( "MATLAB:yprime:invalidNumInputs",
                "Four input arguments required."); 
    } else if (nlhs > 1) {
	    mexErrMsgIdAndTxt( "MATLAB:yprime:maxlhs",
                "Too many output arguments."); 
    }
                    //this does not mess with the integrity of  checkCollisions(...)
                    //since only differences are considered there
    
    // Get the dimensions of image.
    m = mxGetM(IM_IN); 
    n = mxGetN(IM_IN);
    
    //printf("n:%d\n",n);
    //printf("m:%d\n",m);
    
    #if DATATYPE==0
        if (!mxIsDouble(IM_IN) || mxIsComplex(IM_IN)) { 
            mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                "arrayTest requires Image to be of type doubleDatatype"); 
        }
        if (!mxIsDouble(TH_IN) || mxIsComplex(TH_IN)) { 
            mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                "arrayTest requires th to be of type doubleDatatype"); 
        }
        if (!mxIsDouble(MAX_PEAK_INTENSITY_IN) || mxIsComplex(MAX_PEAK_INTENSITY_IN)) { 
            mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                "arrayTest requires maxInt to be of type doubleDatatype"); 
        }
        im = mxGetPr(IM_IN); 
        th = mxGetPr(TH_IN);
        maxInt = mxGetPr(MAX_PEAK_INTENSITY_IN);
        //printf("double version called\n");
    #elif DATATYPE==1
        if (!mxIsUint16(IM_IN)) { 
            mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                    "arrayTest requires image to be of type uint16Datatype"); 
        }
        if (!mxIsUint16(TH_IN)) { 
            mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                    "arrayTest requires thresh to be of type uint16Datatype"); 
        }
        if (!mxIsUint16(MAX_PEAK_INTENSITY_IN)) { 
            mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                    "arrayTest requires that maxIntensity to be of type uint16Datatype"); 
        }
        im = mxGetData(IM_IN); 
        th = mxGetData(TH_IN);
        maxInt = mxGetData(MAX_PEAK_INTENSITY_IN);
        //printf("int version called\n");
    #endif   
    
    minDist = mxGetPr(MIN_DIST_IN);
    scanRadius = mxGetPr(SCAN_RAD_IN);
    
    //border is the maximum of scanRadius and minDist
    mwSize border;
    if (*scanRadius>*minDist){
        border=(mwSize)(ceil(*scanRadius));
    }else{
        border=(mwSize)(ceil(*minDist));
    }
    
    /* Run with a higher amount of allocated memory until we have enough of it...
     * ...here is room for optimization...problem is we dont know how many
     * particles there are.
     */
    maxNumParticles=(mwSize)(m*n / *minDist / *minDist);
    count=maxNumParticles;
    pos=0;
    do{
        //if we have already allocated memory, meaning we are not in the fist iteration
        if(pos){
            //try running again with more memory if we ran out of memory last try
            //the best way to resolve this issue is to recompile with a higher start value
            //of maxNumParticles
            maxNumParticles=maxNumParticles*10;
            free(pos);
        }
        pos = (int*)malloc(2* maxNumParticles * sizeof(int));
        if(!pos)
            mexErrMsgTxt( "pkfndC.c: Failed to allocate memory for peak positions!"); 
        count=findMax(pos,maxNumParticles,m,n,im,*th,*minDist,*scanRadius,border,*maxInt);
    //we ran out of memory during max-search (see abort condition in findMax(...))
    }while(count==maxNumParticles);
    
    /* Create a matlab matrix for the return argument of precisely the correct size */ 
    POS_OUT = mxCreateNumericMatrix(2,count, mxINT32_CLASS, mxREAL);
    /* Assign pointers to the output parameter */ 
    posOut = (int*)mxGetPr(POS_OUT);
    //copy the data to the matlab array
    cpyCont(pos,posOut,2*count);
    //release memory
    free(pos);
    
    return;
}