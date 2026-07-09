////////////////////////////////////////////////////////////////////////////////
// Author: Manish Agarwal and Gourav Shrivastava  , IIT Delhi
////////////////////////////////////////////////////////////////////////////////

// Copyright (c) 2021 NVIDIA Corporation.  All rights reserved.
#include "dcdread.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cuda_runtime.h>
#include <fstream>
#include <nvtx3/nvToolsExt.h>


// TODO: write CUDA syntax to the function header to make this a global
// functions callable from the host
??? void pair_gpu(const float *d_x, const float *d_y, const float *d_z,
                         unsigned int *d_g, int numatm, int nconf,
                         const double xbox, const double ybox,
                         const double zbox, const double box, const double del);

// rdf program main
int main(int argc, char *argv[]) {
  double xbox, ybox, zbox;
  float *h_x, *h_y, *h_z;
  float *d_x, *d_y, *d_z; // Note: device (GPU) variable decleration
  unsigned int *h_g;
  unsigned int *d_g; // Note: device (GPU) variable decleration
  int nbin;
  int numatm, nconf, inconf;
  std::string file;

  ///////////////////Input Details//////////////////////////////////////////////
  inconf = 10;
  nbin = 2000;
  file = "../../_common/input/alk.traj.dcd";
  //////////////////////////////////////////////////////////////////////////////

  std::ifstream infile;
  infile.open(file.c_str());
  if (!infile) {
    std::cout << "file " << file.c_str() << " not found\n";
    return 1;
  }
  assert(infile);

  std::ofstream pairfile, stwo;
  // Output file storing the RDF values.
  pairfile.open("RDF.dat");
  // Output file storing the entropy.
  stwo.open("Pair_entropy.dat");

  dcdreadhead(&numatm, &nconf, infile);
  // Limit the number of frames to 10.
  if (nconf > inconf) {
    nconf = inconf;
  }

  unsigned int sizef = nconf * numatm * sizeof(float);
  unsigned int sizebin = nbin * sizeof(unsigned int);

  // TODO (only managed): Replace host malloc with cuda managed memeory using 
  // cudaMallocManaged(&h_var, size);
  h_x = (float *)malloc(sizef);
  h_y = (float *)malloc(sizef);
  h_z = (float *)malloc(sizef);
  h_g = (unsigned int *)malloc(sizebin);

  memset(h_g, 0, sizebin);

  ///////////////////Reading Coordinates////////////////////////////////////////
  nvtxRangePush("Read_File");
  float ax[numatm], ay[numatm], az[numatm];
  for (int i = 0; i < nconf; i++) {
    dcdreadframe(ax, ay, az, infile, numatm, xbox, ybox, zbox);
    for (int j = 0; j < numatm; j++) {
      h_x[i * numatm + j] = ax[j];
      h_y[i * numatm + j] = ay[j];
      h_z[i * numatm + j] = az[j];
    }
  }
  nvtxRangePop();
  //////////////////////////////////////////////////////////////////////////////

  double box = std::min(xbox, ybox);
  box = std::min(box, zbox);
  double del = box / (2.0 * nbin);

  ///////////////////This is where we will concentrate//////////////////////////
  // TODO (only unmanaged): Allocate memory for device (GPU) using 
  // cudaMalloc((void **)&d_var, size);

  // TODO (only unmanaged): Copy the required data from Host to Device before 
  // calculation on GPU using cudaMemcpy(d_var, h_var, size, cudaMemcpyHostToDevice);

  // Note: Defines the number of threads per block and the number of blocks in
  // the grid.  Here, we are using a 2D grid, where the total of nblock * nthreads
  // in each dimension is natoms (or the closest multiple bigger than natoms).
  dim3 nthreads(16, 16, 1);
  dim3 nblock;
  nblock.x = (numatm + nthreads.x - 1) / nthreads.x;
  nblock.y = (numatm + nthreads.y - 1) / nthreads.y;
  nblock.z = 1;

  nvtxRangePush("Pair_Calculation");
  // TODO: Fill in the threads and blocks in the correct order and 
  // the host or device variables
  pair_gpu<<<?, ?>>>(?_x, ?_y, ?_z, ?_g, numatm, nconf, xbox, ybox,
                                 zbox, box, del);
  nvtxRangePop();

  // Note: Syncing Host and Device
  cudaDeviceSynchronize();
    
  // TODO (only unmanaged): Copy the required data from Device to Host after 
  // calculation on GPU using cudaMemcpy(h_var, d_var, size, cudaMemcpyDeviceToHost);
  //////////////////////////////////////////////////////////////////////////////

  double pi = acos(-1.0);
  double rho = (numatm) / (xbox * ybox * zbox);
  double norm = (4.0 * pi * rho) / 3.0;
  double rlower, rupper, nideal;
  double g[nbin];
  double r, gr, lngr, lngrbond, s2 = 0.0, s2bond = 0.0;

  ///////////////////Calculate Entropy//////////////////////////////////////////
  nvtxRangePush("Entropy_Calculation");
  for (int i = 0; i < nbin; i++) {
    rlower = (i)*del;
    rupper = rlower + del;
    nideal = norm * (rupper * rupper * rupper - rlower * rlower * rlower);
    g[i] = static_cast<double>(h_g[i]) /
           (static_cast<double>(nconf * numatm) * nideal);
    r = (i)*del;
    pairfile << (i + 0.5) * del << " " << g[i] << std::endl;

    if (r < 2.0) {
      gr = 0.0;
    } else {
      gr = g[i];
    }

    if (gr < 1e-5) {
      lngr = 0.0;
    } else {
      lngr = log(gr);
    }

    if (g[i] < 1e-6) {
      lngrbond = 0.0;
    } else {
      lngrbond = log(g[i]);
    }

    s2 = s2 - 2.0 * pi * rho * ((gr * lngr) - gr + 1.0) * del * r * r;
    s2bond = s2bond -
             2.0 * pi * rho * ((g[i] * lngrbond) - g[i] + 1.0) * del * r * r;
  }
  nvtxRangePop();
  //////////////////////////////////////////////////////////////////////////////

  ///////////////////Write Output///////////////////////////////////////////////
  stwo << "s2 value is " << s2 << std::endl;
  stwo << "s2bond value is " << s2bond << std::endl;
  //////////////////////////////////////////////////////////////////////////////

  // TODO (only managed): Deallocate managed memory using // cudaFree(var);
  free(h_x);
  free(h_y);
  free(h_z);
  free(h_g);

  // TODO (only unmanaged): Deallocate memory for device (GPU) using
  // cudaFree(d_var);

  pairfile.close();
  stwo.close();
  return 0;
}

