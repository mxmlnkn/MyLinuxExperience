/**
 * compile with:
 *   'nvcc' -ccbin=/usr/bin/g++-4.9 -std=c++11 --compiler-options -Wall,-Wextra -DCUDACOMMON_GPUINFO_MAIN -o gpuinfo --x cu gpuinfo.cu -lcuda && ./gpuinfo
 */

#ifndef CUDACOMMON_GPUINFO_MAIN
#   pragma once
#endif

#include <cassert>
#include <cstdint>                      // uint64_t
#include <cstdio>
#include <cstdlib>                      // NULL, malloc, free, memset
#include <cstdlib>                      // EXIT_FAILURE, exit
#include <iostream>
#include <stdexcept>
#include <sstream>
#ifdef __CUDACC__
#   include <cuda_runtime_api.h>
#   include <cuda.h>                    // cuDeviceGetAttribute
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
        std::cout << "CUDA error " << (int) rValue << " in " << file
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


/**
 * some helper function to be used in templated kernels to e.g. get the
 * corresponing CUDA vector 4 for a given template parameter
 * http://www.icl.utk.edu/~mgates3/docs/cuda.html
 */
template< typename T > struct CudaVec3;
template< typename T > struct CudaVec4;
template< typename T > struct CudaVec3To4;
template< typename T > struct CudaVec4To3;
#define TMP_CUDAVECS( ELEMENTTYPE, CUDATYPENAME ) \
template<> struct CudaVec3< ELEMENTTYPE >{ typedef CUDATYPENAME##3 value_type; }; \
template<> struct CudaVec4< ELEMENTTYPE >{ typedef CUDATYPENAME##4 value_type; }; \
template<> struct CudaVec3To4< CUDATYPENAME##3 >{ typedef CUDATYPENAME##4 value_type; }; \
template<> struct CudaVec4To3< CUDATYPENAME##4 >{ typedef CUDATYPENAME##3 value_type; };
#define TMP_CUDAVECS_UI( ELEMENTTYPE, CUDATYPENAME ) \
TMP_CUDAVECS( u##ELEMENTTYPE, u##CUDATYPENAME ) \
TMP_CUDAVECS( ELEMENTTYPE, CUDATYPENAME )
TMP_CUDAVECS_UI( int8_t , char  )
TMP_CUDAVECS_UI( int16_t, short )
TMP_CUDAVECS_UI( int32_t, int   )
TMP_CUDAVECS_UI( int64_t, long  )
#undef TMP_CUDAVECS
#undef TMP_CUDAVECS_UI

/**
 * Some debug output for understanding compilation
 * @see http://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#cuda-arch
 * Sources get compiled two times __CUDA_ARCH__
 * @see https://devtalk.nvidia.com/default/topic/516937/__cuda_arch__-undefined-33-/
 * @see http://www.mersenneforum.org/showthread.php?t=18668
 * @see https://devtalk.nvidia.com/default/topic/496061/is-__cuda_arch__-broken-/
 * Normally __CUDA_ARCH__ shouldn't be used in headers! If so, watch out, that
 * is only used inside the function body, so that for host compilation it still
 * is visible... then again if it is a device function, why does it have to
 * be visible ... I'm confused
 * @see http://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#cuda-compilation-trajectory
 * @see http://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#using-separate-compilation-in-cuda
 * @see https://github.com/pathscale/nvidia_sdk_samples/blob/master/vectorAdd/build/cuda/5.0.35-13978363_x64/include/sm_30_intrinsics.h
 *   => they use #if ! defined( __CUDA_ARCH__ ) || __CUDA_ARCH__ >= 300
 *      for body-code it shouldn't matter, but for function headers to be
 *      seen this is the working approach
 */
#if 0

#if defined( __CUDACC__ )
#   warning __CUDACC__ defined
#else
#   warning __CUDACC__ NOT defined
#endif

#if defined( __CUDA_ARCH__ )
#   if __CUDA_ARCH__ < 300
#       warning __CUDA_ARCH__ < 300
#   elif __CUDA_ARCH__ <= 300
#       warning __CUDA_ARCH__ == 300
#   elif __CUDA_ARCH__ <= 350
#       warning __CUDA_ARCH__ in (300,350]
#   elif __CUDA_ARCH__ <= 400
#       warning __CUDA_ARCH__ in (350,400]
#   elif __CUDA_ARCH__ <= 500
#       warning __CUDA_ARCH__ in (400,500]
#   elif __CUDA_ARCH__ <= 600
#       warning __CUDA_ARCH__ in (500,600]
#   else
#       warning __CUDA_ARCH__ > 300
#   endif
#else
#   warning __CUDA_ARCH__ NOT defined!
#endif

#endif

/**
 * Some overloads to automatically use SIMD intrinsics if available, if not
 * then this just saves boiler-plate code, dunno why this isn't overloaded
 * like this by default at least not in CUDA 7 ...
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#simd-video
 * preliminary benchmarks indicated using __vadd2 being slower than two normal
 * adds, therefore deactivate wtih false
 */
#if defined( __CUDA_ARCH__ ) && __CUDA_ARCH__ >= 300 & false
#   define TMP_OPERATORP_UI4( UI )                                             \
    __device__ inline UI##char4 operator+                                      \
    (                                                                          \
        UI##char4 const & x,                                                   \
        UI##char4 const & y                                                    \
    )                                                                          \
    {                                                                          \
        UI##char4 z;                                                           \
        * reinterpret_cast< unsigned int * >( & z ) = __vadd4(                 \
            * reinterpret_cast< unsigned int const * >( & x ),                 \
            * reinterpret_cast< unsigned int const * >( & y )                  \
        );                                                                     \
        return z;                                                              \
    }                                                                          \
                                                                               \
    __device__ inline UI##short4 operator+                                     \
    (                                                                          \
        UI##short4 const & x,                                                  \
        UI##short4 const & y                                                   \
    )                                                                          \
    {                                                                          \
        UI##short4 z;                                                          \
        * reinterpret_cast< unsigned int * >( & z ) = __vadd2(                 \
            * reinterpret_cast< unsigned int const * >( & x ),                 \
            * reinterpret_cast< unsigned int const * >( & y )                  \
        );                                                                     \
        *( reinterpret_cast< unsigned int * >( & z ) + 1 ) = __vadd2(          \
            *( reinterpret_cast< unsigned int const * >( & x ) + 1 ),          \
            *( reinterpret_cast< unsigned int const * >( & y ) + 1 )           \
        );                                                                     \
        return z;                                                              \
    }
    TMP_OPERATORP_UI4()
    TMP_OPERATORP_UI4(u)
    #undef TMP_OPERATORP_UI4
#else
    /**
     * without explicit conversions, yields narrowing warning, because of this:
     * https://stackoverflow.com/questions/4814668/addition-of-two-chars-produces-int
     * ... whyyyyy, I'm dying a bit inside not to talk about the time I lost
     * tracking this down
     */
    __device__ inline char3 operator+( char3 const & x, char3 const & y ) {
        return { char(x.x + y.x), char(x.y + y.y), char(x.z + y.z) }; }
    __device__ inline short3 operator+( short3 const & x, short3 const & y ) {
        return { short(x.x + y.x), short(x.y + y.y), short(x.z + y.z) }; }
    __device__ inline uchar3 operator+( uchar3 const & x, uchar3 const & y )
    {
        return { (unsigned char)(x.x + y.x),
                 (unsigned char)(x.y + y.y),
                 (unsigned char)(x.z + y.z) };
     }
    __device__ inline ushort3 operator+( ushort3 const & x, ushort3 const & y )
    {
        return { (unsigned short)(x.x + y.x),
                 (unsigned short)(x.y + y.y),
                 (unsigned short)(x.z + y.z) };
    }

    __device__ inline char4 operator+( char4 const & x, char4 const & y ) {
        return { char(x.x + y.x), char(x.y + y.y), char(x.z + y.z), char(x.w + y.w) }; }
    __device__ inline short4 operator+( short4 const & x, short4 const & y ) {
        return { short(x.x + y.x), short(x.y + y.y), short(x.z + y.z), short(x.w + y.w) }; }
    __device__ inline uchar4 operator+( uchar4 const & x, uchar4 const & y )
    {
        return { (unsigned char)(x.x + y.x),
                 (unsigned char)(x.y + y.y),
                 (unsigned char)(x.z + y.z),
                 (unsigned char)(x.w + y.w) };
     }
    __device__ inline ushort4 operator+( ushort4 const & x, ushort4 const & y )
    {
        return { (unsigned short)(x.x + y.x),
                 (unsigned short)(x.y + y.y),
                 (unsigned short)(x.z + y.z),
                 (unsigned short)(x.w + y.w) };
    }
#endif
__device__ inline int3 operator+( int3 const & x, int3 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z }; }
__device__ inline long3 operator+( long3 const & x, long3 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z }; }
__device__ inline uint3 operator+( uint3 const & x, uint3 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z }; }
__device__ inline ulong3 operator+( ulong3 const & x, ulong3 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z }; }

