# Many-Ways to GPU

This repository contains the notebooks supporting the DiRAC-adapted Nvidia course, Many-Ways to GPU (originally N-Ways to GPU), which introduces learners to a variety of techniques for developing and optimising codes on Nvidia GPU hardware in both C++ and Fortran.

NB: **This repo does not contain the dataset required for the exercises.** This should be downloaded from Nvidia's archive with `cd _common; python dataset.py`.

## Folder structure

There are 4 folders containing exercises in the form of Jupyter notebooks:

- `standard/` - exercises using standard language constructs like C++'s Parallel STL or Fortran's `do concurrent`
- `openmp/` - exercises using OpenMP's target offloading features
- `openacc/` - exercises using OpenACC
- `cuda/` - exercises using plain CUDA

Each contains a further two folders:

- `jupyter_notebooks/` - notebooks containing all exercise instructions, one notebook for C++ and one for Fortran.
- `source_code/` - the source code to be changed during exercises, along with solutions.

## Accessing these notebooks locally

These notebooks can be *viewed* locally by running jupyter on your own machine. In order to actually *run* any of the notebooks, you must additionally have:

1. An Nvidia GPU
2. Access to Nvidia compilers and profilers (either installed separately or via Nvidia's HPCSDK)

---

These instructions assume you are using a Bash shell and your current working directory is the root of this repo.

```bash
./install_requirements.sh
. venv/bin/activate # activate environment
jupyter-lab
```

Your browser should now open a jupyter lab instance where you should be able to view all cells in the various notebooks. Again, in order to run any cells you must have access to an Nvidia GPU and the Nvidia software stack. See [Folder structure](#Folder-structure) for details on how to navigate the folder structure.
