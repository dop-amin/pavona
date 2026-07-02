// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// CW310 FPGA wrapper for top_wren.
//
// This is a minimal, board-bring-up skeleton. It maps the top_wren I/O onto
// FPGA pins and derives the system clock/reset. It is intentionally simple:
// there is no pinmux/pad ring in this top, so peripheral pins are wired
// directly.
//
// TODO(fpga bring-up):
//   * Replace the pass-through BUFG with a proper MMCM/PLL (clkgen) to hit the
//     desired core frequency, and add the CW310 XDC pin/clock constraints.
//   * Confirm JTAG pin polarity/trst handling for the target debug adapter.
// These require Vivado and the physical board, so they are left as follow-ups.

module chip_wren_cw310 (
  // Board clock and reset
  input  logic IO_CLK,      // board reference clock
  input  logic POR_N,       // power-on reset, active low

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
  logic rst_sys_n;

  // TODO: replace with an MMCM-based clock generator. For now, buffer the board
  // clock straight through.
  BUFG u_clk_buf (
    .I(IO_CLK),
    .O(clk_sys)
  );

  // Synchronize the external power-on reset into the system clock domain.
  logic [1:0] por_sync_q;
  always_ff @(posedge clk_sys or negedge POR_N) begin
    if (!POR_N) begin
      por_sync_q <= 2'b00;
    end else begin
      por_sync_q <= {por_sync_q[0], 1'b1};
    end
  end
  assign rst_sys_n = por_sync_q[1];

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

  top_wren u_top_wren (
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
