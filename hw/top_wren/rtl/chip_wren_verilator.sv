// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Simulation wrapper (for Verilator) around top_wren.
//
// This is intentionally self-contained and simple: the clock and reset are
// driven by the C++ test harness (see chip_wren_verilator_main.cc) via clk_i /
// rst_ni. Firmware is backdoor-loaded into the SRAM through the SramInitFile
// parameter (set at build time with a vlogparam, e.g.
// `--SramInitFile=prog32.vmem`). JTAG is held idle - in simulation we rely on
// the SRAM preload rather than loading over JTAG.
//
// A small UART receive monitor decodes the console output and streams it to
// stdout so a test can observe what the firmware (driving the ACC) prints.

module chip_wren_verilator #(
  parameter SramInitFile = "",
  // UART divisor = round(clk_freq / baud). The firmware must configure the UART
  // NCO to match this ratio; for simulation we pick a small value so bytes come
  // out quickly. See chip_wren_verilator_main.cc / the smoke test.
  parameter int unsigned UartCyclesPerBit = 16
) (
  input logic clk_i,
  input logic rst_ni
);

  import top_wren_pkg::*;

  logic uart_tx;
  logic uart_tx_en;
  prim_alert_pkg::alert_tx_t [acc_reg_pkg::NumAlerts-1:0] acc_alert_tx;

  top_wren #(
    .SramInitFile(SramInitFile)
  ) u_top_wren (
    .clk_i,
    .rst_ni,
    .jtag_i      (jtag_pkg::JTAG_REQ_DEFAULT),
    .jtag_o      (),
    .uart_rx_i   (1'b1),          // idle high
    .uart_tx_o   (uart_tx),
    .uart_tx_en_o(uart_tx_en),
    .acc_alert_tx_o(acc_alert_tx)
  );

  // ---------------------------------------------------------------------------
  // Minimal UART-RX monitor: samples the tx line at the configured bit period
  // and prints decoded bytes. Assumes 8N1 at UartCyclesPerBit cycles/bit.
  // ---------------------------------------------------------------------------
  localparam int unsigned HalfBit = UartCyclesPerBit / 2;

  typedef enum logic [1:0] {UMonIdle, UMonStart, UMonData, UMonStop} umon_e;
  umon_e             umon_state;
  logic [31:0]       umon_cnt;
  logic [2:0]        umon_bit;
  logic [7:0]        umon_shift;
  logic              tx_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      umon_state <= UMonIdle;
      umon_cnt   <= '0;
      umon_bit   <= '0;
      umon_shift <= '0;
      tx_q       <= 1'b1;
    end else begin
      tx_q <= uart_tx;
      unique case (umon_state)
        UMonIdle: begin
          // Detect start bit (falling edge on an idle-high line).
          if (tx_q && !uart_tx) begin
            umon_state <= UMonStart;
            umon_cnt   <= '0;
          end
        end
        UMonStart: begin
          // Wait half a bit to sample mid-bit.
          if (umon_cnt == HalfBit) begin
            umon_state <= UMonData;
            umon_cnt   <= '0;
            umon_bit   <= '0;
          end else begin
            umon_cnt <= umon_cnt + 1;
          end
        end
        UMonData: begin
          if (umon_cnt == UartCyclesPerBit - 1) begin
            umon_cnt              <= '0;
            umon_shift[umon_bit]  <= uart_tx;
            umon_bit              <= umon_bit + 1;
            if (umon_bit == 3'd7) begin
              umon_state <= UMonStop;
            end
          end else begin
            umon_cnt <= umon_cnt + 1;
          end
        end
        UMonStop: begin
          if (umon_cnt == UartCyclesPerBit - 1) begin
            // verilator lint_off BLKSEQ
            $write("%c", umon_shift);
            $fflush();
            // verilator lint_on BLKSEQ
            umon_state <= UMonIdle;
            umon_cnt   <= '0;
          end else begin
            umon_cnt <= umon_cnt + 1;
          end
        end
        default: umon_state <= UMonIdle;
      endcase
    end
  end

  // Keep the alert observation from being optimized away.
  logic unused_alert;
  assign unused_alert = ^{acc_alert_tx, uart_tx_en};

endmodule
