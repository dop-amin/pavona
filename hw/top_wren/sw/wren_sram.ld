/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * Linker script for SRAM-resident firmware on top_wren.
 *
 * The Ibex core boots from the SRAM base (0x1000_0000). On reset it fetches at
 * base + 0x80 (the reset vector); exceptions vector to the base. We therefore
 * place a trap handler at offset 0x0 and the reset entry at offset 0x80.
 */

OUTPUT_ARCH(riscv)
ENTRY(_reset)

MEMORY {
  sram (rwx) : ORIGIN = 0x10000000, LENGTH = 128K
}

SECTIONS {
  .trap 0x10000000 : {
    KEEP(*(.trap))
  } > sram

  .reset 0x10000080 : {
    KEEP(*(.reset))
  } > sram

  .text : ALIGN(4) {
    *(.text)
    *(.text.*)
  } > sram

  .rodata : ALIGN(4) {
    *(.rodata)
    *(.rodata.*)
    *(.srodata)
    *(.srodata.*)
  } > sram

  .data : ALIGN(4) {
    *(.data)
    *(.data.*)
    *(.sdata)
    *(.sdata.*)
  } > sram

  .bss (NOLOAD) : ALIGN(4) {
    _bss_start = .;
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
    *(COMMON)
    _bss_end = .;
  } > sram

  _stack_top = ORIGIN(sram) + LENGTH(sram);
}