__device__ inline int4 operator+( int4 const & x, int4 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z, x.w + y.w }; }
__device__ inline long4 operator+( long4 const & x, long4 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z, x.w + y.w }; }
__device__ inline uint4 operator+( uint4 const & x, uint4 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z, x.w + y.w }; }
__device__ inline ulong4 operator+( ulong4 const & x, ulong4 const & y ) {
    return { x.x + y.x, x.y + y.y, x.z + y.z, x.w + y.w }; }

/**
 * It is utterly confusing that
 * #if defined( __CUDA_ARCH__ ) && __CUDA_ARCH__ >= 0
 *   __device__ inline int f( void ){}
 * #elif defined( __CUDA_ARCH__ )
 *   __device__ inline int f( void ){}
 * #endif
 * does not work if called from inside a __global__ function, but the
 * lower code still seems to never be used ...
 */


#ifdef __CUDACC__
#if ! defined( __CUDA_ARCH__ ) || __CUDA_ARCH__ >= 300

/**
 * Reduces a value inside each warp who calls this function recursively
 * and the thread with lane ID 0 will have the result. Actually all threads
 * in the warps hould have the same result, as there is no predicate being
 * used for the addition and even though the shuffling rotates, it is
 * symmetrical to shifts, therefore it must have the same result for each
 * thread.
 * @verbatim
 * |0|1|2|3|4|5|6|7|
 * +-+-+-+-+-+-+-+-+
 *         .'.'.'.'  delta = 4, i.e. 0 gets the value
 *       .'.'.'.'    of lane 4, 1 of lane 5, ...
 *     .'.'.'.'
 *   .'.'.'.'
 * |0|1|2|3|4|5|6|7|
 * +-+-+-+-+-+-+-+-+
 *     .'.'          delta = 2
 *   .'.'
 * |0|1|2|3|4|5|6|7|
 * +-+-+-+-+-+-+-+-+
 *   .'              delta = 1
 * |0|1|2|3|4|5|6|7|
 * +-+-+-+-+-+-+-+-+
 * @endverbatim
 * @see https://devblogs.nvidia.com/faster-parallel-reductions-kepler/
 */
