// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Minimal Verilator harness for chip_wren_verilator. Drives clk_i/rst_ni and
// runs the model until it finishes. Firmware is preloaded into the SRAM via the
// SramInitFile RTL parameter (set with a fusesoc vlogparam), so this harness
// only needs to toggle the clock; the uartdpi model streams the console to
// stdout and calls $finish when it sees the firmware's completion marker.
// max_cycles is just a safety cap for a firmware that never prints the marker.
//
// Plusargs:
//   +max_cycles=<n>   Safety cap on clock cycles (default 500,000).

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "Vchip_wren_verilator.h"
#include "verilated.h"

static vluint64_t g_time = 0;
double sc_time_stamp() { return g_time; }

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  auto *top = new Vchip_wren_verilator;

  unsigned long max_cycles = 500000;
  if (const char *arg = Verilated::commandArgsPlusMatch("max_cycles=")) {
    // arg is "+max_cycles=<n>"
    const char *eq = std::strchr(arg, '=');
    if (eq && *(eq + 1)) {
      max_cycles = std::strtoul(eq + 1, nullptr, 0);
    }
  }

  // Assert reset for a few cycles.
  top->rst_ni = 0;
  top->clk_i = 0;
  for (int i = 0; i < 10 && !Verilated::gotFinish(); i++) {
    top->clk_i = !top->clk_i;
    top->eval();
    g_time++;
  }
  top->rst_ni = 1;

  unsigned long cycle = 0;
  while (!Verilated::gotFinish() && cycle < max_cycles) {
    top->clk_i = 1;
    top->eval();
    g_time++;
    top->clk_i = 0;
    top->eval();
    g_time++;
    cycle++;
  }

  top->final();
  delete top;
  return 0;
}
