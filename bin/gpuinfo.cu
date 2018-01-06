#pragma once

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>    // EXIT_FAILURE, exit
#include <iostream>


/**
 * compile with:
 *   'nvcc' -ccbin=/usr/bin/g++-4.9 -std=c++11 --compiler-options -Wall,-Wextra -DCUDACOMMON_GPUINFO_MAIN -o gpuinfo --x cu gpuinfo.cu
 */


inline void checkCudaError(const cudaError_t rValue, const char * file, int line )
{
    if ( (rValue) != cudaSuccess )
    {
        std::cout << "CUDA error in " << file
                  << " line:" << line << " : "
                  << cudaGetErrorString(rValue) << "\n";
        assert( false );
    }
}
#define CUDA_ERROR(X) checkCudaError( X, __FILE__, __LINE__ );


template< typename T, typename S >
__host__ __device__
inline T ceilDiv( T a, S b )
{
    assert( b != 0 );
    assert( a == a );
    assert( b == b );
    return (a+b-1)/b;
}

/**
 * Chooses an optimal configuration for number of blocks and number of threads
 * Note that every kernel may have to calculate on a different amount of
 * elements, so this needs to be calculated inside the kernel with:
 *    for ( i = linid; i < nElements; i += nBlocks * nThreads )
 * which yields the following number of iterations:
 *    nIterations = (nElements-1 - linid) / ( nBlocks * nThreads ) + 1
 * derivation:
 *    search for highest n which satisfies i + n*s <= m-1
 *    note that we used <= m-1 instead of < m to work with floor later on
 *    <=> search highest n: n <= (m-1-i)/s
 *    which is n = floor[ (m-1-i)/s ]. Note that floor wouldn't be possible
 *    for < m, because it wouldn't account for the edge case for (m-1-i)/s == n
 *    the highest n means the for loop will iterate with i, i+s, i+2*s, i+...n*s
 *    => nIterations = n+1 = floor[ (m-1-i)/s ] + 1
 */
inline void calcKernelConfig( int iDevice, uint64_t n, int * nBlocks, int * nThreads )
{
    int const nMaxThreads  = 256;
    int const nMinElements = 32; /* The assumption: one kernel with nMinElements work won't be much slower than nMinElements kernels with each 1 work element. Of course this is workload / kernel dependent, so the fixed value may not be the best idea */

    /* set current device and get device infos */
    int nDevices;
    CUDA_ERROR( cudaGetDeviceCount( &nDevices ) );
    assert( iDevice < nDevices );
    CUDA_ERROR( cudaSetDevice( iDevice ) );

    // for GTX 760 this is 12288 threads per device and 384 real cores
    cudaDeviceProp deviceProperties;
    CUDA_ERROR( cudaGetDeviceProperties( &deviceProperties, iDevice) );

    int const nMaxThreadsGpu = deviceProperties.maxThreadsPerMultiProcessor
                             * deviceProperties.multiProcessorCount;
    if ( n < (uint64_t) nMaxThreadsGpu * nMinElements )
    {
        auto nThreadsNeeded = ceilDiv( n, nMinElements );
        *nBlocks  = ceilDiv( nThreadsNeeded, nMaxThreads );
        *nThreads = nMaxThreads;
        if ( *nBlocks == 1 )
        {
            assert( nThreadsNeeded <= nMaxThreads );
            *nThreads = nThreadsNeeded;
        }
    }
    else
    {
        *nBlocks  = nMaxThreadsGpu / nMaxThreads;
        *nThreads = nMaxThreads;
    }
    assert( *nBlocks > 0 );
    assert( *nThreads > 0 );
    uint64_t nIterations = 0;
    for ( uint64_t linid = 0; linid < (uint64_t) *nBlocks * *nThreads; ++linid )
    {
        /* note that this only works if linid < n */
        assert( linid < n );
        nIterations += (n-linid-1) / ( *nBlocks * *nThreads ) + 1;
        //printf( "[thread %i] %i elements\n", linid, (n-linid) / ( *nBlocks * *nThreads ) );
    }
    //printf( "Total %i elements out of %i wanted\n", nIterations, n );
    assert( nIterations == n );
}


template< class T >
struct GpuArray
{
    T * host, * gpu;
    unsigned long long int const nBytes;
    cudaStream_t mStream;

