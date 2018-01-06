/**
 * compile with:
 *   'nvcc' -ccbin=/usr/bin/g++-4.9 -std=c++11 --compiler-options -Wall,-Wextra -DCUDACOMMON_GPUINFO_MAIN -o gpuinfo --x cu cudacommon.hpp && ./gpuinfo
 */

#ifndef CUDACOMMON_GPUINFO_MAIN
#   pragma once
#endif

#include <cassert>
#include <cstdio>
#include <cstdlib>                      // NULL, malloc, free, memset
#include <cstdlib>                      // EXIT_FAILURE, exit
#include <iostream>
#include <stdexcept>
#include <stdint.h>                     // uint64_t
#include <sstream>
#ifdef __CUDACC__
#   include <cuda_runtime_api.h>
#endif


#define __FILENAME__ (__builtin_strrchr(__FILE__, '/') ? __builtin_strrchr(__FILE__, '/') + 1 : __FILE__)

/* https://stackoverflow.com/questions/8796369/cuda-and-nvcc-using-the-preprocessor-to-choose-between-float-or-double
It seems you might be conflating two things - how to differentiate between the host and device compilation trajectories when nvcc is processing CUDA code, and how to differentiate between CUDA and non-CUDA code. There is a subtle difference between the two. __CUDA_ARCH__ answers the first question, and __CUDACC__ answers the second.
*/
#if defined( __CUDACC__ )

inline void checkCudaError
(
    cudaError_t  const rValue,
    char const * const file,
    int          const line
)
{
    if ( rValue != cudaSuccess )
    {
        std::cout << "CUDA error in " << file
                  << " line:" << line << " : "
                  << cudaGetErrorString( rValue ) << "\n";
        exit( EXIT_FAILURE );
    }
}
#define CUDA_ERROR(X) checkCudaError( X, __FILENAME__, __LINE__ );

#endif

/* make this header work even when not using CUDA */
#if ! defined( __CUDACC__ ) && ! defined( __host__ ) && ! defined( __device__ )
#   define __host__
#   define __device__
#endif



template< typename T, typename S >
__host__ __device__
inline T ceilDiv( T a, S b )
{
    assert( b != 0 );
    assert( a == a );
    assert( b == b );
    return (a+b-1)/b;
}

#include <sstream>
#include <string>
#include <vector>

/**
 * Given the number of bytes, this function prints out an exact human
 * readable format, e.g. 128427:
 *   logical: 125 MiB 427 B
 *   SI     : 128 MB 427 B
 * Wasn't intented, but in both representations the amount of bytes are
 * identical for this number. (This works if xMiB * 1024 ends on 000)
 */
