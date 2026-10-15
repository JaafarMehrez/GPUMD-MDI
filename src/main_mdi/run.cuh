/*
    Copyright 2017 Zheyong Fan and GPUMD development team
    This file is part of GPUMD.
    GPUMD is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    GPUMD is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with GPUMD.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma once

class Force;
class Integrate;
class Measure;
class RunInput;

#include "force/force.cuh"
#include "integrate/integrate.cuh"
#include "measure/measure.cuh"
#include "model/atom.cuh"
#include "model/box.cuh"
#include "model/group.cuh"
#include "utilities/common.cuh"
#include "utilities/gpu_vector.cuh"
#include "velocity.cuh"
#include <array>
#include <string>
#include <vector>

class Run
{
public:
  Run(const RunInput& run_input, bool skip_run_commands = false);

  // MDI interface helpers
  int mdi_get_natoms();
  void mdi_get_positions(std::vector<double>& out_positions);
  void mdi_set_positions(const double* positions);
  void mdi_set_forces(const double* forces);
  void mdi_set_energy(double energy);
  void mdi_set_stress(const double* stress_3x3);
  void mdi_compute_forces();
  void mdi_get_forces(std::vector<double>& out_forces);
  void mdi_get_potential(std::vector<double>& out_potential);
  void mdi_initialize_for_mdi();
  void mdi_step_one();
  void mdi_finalize_for_mdi();

private:
  void execute_run_in(const RunInput& run_input);
  void perform_a_run(const int number_of_steps);
  void compute_force();
  void parse_one_keyword(
    const std::vector<std::string>& tokens, const RunInput& run_input);

  // keyword parsing functions
  void parse_velocity(const std::vector<std::string>& tokens);
  void parse_change_box(const std::vector<std::string>& tokens);
  void parse_correct_velocity(
    const std::vector<std::string>& tokens, const std::vector<Group>& group);
  void parse_time_step(const std::vector<std::string>& tokens);
  void parse_run(const std::vector<std::string>& tokens);

  // MDI bookkeeping reused by the single-step driver loop
  int mdi_step_counter = 0;
  int mdi_number_of_steps_ = 0; // run length requested by the last 'run' command (for ramp/init)
  double mdi_initial_time_step_ = 0.0; // fixed cap for the max-distance adaptive time step
  bool skip_run_commands_ = false; // when true, 'run' commands are parsed but not executed
  bool external_forces_pending =
    false; // when true, use forces supplied by mdi_set_forces for the next step
  bool external_energy_pending = false;
  bool external_stress_pending = false;
  double external_total_energy = 0.0;            // eV (system total)
  std::array<double, 9> external_stress = {0.0}; // eV/A^3 (3x3 row-major)

  int number_of_types; // number of atom types
  int has_velocity_in_xyz = 0;
  bool has_seen_dftd3_command = false;
  bool has_seen_kspace_command = false;
  bool has_replicate_ = false;
  int replicate_size_[3] = {1, 1, 1};
  std::string first_potential_filename_;
  double global_time = 0.0; // run time of entire simulation (fs)
  double time_step = 1.0 / TIME_UNIT_CONVERSION;
  double max_distance_per_step = -1.0;
  Atom atom;
  GPU_Vector<double> thermo; // some thermodynamic quantities
  Velocity velocity;
  Box box;
  std::vector<Group> group;

  Force force;
  Integrate integrate;
  Measure measure;
};