    inline GpuArray
    (
        unsigned long long int const nElements = 1,
        cudaStream_t rStream = 0
    )
    : nBytes( nElements * sizeof(T) ),
      mStream( rStream )
    {
        host = (T*) malloc( nBytes );
        CUDA_ERROR( cudaMalloc( (void**) &gpu, nBytes ) );
        assert( host != NULL );
        assert( gpu  != NULL );
    }
    inline ~GpuArray()
    {
        CUDA_ERROR( cudaFree( gpu ) );
        free( host );
    }
    inline void down( void )
    {
        CUDA_ERROR( cudaMemcpyAsync( (void*) host, (void*) gpu, nBytes, cudaMemcpyDeviceToHost ) );
        CUDA_ERROR( cudaPeekAtLastError() );
    }
    inline void up( void )
    {
        CUDA_ERROR( cudaMemcpyAsync( (void*) gpu, (void*) host, nBytes, cudaMemcpyHostToDevice ) );
        CUDA_ERROR( cudaPeekAtLastError() );
    }
};


inline
__device__
long long unsigned int getLinearThreadId( void )
{
    long long unsigned int i    = threadIdx.x;
    long long unsigned int iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax;
    // expands to: i = blockDim.x * blockDim.y * threadIdx.z + blockDim.x * threadIdx.y + threadIdx.x

    return i;
}

inline
__device__
long long unsigned int getLinearGlobalId( void )
{
    long long unsigned int i    = threadIdx.x;
    long long unsigned int iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax; iMax *= blockDim.z;
    i +=  blockIdx.x * iMax; iMax *= gridDim.x;
    i +=  blockIdx.y * iMax; iMax *= gridDim.y;
    i +=  blockIdx.z * iMax;

    return i;
}

#include <utility>                  // pair

inline
__device__
void getLinearGlobalIdSize
(
    long long unsigned int * riThread,
    long long unsigned int * rnThreads
)
{
    auto & i    = *riThread ;
    auto & iMax = *rnThreads;

    i    = threadIdx.x;
    iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax; iMax *= blockDim.z;
    i +=  blockIdx.x * iMax; iMax *= gridDim.x;
    i +=  blockIdx.y * iMax; iMax *= gridDim.y;
    i +=  blockIdx.z * iMax; iMax *= gridDim.z;
}

inline
__device__
long long unsigned int getLinearBlockId( void )
{
    long long unsigned int i    = blockIdx.x;
    long long unsigned int iMax = gridDim.x;

    i += blockIdx.y * iMax; iMax *= gridDim.y;
    i += blockIdx.z * iMax;
    // expands to: i = blockDim.x * blockDim.y * threadIdx.z + blockDim.x * threadIdx.y + threadIdx.x

    return i;
}

inline
__device__
long long unsigned int getBlockSize( void )
{
    return blockDim.x * blockDim.y * blockDim.z;
}

inline
__device__
long long unsigned int getGridSize( void )
{
    return gridDim.x * gridDim.y * gridDim.z;
}


#include <cassert>
#include <cstdio>               // printf, fflush
#include <cstdlib>              // NULL, malloc, free


/**
 * Returns the number of arithmetic CUDA cores per streaming multiprocessor
 * Note that there are also extra special function units.
 * Note that for 2.0 the two warp schedulers can only issue 16 instructions
 * per cycle each. Meaning the 32 CUDA cores can't be used in parallel with
 * the 4 special function units. For 2.1 up this is a different matter
 * http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capabilities
 **/
int getCudaCoresPerMultiprocessor
(
    int const majorVersion,
    int const minorVersion
)
{
    if ( majorVersion == 2 && minorVersion == 0 ) /* Fermi */
        return 32;
    if ( majorVersion == 2 && minorVersion == 1 ) /* Fermi */
        return 48;
    if ( majorVersion == 3 )  /* Kepler */
        return 192;
    if ( majorVersion == 5 )  /* Maxwell */
        return 128;
    if ( majorVersion == 6 )  /* Pascal */
        return 64;
    return 0;   /* unknown, could also throw exception= */
}

std::string getCudaCodeName
(
    int const majorVersion,
    int const = 0
)
{
    if ( majorVersion == 2 )
        return "Fermi";
    if ( majorVersion == 3 )
        return "Kepler";
    if ( majorVersion == 5 )
        return "Maxwell";
    if ( majorVersion == 6 )
        return "Pascal";
    return 0;   /* unknown, could also throw exception= */
}

