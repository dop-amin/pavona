// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Minimal startup for SRAM-resident firmware on top_wren.

  // Exception/interrupt trap vector: sits at the SRAM base (offset 0x0). For
  // this smoke firmware we simply spin - any trap is a failure to inspect.
  .section .trap, "ax"
  .global _trap
_trap:
  j _trap

  // Reset entry: the linker places this at SRAM base + 0x80, where Ibex fetches
  // its first instruction out of reset.
  .section .reset, "ax"
  .global _reset
_reset:
  // Set up the stack pointer.
  la   sp, _stack_top

  // Zero the .bss section.
  la   t0, _bss_start
  la   t1, _bss_end
1:
  bgeu t0, t1, 2f
  sw   zero, 0(t0)
  addi t0, t0, 4
  j    1b
2:
  call main

  // main returned: idle forever.
3:
  wfi
  j    3b
