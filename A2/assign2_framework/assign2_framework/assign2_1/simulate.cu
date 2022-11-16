/*
 * simulate.cu
 *
 * Implementation of a wave equation simulation, parallelized on the GPU using
 * CUDA.
 *
 * You are supposed to edit this file with your implementation, and this file
 * only.
 *
 */

 #include <stdio.h>
 #include <stdlib.h>
 #include <math.h>
 #include <string.h>
 #include "timer.hh"
 #include <iostream>

#include "simulate.hh"

using namespace std;


/* Utility function, use to do error checking for CUDA calls
 *
 * Use this function like this:
 *     checkCudaCall(<cuda_call>);
 *
 * For example:
 *     checkCudaCall(cudaMalloc((void **) &deviceRGB, imgS * sizeof(color_t)));
 *
 * Special case to check the result of the last kernel invocation:
 *     kernel<<<...>>>(...);
 *     checkCudaCall(cudaGetLastError());
**/
static void checkCudaCall(cudaError_t result) {
    if (result != cudaSuccess) {
        cerr << "cuda error: " << cudaGetErrorString(result) << endl;
        exit(EXIT_FAILURE);
    }
}


__global__ void wave_eq_Kernel(float *deviceA, float *deviceB, float *deviceC) {
    unsigned i = blockIdx.x * blockDim.x + threadIdx.x;
    float temp = 2 * deviceB[i] - deviceA[i] + 0.15 * (deviceB[i - 1] - (2 * deviceB[i] - deviceB[i + 1]));
    deviceC[i] = temp;
}

/* Function that will simulate the wave equation, parallelized using CUDA.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * num_threads: how many threads to use (excluding the main threads)
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulate(const long i_max, const long t_max, const long block_size,
                 double *old_array, double *current_array, double *next_array) {
    int threadBlockSize = 512;

    float* deviceA = NULL;
    checkCudaCall(cudaMalloc((void **) &deviceA, i_max * sizeof(float)));
    if (deviceA == NULL) {
        cerr << "Error allocating memory for a on the device" << endl;
        return 0;
    }

    float* deviceB = NULL;
    checkCudaCall(cudaMalloc((void **) &deviceB, i_max * sizeof(float)));
    if (deviceB == NULL) {
        checkCudaCall(cudaFree(deviceA));
        cerr << "Error allocating memory for B on the device" << endl;
        return 0;
    }

    float* deviceC = NULL;
    checkCudaCall(cudaMalloc((void **) &deviceC, i_max * sizeof(float)));
    if (deviceC == NULL) {
        checkCudaCall(cudaFree(deviceA));
        checkCudaCall(cudaFree(deviceB));
        cerr << "Error allocating memory for C on the device" << endl;
        return 0;
    }

    //CUDA timer
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    for (int t = 0; t < t_max; t++) {
        // Copy the original arrays to the GPU
        checkCudaCall(cudaMemcpy(deviceA, old_array, i_max*sizeof(float), cudaMemcpyHostToDevice));
        checkCudaCall(cudaMemcpy(deviceB, current_array, i_max*sizeof(float), cudaMemcpyHostToDevice));
        checkCudaCall(cudaMemcpy(deviceC, next_array, i_max*sizeof(float), cudaMemcpyHostToDevice));

        // Execute the wave_eq_kernel
        cudaEventRecord(start, 0);
        wave_eq_Kernel<<<i_max/threadBlockSize, threadBlockSize>>>(deviceA, deviceB, deviceC);
        cudaEventRecord(stop, 0);

        // Check whether the kernel invocation was successful
        checkCudaCall(cudaGetLastError());
        cout << "test" <<endl;

        // Copy result back to host
        checkCudaCall(cudaMemcpy(next_array, deviceA, i_max*sizeof(float), cudaMemcpyHostToDevice));
        checkCudaCall(cudaMemcpy(old_array, deviceB, i_max*sizeof(float), cudaMemcpyHostToDevice));
        checkCudaCall(cudaMemcpy(current_array, deviceC, i_max*sizeof(float), cudaMemcpyHostToDevice));
    }
    // Cleanup GPU-side data
    checkCudaCall(cudaFree(deviceA));
    checkCudaCall(cudaFree(deviceB));
    checkCudaCall(cudaFree(deviceC));

    float elapsedTime;
    cudaEventElapsedTime(&elapsedTime, start, stop);
    cout << "Kernel invocation took " << elapsedTime << " milliseconds" << endl;

    return current_array;
}
