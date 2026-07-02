// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Single-output 7-series clock generator for the wren CW310 build.
//
// Turns the 100 MHz board clock into a conservative ~24 MHz system clock via an
// MMCM (same VCO/divider choice as the reference tops, trimmed to one output),
// and produces a reset that is held until the MMCM locks. The Verilator
// simulation drives top_wren directly and never instantiates this module; the
// bypass below exists only so the CW310 wrapper can be run through Verilator
// lint without the Xilinx unisim primitives (BUFG/MMCME2_ADV).

module clkgen_xil7series #(
  parameter bit AddClkBuf = 1
) (
  input  logic clk_i,    // board reference clock (100 MHz)
  input  logic rst_ni,   // external async reset, active low
  output logic clk_o,     // system clock (~24 MHz)
  output logic rst_no     // deasserted once locked and rst_ni released
);

`ifdef VERILATOR
  // Simulation: pass the input clock straight through.
  assign clk_o  = clk_i;
  assign rst_no = rst_ni;
`else
  logic locked_pll;
  logic clk_fb_unbuf, clk_fb_buf;
  logic clk_main_unbuf, clk_main_buf;

  MMCME2_ADV #(
    .BANDWIDTH          ("OPTIMIZED"),
    .COMPENSATION       ("ZHOLD"),
    .STARTUP_WAIT       ("FALSE"),
    .CLKIN1_PERIOD      (10.000),  // f_CLKIN = 100 MHz
    .DIVCLK_DIVIDE      (1),       // f_PFD = 100 MHz
    .CLKFBOUT_MULT_F    (12.000),  // f_VCO = 1200 MHz
    .CLKFBOUT_PHASE     (0.000),
    .CLKOUT0_DIVIDE_F   (50.0),    // f_main = 24 MHz
    .CLKOUT0_PHASE      (0.000),
    .CLKOUT0_DUTY_CYCLE (0.500)
  ) pll (
    .CLKFBOUT    (clk_fb_unbuf),
    .CLKFBOUTB   (),
    .CLKOUT0     (clk_main_unbuf),
    .CLKOUT0B    (),
    .CLKOUT1     (),
    .CLKOUT1B    (),
    .CLKOUT2     (),
    .CLKOUT2B    (),
    .CLKOUT3     (),
    .CLKOUT3B    (),
    .CLKOUT4     (),
    .CLKOUT5     (),
    .CLKOUT6     (),
    .CLKFBIN     (clk_fb_buf),
    .CLKIN1      (clk_i),
    .CLKIN2      (1'b0),
    .CLKINSEL    (1'b1),
    .DADDR       (7'h0),
    .DCLK        (1'b0),
    .DEN         (1'b0),
    .DI          (16'h0),
    .DO          (),
    .DRDY        (),
    .DWE         (1'b0),
    .PSCLK       (1'b0),
    .PSEN        (1'b0),
    .PSINCDEC    (1'b0),
    .PSDONE      (),
    .CLKFBSTOPPED(),
    .CLKINSTOPPED(),
    .LOCKED      (locked_pll),
    .PWRDWN      (1'b0),
    // Do not reset the MMCM on the external reset (keeps ILA connected).
    .RST         (1'b0)
  );

  BUFG clk_fb_bufg (
    .I(clk_fb_unbuf),
    .O(clk_fb_buf)
  );

  if (AddClkBuf == 1) begin : gen_clk_buf
    BUFG clk_main_bufg (
      .I(clk_main_unbuf),
      .O(clk_main_buf)
    );
  end else begin : gen_no_clk_buf
    assign clk_main_buf = clk_main_unbuf;
  end

  assign clk_o  = clk_main_buf;
  assign rst_no = locked_pll & rst_ni;
`endif

endmodule