inline std::string prettyPrintBytes
(
    size_t       bytes,
    bool   const logical = true
)
{
    char const suffixes[] = { ' ', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' };
    std::stringstream out;
    std::vector< size_t > parts;
    for ( unsigned i = 0u; i < sizeof( suffixes ); ++i )
    {
        parts.push_back( bytes % size_t( 1024 ) );
        bytes /= size_t( 1024 );
        if ( bytes == 0 )
            break;
    }
    assert( parts.size() > 0 );
    for ( int i = (int) parts.size()-1; i >= 0; --i )
    {
        if ( i != (int) parts.size()-1 && parts.at(i) == 0 )
            continue;
        out << parts[i] << " " << suffixes[i] << ( logical ? "i" : "" )
            << "B" << ( i > 0 ? " " : "" );
    }
    std::string result = out.str();
    result.erase( result.size()-1, 1 );
    return result;
}

#if defined( __CUDACC__ )

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
        uint64_t const nThreadsNeeded = ceilDiv( n, nMinElements );
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


inline __device__ long long unsigned int getLinearThreadId( void )
{
    long long unsigned int i    = threadIdx.x;
    long long unsigned int iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax;
    // expands to: i = blockDim.x * blockDim.y * threadIdx.z + blockDim.x * threadIdx.y + threadIdx.x

    return i;
}

inline __device__ long long unsigned int getLinearGlobalId( void )
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

inline __device__ void getLinearGlobalIdSize
(
    long long unsigned int * riThread,
    long long unsigned int * rnThreads
)
{
    long long unsigned & i    = *riThread ;
    long long unsigned & iMax = *rnThreads;

    i    = threadIdx.x;
    iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax; iMax *= blockDim.z;
    i +=  blockIdx.x * iMax; iMax *= gridDim.x;
    i +=  blockIdx.y * iMax; iMax *= gridDim.y;
    i +=  blockIdx.z * iMax; iMax *= gridDim.z;
}

inline __device__ long long unsigned int getLinearBlockId( void )
{
    long long unsigned int i    = blockIdx.x;
    long long unsigned int iMax = gridDim.x;

    i += blockIdx.y * iMax; iMax *= gridDim.y;
    i += blockIdx.z * iMax;
    // expands to: i = blockDim.x * blockDim.y * threadIdx.z + blockDim.x * threadIdx.y + threadIdx.x

    return i;
}

inline __device__ long long unsigned int getBlockSize( void )
{
    return blockDim.x * blockDim.y * blockDim.z;
}

inline __device__ long long unsigned int getGridSize( void )
{
    return gridDim.x * gridDim.y * gridDim.z;
}

#endif


#include <cassert>
#include <cstdio>               // printf, fflush
#include <cstdlib>              // NULL, malloc, free


/**
 * Returns the number of arithmetic CUDA cores per streaming multiprocessor
 * Note that there are also extra special function units.
 * This corresponds to 32 bit add, multiply, FMA instructions.
 * 64-bit capabilities will be (far) less
 * Note that for 2.0 the two warp schedulers can only issue 16 instructions
 * per cycle each. Meaning the 32 CUDA cores can't be used in parallel with
 * the 4 special function units. For 2.1 up this is a different matter
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capabilities
 *      from CUDA Toolkit v9.0.176
 **/
inline int getCudaCoresPerMultiprocessor
(
    int const majorVersion,
    int const minorVersion
)
{
    if ( majorVersion == 2 && minorVersion == 0 ) /* Fermi   */ return 32 ;
    if ( majorVersion == 2 && minorVersion == 1 ) /* Fermi   */ return 48 ;
    if ( majorVersion == 3 )                      /* Kepler  */ return 192;
    if ( majorVersion == 5 )                      /* Maxwell */ return 128;
    if ( majorVersion == 6 )                      /* Pascal  */ return 64 ;
    if ( majorVersion == 6 && minorVersion == 1 ) /* Pascal  */ return 128;
    if ( majorVersion == 6 && minorVersion == 2 ) /* Pascal  */ return 128;
    if ( majorVersion == 7 )                      /* Volta   */ return 64 ;
    return 0; /* unknown, could also throw exception */
}
/**
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capabilities
 *      from CUDA Toolkit v9.0.176
 **/
inline int getCudaMaxConcurrentKernels
(
    int const majorVersion,
    int const minorVersion
)
{
    if ( majorVersion == 2 ) /* Fermi */ return 0;
    if ( majorVersion == 3 && minorVersion == 0 ) /* Kepler  */ return 16 ;
    if ( majorVersion == 3 && minorVersion == 2 ) /* Kepler  */ return 4  ;
    if ( majorVersion == 3 && minorVersion == 5 ) /* Kepler  */ return 32 ;
    if ( majorVersion == 3 && minorVersion == 7 ) /* Kepler  */ return 32 ;
    if ( majorVersion == 5 && minorVersion == 0 ) /* Maxwell */ return 32 ;
    if ( majorVersion == 5 && minorVersion == 2 ) /* Maxwell */ return 32 ;
    if ( majorVersion == 5 && minorVersion == 3 ) /* Maxwell */ return 16 ;
    if ( majorVersion == 6 && minorVersion == 0 ) /* Pascal  */ return 128;
    if ( majorVersion == 6 && minorVersion == 1 ) /* Pascal  */ return 32 ;
    if ( majorVersion == 6 && minorVersion == 2 ) /* Pascal  */ return 16 ;
    if ( majorVersion == 7 && minorVersion == 0 ) /* Volta   */ return 128;
    return 0;   /* unknown, could also throw exception */
}

/**
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capability
 *      from CUDA Toolkit v9.0.176
 */
inline std::string getCudaCodeName
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
    if ( majorVersion == 7 )
        return "Volta";
    return 0; /* unknown, could also throw exception */
}


