## Copyright lowRISC contributors (OpenTitan project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0
##
## Clock constraints for the wren CW310 build.

## 100 MHz board reference clock on IO_CLK (CW310 PLL_CLK2).
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports IO_CLK]

## Name the MMCM system-clock output for easier constraint/timing reports.
create_generated_clock -name clk_sys [get_pins u_clkgen/gen_clk_buf.clk_main_bufg/O]

## The reset synchronizer's async assert is intentionally asynchronous; do not
## time it.
set_false_path -through [get_ports POR_N]
