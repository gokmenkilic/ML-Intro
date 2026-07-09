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
#include <fstream>
#include <nvtx3/nvToolsExt.h>

// Note: The addition of execution header file
#include <algorithm>
#include <atomic>
#include <execution>
// #include <ranges> // not needed for thrust::counting_iterator

// Function declation where distances are calculated
// Note: d_g is std::atomic<int> rahter than unsigned int
void pair_gpu(const float *d_x, const float *d_y, const float *d_z,
              std::atomic<int> *d_g, int numatm, int nconf, const double xbox,
              const double ybox, const double zbox, const double box,
              const double del);

int main(int argc, char *argv[]) {
  double xbox, ybox, zbox;
  float *h_x, *h_y, *h_z;
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

  h_x = (float *)malloc(sizef);
  h_y = (float *)malloc(sizef);
  h_z = (float *)malloc(sizef);

  // Note: We are using standard std atomic which gets mapped to respective
  // atomic operations to ensure thread safety
  std::atomic<int> *h_g = new std::atomic<int>[nbin];
  std::fill(std::execution::par, h_g, h_g + nbin, 0);

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
  nvtxRangePush("Pair_Calculation");
  pair_gpu(h_x, h_y, h_z, h_g, numatm, nconf, xbox, ybox, zbox, box, del);
  nvtxRangePop();
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
    // Note: Atomic needs to be safely read before it can be cast
    g[i] = static_cast<double>(h_g[i].load()) /
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

  free(h_x), free(h_y), free(h_z);
  delete[] h_g;
  pairfile.close();
  stwo.close();
  return 0;
}

// Note: d_g is std::atomic<int> rahter than unsigned int
void pair_gpu(const float *d_x, const float *d_y, const float *d_z,
              std::atomic<int> *d_g, int numatm, int nconf, const double xbox,
              const double ybox, const double zbox, const double box,
              const double del) {
  // Note: We declare these variables directly in the lambda function
  // double r, dx, dy, dz;
  // int ig;
  double cut = box * 0.5;

  for (int frame = 0; frame < nconf; frame++) {
    std::for_each(
        // Note: We are using thrust to generate the parallel itterator
        std::execution::par, thrust::counting_iterator<unsigned int>(0u),
        thrust::counting_iterator<unsigned int>(numatm * numatm),
        // Note: We are passing the logic through a lambda function
        [d_x, d_y, d_z, d_g, numatm, frame, xbox, ybox, zbox, cut,
         del](unsigned int index) {
          int id1 = index / numatm;
          int id2 = index % numatm;

          float dx = d_x[frame * numatm + id1] - d_x[frame * numatm + id2];
          float dy = d_y[frame * numatm + id1] - d_y[frame * numatm + id2];
          float dz = d_z[frame * numatm + id1] - d_z[frame * numatm + id2];

          dx = dx - xbox * (std::round(dx / xbox));
          dy = dy - ybox * (std::round(dy / ybox));
          dz = dz - zbox * (std::round(dz / zbox));

          float r = sqrtf(dx * dx + dy * dy + dz * dz);
          if (r < cut) {
            int ig = (int)(r / del);
            // Note: Atomic addition using std::atomic<T>::fetch_add
            d_g[ig].fetch_add(1, std::memory_order_relaxed);
          }
        });
  }
}
