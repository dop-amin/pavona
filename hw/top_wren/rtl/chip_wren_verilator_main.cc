// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Minimal Verilator harness for chip_wren_verilator. Drives clk_i/rst_ni and
// runs the model for a bounded number of cycles. Firmware is preloaded into the
// SRAM via the SramInitFile RTL parameter (set with a fusesoc vlogparam), so
// this harness only needs to toggle the clock; the DUT's UART monitor streams
// decoded console output to stdout, and the model calls $finish when done.
//
// Plusargs:
//   +max_cycles=<n>   Stop after n clock cycles (default 2,000,000).

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

  unsigned long max_cycles = 2000000;
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