/**
 * @return flops (not GFlops, ... )
 */
float getCudaPeakFlops( cudaDeviceProp const & props )
{
    return (float) props.multiProcessorCount * props.clockRate /* kHz */ * 1e3f *
        getCudaCoresPerMultiprocessor( props.major, props.minor );
}

/**
 * @param[out] rpDeviceProperties - Array of cudaDeviceProp of length rnDevices
 *             the user will need to free (C-style) this data on program exit!
 * @param[out] rnDevices - will hold number of cuda devices
 **/
inline void getCudaDeviceProperties
(
    cudaDeviceProp **       rpDeviceProperties = NULL,
    int             *       rnDevices          = NULL,
    bool              const rPrintInfo         = true
)
{
    printf( "Getting Device Informations. As this is the first command, "
            "it can take ca.30s, because the GPU must be initialized.\n" );
    fflush( stdout );

    int fallbackNDevices;
    if ( rnDevices == NULL )
        rnDevices = &fallbackNDevices;
    CUDA_ERROR( cudaGetDeviceCount( rnDevices ) );

    cudaDeviceProp * fallbackPropArray;
    if ( rpDeviceProperties == NULL )
        rpDeviceProperties = &fallbackPropArray;
    *rpDeviceProperties = (cudaDeviceProp*) malloc( (*rnDevices) * sizeof(cudaDeviceProp) );
    assert( *rpDeviceProperties != NULL );

    for ( int iDevice = 0; iDevice < (*rnDevices); ++iDevice )
    {
        cudaDeviceProp * prop = &( (*rpDeviceProperties)[iDevice] );
        CUDA_ERROR( cudaGetDeviceProperties( prop, iDevice ) );

		if ( not rPrintInfo )
			continue;

        if ( iDevice == 0 && prop->major == 9999 && prop->minor == 9999 )
            printf("There is no device supporting CUDA.\n");

		const char cms[5][20] =
			{ "Default", "Exclusive", "Prohibited", "ExclusiveProcess", "Unknown" };
		const char * computeModeString;
		switch ( prop->computeMode )
        {
			case cudaComputeModeDefault          : computeModeString = cms[0];
			case cudaComputeModeExclusive        : computeModeString = cms[1];
			case cudaComputeModeProhibited       : computeModeString = cms[2];
			case cudaComputeModeExclusiveProcess : computeModeString = cms[3];
			default                              : computeModeString = cms[4];
		}
        auto const coresPerSM = getCudaCoresPerMultiprocessor( prop->major, prop->minor );
        auto const peakFlops  = getCudaPeakFlops( *prop );

        printf( "\n================== Device Number %i ==================\n",iDevice );
        printf( "| Device name              : %s\n"        , prop->name );
        printf( "| Computability            : %i.%i\n"     , prop->major,
                                                             prop->minor );
        printf( "| Code Name                : %s\n"        , getCudaCodeName( prop->major, prop->minor ).c_str() );
        printf( "| PCI Bus ID               : %i\n"        , prop->pciBusID );
        printf( "| PCI Device ID            : %i\n"        , prop->pciDeviceID );
        printf( "| PCI Domain ID            : %i\n"        , prop->pciDomainID );
		printf( "|------------------- Architecture -------------------\n" );
        printf( "| Number of SMX            : %i\n"        , prop->multiProcessorCount );
        printf( "| Max Threads per SMX      : %i\n"        , prop->maxThreadsPerMultiProcessor );
        printf( "| Max Threads per Block    : %i\n"        , prop->maxThreadsPerBlock );
        printf( "| Warp Size                : %i\n"        , prop->warpSize );
        printf( "| Clock Rate               : %f GHz\n"    , prop->clockRate/1.0e6f );
        printf( "| Max Block Size           : (%i,%i,%i)\n", prop->maxThreadsDim[0],
                                                             prop->maxThreadsDim[1],
                                                             prop->maxThreadsDim[2] );
        printf( "| Max Grid Size            : (%i,%i,%i)\n", prop->maxGridSize[0],
                                                             prop->maxGridSize[1],
                                                             prop->maxGridSize[2] );
		printf( "|  => Max conc. Threads    : %i\n"        , prop->multiProcessorCount *
		                                                     prop->maxThreadsPerMultiProcessor );
		printf( "|  => Warps per SMX        : %i\n"        , prop->maxThreadsPerMultiProcessor /
		                                                     prop->warpSize );
        printf( "| CUDA Cores per Multiproc.: %i\n"        , coresPerSM );
        printf( "| Total CUDA Cores         : %i\n"        , prop->multiProcessorCount * coresPerSM );
        printf( "| Clock Rate               : %f GHz\n"    , peakFlops / 1e9f );
		printf( "|---------------------- Memory ----------------------\n" );
        printf( "| Total Global Memory      : %lu Bytes\n" , prop->totalGlobalMem );
        printf( "| Total Constant Memory    : %lu Bytes\n" , prop->totalConstMem );
        printf( "| Shared Memory per Block  : %lu Bytes\n" , prop->sharedMemPerBlock );
        printf( "| L2 Cache Size            : %u Bytes\n"  , prop->l2CacheSize );
        printf( "| Registers per Block      : %i\n"        , prop->regsPerBlock );
        printf( "| Memory Bus Width         : %i Bits\n"   , prop->memoryBusWidth );
        printf( "| Memory Clock Rate        : %f GHz\n"    , prop->memoryClockRate/1.0e6f );
        printf( "| Memory Pitch             : %lu\n"       , prop->memPitch );
        printf( "| Unified Addressing       : %i\n"        , prop->unifiedAddressing );
        printf( "| Texture Alignment        :  %ld\n"      , prop->textureAlignment );
        printf( "| Max 1D Texture Size      : %i\n"        , prop->maxTexture1D );
        printf( "| Max 2D Texture Size      : (%i,%i)\n"   , prop->maxTexture2D[0],
                                                             prop->maxTexture2D[1] );
        // this really is ONLY in CUDA 3.2. (maybe 3.x) available Oo
        //printf( "| Max 2D Texture Array Size: (%i,%i)\n"   , prop->maxTexture2DArray[0],
        //                                                     prop->maxTexture2DArray[1] );
        printf( "| Max 3D Texture Size      : (%i,%i,%i)\n", prop->maxTexture3D[0],
                                                             prop->maxTexture3D[1] ,
                                                             prop->maxTexture3D[2] );
		printf( "|--------------------- Graphics ---------------------\n" );
		printf( "| Compute mode             : %s\n"        ,      computeModeString );
		printf( "|---------------------- Other -----------------------\n" );
        printf( "| Can map Host Memory      : %s\n"        , prop->canMapHostMemory  ? "true" : "false" );
        printf( "| Can run Kernels conc.    : %s\n"        , prop->concurrentKernels ? "true" : "false" );
		printf( "| Number of Asyn. Engines  : %i\n"        , prop->asyncEngineCount );
        printf( "| Can Copy and Kernel conc.: %s\n"        , prop->deviceOverlap     ? "true" : "false" );
        printf( "| ECC Enabled              : %s\n"        , prop->ECCEnabled        ? "true" : "false" );
        printf( "| Device is Integrated     : %s\n"        , prop->integrated        ? "true" : "false" );
        printf( "| Kernel Timeout Enabled   : %s\n"        , prop->kernelExecTimeoutEnabled ? "true" : "false" );
        printf( "| Uses TESLA Driver        : %s\n"        , prop->tccDriver         ? "true" : "false" );
        printf( "=====================================================\n" );
    }
}

