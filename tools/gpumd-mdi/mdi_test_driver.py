#!/usr/bin/env python3
"""
Minimal MDI DRIVER for testing `gpumd-mdi` as an ENGINE without VASP.

This connects to a running `gpumd-mdi --mdi "-role ENGINE ..."` process,
reads the atom count and coordinates, computes simple Lennard-Jones pair
forces in Python, and feeds them back via >ENERGY / >STRESS / >FORCES. It
exercises the full MDI command loop (handshake, coordinate exchange, external
forces, MD integration, EXIT) while requiring no QM code.

Start the ENGINE first, in the same working directory, then run this driver:

    # terminal 1
    /path/to/gpumd-mdi --mdi \
        "-role ENGINE -name gpumd -method TCP -hostname localhost -port 8021" \
        -in run.in

    # terminal 2
    python3 mdi_test_driver.py --port 8021 --steps 5

Anything the ENGINE writes with `dump_xyz` / `dump_thermo` in `run.in` will
reflect the externally supplied forces, so `dump.xyz` / `dump_thermo.out`
are a quick way to confirm the coupling works.
"""

import argparse

import numpy as np

try:
    import mdi
except ImportError:
    raise SystemExit("ERROR: MDI Library not found. Install with: pip install mdi")


def lj_pair(natoms, coords, sigma, epsilon):
    """Return (energy, forces) for a simple LJ system in eV / eV/A."""
    energy = 0.0
    forces = np.zeros(3 * natoms)
    pos = np.asarray(coords, dtype=float).reshape(natoms, 3)
    for i in range(natoms):
        for j in range(i + 1, natoms):
            d = pos[i] - pos[j]
            r2 = float(d @ d)
            if r2 < 1.0e-12:
                continue
            inv_r2 = 1.0 / r2
            sr2 = (sigma * sigma) * inv_r2
            sr6 = sr2 * sr2 * sr2
            sr12 = sr6 * sr6
            energy += 4.0 * epsilon * (sr12 - sr6)
            f = 24.0 * epsilon * (2.0 * sr12 - sr6) * inv_r2 * d
            forces[3 * i : 3 * i + 3] += f
            forces[3 * j : 3 * j + 3] -= f
    return energy, forces


def main():
    parser = argparse.ArgumentParser(
        description="Minimal VASP-free MDI DRIVER for gpumd-mdi (ENGINE)."
    )
    parser.add_argument("--port", type=int, default=8021, help="MDI TCP port")
    parser.add_argument("--steps", type=int, default=5, help="Number of MD steps")
    parser.add_argument("--sigma", type=float, default=2.3, help="LJ sigma (A)")
    parser.add_argument("--epsilon", type=float, default=0.4, help="LJ epsilon (eV)")
    args = parser.parse_args()

    print(f"[driver] MDI_Init DRIVER on port {args.port}", flush=True)
    mdi.MDI_Init(
        f"-role DRIVER -name test_driver -method TCP -port {args.port}"
    )
    comm = mdi.MDI_Accept_Communicator()
    print(f"[driver] connected to ENGINE (comm={comm})", flush=True)

    mdi.MDI_Send_Command("<NATOMS", comm)
    natoms = mdi.MDI_Recv(1, mdi.MDI_INT, comm)
    if isinstance(natoms, (list, tuple)):
        natoms = natoms[0]
    natoms = int(natoms)
    print(f"[driver] ENGINE reports {natoms} atoms", flush=True)

    for step in range(1, args.steps + 1):
        mdi.MDI_Send_Command("<COORDS", comm)
        coords = np.array(
            mdi.MDI_Recv(3 * natoms, mdi.MDI_DOUBLE, comm), dtype=float
        )
        print(f"[driver] step {step}: coords[0:3] = {coords[:3]}", flush=True)

        energy, forces = lj_pair(natoms, coords, args.sigma, args.epsilon)
        print(
            f"[driver] step {step}: E = {energy:.6f} eV, "
            f"|F| = {np.linalg.norm(forces):.6f} eV/A",
            flush=True,
        )

        mdi.MDI_Send_Command(">ENERGY", comm)
        mdi.MDI_Send(np.array([energy]), 1, mdi.MDI_DOUBLE, comm)
        mdi.MDI_Send_Command(">STRESS", comm)
        mdi.MDI_Send(np.zeros(9), 9, mdi.MDI_DOUBLE, comm)
        mdi.MDI_Send_Command(">FORCES", comm)
        mdi.MDI_Send(forces, 3 * natoms, mdi.MDI_DOUBLE, comm)

    mdi.MDI_Send_Command("EXIT", comm)
    print("[driver] sent EXIT; done", flush=True)


if __name__ == "__main__":
    main()