template< typename T > __inline__ __device__
T warpReduceSum( T x )
{
#if 0
    #pragma unroll
    for ( int delta = warpSize >> 1; delta > 0; delta >>= 1 )
        x += __shfl_down( x, delta );
#else
    assert( warpSize == 32 );
    x += __shfl_down( x, 16 );
    x += __shfl_down( x,  8 );
    x += __shfl_down( x,  4 );
    x += __shfl_down( x,  2 );
    x += __shfl_down( x,  1 );
#endif
    return x;
}

template< typename T > __inline__ __device__
T warpAllReduceSum( T x )
{
#if 0
    #pragma unroll
    for ( int mask = warpSize >> 1; mask > 0; mask >>= 1 )
        x += __shfl_xor( x, mask );
#else
    assert( warpSize == 32 );
    x += __shfl_xor( x, 16 );
    x += __shfl_xor( x,  8 );
    x += __shfl_xor( x,  4 );
    x += __shfl_xor( x,  2 );
    x += __shfl_xor( x,  1 );
#endif
    return x;
}

/**
 * Similar to warpReduceSum, but actually returns the cumulative sum
 * of all elements with lower threadIds, such that it can be used to
 * calculate the cumulative sums inside a kernel which filters by linear
 * thread ID.
 * It is down recursively with a divide and conquer scheme, i.e. at each
 * step each thread only has the cumsum in as viewn in an interval of 2,4,8,...
 * E.g. if each thread would store a 1, being denoted as a block, then
 * the result of each thread having the corresponding cumsum, would look
 * like a triangle and the intermediary steps would looke like the following:
 * @verbatim
 * 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
 *
 * x x x x x x x x x x x x x x x x
 *
 *               |
 *               v
 *
 * x x x x x x x x x x x x x x x x
 * x   x   x   x   x   x   x   x
 *
 *               |
 *               v
 *
 * ,-+-+-. ,-+-+-. ,-+-+-.
 * v v v | v v v | v v v |
 *       |       |       |
 * x x x x x x x x x x x x x x x x
 * x x x   x x x   x x x   x x x
 * x x     x x     x x     x x
 * x       x       x       x
 *
 *               |
 *               v
 *
 * ,-+-+-+-+-+-+-+-.
 * v v v v v v v v |
 *                 |
 * x x x x x x x x x x x x x x x x
 * x x x x x x x   x x x x x x x
 * x x x x x x     x x x x x x
 * x x x x x       x x x x x
 * x x x x         x x x x
 * x x x           x x x
 * x x             x x
 * x               x
 * @endverbatim
 * Would be a bitch to do with __shfl_down, instead use __shfl_idx
 * Basically we just need to mask out some bits of the src laneId,
 * to get the target! The higher bits are basically indexing the
 * subintervals and the lower bits those inside the subintervals
 *
 * @see https://devblogs.nvidia.com/cuda-pro-tip-optimized-filtering-warp-aggregated-atomics/
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/#warp-shuffle-functions
 *   -> since CUDA 9 they got renamed to have a suffix '_sync'
 * Actually we could delegate some of the bitmasking to CUDA by using the
 * width parameter!
 */
