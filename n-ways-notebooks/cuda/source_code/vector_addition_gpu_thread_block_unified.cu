// Copyright (c) 2021 NVIDIA Corporation.  All rights reserved.
#include <stdio.h>
#include <stdlib.h>

// CUDA kernel. Each thread takes care of one element of c
__global__ void device_add(int *a, int *b, int *c) {
  // Get our global thread ID
  int idx = threadIdx.x + blockIdx.x * blockDim.x;
  c[idx] = a[idx] + b[idx];
}

void fill_array(unsigned n, int *data) {
  for (int idx = 0; idx < n; idx++)
    data[idx] = idx + 1;
}

int main(void) {
  // Unified memory
  int *a, *b, *c;
  int threads_per_block = 0, no_of_blocks = 0;
  unsigned n = 4;
  int size = n * sizeof(int);

  // 1/2 Allocate memory on the GPU
  cudaMallocManaged(&a, size);
  cudaMallocManaged(&b, size);
  cudaMallocManaged(&c, size);

  // 3 Populate/initialize the CPU
  fill_array(n, a);
  fill_array(n, b);

  // 5 Call the GPU function
  threads_per_block = 2;
  no_of_blocks = n / threads_per_block;
  device_add<<<no_of_blocks, threads_per_block>>>(a, b, c);

  // 6 Synchronize the device and host
  cudaDeviceSynchronize();

  // 8 Consume the crunched data on Host
  for (int idx = 0; idx < n; idx++) {
    printf(" %d + %d  = %d\n", a[idx], b[idx], c[idx]);
  }

  // 9/10 Free memory on Device
  cudaFree(a);
  cudaFree(b);
  cudaFree(c);

  return 0;
}
