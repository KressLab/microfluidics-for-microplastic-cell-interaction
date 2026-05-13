#include <math.h>
#include "mex.h"
#include "matrix.h"
#include <inttypes.h>

// Input Arguments Shortcuts

#define	VOLUME_IN	prhs[0]
#define IM_SZ_IN prhs[1]
#define	TH_IN	prhs[2]
#define	MIN_DIST_IN	prhs[3]
#define	SCAN_RAD_IN prhs[4]
#define	MAX_PEAK_INTENSITY_IN prhs[5]

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
 *  Tests whether the point k,l,o is larger than the eight points along the axis that are
 *  dist away.
 */
static bool testMaxAtDist(inputDatatype* vol,mwSize n, mwSize o, mwSize p,mwSize q, mwSize r, mwSize dist){
        if(vol[(p+dist)*(o*n)+q*o+r] > vol[(p)*(o*n)+q*o+r] ||
           vol[(p-dist)*(o*n)+q*o+r] > vol[(p)*(o*n)+q*o+r] ||
           vol[(p)*(o*n)+(q+dist)*o+r] > vol[(p)*(o*n)+q*o+r] ||
           vol[(p)*(o*n)+(q-dist)*o+r] > vol[(p)*(o*n)+q*o+r] ||
           vol[(p)*(o*n)+(q)*o+(r+dist)] > vol[(p)*(o*n)+q*o+r] ||
           vol[(p)*(o*n)+(q)*o+(r-dist)] > vol[(p)*(o*n)+q*o+r])
            return FALSE;
    return TRUE;
}

/*
 *  Checks whether the position k,l,o is a local maximum in vol[m*n*o]
 *  therefore, checks all the pixels within radius scanRadiusD around the point
 *  k,l. Also checks if the pixel is brigther than maxInt.
*/
static bool isLocalMax(inputDatatype* vol,mwSize n,mwSize o,mwSize p,mwSize q,mwSize r,double scanRadiusD){
    mwSize scanRadius=(mwSize)scanRadiusD;
    // gradually do a quick check at boundaries farthest away in x-and y-direction
    mwSize step=(mwSize)sqrt(scanRadiusD);
    // considerable speed up at large scanRadius, especially when blobs are dense
    if(!testMaxAtDist(vol,n,o,p,q,r,scanRadius)){
        return FALSE;
    }
    //check if any of the pixels within range of scanRadiusD is brighter than the
    //pixel in the middle
    for(mwSize i=-scanRadius;i<scanRadius+1;i++){
        //iterate over circle
        int jLim=(mwSize)(sqrt(scanRadiusD*scanRadiusD-i*i));
        //save loop condition evals for j<=0
        //case j=0
        for(mwSize j=-jLim;j<jLim+1;j++){
            mwSize kLim=(mwSize)(sqrt(scanRadiusD*scanRadiusD-i*i-j*j));
            for(mwSize k=-kLim;k<kLim+1;k++){
                if(vol[(i+p)*(o*n)+(j+q)*o+(k+r)]>vol[p*(o*n)+q*o+r]){
                   return FALSE;
                }
            }
        }
    }
    //if we havent found any pixel brighter than the pixel, we have a max
    //this makes overilluminated areas a bunch of maximas
    //those are filtered using detectCollision later
    return TRUE;
}

/*
 * Marks the lower intensity of two positions within a range of minDist with
 * -1.
 */