template< typename T > __device__ inline
T warpReduceCumSum( T x )
{
    /* todo */
    assert( warpSize == 32 );
    /* first calculate y_i = \sum_{k=0}^{2^i}  x_i */
    /* & (32-1) -> laneID, not sure if faster than % warpSize */;
    int const laneId = threadIdx.x & 0x1F;
#if 0
    for ( int width = 1; width < warpSize; width <<= 1 )
    {
        int const srcId = ( laneId & ~( width-1 ) ) - 1;
        int const dx = __shfl( x, srcId );
        if ( laneId % ( width * 2 ) >= width )
            x += dx;
    }
#else
    T dx;
    assert( warpSize == 32 );
    /**
     * using that l % 2^k is same as l &~( 2^k-1 ) and that
     * x & 0b0001111 >= 0b0001000 would be the same as checking
     * whether bit 4 was set, i.e. x & 0b0001000 != 0
     * lastly use that __shfl( x, laneId & 0b111100 - 1 )
     * would be the same as as: __shfl( x, id = 0b11, width = 0b1000 )
     */
    #if 0
        dx = __shfl( x, ( laneId & 0xFFFF ) - 1 ); if ( laneId %  2 >=  1 ) x += dx;
        dx = __shfl( x, ( laneId & 0xFFFE ) - 1 ); if ( laneId %  4 >=  2 ) x += dx;
        dx = __shfl( x, ( laneId & 0xFFFC ) - 1 ); if ( laneId %  8 >=  4 ) x += dx;
        dx = __shfl( x, ( laneId & 0xFFF8 ) - 1 ); if ( laneId % 16 >=  8 ) x += dx;
        dx = __shfl( x, ( laneId & 0xFFF0 ) - 1 ); if ( laneId % 32 >= 16 ) x += dx;
    #else
        dx = __shfl( x,  0,  2 ); if ( laneId &  1 ) x += dx;
        dx = __shfl( x,  1,  4 ); if ( laneId &  2 ) x += dx;
        dx = __shfl( x,  3,  8 ); if ( laneId &  4 ) x += dx;
        dx = __shfl( x,  7, 16 ); if ( laneId &  8 ) x += dx;
        dx = __shfl( x, 15, 32 ); if ( laneId & 16 ) x += dx;
    #endif
#endif
    return x;
}

/**
 * same as warpReduceCumSum, but only can input bool, not a 32-bit number
 * __popc returns int @see http://docs.nvidia.com/cuda/cuda-math-api/group__CUDA__MATH__INTRINSIC__INT.html#group__CUDA__MATH__INTRINSIC__INT_1g43c9c7d2b9ebf202ff1ef5769989be46
 */
__device__ inline int warpReduceCumSumPredicate( bool const x )
{
    /* __ballot deprecated since CUDA 9 sets laneId-th bit set, i.e. lower are
     * to the "right" i.e. wil result in lower numbers */
    assert( warpSize == 32 );
    int const laneId = threadIdx.x & 0x1F; /* 32-1 -> laneID, not sure if faster than % warpSize */;
    int const mask = ( 2u << laneId ) - 1u; // will even wark for laneId 31, reslting in 0-1=-1
    return __popc( __ballot(x) & mask );
}

__device__ inline int warpReduceSumPredicate( bool const x )
{
    /* Inactive threads are represented by 0 bit!
     * @see https://stackoverflow.com/questions/23589734/ballot-behavior-on-inactive-lanes?rq=1 */
    return __popc( __ballot(x) );
}

/**
 * return type is int, because that's the return type for popc
 * and therefore by extension the one for __shfl, therefore typecasts
 * would be avoidable if you need something else
 *
 * Giving a __shared__ memory pointer like this only works for
 * __CUDA_ARCH__ >= 200
 */
__device__ inline int blockReduceCumSumPredicate( bool const x, int * const smBuffer )
{
    assert( threadIdx.y == 0 );
    assert( threadIdx.z == 0 );
    assert( blockDim.x <= warpSize * warpSize );
    /* calculate cum sums per warp */
    int cumsum = warpReduceCumSumPredicate( x );
    /* write all largest cumSums per warp, i.e. highest threadIdx / laneId
     * into __shared__ buffer. The highest thread doesn't need to store
     * its value, because noone needs to add it, this is useful, because
     * that allows calling this with some higher threadIds being filtered out */
    int const iSubarray = threadIdx.x / warpSize;
    if ( threadIdx.x % warpSize == warpSize - 1 )
        smBuffer[ iSubarray ] = cumsum;
    /* the first warp now reduces these intermediary sums to another cumsum
     * and writes it back. This is enough assuming that warpSize * warpSize <=
     * maxThreadsPerBlock, which is the case normally, i.e. 32^2 <= 1024 */
    /* DOOOOOOOOOOOOOOOOOOOOOOOOONNNNNNNTTTTTTTTT put __syncthreads inside
     * an if-statement if you ever wanna use it ouside the if statement again!
     * The bug caused by using this commented code, cost me hours to track
     * down ... */
    /*
    if ( threadIdx.x < warpSize )
    {
        __syncthreads();
        int const globalCumSum = warpReduceCumSum( smBuffer[ threadIdx.x ] );
        __syncthreads();
        smBuffer[ threadIdx.x ] = globalCumSum;
    }
    */
    __syncthreads();
    int globalCumSum;
    if ( threadIdx.x < warpSize )
        globalCumSum = warpReduceCumSum( smBuffer[ threadIdx.x ] );
    __syncthreads();
    if ( threadIdx.x < warpSize )
        smBuffer[ threadIdx.x ] = globalCumSum;
    /* now we need to apply these cumsums which kinda act like global offsets
     * to all our "small" cumsum variations */
    __syncthreads();
    if ( iSubarray > 0 )
        cumsum += smBuffer[ iSubarray-1 ];
    /* wait until everyone read before giving control back which could
     * possibly mess up the buffer! */
    __syncthreads();
    return cumsum;
}

