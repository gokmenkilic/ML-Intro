// Copyright (c) 2021 NVIDIA Corporation.  All rights reserved.
#include <stdio.h>
#include <stdlib.h>

__global__ void device_add(int *a, int *b, int *c) {
  c[threadIdx.x] = a[threadIdx.x] + b[threadIdx.x];
}

void fill_array(unsigned n, int *data) {
  for (int idx = 0; idx < n; idx++)
    data[idx] = idx + 1;
}

int main(void) {
  // Host copies of a, b, c
  int *h_a, *h_b, *h_c;
  // Device copies of a, b, c
  int *d_a, *d_b, *d_c;
  int threads_per_block = 0, no_of_blocks = 0;
  unsigned n = 4;
  int size = n * sizeof(int);

  // 1 Allocate memory on the CPU
  h_a = (int *)malloc(size);
  h_b = (int *)malloc(size);
  h_c = (int *)malloc(size);

  // 2 Allocate memory on the GPU
  cudaMalloc((void **)&d_a, size);
  cudaMalloc((void **)&d_b, size);
  cudaMalloc((void **)&d_c, size);

  // 3 Populate/initialize the CPU
  fill_array(n, h_a);
  fill_array(n, h_b);

  // 4 Transfer the data from the host to the device with cudaMemcpy()
  cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_b, h_b, size, cudaMemcpyHostToDevice);

  // 5 Call the GPU function
  device_add<<<1, n>>>(d_a, d_b, d_c);

  // 6 Synchronize the device and host
  cudaDeviceSynchronize();

  // 7 Transfer data from the device to the host with cudaMemcpy()
  cudaMemcpy(h_c, d_c, size, cudaMemcpyDeviceToHost);

  // 8 Consume the crunched data on Host
  for (int idx = 0; idx < n; idx++) {
    printf(" %d + %d  = %d\n", h_a[idx], h_b[idx], h_c[idx]);
  }

  // 9 Free memory on Host
  free(h_a);
  free(h_b);
  free(h_c);

  // 10 Free memory on Device
  cudaFree(d_a);
  cudaFree(d_b);
  cudaFree(d_c);

  return 0;
}
