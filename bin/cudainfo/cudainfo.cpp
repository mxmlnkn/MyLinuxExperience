/*
nvcc -x cu --compiler-options -Wall,-Wextra -std=c++11 -DNDEBUG cudainfo.cpp
*/

#include "cudacommon.hpp"


int main( void )
{
    /* show debug CUDA information per graphic card found and chose graphic
     * card without kernel timeout, if found, i.e. graphic card not used for
     * display! */
    {
        int nCudaDevices = 0;
        cudaDeviceProp * props = NULL;
        getCudaDeviceProperties( &props, &nCudaDevices );
        assert( props != NULL );
        int iDeviceToUse = 0;
        for ( auto iDevice = 0; iDevice < nCudaDevices; ++iDevice )
        {
            if ( ! props[iDevice].kernelExecTimeoutEnabled )
            {
                iDeviceToUse = iDevice;
                break;
            }
        }
        CUDA_ERROR( cudaSetDevice( iDeviceToUse ) );

        free( props );
        props = NULL;
    }

}