/**
 * exactly same as blockReduceCumSumPredicate, but loose the 'Predicate'
 * suffix in al function names
 */
__device__ inline int blockReduceCumSum( int const x, int * const smBuffer )
{
    assert( threadIdx.y == 0 );
    assert( threadIdx.z == 0 );
    assert( blockDim.x <= warpSize * warpSize );
    int cumsum = warpReduceCumSum( x );
    int const iSubarray = threadIdx.x / warpSize;
    if ( threadIdx.x % warpSize == warpSize - 1 )
        smBuffer[ iSubarray ] = cumsum;
    __syncthreads();
    int globalCumSum;
    if ( threadIdx.x < warpSize )
        globalCumSum = warpReduceCumSum( smBuffer[ threadIdx.x ] );
    __syncthreads();
    if ( threadIdx.x < warpSize )
        smBuffer[ threadIdx.x ] = globalCumSum;
    __syncthreads();
    if ( iSubarray > 0 )
        cumsum += smBuffer[ iSubarray-1 ];
    __syncthreads();
    return cumsum;
}

__device__ inline int blockReduceSumPredicate( bool const x, int * const smBuffer )
{
    assert( threadIdx.y == 0 );
    assert( threadIdx.z == 0 );
    assert( blockDim.x <= warpSize * warpSize );
    int sum = warpReduceSumPredicate( x );
    if ( threadIdx.x < warpSize )
        smBuffer[ threadIdx.x ] = 0;
    __syncthreads();
    if ( threadIdx.x % warpSize == 0 )
        smBuffer[ threadIdx.x / warpSize ] = sum;
    __syncthreads();
    if ( threadIdx.x < warpSize )
        sum = warpReduceSum( smBuffer[ threadIdx.x ] );
    __syncthreads();
    // only threadIdx.x == 0 has the correct value!
    return sum;
}

/**
 * same as blockReduceSumPredicate just delate the "Predicate" inside first
 * warp reduce function name
 */
__device__ inline int blockReduceSum( int const x, int * const smBuffer )
{
    assert( threadIdx.y == 0 );
    assert( threadIdx.z == 0 );
    assert( blockDim.x <= warpSize * warpSize );
    int sum = warpReduceSum( x );
    if ( threadIdx.x < warpSize )
        smBuffer[ threadIdx.x ] = 0;
    __syncthreads();
    int const iSubarray = threadIdx.x / warpSize;
    if ( threadIdx.x % warpSize == 0 )
        smBuffer[ iSubarray ] = sum;
    __syncthreads();
    if ( threadIdx.x < warpSize )
        sum = warpReduceSum( smBuffer[ threadIdx.x ] );
    // only threadIdx.x == 0 has the correct value!
    return sum;
}
#endif // __CUDA_ARCH__ >= 300

#endif // __CUDACC__


