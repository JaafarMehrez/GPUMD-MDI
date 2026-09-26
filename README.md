# GPUMD-MDI

MDI (MolSSI Driver Interface) integration for [GPUMD](https://github.com/brucefan1983/GPUMD),
allowing GPUMD to run as an MDI ENGINE coupled to other codes (e.g. VASP as a QM DRIVER).

> **Status:** maintained separately from the main GPUMD repository.
> The interface previously lived in the [GPUMD](https://github.com/brucefan1983/GPUMD) repo
> (`src/main_mdi/`) and was moved out to keep the GPUMD core lean.
> See [GPUMD issue #1786](https://github.com/brucefan1983/GPUMD/issues/1786) for context.
> The full implementation and history remain available in the GPUMD git history.

This package follows the same pattern as
[GPUMD-PySAGES](https://github.com/JaafarMehrez/GPUMD-PySAGES): it contains the interface
sources and a small build script that injects them into any GPUMD checkout.

## Requirements

- A checkout of [GPUMD](https://github.com/brucefan1983/GPUMD) (master / v5.x)
- CUDA toolkit + host compiler (same as a normal GPUMD build)
- [MDI Library](https://github.com/MolSSI-MDI/MDI_Library) (for linking `USE_MDI+MDI_LIB`)
- VASP (optional, for the bundled VASP driver example)
- Python 3 + `mdi` + `numpy` (optional, for the Python VASP driver)

## Building

```bash
git clone https://github.com/JaafarMehrez/GPUMD-MDI.git
cd GPUMD-MDI

# Build gpumd-mdi against your GPUMD checkout:
./build.sh /path/to/GPUMD USE_MDI=1 MDI_LIB=1 \
  MDI_LIB_PATH=/path/to/MDI_Library/install/lib64 \
  MDI_INC_PATH=/path/to/MDI_Library/install/include
```

The `gpumd-mdi` executable is produced in `/path/to/GPUMD/src/`.

See [doc/README.md](doc/README.md) for full build and usage instructions,
driver/engine examples, and the list of supported MDI commands.

## Repository layout

```
src/main_mdi/          MDI engine sources (main.cu, mdi_stub.cu, run.cu/cuh, mdi_fallback.h)
src/makefile_mdi       Build rules for the gpumd-mdi executable
doc/README.md          Build + usage documentation
examples/gpumd_mdi/    Minimal GPUMD–VASP MDI example (Cu dimer)
tools/gpumd-mdi/       VASP MDI driver (Python) + launcher script
```

## Running the VASP example

```bash
cd examples/gpumd_mdi
bash ../../tools/gpumd-mdi/run_mdi_vasp_gpumd.sh \
  --gpumd-bin /path/to/GPUMD/src/gpumd-mdi \
  --run-in run.in \
  --vasp-cmd "vasp_std" \
  --poscar POSCAR_template \
  --steps 3
```

## Supported MDI commands (GPUMD as ENGINE)

| Command    | Meaning                                            |
|-----------|----------------------------------------------------|
| `<NATOMS`  | Returns the number of atoms                        |
| `>COORDS`  | Receives atomic coordinates from the driver        |
| `<COORDS`  | Sends atomic coordinates to the driver             |
| `<FORCES`  | Computes and sends forces to the driver            |
| `>FORCES`  | Receives forces from the driver (QM/MM coupling)   |
| `<ENERGY`  | Computes and sends potential energy to the driver  |
| `>ENERGY`  | Receives energy from the driver                    |
| `>STRESS`  | Receives stress tensor from the driver             |
| `EXIT`     | Exits the MDI communication loop                   |

## License and attribution

- The interface sources (`src/main_mdi/`, `src/makefile_mdi`) are derived from
  [GPUMD](https://github.com/brucefan1983/GPUMD) and are licensed under
  **GPL-3.0-or-later**, matching GPUMD (see [LICENSE](LICENSE)).
- MDI interface contributed by **Jaafar Mehrez** (Shanghai Jiao Tong University /
  HPQC Labs) — see the contribution notes in `src/main_mdi/mdi_stub.cu`.
- The Python driver and examples are provided for convenience under the same license.

## Citation

If you use this interface in research, please cite GPUMD, the relevant QM code
(e.g. VASP), and the MDI library, and mention this interface.
See [CITATION.cff](CITATION.cff) for details.