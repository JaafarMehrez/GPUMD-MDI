# GPUMD MDI Interface

MDI (MolSSI Driver Interface) integration for GPUMD, allowing GPUMD to be used as an MD engine
interfaced with other codes like VASP.

This interface is maintained separately from the main GPUMD repository
(see [GPUMD issue #1786](https://github.com/brucefan1983/GPUMD/issues/1786)).
The interface sources are copied into a GPUMD checkout and built as a standalone
`gpumd-mdi` executable.

---

## 1. Prerequisites

- **GPUMD**
  - A checkout of [GPUMD](https://github.com/brucefan1983/GPUMD) (master / v5.x).

- **MDI library**
  - Install the MDI library following the official instructions:
    [MDI installation guide](https://molssi-mdi.github.io/MDI_Library/user_guide/installation.html).
  - Note the installation prefix, in particular:
    - `MDI_INC_PATH`: directory that contains `mdi.h`
      (for example, `/path/to/MDI_Library/install/include`)
    - `MDI_LIB_PATH`: directory that contains the MDI library
      (for example, `/path/to/MDI_Library/install/lib64`)

- **VASP**
  - A working VASP executable (for example, `vasp_std` or `mpirun -n N vasp_std`) available in
    your `PATH` or referenced via a full path.

- **Python**
  - Python 3
  - Python MDI interface:

    ```bash
    pip install mdi
    ```

  - `numpy`

---

## 2. Compiling `GPUMD` with MDI support

From this repository, run the build script with the path to your GPUMD checkout:

```bash
./build.sh /path/to/GPUMD USE_MDI=1 MDI_LIB=1 \
  MDI_LIB_PATH=/path/to/MDI_Library/install/lib64 \
  MDI_INC_PATH=/path/to/MDI_Library/install/include
```

The script copies `src/main_mdi/` and `src/makefile_mdi` into `/path/to/GPUMD/src/` and
builds the `gpumd-mdi` executable there. It is linked against the MDI library and can run
in ENGINE mode:

```bash
cd /path/to/GPUMD/src
./gpumd-mdi --mdi "-role ENGINE -name gpumd -method TCP -port 8021" -in run.in
```

> **Note:** `makefile_mdi` exposes two independent switches. `USE_MDI=1` enables the
> MDI code paths; `MDI_LIB=1` links the real MDI library (`-lmdi`) using
> `MDI_INC_PATH` / `MDI_LIB_PATH`. For a working executable that actually speaks MDI,
> always pass `MDI_LIB=1` together with those two paths.

---

## 3. MDI Commands Supported

GPUMD as an MDI ENGINE supports the following commands:

- `<NATOMS`: Returns the number of atoms
- `>COORDS`: Receives atomic coordinates from driver
- `<COORDS`: Sends atomic coordinates to driver
- `<FORCES`: Computes and sends forces to driver
- `>FORCES`: Receives forces from driver (for QM/MM coupling)
- `<ENERGY`: Computes and sends potential energy to driver
- `>ENERGY`: Receives energy from driver
- `>STRESS`: Receives stress tensor from driver
- `EXIT`: Exit the MDI communication loop

---

## 4. Files and layout for the VASP–GPUMD example

MDI-related helper scripts are collected under:

- `tools/gpumd-mdi/run_mdi_vasp_gpumd.sh` where:
  - `GPUMD` runs as MDI ENGINE (MD integrator)
  - `vasp_mdi_driver.py` runs as DRIVER (QM calculator)

- `tools/gpumd-mdi/vasp_mdi_driver.py`
  Python MDI DRIVER that:
  - connects to the `GPUMD` ENGINE over MDI,
  - launches VASP for QM calculations,
  - reads forces (and energy) from `vasprun.xml`,
  - sends QM forces and energy back to `GPUMD`.

An example input system is provided in:

- `examples/gpumd_mdi/` (Cu dimer), containing
  - `INCAR_template`, `POSCAR_template`, `POTCAR`, `run.in`, `model.xyz`

> **Note:** `examples/gpumd_mdi/run.in` references the NEP potential
> `../../potentials/nep/nep89_20250409/nep89_20250409.txt` relative to a GPUMD checkout.
> Make sure that file is reachable from where you run the example, or edit `run.in` to
> point at any valid GPUMD potential file.

---

## 5. Running the minimal VASP–GPUMD MDI example

Assuming:
- `GPUMD` has been compiled with MDI support as described above, and
- you have a working VASP executable (e.g. `vasp_std`),

you can run the minimal example as follows (from the repository root):

```bash
cd examples/gpumd_mdi

bash ../../tools/gpumd-mdi/run_mdi_vasp_gpumd.sh \
  --gpumd-bin /path/to/GPUMD/src/gpumd-mdi \
  --run-in run.in \
  --vasp-cmd "vasp_std" \
  --poscar POSCAR_template \
  --steps 3 \
  --no-cleanup
```

Key options:

- `--gpumd-bin`
  Path to the `gpumd-mdi` binary.

- `--run-in`
  GPUMD input file (default: `run.in`).

- `--vasp-cmd`
  Command used to run VASP (`vasp_std`, `mpirun -n 8 vasp_std`, etc.).

- `--poscar`
  POSCAR template file (default: `POSCAR_template`).

- `--steps`
  Number of MD steps controlled by the DRIVER.

- `--no-cleanup`
  Keep all the log directories and files

The script:

1. Starts `GPUMD` as MDI ENGINE in the background.
2. Starts the Python VASP DRIVER (`vasp_mdi_driver.py`) as MDI DRIVER.
3. Runs VASP at each MD step to compute QM energies and forces.
4. Sends QM forces and energy back to `GPUMD` via MDI.
5. Lets `GPUMD` perform the MD time integration.

Standard `GPUMD` dump and compute keywords in `run.in` (for example, `dump_xyz`,
`dump_thermo`, etc.) work as usual, so forces and thermodynamic quantities can be written
to the standard output files while using QM forces from VASP.

---

## 6. Extending to other DRIVER codes

The current example focuses on `VASP` as the QM DRIVER.
In principle, any external code that implements the MDI protocol can be used as a DRIVER:

- Replace `vasp_mdi_driver.py` with a DRIVER that:
  - connects to `GPUMD` over MDI,
  - requests coordinates from `GPUMD`,
  - computes energies and forces,
  - sends them back via the appropriate MDI commands.

The MDI-specific logic inside `GPUMD` is generic and not tied to VASP.