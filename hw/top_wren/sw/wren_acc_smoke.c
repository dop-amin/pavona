// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Minimal ACC smoke test for top_wren.
//
// Exercises the full path that this top exists to provide: Ibex loads a program
// into the ACC's instruction memory, starts it, waits for completion and checks
// the error status - then reports the result over the UART. The ACC program is a
// single ECALL, which the ACC executes and immediately finishes with no error.
// This proves the ACC boots (initial secure wipe completes), accepts a program,
// executes, and returns to idle, all driven by firmware over the TL-UL fabric.
//
// Register offsets are taken from acc_reg_pkg / uart_reg_pkg; base addresses
// from top_wren_pkg (the flat address map).

#include <stdint.h>

// ---- Address map (matches hw/top_wren/rtl/top_wren_pkg.sv) -----------------
#define ACC_BASE   0x41300000u
#define UART_BASE  0x40000000u

// ---- ACC registers (acc_reg_pkg) -------------------------------------------
#define ACC_CMD_OFFSET      0x10u
#define ACC_STATUS_OFFSET   0x18u
#define ACC_ERR_BITS_OFFSET 0x1cu
#define ACC_IMEM_OFFSET     0x8000u

#define ACC_CMD_EXECUTE     0xd8u   // acc_pkg::CmdExecute
#define ACC_STATUS_IDLE     0x00u   // acc_pkg::StatusIdle

// ---- UART registers (uart_reg_pkg) -----------------------------------------
#define UART_CTRL_OFFSET    0x10u
#define UART_STATUS_OFFSET  0x14u
#define UART_WDATA_OFFSET   0x1cu

// UART CTRL fields: bit0 TX enable, bits[31:16] NCO.
// The Verilator UART monitor (chip_wren_verilator.sv) decodes at
// UartCyclesPerBit cycles/bit; pick NCO so the bit period matches. Tune this
// pair together for your target frequency.
#define UART_NCO            0x0100u
#define UART_CTRL_TX_EN     0x1u
// UART STATUS bit: TXFULL is bit0.
#define UART_STATUS_TXFULL  0x1u

static inline void mmio_write32(uint32_t addr, uint32_t val) {
  *(volatile uint32_t *)addr = val;
}
static inline uint32_t mmio_read32(uint32_t addr) {
  return *(volatile uint32_t *)addr;
}

static void uart_init(void) {
  mmio_write32(UART_BASE + UART_CTRL_OFFSET,
               (UART_NCO << 16) | UART_CTRL_TX_EN);
}

static void uart_putc(char c) {
  while (mmio_read32(UART_BASE + UART_STATUS_OFFSET) & UART_STATUS_TXFULL) {
  }
  mmio_write32(UART_BASE + UART_WDATA_OFFSET, (uint8_t)c);
}

static void uart_puts(const char *s) {
  for (; *s; s++) {
    uart_putc(*s);
  }
}

static void uart_puthex(uint32_t v) {
  static const char hex[] = "0123456789abcdef";
  uart_puts("0x");
  for (int i = 28; i >= 0; i -= 4) {
    uart_putc(hex[(v >> i) & 0xf]);
  }
}

static void acc_wait_idle(void) {
  while (mmio_read32(ACC_BASE + ACC_STATUS_OFFSET) != ACC_STATUS_IDLE) {
  }
}

int main(void) {
  uart_init();
  uart_puts("wren: ACC smoke start\r\n");

  // Wait for the ACC's initial secure wipe to complete.
  acc_wait_idle();

  // Load a one-instruction program (ECALL) into IMEM word 0. ECALL ends an ACC
  // program, so execution finishes immediately with no error.
  mmio_write32(ACC_BASE + ACC_IMEM_OFFSET + 0x0, 0x00000073u);

  // Start execution and wait for completion.
  mmio_write32(ACC_BASE + ACC_CMD_OFFSET, ACC_CMD_EXECUTE);
  acc_wait_idle();

  uint32_t err = mmio_read32(ACC_BASE + ACC_ERR_BITS_OFFSET);
  if (err == 0) {
    uart_puts("wren: ACC PASS\r\n");
  } else {
    uart_puts("wren: ACC FAIL err=");
    uart_puthex(err);
    uart_puts("\r\n");
  }

  return 0;
}
