// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// CW310 FPGA wrapper for top_wren.
//
// Maps the top_wren I/O directly onto FPGA pins (there is no pinmux/pad ring in
// this top) and derives the ~24 MHz system clock from the 100 MHz board clock
// via clkgen_xil7series. Pin assignments live in data/pins_cw310.xdc and the
// clock constraint in data/clocks.xdc.
//
// Note: the design comes up with an empty SRAM; load firmware over JTAG (rv_dm
// system-bus access) after programming the bitstream, or bake a VMEM into
// synthesis via the SramInitFile parameter.

module chip_wren_cw310 #(
  // Optional firmware image baked into the SRAM at synthesis (VMEM, 32-bit
  // words). Leave empty to load over JTAG after programming.
  parameter SramInitFile = ""
) (
  // Board clock and reset
  input  logic IO_CLK,      // board reference clock (100 MHz)
  input  logic POR_N,       // power-on reset button, active low

  // JTAG (rv_dm)
  input  logic JTAG_TCK,
  input  logic JTAG_TMS,
  input  logic JTAG_TDI,
  input  logic JTAG_TRST_N,
  output logic JTAG_TDO,

  // UART console
  input  logic UART_RX,
  output logic UART_TX
);

  // ---------------------------------------------------------------------------
  // Clock and reset
  // ---------------------------------------------------------------------------
  logic clk_sys;
  logic rst_clkgen_n;   // MMCM-locked + POR, still async to clk_sys
  logic rst_sys_n;

  clkgen_xil7series u_clkgen (
    .clk_i (IO_CLK),
    .rst_ni(POR_N),
    .clk_o (clk_sys),
    .rst_no(rst_clkgen_n)
  );

  // Synchronize reset deassertion into the system clock domain (async assert,
  // synchronous release).
  logic [1:0] rst_sync_q;
  always_ff @(posedge clk_sys or negedge rst_clkgen_n) begin
    if (!rst_clkgen_n) begin
      rst_sync_q <= 2'b00;
    end else begin
      rst_sync_q <= {rst_sync_q[0], 1'b1};
    end
  end
  assign rst_sys_n = rst_sync_q[1];

  // ---------------------------------------------------------------------------
  // JTAG plumbing
  // ---------------------------------------------------------------------------
  jtag_pkg::jtag_req_t jtag_req;
  jtag_pkg::jtag_rsp_t jtag_rsp;

  assign jtag_req.tck    = JTAG_TCK;
  assign jtag_req.tms    = JTAG_TMS;
  assign jtag_req.tdi    = JTAG_TDI;
  assign jtag_req.trst_n = JTAG_TRST_N;
  assign JTAG_TDO        = jtag_rsp.tdo;

  // ---------------------------------------------------------------------------
  // top_wren instance
  // ---------------------------------------------------------------------------
  logic uart_tx;
  logic uart_tx_en;

  top_wren #(
    .SramInitFile(SramInitFile)
  ) u_top_wren (
    .clk_i (clk_sys),
    .rst_ni(rst_sys_n),
    .jtag_i(jtag_req),
    .jtag_o(jtag_rsp),
    .uart_rx_i   (UART_RX),
    .uart_tx_o   (uart_tx),
    .uart_tx_en_o(uart_tx_en),
    .acc_alert_tx_o()
  );

  // The UART TX enable is always asserted for a push-pull FPGA output; drive the
  // pin directly.
  assign UART_TX = uart_tx;
  logic unused_tx_en;
  assign unused_tx_en = uart_tx_en;

endmodule