// TODO: Write CUDA syntax to make this function a global
// functions callable from the host (CPU)
 ??? void pair_gpu(const float *d_x, const float *d_y, const float *d_z,
                         unsigned int *d_g, int numatm, int nconf,
                         const double xbox, const double ybox,
                         const double zbox, const double box,
                         const double del) {
  float r, dx, dy, dz;
  int ig;
  double cut = box * 0.5;

  // TODO: Write indexing logic using threads and blocks
  // Hint: As we assigned a 2d grid of blocks, id1 gets its values 
  //       from the .x dim and id2 from the .y dim. 
  int id1 = ?
  int id2 = ?

  for (int frame = 0; frame < nconf; frame++) {
    if (id1 < numatm && id2 < numatm) {
      dx = d_x[frame * numatm + id1] - d_x[frame * numatm + id2];
      dy = d_y[frame * numatm + id1] - d_y[frame * numatm + id2];
      dz = d_z[frame * numatm + id1] - d_z[frame * numhfhfgatm + id2];

      dx = dx - xbox * (std::round(dx / xbox));
      dy = dy - ybox * (std::round(dy / ybox));
      dz = dz - zbox * (std::round(dz / zbox));

      r = sqrtf(dx * dx + dy * dy + dz * dz);
      if (r < cut) {
        ig = static_cast<int>(r / del);
        // Note: Using CUDA API atomic function atomicAdd()
        atomicAdd(&d_g[ig], 1);
      }
    }
  }
}
