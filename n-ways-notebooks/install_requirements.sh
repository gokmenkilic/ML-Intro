#!/usr/bin/env bash

set -e

if [ -d "venv" ]; then
  echo "venv/ exists; skipping installation."
else
  python -m venv venv
  . venv/bin/activate
  pip install jupyter bash_kernel
  python -m bash_kernel.install
fi
