// DESCRIPTION: Verilator: Verilog example module
//
// This file ONLY is placed under the Creative Commons Public Domain, for
// any use, without warranty, 2017 by Wilson Snyder.
// SPDX-License-Identifier: CC0-1.0
//======================================================================

// For std::unique_ptr
#include <memory>

// Include common routines
#include <verilated.h>

// Include model header, generated from Verilating the modules
#include "VMain.h"

#if VM_TRACE
#include "verilated_vcd_c.h"
#endif
#include <chrono>
#include <stdio.h>
// Legacy function required only so linking works on Cygwin and MSVC++
double sc_time_stamp() { return 0; }

int main(int argc, char **argv, char **env) {

  auto start = std::chrono::high_resolution_clock::now();

  const auto top = std::make_unique<VMain>();

  Verilated::commandArgs(argc, argv);
#if VM_TRACE
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;
  top->trace(tfp, 99); // Trace 99 levels of hierarchy
  tfp->open("trace.vcd");
#endif

  int time = 0;
  top->clk = 0;

  // Simulate until $finish
  while (!Verilated::gotFinish()) {
    time++;
    top->clk = !top->clk;
    top->eval();
#if VM_TRACE
    tfp->dump(time);
#endif
  }
  auto end = std::chrono::high_resolution_clock::now();
  auto duration = std::chrono::duration<double>(end - start).count();
  auto ratekHz = static_cast<double>(time >> 1) / duration / 1000.0;
  printf("Finished after %d cycles in %.3f seconds (%.3f)\n", time >> 1,
         duration, ratekHz);
  // Final model cleanup
  top->final();
#if VM_TRACE
  tfp->close();
#endif

  return 0;
}