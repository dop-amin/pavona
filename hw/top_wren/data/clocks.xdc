## Copyright lowRISC contributors (OpenTitan project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0
##
## Clock constraints for the wren CW310 build.

## 100 MHz board reference clock on IO_CLK (CW310 PLL_CLK2). The MMCM-derived
## system clock (~24 MHz) is auto-derived by Vivado from this input, so we do
## not name it explicitly here.
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports IO_CLK]

## The reset (POR_N) is asynchronous; do not time paths through it. (Reset
## release is resynchronized in RTL.)
set_false_path -through [get_ports POR_N]
