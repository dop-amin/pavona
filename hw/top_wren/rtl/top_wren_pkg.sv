// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Package for the minimal ACC-centric top "wren".
//
// Holds the flat address map for the single main crossbar and the host/device
// index enumerations used by the hand-written TL-UL socket fabric in
// top_wren.sv. Kept small on purpose: this top exposes the ACC plus the minimum
// needed to load and run firmware on it (Ibex + SRAM + rv_dm/JTAG + one UART).

package top_wren_pkg;

  // ---------------------------------------------------------------------------
  // Fabric sizing
  // ---------------------------------------------------------------------------
  // Hosts on the M:1 socket.
  localparam int unsigned NumHost = 3;
  localparam int unsigned HostIbexInstr = 0;
  localparam int unsigned HostIbexData  = 1;
  localparam int unsigned HostRvDmSba   = 2;

  // Devices on the 1:N socket. Keep the enum and the address map below in sync.
  localparam int unsigned NumDevice = 6;
  localparam int unsigned DevSram        = 0;  // plain code + data SRAM window
  localparam int unsigned DevRvDmMem     = 1;  // rv_dm debug ROM / mem
  localparam int unsigned DevRvDmRegs    = 2;  // rv_dm control CSRs
  localparam int unsigned DevAcc         = 3;  // ACC (regs + IMEM + DMEM windows)
  localparam int unsigned DevUart        = 4;  // UART
  localparam int unsigned DevIbexCfg     = 5;  // rv_core_ibex config CSRs

  // Width of the socket_1n device selector. With ExplicitErrs=1 we need to be
  // able to represent the value NumDevice (the error responder).
  localparam int unsigned DevSelWidth = $clog2(NumDevice + 1);
  // Value routed to the socket_1n built-in error responder for unmapped
  // addresses.
  localparam logic [DevSelWidth-1:0] DevSelError = DevSelWidth'(NumDevice);

  // ---------------------------------------------------------------------------
  // Address map (32-bit). base = start address, mask = size-1 (address is in a
  // device's range when (addr & ~mask) == base). Bases are aligned to their
  // size and match the reference tops where the RTL bakes in assumptions
  // (rv_dm mem vs. Ibex Dm* params, ACC internal windows).
  // ---------------------------------------------------------------------------
  localparam logic [31:0] SramBase = 32'h1000_0000;  // 128 KiB code + data
  localparam int unsigned SramSizeBytes = 32'h0002_0000;  // 128 KiB
  localparam logic [31:0] SramMask = SramSizeBytes - 1;
  // The plain SRAM (prim_ram_1p_adv) is organized as 32-bit words.
  localparam int unsigned SramSizeWords = SramSizeBytes / 4;

  localparam logic [31:0] RvDmMemBase = 32'h0001_0000;  // debug ROM / mem, 4 KiB
  localparam logic [31:0] RvDmMemMask = 32'h0000_0FFF;

  localparam logic [31:0] RvDmRegsBase = 32'h4120_0000;  // 4 KiB slot
  localparam logic [31:0] RvDmRegsMask = 32'h0000_0FFF;

  localparam logic [31:0] AccBase = 32'h4130_0000;  // regs + IMEM + DMEM windows
  localparam logic [31:0] AccMask = 32'h0001_FFFF;  // 128 KiB

  localparam logic [31:0] UartBase = 32'h4000_0000;  // 4 KiB slot
  localparam logic [31:0] UartMask = 32'h0000_0FFF;

  localparam logic [31:0] IbexCfgBase = 32'h411F_0000;  // 4 KiB slot
  localparam logic [31:0] IbexCfgMask = 32'h0000_0FFF;

  // rv_dm mem window sizing for the Ibex Dm* parameters. Keep consistent with
  // RvDmMemBase / RvDmMemMask above.
  localparam logic [31:0] DmBaseAddr      = RvDmMemBase;
  localparam logic [31:0] DmAddrMask      = RvDmMemMask;
  // The rv_dm debug ROM places the halt / exception entry points at fixed
  // offsets within its mem window (matches the reference tops' 0x800 / 0x808).
  localparam logic [31:0] DmHaltAddr      = RvDmMemBase + 32'h0000_0800;
  localparam logic [31:0] DmExceptionAddr = RvDmMemBase + 32'h0000_0808;

  // Ibex reset fetch base: boot straight into SRAM.
  localparam logic [31:0] BootAddr = SramBase;

endpackage