#if defined(__CUDA_ARCH__) && __CUDA_ARCH__ < 600
/**
 * atomicAdd for double is not natively implemented, because it's not
 * supported by (all) the hardware, therefore resulting in a time penalty.
 * http://stackoverflow.com/questions/12626096/why-has-atomicadd-not-been-implemented-for-doubles
 */
inline __device__ double atomicAdd(double* address, double val)
{
    unsigned long long int* address_as_ull =
                             (unsigned long long int *) address;
    unsigned long long int old = *address_as_ull, assumed;
    do
    {
        assumed = old;
        old = atomicCAS(address_as_ull, assumed,
              __double_as_longlong( val + __longlong_as_double(assumed) ));
    } while (assumed != old);
    return __longlong_as_double(old);
}
#endif


template< class T >
class MirroredVector
{
public:
    T * cpu = NULL;
    T * gpu = NULL;
    size_t n;

    MirroredVector() : n( 0 ), cpu( NULL ), gpu( NULL ) {}
    MirroredVector( size_t const rN ) : n( rN )
    {
        cpu = new T[ n ];
        CUDA_ERROR( cudaMalloc( (void**) &gpu, n * sizeof(T) ) );
        assert( cpu != NULL );
        assert( gpu != NULL );
    }
    void push( void ) const
    {
        assert( cpu != NULL );
        assert( gpu != NULL );
        assert( n > 0 );
        CUDA_ERROR( cudaMemcpy( (void*) gpu, (void*) cpu, n * sizeof(T), cudaMemcpyHostToDevice ) );
        CUDA_ERROR( cudaPeekAtLastError() );
    }
    void pop( void ) const
    {
        assert( cpu != NULL );
        assert( gpu != NULL );
        assert( n > 0 );
        CUDA_ERROR( cudaMemcpyAsync( (void*) cpu, (void*) gpu, n * sizeof(T), cudaMemcpyDeviceToHost ) );
        CUDA_ERROR( cudaPeekAtLastError() );
    }
    ~MirroredVector()
    {
        if ( cpu != NULL )
        {
            delete[] cpu;
            cpu = NULL;
        }
        if ( gpu != NULL )
        {
            CUDA_ERROR( cudaFree( gpu ) );
            gpu = NULL;
        }
    }
};