template< typename T, typename S >
__host__ __device__
inline T ceilDiv( T a, S b )
{
    assert( b != S(0) );
    assert( a == a );
    assert( b == b );
    return ( a + b - T(1) ) / b;
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


inline __device__ unsigned long long int getLinearThreadId( void )
{
    unsigned long long int i    = threadIdx.x;
    unsigned long long int iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax;
    // expands to: i = blockDim.x * blockDim.y * threadIdx.z + blockDim.x * threadIdx.y + threadIdx.x

    return i;
}

inline __device__ unsigned long long int getLinearGlobalId( void )
{
    unsigned long long int i    = threadIdx.x;
    unsigned long long int iMax = blockDim.x;

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
    unsigned long long int * riThread,
    unsigned long long int * rnThreads
)
{
    unsigned long long int & i    = *riThread ;
    unsigned long long int & iMax = *rnThreads;

    i    = threadIdx.x;
    iMax = blockDim.x;

    i += threadIdx.y * iMax; iMax *= blockDim.y;
    i += threadIdx.z * iMax; iMax *= blockDim.z;
    i +=  blockIdx.x * iMax; iMax *= gridDim.x;
    i +=  blockIdx.y * iMax; iMax *= gridDim.y;
    i +=  blockIdx.z * iMax; iMax *= gridDim.z;
}

inline __device__ unsigned long long int getLinearBlockId( void )
{
    unsigned long long int i    = blockIdx.x;
    unsigned long long int iMax = gridDim.x;

    i += blockIdx.y * iMax; iMax *= gridDim.y;
    i += blockIdx.z * iMax;
    // expands to: i = blockDim.x * blockDim.y * threadIdx.z + blockDim.x * threadIdx.y + threadIdx.x

    return i;
}

inline __device__ unsigned long long int getBlockSize( void )
{
    return blockDim.x * blockDim.y * blockDim.z;
}

inline __device__ unsigned long long int getGridSize( void )
{
    return gridDim.x * gridDim.y * gridDim.z;
}

#endif // __CUDACC__


#include <cassert>
#include <cstdio>               // printf, fflush
#include <cstdlib>              // NULL, malloc, free
#include <map>


/**
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#arithmetic-instructions
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capabilities
 * @see https://devtalk.nvidia.com/default/topic/763273/peak-performance-of-integer-operation/
 * "Multiple instructions" means there is no native instruction to perform that operation, and instead the compiler emits an instruction sequence to perform the operation. It is typically on the order of 5-50 instructions. This can vary from operation to operation, architecture to architecture, and even compiler version to compiler version. If you want to find out what it is for a specific case, create a small test code, compile it, and then dump the machine code using
 *   cuobjdump -sass mycode
 * 32-bit integer add is at approximately the same throughput as corresponding floating point operations for all architectures. So I guess your concern is primarily around the 32-bit integer multiply.
 * => signaled here in the table with -1
 * @see https://devtalk.nvidia.com/default/topic/948014/forward-looking-gpu-integer-performance/?offset=14
 */
static std::map< std::string, std::vector< int > > sCudaInstructionThroughput =
{
                 /* 3.0 & 3.2, 3.5 & 3.7, 5.0 & 5.2, 5.3, 6.0, 6.1, 6.2, 7.0 */
    { "hpfpfma"    , {   0,   0,   0, 256, 128,   2, 256, 128 } },
    { "spfpfma"    , { 192, 192, 128, 128,  64, 128, 128,  64 } },
    { "dpfpfma"    , {   8,  64,   4,   4,  32,   4,   4,  32 } },
    { "sprecip"    , {  32,  32,  32,  32,  16,  32,  32,  16 } }, /* identical to special function units */
    { "32biadd"    , { 160, 160, 128, 128,  64, 128, 128,  64 } }, /* identical to spfma, except for kepler! */
    { "32bimul"    , {  32,  32,  -1,  -1,  -1,  -1,  -1,  64 } },
    { "32bishift"  , {  32,  64,  64,  64,  32,  64,  64,  64 } }, /* 2x special function, except 3.0, 3.2 */
    { "cmp"        , { 160, 160,  64,  64,  32,  64,  64,  64 } },
    { "32bireverse", {  32,  32,  64,  64,  32,  64,  64,  -1 } },
    { "32biand"    , { 160, 160, 128, 128,  64, 128, 128,  64 } }, /* identical to 32biadd */
    { "popc"       , {  32,  32,  32,  32,  16,  32,  32,  16 } }, /* identical to sprecip */
    { "shfl"       , {  32,  32,  32,  32,  32,  32,  32,  32 } }, /* always: 32 */
    { "convto32bit", { 128, 128,  32,  32,  16,  32,  32,  16 } },
    { "conv64bit"  , {   8,  32,   4,   4,  16,   4,   4,  16 } },
    { "convmisc"   , {  32,  32,  32,  32,  16,  32,  32,  16 } }  /* identical to sprecip */
};

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
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#arithmetic-instructions
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
    if ( majorVersion == 6 && minorVersion == 0 ) /* Pascal  */ return 64 ;
    if ( majorVersion == 6 && minorVersion == 1 ) /* Pascal  */ return 128;
    if ( majorVersion == 6 && minorVersion == 2 ) /* Pascal  */ return 128;
    if ( majorVersion == 7 )                      /* Volta   */ return 64 ;
    return 0; /* unknown, could also throw exception */
}

inline int getSpecialFunctionUnitsPerMultiprocessor
(
    int const majorVersion,
    int const minorVersion
)
{
    if ( majorVersion == 3 )                      /* Kepler  */ return 32;
    if ( majorVersion == 5 )                      /* Maxwell */ return 32;
    if ( majorVersion == 6 && minorVersion == 0 ) /* Pascal  */ return 16;
    if ( majorVersion == 6 && minorVersion == 1 ) /* Pascal  */ return 32;
    if ( majorVersion == 6 && minorVersion == 2 ) /* Pascal  */ return 32;
    if ( majorVersion == 7 )                      /* Volta   */ return 16;
    return 0; /* unknown, could also throw exception */
}

inline int getWarpSchedulersPerMultiprocessor
(
    int const majorVersion,
    int const minorVersion
)
{
    if ( majorVersion == 3 )                      /* Kepler  */ return 4;
    if ( majorVersion == 5 )                      /* Maxwell */ return 4;
    if ( majorVersion == 6 && minorVersion == 0 ) /* Pascal  */ return 2;
    if ( majorVersion == 6 && minorVersion == 1 ) /* Pascal  */ return 4;
    if ( majorVersion == 6 && minorVersion == 2 ) /* Pascal  */ return 4;
    if ( majorVersion == 7 )                      /* Volta   */ return 4;
    return 0; /* unknown, could also throw exception */
}

