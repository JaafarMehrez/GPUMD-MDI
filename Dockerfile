################################################################################
# GPUMD-MDI: reproducible containerized build environment
#
# Mirrors the approach used in GPUMD-PySAGES, with the MDI library added as a
# dependency (required to link the `gpumd-mdi` executable).
#
# Build the image:
#   docker build -t gpumd-mdi .
#
# Build `gpumd-mdi` inside the container (GPUMD is cloned to /opt/GPUMD):
#   docker run --rm -it --gpus all gpumd-mdi \
#       /opt/GPUMD-MDI/build.sh /opt/GPUMD \
#       MDI_INC_PATH=/opt/mdi/include MDI_LIB_PATH=/opt/mdi/lib
#
# Note on GPUs: `docker build` and `docker run` without `--gpus all` work for
# inspecting the environment. Running an actual MDI simulation (or the VASP
# example) requires an NVIDIA container runtime and `--gpus all`. VASP is
# licensed and NOT bundled; mount your own VASP build to run the example,
# e.g. -v /path/to/vasp:/opt/vasp.
################################################################################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04

LABEL maintainer="Jaafar Mehrez <jaafarmehrez@sjtu.edu.cn>"
LABEL org.opencontainers.image.source="https://github.com/JaafarMehrez/GPUMD-MDI"
LABEL org.opencontainers.image.description="GPUMD-MDI: MDI (MolSSI Driver Interface) integration for GPUMD"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates cmake g++ git make wget \
    python3 python3-dev python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install the MDI library (provides mdi.h and -lmdi, needed to link gpumd-mdi)
# and the Python MDI package (used by the bundled VASP driver).
#
# Only the C API is needed by GPUMD, so C++/Fortran/Python/plugin/MPI support
# are switched off: that avoids needing gfortran, Python dev headers, and MPI.
# BUILD_SHARED_LIBS=OFF yields a static libmdi, which `-lmdi` then links
# statically, so the resulting gpumd-mdi runs without LD_LIBRARY_PATH.
RUN git clone --depth 1 https://github.com/MolSSI-MDI/MDI_Library.git /opt/MDI_Library \
    && cmake -S /opt/MDI_Library -B /opt/MDI_Library/build \
         -DCMAKE_INSTALL_PREFIX=/opt/mdi \
         -DCMAKE_INSTALL_LIBDIR=lib \
         -DCMAKE_BUILD_TYPE=Release \
         -DBUILD_SHARED_LIBS=OFF \
         -DMDI_CXX=OFF -DMDI_Fortran=OFF -DMDI_Python=OFF \
         -DMDI_PLUGINS=OFF -DMDI_USE_MPI=OFF -DMDI_TEST_CODES=OFF \
    && cmake --build /opt/MDI_Library/build -j"$(nproc)" \
    && cmake --install /opt/MDI_Library/build \
    && pip3 install --no-cache-dir mdi numpy

# Clone GPUMD (master). Build gpumd-mdi against this checkout with build.sh.
RUN git clone https://github.com/brucefan1983/GPUMD.git /opt/GPUMD

# Copy in this interface package (sources + build.sh + examples + tools)
COPY . /opt/GPUMD-MDI

# Optionally build gpumd-mdi at image build time. Compiling does not require a
# GPU, so this also validates the build inside `docker build`.
# Skip it with:  docker build --build-arg SKIP_BUILD=1 -t gpumd-mdi .
ARG SKIP_BUILD=0
RUN if [ "$SKIP_BUILD" != "1" ]; then \
        /opt/GPUMD-MDI/build.sh /opt/GPUMD \
            MDI_INC_PATH=/opt/mdi/include \
            MDI_LIB_PATH=/opt/mdi/lib; \
    fi

WORKDIR /opt/GPUMD-MDI

CMD ["/bin/bash"]
