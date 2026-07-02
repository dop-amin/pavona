// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Simulation wrapper (for Verilator) around top_wren.
//
// The clock and reset are driven by the C++ test harness (see
// chip_wren_verilator_main.cc) via clk_i / rst_ni. Firmware is backdoor-loaded
// into the SRAM through the SramInitFile parameter (set at build time with a
// vlogparam, e.g. `--SramInitFile=prog32.vmem`). JTAG is held idle - in
// simulation we rely on the SRAM preload rather than loading over JTAG.
//
// The console UART is decoded by the shared uartdpi model (hw/dv/dpi/uartdpi),
// which streams output to stdout and a log file and $finishes the simulation
// when it sees the firmware's completion marker (EXIT_STRING).

module chip_wren_verilator #(
  parameter SramInitFile = ""
) (
  input logic clk_i,
  input logic rst_ni
);

  // UART: uartdpi drives the DUT's rx and receives the DUT's tx.
  logic dut_uart_tx;
  logic dut_uart_rx;
  logic dut_uart_tx_en;

  top_wren #(
    .SramInitFile(SramInitFile)
  ) u_top_wren (
    .clk_i,
    .rst_ni,
    .jtag_i      (jtag_pkg::JTAG_REQ_DEFAULT),
    .jtag_o      (),
    .uart_rx_i   (dut_uart_rx),
    .uart_tx_o   (dut_uart_tx),
    .uart_tx_en_o(dut_uart_tx_en),
    .acc_alert_tx_o()
  );

  // BAUD/FREQ are artificial: uartdpi only uses their ratio (FREQ/BAUD) as the
  // cycles-per-bit, which must match the firmware's UART NCO. With a single
  // system clock here, cycles-per-bit = 2**20 / NCO; NCO = 0x8000 gives 32, so
  // FREQ/BAUD = 32. Keep this in sync with UART_NCO in sw/wren_acc_smoke.c.
  uartdpi #(
    .BAUD       (31_250),
    .FREQ       (1_000_000),
    .NAME       ("uart0"),
    .EXIT_STRING("WREN_EXIT")
  ) u_uart (
    .clk_i,
    .rst_ni,
    .active(1'b1),
    .tx_o  (dut_uart_rx),
    .rx_i  (dut_uart_tx)
  );

  logic unused_tx_en;
  assign unused_tx_en = dut_uart_tx_en;

endmodule