inline int getDoublePrecisionUnitsPerMultiprocessor
(
    int const majorVersion,
    int const minorVersion
)
{
    if ( majorVersion == 3 && minorVersion == 0 ) /* Kepler  */ return 8 ;
    if ( majorVersion == 3 && minorVersion == 2 ) /* Kepler  */ return 8 ;
    if ( majorVersion == 3 && minorVersion == 5 ) /* Kepler  */ return 64; /* 8 for GeForce GPUs .. how to differentiate? */
    if ( majorVersion == 3 && minorVersion == 7 ) /* Kepler  */ return 64;
    if ( majorVersion == 5 )                      /* Maxwell */ return 4 ;
    if ( majorVersion == 6 && minorVersion == 0 ) /* Pascal  */ return 32;
    if ( majorVersion == 6 && minorVersion == 1 ) /* Pascal  */ return 4 ;
    if ( majorVersion == 6 && minorVersion == 2 ) /* Pascal  */ return 4 ;
    if ( majorVersion == 7 )                      /* Volta   */ return 32;
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
    if ( majorVersion == 2 ) return "Fermi"  ;
    if ( majorVersion == 3 ) return "Kepler" ;
    if ( majorVersion == 5 ) return "Maxwell";
    if ( majorVersion == 6 ) return "Pascal" ;
    if ( majorVersion == 7 ) return "Volta"  ;
    return 0; /* unknown, could also throw exception */
}


#if defined( __CUDACC__ )

/**
 * @return flops (not GFlops, ... )
 * @see https://www.techpowerup.com/gpudb/1857/geforce-gtx-760
 * As can be seen here:
 * @see http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#arithmetic-instructions
 * The throughput since at least Compute Capability 3.0 offers as many FMAs
 * as simple additions, therefore for the flops we need a factor 2 to get
 * the theoretical flops
 */
inline float getCudaPeakSPFlops( cudaDeviceProp const & props )
{
    return (float) props.multiProcessorCount * props.clockRate /* kHz */ * 1e3f *
        getCudaCoresPerMultiprocessor( props.major, props.minor ) * 2 /* FMA */;
}

inline float getCudaPeakDPFlops( cudaDeviceProp const & props )
{
    return (float) props.multiProcessorCount * props.clockRate /* kHz */ * 1e3f *
        getDoublePrecisionUnitsPerMultiprocessor( props.major, props.minor ) * 2 /* FMA */;
}


#include <sstream>

inline std::string getCudaCacheConfigString( void )
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

inline std::string getCudaSharedMemBankSizeString( void )
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


