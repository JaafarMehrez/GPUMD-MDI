# GPUMD-MDI

MDI (MolSSI Driver Interface) integration for [GPUMD](https://github.com/brucefan1983/GPUMD),
allowing GPUMD to run as an MDI ENGINE coupled to other codes (e.g. VASP as a QM DRIVER).

> **Status:** maintained separately from the main GPUMD repository.
> The interface previously lived in the [GPUMD](https://github.com/brucefan1983/GPUMD) repo
> (`src/main_mdi/`) and was moved out to keep the GPUMD core clean.
> See [GPUMD issue #1786](https://github.com/brucefan1983/GPUMD/issues/1786) for context.
> The full implementation and history remain available in the GPUMD git history.

## Requirements

- A checkout of [GPUMD](https://github.com/brucefan1983/GPUMD) (master / v5.x)
- CUDA toolkit + host compiler (same as a normal GPUMD build)
- [MDI Library](https://github.com/MolSSI-MDI/MDI_Library) (for linking `USE_MDI+MDI_LIB`)
- VASP (optional, for the bundled VASP driver example)
- Python 3 + `mdi` + `numpy`
  (needed for the VASP driver, and for the no-VASP smoke test below)

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

When `MDI_LIB_PATH` is supplied, the build bakes an `rpath` into the executable
(`-Xlinker -rpath -Xlinker $(MDI_LIB_PATH)`), so a shared `libmdi` is found at
runtime without setting `LD_LIBRARY_PATH`. To get a fully self-contained binary
instead, build the MDI library statically (`-DBUILD_SHARED_LIBS=OFF`, as the
`Dockerfile` does).

Alternatively, use the provided `Dockerfile` for a reproducible, self-contained
build environment (CUDA + MDI library + GPUMD + this interface):

```bash
docker build -t gpumd-mdi .
docker run --rm -it --gpus all gpumd-mdi /opt/GPUMD-MDI/build.sh /opt/GPUMD
```

See [doc/README.md](doc/README.md) for full build and usage instructions,
driver/engine examples, and the list of supported MDI commands.

## Repository layout

```
src/main_mdi/          MDI engine sources (main.cu, mdi_stub.cu, run.cu/cuh, mdi_fallback.h)
src/makefile_mdi       Build rules for the gpumd-mdi executable
doc/README.md          Build + usage documentation
examples/gpumd_mdi/    Minimal GPUMD–VASP MDI example (Cu dimer)
                       (INCAR, POSCAR, POTCAR, model.xyz, run.in)
tools/gpumd-mdi/       run_mdi_vasp_gpumd.sh  launcher (GPUMD ENGINE + VASP DRIVER)
                       vasp_mdi_driver.py     Python MDI DRIVER that runs VASP
                       mdi_test_driver.py     VASP-free MDI DRIVER (smoke test)
Dockerfile             Reproducible containerized build (CUDA + MDI + GPUMD)
build.sh               Builds gpumd-mdi against a GPUMD checkout
.github/workflows/     CI: periodic build against GPUMD master
```

## Quick test without VASP

`tools/gpumd-mdi/mdi_test_driver.py` is a minimal MDI DRIVER that computes simple
Lennard-Jones forces in Python and feeds them to GPUMD. It needs no QM code and
exercises the whole command loop (`<NATOMS`, `<COORDS`, `>ENERGY`, `>STRESS`,
`>FORCES`, `EXIT`).

Make sure `run.in` points at a reachable NEP potential file (see the note below),
then run the ENGINE and DRIVER in two shells from the example directory:

```bash
# terminal 1 — GPUMD as MDI ENGINE
CUDA_VISIBLE_DEVICES=0 /path/to/GPUMD/src/gpumd-mdi --mdi \
  "-role ENGINE -name gpumd -method TCP -hostname localhost -port 8021" -in run.in

# terminal 2 — minimal Python driver
python3 tools/gpumd-mdi/mdi_test_driver.py --port 8021 --steps 5
```

If the coupling works, the ENGINE prints the MDI command loop, the driver reports
energies/forces, and any `dump_xyz` / `dump_thermo` files show the atoms moving.

## Running the VASP example

```bash
cd examples/gpumd_mdi
bash ../../tools/gpumd-mdi/run_mdi_vasp_gpumd.sh \
  --gpumd-bin /path/to/GPUMD/src/gpumd-mdi \
  --run-in run.in \
  --vasp-cmd "vasp_std" \
  --poscar POSCAR \
  --steps 3
```

## Notes and troubleshooting

- **`run.in` potential path.** The example `run.in` ships with a placeholder
  `potential /path/to/nep89_20250409.txt`; edit it to point at a valid GPUMD
  potential file (for example
  `<GPUMD>/potentials/nep/nep89_20250409/nep89_20250409.txt`). The potential is
  still loaded in MDI mode, even though forces come from the DRIVER.

- **Small cells / multiple GPUs.** GPUMD auto-detects all visible GPUs and uses
  its multi-GPU NEP path when more than one is present. That path requires each
  GPU's domain to span at least **5× the NEP cutoff**, so a small cell (such as
  the 2-atom Cu dimer in a 10 Å box) aborts with:

  ```
  The longest direction has less than 5 times of the NEP cutoff per GPU.
  Please reduce the number of GPUs or increase the simulation cell size.
  ```

  Restrict the ENGINE to a single GPU (`CUDA_VISIBLE_DEVICES=0 …`, as shown
  above) or enlarge the simulation cell.

- **`POSCAR` is reused as the driver's template.** The VASP driver reads
  `POSCAR` for the lattice/atom types and rewrites it each step with the current
  coordinates, so running the example modifies the tracked file. Restore it with
  `git checkout examples/gpumd_mdi/POSCAR`.

- **`libmdi` at runtime.** If you linked a shared `libmdi` and skipped the rpath
  (e.g. an older build), export
  `LD_LIBRARY_PATH=/path/to/MDI_Library/install/lib64:$LD_LIBRARY_PATH` before
  launching the ENGINE.

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
