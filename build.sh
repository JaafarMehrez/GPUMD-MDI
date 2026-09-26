#!/usr/bin/env bash
################################################################################
# GPUMD-MDI build script
#
# Builds the `gpumd-mdi` executable against a user-supplied GPUMD source tree.
#
# Usage:
#   ./build.sh /path/to/GPUMD
#   ./build.sh /path/to/GPUMD USE_MDI=1 MDI_LIB=1 \
#       MDI_LIB_PATH=/path/to/MDI_Library/install/lib64 \
#       MDI_INC_PATH=/path/to/MDI_Library/install/include
#
# The script copies src/main_mdi/ and src/makefile_mdi from this repository
# into <GPUMD>/src/, then runs `make -f makefile_mdi` from there.
#
# Requirements
#   - A checkout of https://github.com/brucefan1983/GPUMD
#   - The MDI library (https://github.com/MolSSI-MDI/MDI_Library) installed,
#     preferably with the -lmdi library and mdi.h discoverable via
#     MDI_LIB_PATH / MDI_INC_PATH so that USE_MDI + MDI_LIB linking works.
#   - CUDA toolkit and host compiler (same as a normal GPUMD build).
#
# Notes
#   - `USE_MDI=1` is enabled by default; pass MDI_LIB=1 together with the
#     MDI_LIB_PATH / MDI_INC_PATH above to link the real MDI library.
#   - The copied files remain in your GPUMD checkout after the build
#     (remove them with `make -f makefile_mdi clean` from src/ if desired).
################################################################################
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 /path/to/GPUMD [extra make args...]" >&2
  echo "  e.g. $0 ~/GPUMD USE_MDI=1 MDI_LIB=1 MDI_LIB_PATH=/my/mdi/lib64 MDI_INC_PATH=/my/mdi/include" >&2
  exit 1
}

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

GPUMD_SRC="$1"
shift

GPUMD_SRC_DIR="$GPUMD_SRC/src"
if [[ ! -d "$GPUMD_SRC_DIR" ]]; then
  echo "ERROR: GPUMD source tree not found (looked for $GPUMD_SRC_DIR)" >&2
  exit 1
fi

echo "==> Copying MDI sources into $GPUMD_SRC_DIR"
cp -r "$HERE/src/main_mdi" "$GPUMD_SRC_DIR/"
cp "$HERE/src/makefile_mdi" "$GPUMD_SRC_DIR/"

cd "$GPUMD_SRC_DIR"

if [[ $# -gt 0 ]]; then
  echo "==> Building with: make -f makefile_mdi $*"
  exec make -f makefile_mdi "$@"
fi

echo "==> Building with: make -f makefile_mdi USE_MDI=1 MDI_LIB=1"
exec make -f makefile_mdi USE_MDI=1 MDI_LIB=1