template< class T >
__device__ void swap( T & a, T & b )
{
    auto const c = a;
    a = b;
    b = c;
}


__device__
inline
int snprintFloat
(
    char        * const msg  ,
    unsigned int  const nChars,
    float         const f
)
{
    assert( false && "unfinished skeleton" );
    return 0;
}

template< typename T >
__device__
inline
int snprintInt
(
    char             * const msg  ,
    unsigned int       const nChars,
    T                        number,
    unsigned short int const base = 10u
)
{
    assert( base <= ( '9' - '0' + 1 ) + ( 'Z' - 'A' + 1 ) && "base was chosen too high, not sure how to convert that to characters!" );

    unsigned int nCharsWritten = 0u;
    if ( nCharsWritten+1 >= nChars )
        return 0;
    else if ( number < 0 )
    {
        msg[ nCharsWritten++ ] = '-';
        number = -number;
    }

    unsigned int expFloorLogBase = 1;
    while ( number / expFloorLogBase >= base )
        expFloorLogBase *= base;

    /* e.g. a possible run for 1230:
     *   digit 0 = 1 = 1230 / 1000
     *   digit 1 = 2 = 230  / 100
     *   digit 2 = 3 = 30   / 10
     *   digit 3 = 0 = 0    / 1 */
    while ( expFloorLogBase != 0 )
    {
        auto const digit = number / expFloorLogBase;
        number          %= expFloorLogBase;
        expFloorLogBase /= base;
        assert( digit <= base );

        if ( nCharsWritten+1 < nChars )
        {
            if ( digit < '9' - '0' + 1 )
                msg[ nCharsWritten++ ] = '0' + (unsigned char) digit;
            else if ( digit - ( '9' - '0' + 1 ) < 'Z' - 'A' + 1u )
                msg[ nCharsWritten++ ] = 'Z' + (unsigned char)( digit - ( '9' - '0' + 1u ) );
            else
                assert( false && "base was chosen too high, not sure how to convert that to characters!" );
        }
        else
            break;
    }

    assert( nCharsWritten+1 <= nChars ); // includes nChars > 0
    msg[ nCharsWritten ] = '\0';
    return nCharsWritten;
}

__device__
inline
int snprintFloatArray
(
    char        * const msg  ,
    unsigned int  const nChars,
    float const * const gpData,
    unsigned int  const nElements
)
{
    unsigned int nCharsWritten = 0u;
    for ( auto j = 0u; j < nElements; ++j )
    {
        if ( nCharsWritten + 1 >= nChars )
            break;
        msg[ nCharsWritten++ ] = ' ';
        //nCharsWritten += snprintFloat( msg, nChars - nCharsWritten, gpData[j] );
        nCharsWritten += snprintInt( msg + nCharsWritten, nChars - nCharsWritten, (int)( 10000 * gpData[j] ) );
    }
    assert( nCharsWritten < nChars );
    msg[ nCharsWritten ] = '\0';
    return nCharsWritten;
}

#ifdef CUDACOMMON_GPUINFO_MAIN
int main( void )
{
    cudaDeviceProp * pGpus = NULL;
    int              nGpus = 0   ;
    getCudaDeviceProperties( &pGpus, &nGpus, true );
    return 0;
}
#endif