inline std::string printSharedMemoryConfig( void )
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
 * @see https://www.cs.cmu.edu/afs/cs/academic/class/15668-s11/www/cuda-doc/html/structcudaDeviceProp.html
 * Most of these can also be queried using cuDeviceGetAttribute from the
 * cuda_runtime_api.h header
 * @see http://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__DEVICE.html
 *      v9.0.176
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
        int const coresPerSM = getCudaCoresPerMultiprocessor( prop->major, prop->minor );

        /**
         * @see http://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__TYPES.html#group__CUDA__TYPES_1ge12b8a782bebe21b1ac0091bf9f4e2a3
         * List of attributes not included in device properties:
         */
        #define TMP_ATTRIBUTE( VARNAME, NUMBER ) \
        int VARNAME = -1;                        \
        if ( NUMBER < CU_DEVICE_ATTRIBUTE_MAX )  \
            cuDeviceGetAttribute( &VARNAME, (CUdevice_attribute) NUMBER, iDevice );
        /*
        CU_DEVICE_ATTRIBUTE_MAX_PITCH (could be normal mem pitch?)
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
        CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_PITCH = 72
            Maximum 2D linear texture pitch in bytes
        CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_MIPMAPPED_WIDTH = 73
            Maximum mipmapped 2D texture width
        CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_MIPMAPPED_HEIGHT = 74
            Maximum mipmapped 2D texture height
        CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_MIPMAPPED_WIDTH = 77
            Maximum mipmapped 1D texture width
        */
        TMP_ATTRIBUTE( bStreamPrioritiesSupported, 78 ) // CU_DEVICE_ATTRIBUTE_STREAM_PRIORITIES_SUPPORTED
        TMP_ATTRIBUTE( bGlobalL1CacheSupported   , 79 ) // CU_DEVICE_ATTRIBUTE_GLOBAL_L1_CACHE_SUPPORTED
        TMP_ATTRIBUTE( bLocalL1CacheSupported    , 80 ) // CU_DEVICE_ATTRIBUTE_LOCAL_L1_CACHE_SUPPORTED
        TMP_ATTRIBUTE( nBytesMaxSMPerMP          , 81 ) // CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_MULTIPROCESSOR
        // CU_DEVICE_ATTRIBUTE_MANAGED_MEMORY = 83 Device can allocate managed memory on this system
        TMP_ATTRIBUTE( nBytesMaxRegistersPerMP   , 82 ) // CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_MULTIPROCESSOR
        TMP_ATTRIBUTE( bMultiGpuBoard            , 84 ) // CU_DEVICE_ATTRIBUTE_MULTI_GPU_BOARD
        TMP_ATTRIBUTE( iMultiGpuBoardId          , 85 ) // CU_DEVICE_ATTRIBUTE_MULTI_GPU_BOARD_GROUP_ID
        TMP_ATTRIBUTE( ratioSPToDPFlops          , 87 ) // CU_DEVICE_ATTRIBUTE_SINGLE_TO_DOUBLE_PRECISION_PERF_RATIO
        /*
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
        #undef TMP_ATTRIBUTE

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
        printf( "| Warp Schedulers per MP   : %i\n"        , getWarpSchedulersPerMultiprocessor( prop->major, prop->minor ) );
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
        printf( "| Peak SP-FLOPS            : %f GFLOPS\n" , getCudaPeakSPFlops( *prop ) / 1e9f );
        printf( "| Peak DP-FLOPS            : %f GFLOPS\n" , getCudaPeakDPFlops( *prop ) / 1e9f );
        printf( "| Peak SP/DP-FLOPS         : %i (%i)\n"   , ratioSPToDPFlops, getCudaCoresPerMultiprocessor( prop->major, prop->minor ) / getDoublePrecisionUnitsPerMultiprocessor( prop->major, prop->minor ) );
        printf( "| Special Fun. Units per MP: %i\n"        , getSpecialFunctionUnitsPerMultiprocessor( prop->major, prop->minor ) );
        printf( "|---------------------- Memory ----------------------\n" );
        printf( "| Total Global Memory      : %lu Bytes\n" , prop->totalGlobalMem );
        printf( "| Total Constant Memory    : %lu Bytes\n" , prop->totalConstMem );
        printf( "| Shared Memory per Block  : %lu Bytes\n" , prop->sharedMemPerBlock );
        printf( "| Shared Memory per Multip.: %i Bytes\n"  , nBytesMaxSMPerMP );
        printf( "| Global L1 Cache supported: %s\n"        , bGlobalL1CacheSupported ? "true" : "false" );
        printf( "| Local  L1 Cache supported: %s\n"        , bLocalL1CacheSupported  ? "true" : "false" );
        printf( "| L2 Cache Size            : %u Bytes\n"  , prop->l2CacheSize );
        printf( "| Registers per Block      : %i\n"        , prop->regsPerBlock );
        printf( "| Registers per Multiproc. : %i\n"        , nBytesMaxRegistersPerMP );
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
        printf( "| Stream Priorities Supp.  : %s\n"        , bStreamPrioritiesSupported ? "true" : "false" );
        printf( "| Multi-GPU Board          : %s\n"        , bMultiGpuBoard          ? "true" : "false" );
        if ( bMultiGpuBoard )
        printf( "| Multi-GPU Board ID       : %i\n"        , iMultiGpuBoardId );
        printf( "=====================================================\n" );
        fflush( stdout );
    }

    if ( rpDeviceProperties == &fallbackPropArray )
        free( fallbackPropArray );
}

#if defined( __CUDA_ARCH__ ) && __CUDA_ARCH__ < 600
/**
 * atomicAdd for double is not natively implemented, because it's not
 * supported by (all) the hardware, therefore resulting in a time penalty.
 * http://stackoverflow.com/questions/12626096/why-has-atomicadd-not-been-implemented-for-doubles
 * https://stackoverflow.com/questions/37566987/cuda-atomicadd-for-doubles-definition-error
 */
inline __device__
double atomicAdd( double * address, double val )
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

#endif // __CUDACC__


template< class T >
class MirroredVector;

template< class T >
class MirroredTexture;


#ifdef __CUDACC__

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
    cudaStream_t const mStream  ;
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
     * @param[in] rAsync -1 uses the default as configured using the constructor
     *                    0 (false) synchronizes stream after memcpyAsync
     *                    1 (true ) will transfer asynchronously
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
    inline void pushAsync( void ) const { push( true ); }

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
    inline void popAsync( void ) const { pop( true ); }

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
        cudaStream_t rStream = 0,
        bool const   rAsync  = false
    )
     : MirroredVector<T>( rnElements, rStream, rAsync ), texture( 0 )
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

#endif // __CUDACC__


template< class T >
inline __device__ __host__
void swap( T & a, T & b )
{
    T const c = a;
    a = b;
    b = c;
}


template< typename T >
inline __device__ __host__
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

inline __device__ __host__
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
#include <cmath>                            // isnan, isinf
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