#if defined( __CUDACC__ )

/**
 * @return flops (not GFlops, ... )
 */
inline float getCudaPeakFlops( cudaDeviceProp const & props )
{
    return (float) props.multiProcessorCount * props.clockRate /* kHz */ * 1e3f *
        getCudaCoresPerMultiprocessor( props.major, props.minor );
}

#include <sstream>

std::string getCudaCacheConfigString( void )
{
    std::stringstream out;
    out << "Prefer ";
    cudaFuncCache funcCache;
    cudaDeviceGetCacheConfig( &funcCache );
    switch ( funcCache )
    {
        case cudaFuncCachePreferNone  : out << "None"  ; break;
        case cudaFuncCachePreferShared: out << "Shared"; break;
        case cudaFuncCachePreferL1    : out << "L1"    ; break;
        case cudaFuncCachePreferEqual : out << "Equal" ; break;
        default: printf( "?" );
    }
    return out.str();
}

std::string getCudaSharedMemBankSizeString( void )
{
    std::stringstream out;
    cudaSharedMemConfig config;
    cudaDeviceGetSharedMemConfig( &config );
    switch ( config )
    {
        case cudaSharedMemBankSizeDefault  : out << "Default"; break;
        case cudaSharedMemBankSizeFourByte : out << "4 Bytes"; break;
        case cudaSharedMemBankSizeEightByte: out << "8 Bytes"; break;
        default: printf( "?" );
    }
    return out.str();
}


std::string printSharedMemoryConfig( void )
{
    std::stringstream out;
    out << "[Shared Memory] Config: " << getCudaCacheConfigString()
        << ", Bank Size: " << getCudaSharedMemBankSizeString() << "\n";
    return out.str();
}