static void detectCollisions(int* pos, mwSize count, inputDatatype* intensities, inputDatatype minDist, bool* collisions){
    int posI1,posI2,posI3,posJ1,posJ2,posJ3,dPos1,dPos2,dPos3;
    //performance...factor mult. out of loops.
    double minDistSqr=minDist*minDist;
    
    //for every pair of maxima within a distance of minDist, check which one is brighter
    //mark the intensity of the darker one
    for(mwSize i=0;i<count;i++){
        for(mwSize j=0;j<i;j++){
            if(collisions[j]){
                continue;
            }
            posI1=pos[3*i];
            posI2=pos[3*i+1];
            posI3=pos[3*i+2];
            posJ1=pos[3*j];
            posJ2=pos[3*j+1];
            posJ3=pos[3*j+2];
            dPos1=posI1-posJ1;
            dPos2=posI2-posJ2;
            dPos3=posI3-posJ3;            
            if((dPos1*dPos1)+(dPos2*dPos2)+(dPos3*dPos3)<=minDistSqr){
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

static int removeCollisions(int* pos, mwSize count, bool* collisions){
    int* newPos=(int*)malloc(3*count*sizeof(int));
    if(!newPos)
        mexErrMsgTxt( "pkfndC.c: Failed to allocate memory for new peak positions!"); 
    mwSize i;
    mwSize newCount=0;
    
    for(i=0;i<count;i++){
        if(!collisions[i]){
            newPos[3*newCount]=pos[3*i];
            newPos[3*newCount+1]=pos[3*i+1];
            newPos[3*newCount+2]=pos[3*i+2];
            newCount=newCount+1;
        }
    }
    
    for(i=0;i<3*newCount;i++){
        pos[i]=newPos[i];
    }
    free(newPos);
    return newCount;
}

static int findMax(int* pos,int maxParticleCount,mwSize m,mwSize n,mwSize o,inputDatatype* vol,inputDatatype th,double minDistD,double scanRadiusD, mwSize border, inputDatatype maxInt){
    //detect maxima with size scanRadiusD
    mwSize scanRadius=(int)scanRadiusD;
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
            for(mwSize k=border;k<o-border;k++){                inputDatatype currentIntensity=vol[i*(o*n)+j*o+k];
                if(currentIntensity<=th || currentIntensity>=maxInt){
                    continue;
                }
                if(isLocalMax(vol,n,o,i,j,k,scanRadiusD)){
                    //convert directly to matlab coordinates
                    pos[3*count]=k+1;
                    pos[3*count+1]=j+1;
                    pos[3*count+2]=i+1;
                    intensities[count]=currentIntensity;
                    count=count+1;
                }
                if(count==maxParticleCount)
                    return count;
            }
        }
    }
    
    //remove lower local maxima within size of minDistD
    if(minDistD>0){
        //for count*count>m*n, the original implementation of ERD should be faster
        //since it has linear runtime
        bool* collisions = (bool*)malloc(count * sizeof(bool));
        for(int i=0;i<count;i++){
            collisions[i]=FALSE;
        }
        detectCollisions(pos,count,intensities,minDistD,collisions);
        count=removeCollisions(pos,count,collisions);
        free(collisions);
    }
    //not necessary anymore
    free(intensities);
    
    return count;
}

/*
 *  Main mex function to be called by matlab
 */
void mexFunction(int nlhs, mxArray *plhs[], 
		  int nrhs, const mxArray*prhs[] )
{
    int *posOut,*pos;
    mwSize *imSz;
    mwSize maxNumParticles;
    mwSize count;
    inputDatatype *vol;
    inputDatatype *th,*maxInt;
    double *minDist,*scanRadius;
    mwSize m,n,o;
    
    //Check for proper number of arguments
    if (nrhs != 6) { 
	    mexErrMsgIdAndTxt( "MATLAB:yprime:invalidNumInputs",
                "Six input arguments required."); 
    } else if (nlhs > 1) {
	    mexErrMsgIdAndTxt( "MATLAB:yprime:maxlhs",
                "Too many output arguments."); 
    }
    
    // Get the dimensions of image.
    imSz=(mwSize*)mxGetPr(IM_SZ_IN);
    
    o = (mwSize)imSz[0];
    n = (mwSize)imSz[1];
    m = (mwSize)imSz[2];    
    
    #if DATATYPE==0
    if (!mxIsDouble(VOLUME_IN) || mxIsComplex(VOLUME_IN)) { 
        mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
            "arrayTest requires vol to be of type double16Datatype"); 
    }
    if (!mxIsDouble(TH_IN) || mxIsComplex(TH_IN)) { 
        mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
            "arrayTest requires th to be of type doubleDatatype"); 
    }
    if (!mxIsDouble(MAX_PEAK_INTENSITY_IN) || mxIsComplex(MAX_PEAK_INTENSITY_IN)) { 
        mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
            "arrayTest requires maxInt to be of type doubleDatatype"); 
    }
    vol = mxGetPr(VOLUME_IN); 
    th = mxGetPr(TH_IN);
    maxInt = mxGetPr(MAX_PEAK_INTENSITY_IN);
    #elif DATATYPE==1
    if (!mxIsUint16(VOLUME_IN)) { 
	    mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                "arrayTest requires vol to be of type uint16Datatype"); 
    }
    if (!mxIsUint16(TH_IN)) { 
	    mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                "arrayTest requires th to be of type uint16Datatype"); 
    }
    if (!mxIsUint16(MAX_PEAK_INTENSITY_IN)) { 
	    mexErrMsgIdAndTxt( "MATLAB:yprime:invalidIM",
                "arrayTest requires maxInt to be of type uint16Datatype"); 
    }
    vol = mxGetData(VOLUME_IN); 
    th = mxGetData(TH_IN);
    maxInt = mxGetData(MAX_PEAK_INTENSITY_IN);
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
    maxNumParticles=(mwSize)(m*n*o / *minDist / *minDist / *minDist);;
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
        pos = (int*)malloc(3* maxNumParticles * sizeof(int));
        if(!pos)
            mexErrMsgTxt( "pkfnd3DC.c: Failed to allocate memory for peak positions!"); 
        count=findMax(pos,maxNumParticles,m,n,o,vol,*th,*minDist,*scanRadius,border,*maxInt);
    //we ran out of memory during max-search (see abort condition in findMax(...))
    }while(count==maxNumParticles);
    
    /* Create a matlab matrix for the return argument of precisely the correct size */ 
    POS_OUT = mxCreateNumericMatrix(3,count, mxINT32_CLASS, mxREAL);
    /* Assign pointers to the output parameter */ 
    posOut = (int*)mxGetPr(POS_OUT);
    //copy the data to the matlab array
    cpyCont(pos,posOut,3*count);
    //release memory
    free(pos);
    
    return;
}