/**
 * @param[out] rpDeviceProperties - Array of cudaDeviceProp of length rnDevices
 *             the user will need to free (C-style) this data on program exit!
 * @param[out] rnDevices - will hold number of cuda devices
 *
 * Most of these can also be queried using cuDeviceGetAttribute from the
 * cuda_runtime_api.h header
 * @see http://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__DEVICE.html
 *      v9.0.176
 * @see http://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__TYPES.html#group__CUDA__TYPES_1ge12b8a782bebe21b1ac0091bf9f4e2a3
 * List of attributes not included in device properties:
 *   CU_DEVICE_ATTRIBUTE_MAX_PITCH (could be normal mem pitch?)
 CU_DEVICE_ATTRIBUTE_UNIFIED_ADDRESSING = 41
    Device shares a unified address space with the host
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_LAYERED_WIDTH = 42
    Maximum 1D layered texture width
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_LAYERED_LAYERS = 43
    Maximum layers in a 1D layered texture
    CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_WIDTH_ALTERNATE = 47
    Alternate maximum 3D texture width
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_HEIGHT_ALTERNATE = 48
    Alternate maximum 3D texture height
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_DEPTH_ALTERNATE = 49
    Alternate maximum 3D texture depth
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURECUBEMAP_WIDTH = 52
    Maximum cubemap texture width/height
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURECUBEMAP_LAYERED_WIDTH = 53
    Maximum cubemap layered texture width/height
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURECUBEMAP_LAYERED_LAYERS = 54
    Maximum layers in a cubemap layered texture
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE1D_WIDTH = 55
    Maximum 1D surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_WIDTH = 56
    Maximum 2D surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_HEIGHT = 57
    Maximum 2D surface height
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE3D_WIDTH = 58
    Maximum 3D surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE3D_HEIGHT = 59
    Maximum 3D surface height
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE3D_DEPTH = 60
    Maximum 3D surface depth
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE1D_LAYERED_WIDTH = 61
    Maximum 1D layered surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE1D_LAYERED_LAYERS = 62
    Maximum layers in a 1D layered surface
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_LAYERED_WIDTH = 63
    Maximum 2D layered surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_LAYERED_HEIGHT = 64
    Maximum 2D layered surface height
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_LAYERED_LAYERS = 65
    Maximum layers in a 2D layered surface
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACECUBEMAP_WIDTH = 66
    Maximum cubemap surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACECUBEMAP_LAYERED_WIDTH = 67
    Maximum cubemap layered surface width
CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACECUBEMAP_LAYERED_LAYERS = 68
    Maximum layers in a cubemap layered surface
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_LINEAR_WIDTH = 69
    Maximum 1D linear texture width
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_WIDTH = 70
    Maximum 2D linear texture width
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_HEIGHT = 71
    Maximum 2D linear texture height
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_PITCH = 72
    Maximum 2D linear texture pitch in bytes
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_MIPMAPPED_WIDTH = 73
    Maximum mipmapped 2D texture width
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_MIPMAPPED_HEIGHT = 74
    Maximum mipmapped 2D texture height
CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR = 75
    Major compute capability version number
CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR = 76
    Minor compute capability version number
CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_MIPMAPPED_WIDTH = 77
    Maximum mipmapped 1D texture width
CU_DEVICE_ATTRIBUTE_STREAM_PRIORITIES_SUPPORTED = 78
    Device supports stream priorities
CU_DEVICE_ATTRIBUTE_GLOBAL_L1_CACHE_SUPPORTED = 79
    Device supports caching globals in L1
CU_DEVICE_ATTRIBUTE_LOCAL_L1_CACHE_SUPPORTED = 80
    Device supports caching locals in L1
CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_MULTIPROCESSOR = 81
    Maximum shared memory available per multiprocessor in bytes
CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_MULTIPROCESSOR = 82
    Maximum number of 32-bit registers available per multiprocessor
CU_DEVICE_ATTRIBUTE_MANAGED_MEMORY = 83
    Device can allocate managed memory on this system
CU_DEVICE_ATTRIBUTE_MULTI_GPU_BOARD = 84
    Device is on a multi-GPU board
CU_DEVICE_ATTRIBUTE_MULTI_GPU_BOARD_GROUP_ID = 85
    Unique id for a group of devices on the same multi-GPU board
CU_DEVICE_ATTRIBUTE_SINGLE_TO_DOUBLE_PRECISION_PERF_RATIO = 87
    Ratio of single precision performance (in floating-point operations per second) to double precision performance
CU_DEVICE_ATTRIBUTE_PAGEABLE_MEMORY_ACCESS = 88
    Device supports coherently accessing pageable memory without calling cudaHostRegister on it
CU_DEVICE_ATTRIBUTE_CONCURRENT_MANAGED_ACCESS = 89
    Device can coherently access managed memory concurrently with the CPU
CU_DEVICE_ATTRIBUTE_COMPUTE_PREEMPTION_SUPPORTED = 90
    Device supports compute preemption.
CU_DEVICE_ATTRIBUTE_CAN_USE_HOST_POINTER_FOR_REGISTERED_MEM = 91
    Device can access host registered memory at the same virtual address as the CPU
CU_DEVICE_ATTRIBUTE_CAN_USE_STREAM_MEM_OPS = 92
    cuStreamBatchMemOp and related APIs are supported.
CU_DEVICE_ATTRIBUTE_CAN_USE_64_BIT_STREAM_MEM_OPS = 93
    64-bit operations are supported in cuStreamBatchMemOp and related APIs.
CU_DEVICE_ATTRIBUTE_CAN_USE_STREAM_WAIT_VALUE_NOR = 94
    CU_STREAM_WAIT_VALUE_NOR is supported.
CU_DEVICE_ATTRIBUTE_COOPERATIVE_LAUNCH = 95
    Device supports launching cooperative kernels via cuLaunchCooperativeKernel
CU_DEVICE_ATTRIBUTE_COOPERATIVE_MULTI_DEVICE_LAUNCH = 96
    Device can participate in cooperative kernels launched via cuLaunchCooperativeKernelMultiDevice
CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK_OPTIN = 97
    Maximum optin shared memory per block
CU_DEVICE_ATTRIBUTE_MAX
 */
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
        int   const coresPerSM = getCudaCoresPerMultiprocessor( prop->major, prop->minor );
        float const peakFlops  = getCudaPeakFlops( *prop );

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
        printf( "| Peak FLOPS               : %f GFLOPS\n" , peakFlops / 1e9f );
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
        printf( "| Cache Configuration      : %s\n"        , getCudaCacheConfigString().c_str() );
        printf( "| Shared Memory Bank Size  : %s\n"        , getCudaSharedMemBankSizeString().c_str() );
		printf( "|--------------------- Graphics ---------------------\n" );
		printf( "| Compute mode             : %s\n"        ,      computeModeString );
		printf( "|---------------------- Other -----------------------\n" );
        printf( "| Can map Host Memory      : %s\n"        , prop->canMapHostMemory  ? "true" : "false" );
        printf( "| Can run Kernels conc.    : %s\n"        , prop->concurrentKernels ? "true" : "false" );
        printf( "|   => max. conc. kernels  : %i\n"        , getCudaMaxConcurrentKernels( prop->major, prop->minor ) );
		printf( "| Number of Asyn. Engines  : %i\n"        , prop->asyncEngineCount );
        printf( "| Can Copy and Kernel conc.: %s\n"        , prop->deviceOverlap     ? "true" : "false" );
        printf( "| ECC Enabled              : %s\n"        , prop->ECCEnabled        ? "true" : "false" );
        printf( "| Device is Integrated     : %s\n"        , prop->integrated        ? "true" : "false" );
        printf( "| Kernel Timeout Enabled   : %s\n"        , prop->kernelExecTimeoutEnabled ? "true" : "false" );
        printf( "| Uses TESLA Driver        : %s\n"        , prop->tccDriver         ? "true" : "false" );
        printf( "=====================================================\n" );
        fflush(stdout);
    }

    if ( rpDeviceProperties == &fallbackPropArray )
        free( fallbackPropArray );
}

#endif

#if defined( __CUDA_ARCH__ ) && __CUDA_ARCH__ < 600
/**
 * atomicAdd for double is not natively implemented, because it's not
 * supported by (all) the hardware, therefore resulting in a time penalty.
 * http://stackoverflow.com/questions/12626096/why-has-atomicadd-not-been-implemented-for-doubles
 * https://stackoverflow.com/questions/37566987/cuda-atomicadd-for-doubles-definition-error
 */
inline __device__
double atomicAdd( double* address, double val )
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
class MirroredVector;

template< class T >
class MirroredTexture;


#if defined( __CUDACC__ )

/**
 * https://stackoverflow.com/questions/10535667/does-it-make-any-sense-to-use-inline-keyword-with-templates
 */
template< class T >
class MirroredVector
{
    #define DEBUG_MIRRORED_VECTOR 0
public:
    typedef T value_type;

    T *                host     ;
    T *                gpu      ;
    size_t       const nElements;
    size_t       const nBytes   ;
    cudaStream_t const mStream  ;   /* not implemented yet */
    bool         const mAsync   ;

    inline MirroredVector()
     : host( NULL ), gpu( NULL ), nElements( 0 ), nBytes( 0 ), mStream( 0 ), mAsync( false )
    {}

    inline void malloc()
    {
        if ( host == NULL )
        {
            #if DEBUG_MIRRORED_VECTOR > 10
                std::cerr << "[" << __FILENAME__ << "::MirroredVector::malloc]"
                    << "Allocate " << prettyPrintBytes( nBytes ) << " on host.\n";
            #endif
            host = (T*) ::malloc( nBytes );
        }
        if ( gpu == NULL )
        {
            #if DEBUG_MIRRORED_VECTOR > 10
                std::cerr << "[" << __FILENAME__ << "::MirroredVector::malloc]"
                    << "Allocate " << prettyPrintBytes( nBytes ) << " on GPU.\n";
            #endif
            CUDA_ERROR( cudaMalloc( (void**) &gpu, nBytes ) );
        }
        if ( ! ( host != NULL && gpu != NULL ) )
        {
            std::stringstream msg;
            msg << "[" << __FILENAME__ << "::MirroredVector::malloc] "
                << "Something went wrong when trying to allocate memory "
                << "(host=" << (void*) host << ", gpu=" << (void*) gpu
                << ", nBytes=" << nBytes << std::endl;
            throw std::runtime_error( msg.str() );
        }
    }

    inline MirroredVector
    (
        size_t const rnElements,
        cudaStream_t rStream = 0,
        bool const   rAsync  = false
    )
     : host( NULL ), gpu( NULL ), nElements( rnElements ),
       nBytes( rnElements * sizeof(T) ), mStream( rStream ),
       mAsync( rAsync )
    {
        this->malloc();
    }

    /**
     * Uses async, but not that by default the memcpy gets queued into the
     * same stream as subsequent kernel calls will, so that a synchronization
     * will be implied
     */
    inline void push( int const rAsync = -1 ) const
    {
        if ( ! ( host != NULL || gpu != NULL || nBytes == 0 ) )
        {
            std::stringstream msg;
            msg << "[" << __FILENAME__ << "::MirroredVector::push] "
                << "Can't push, need non NULL pointers and more than 0 elements. "
                << "(host=" << (void*) host << ", gpu=" << (void*) gpu
                << ", nBytes=" << nBytes << std::endl;
            throw std::runtime_error( msg.str() );
        }
        CUDA_ERROR( cudaMemcpyAsync( (void*) gpu, (void*) host, nBytes,
                                     cudaMemcpyHostToDevice, mStream ) );
        CUDA_ERROR( cudaPeekAtLastError() );
        if ( ( rAsync == -1 && ! mAsync ) || ! rAsync )
            CUDA_ERROR( cudaStreamSynchronize( mStream ) );
    }

    inline void pop( int const rAsync = -1 ) const
    {
        if ( ! ( host != NULL || gpu != NULL || nBytes == 0 ) )
        {
            std::stringstream msg;
            msg << "[" << __FILENAME__ << "::MirroredVector::pop] "
                << "Can't pop, need non NULL pointers and more than 0 elements. "
                << "(host=" << (void*) host << ", gpu=" << (void*) gpu
                << ", nBytes=" << nBytes << std::endl;
            throw std::runtime_error( msg.str() );
        }
        CUDA_ERROR( cudaMemcpyAsync( (void*) host, (void*) gpu, nBytes,
                                     cudaMemcpyDeviceToHost, mStream ) );
        CUDA_ERROR( cudaPeekAtLastError() );
        if ( ( rAsync == -1 && ! mAsync ) || ! rAsync )
            CUDA_ERROR( cudaStreamSynchronize( mStream ) );
    }

    inline void free()
    {
        if ( host != NULL )
        {
            ::free( host );
            host = NULL;
        }
        if ( gpu != NULL )
        {
            CUDA_ERROR( cudaFree( gpu ) );
            gpu = NULL;
        }
    }

    inline ~MirroredVector()
    {
        this->free();
    }

    #undef DEBUG_MIRRORED_VECTOR
};

template< typename T >
std::ostream & operator<<( std::ostream & out, MirroredVector<T> const & x )
{
    out << "( nElements = " << x.nElements << ", "
        << "nBytes = " << x.nBytes << ","
        << "sizeof(T) = " << sizeof(T) << ","
        << "host = " << x.host << ","
        << "gpu = " << x.gpu << " )";
    return out;
}

template< class T >
class MirroredTexture : public MirroredVector<T>
{
public:
    cudaResourceDesc    mResDesc;
    cudaTextureDesc     mTexDesc;
    cudaTextureObject_t texture ;

    /**
     * @see http://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__TEXTURE__OBJECT.html
     * @see https://devblogs.nvidia.com/parallelforall/cuda-pro-tip-kepler-texture-objects-improve-performance-and-flexibility/
     * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#texture-memory
     */
    inline void bind()
    {
        memset( &mResDesc, 0, sizeof( mResDesc ) );
        /**
         * enum cudaResourceType
         *   cudaResourceTypeArray          = 0x00
         *   cudaResourceTypeMipmappedArray = 0x01
         *   cudaResourceTypeLinear         = 0x02
         *   cudaResourceTypePitch2D        = 0x03
         */
        mResDesc.resType = cudaResourceTypeLinear;
        /**
         * enum cudaChannelFormatKind
         *   cudaChannelFormatKindSigned   = 0
         *   cudaChannelFormatKindUnsigned = 1
         *   cudaChannelFormatKindFloat    = 2
         *   cudaChannelFormatKindNone     = 3
         */
        mResDesc.res.linear.desc.f      = cudaChannelFormatKindUnsigned;
        mResDesc.res.linear.desc.x      = sizeof(T) * 8; // bits per channel
        mResDesc.res.linear.devPtr      = this->gpu;
        mResDesc.res.linear.sizeInBytes = this->nBytes;

        memset( &mTexDesc, 0, sizeof( mTexDesc ) );
        /**
         * enum cudaTextureReadMode
         *   cudaReadModeElementType     = 0
         *     Read texture as specified element type
         *   cudaReadModeNormalizedFloat = 1
         *     Read texture as normalized float
         */
        mTexDesc.readMode = cudaReadModeElementType;

        /* the last three arguments are pointers to constants! */
        cudaCreateTextureObject( &texture, &mResDesc, &mTexDesc, NULL );
    }

    inline MirroredTexture
    (
        size_t const rnElements,
        cudaStream_t rStream = 0
    )
     : MirroredVector<T>( rnElements, rStream ), texture( 0 )
    {
        this->bind();
    }

    inline ~MirroredTexture()
    {
        cudaDestroyTextureObject( texture );
        texture = 0;
        this->free();
    }
};

#endif


template< class T > __device__ inline void swap( T & a, T & b )
{
    T const c = a;
    a = b;
    b = c;
}

template< typename T >
__host__ __device__ inline
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
        unsigned int const digit = number / expFloorLogBase;
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

__host__ __device__ inline
int snprintFloatArray
(
    char        * const msg  ,
    unsigned int  const nChars,
    float const * const gpData,
    unsigned int  const nElements
)
{
    unsigned int nCharsWritten = 0u;
    for ( unsigned int j = 0u; j < nElements; ++j )
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

#if __cplusplus >= 201103

/**
 * @see https://stackoverflow.com/questions/18625964/checking-if-an-input-is-within-its-range-of-limits-in-c
 * Use e.g. like this:
 *   int32_t value = 123456;
 *   assert( inRange< uint16_t >( value ) ); // will fail, because max. is 65535
 */
#include <limits>
#include <type_traits>                      // remove_reference

template< typename T_Range, typename T_Value, bool T_RangeSigned, bool T_ValueSigned >
struct InIntegerRange;

template< typename T_Range, typename T_Value >
struct InIntegerRange< T_Range, T_Value, false, false >
{
    bool operator()( T_Value const & x )
    {
        return x >= std::numeric_limits< T_Range >::min() &&
               x <= std::numeric_limits< T_Range >::max();
    }
};

template< typename T_Range, typename T_Value >
struct InIntegerRange< T_Range, T_Value, false, true >
{
    bool operator()( T_Value const & x )
    {
        return x >= 0 && x <= std::numeric_limits< T_Range >::max();
    }
};

template< typename T_Range, typename T_Value >
struct InIntegerRange< T_Range, T_Value, true, false >
{
    bool operator()( T_Value const & x )
    {
        return x <= std::numeric_limits< T_Range >::max(); /* x >= 0 is given */
    }
};

template< typename T_Range, typename T_Value >
struct InIntegerRange< T_Range, T_Value, true, true >
{
    bool operator()( T_Value const & x )
    {
        return x >= std::numeric_limits< T_Range >::min() &&
               x <= std::numeric_limits< T_Range >::max();
    }
};

template< typename T_Range, typename T_Value >
inline bool inRange( T_Value const & x )
{
    using Range = typename std::remove_reference< T_Range >::type;
    using Value = typename std::remove_reference< T_Value >::type;

    if( std::numeric_limits< Range >::is_integer )
    {
        return InIntegerRange< Range, Value,
                               std::numeric_limits< Range >::is_signed,
                               std::numeric_limits< Value >::is_signed >()( x );
    }
    else
    {
        return ( x > 0 ? x : -x ) <= std::numeric_limits< Range >::max() ||
               ( std::isnan(x) && std::numeric_limits< Range >::has_quiet_NaN ) ||
               ( std::isinf(x) && std::numeric_limits< Range >::has_infinity );
    }
}

#endif

#ifdef CUDACOMMON_GPUINFO_MAIN
    int main( void )
    {
        cudaDeviceProp * pGpus = NULL;
        int              nGpus = 0   ;
        getCudaDeviceProperties( &pGpus, &nGpus, true );
        return 0;
    }
#endif
