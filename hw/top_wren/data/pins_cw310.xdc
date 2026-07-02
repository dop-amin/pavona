## Copyright lowRISC contributors (OpenTitan project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0
##
## Pin constraints for the wren CW310 (Kintex-7 XC7K410T) build.
##
## Package pins are reused from the reference CW310 pinout. Because wren has no
## pinmux, top-level signals are wired directly here. CONFIRM these against how
## you physically wire JTAG/UART on your board before relying on them.

## ---- Clock and reset --------------------------------------------------------
## 100 MHz reference (PLL_CLK2).
set_property -dict { PACKAGE_PIN N21 IOSTANDARD LVCMOS33 } [get_ports { IO_CLK }]
## Power-on reset: pushbutton SW2 (active low).
set_property -dict { PACKAGE_PIN Y7  IOSTANDARD LVCMOS18 } [get_ports { POR_N }]

## ---- UART console (via the on-board SAM3X USB-serial bridge) -----------------
## FPGA RX  <- SAM_TXD1 (W24); FPGA TX -> SAM_RXD1 (AA22).
set_property -dict { PACKAGE_PIN W24  IOSTANDARD LVCMOS33 } [get_ports { UART_RX }]
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 } [get_ports { UART_TX }]

## ---- JTAG (rv_dm TAP) on the PMOD1 header -----------------------------------
## Pin choice is arbitrary among the free user IO; adjust to your adapter.
set_property -dict { PACKAGE_PIN T22 IOSTANDARD LVCMOS33 } [get_ports { JTAG_TCK }]    ; # PMOD1_IO4
set_property -dict { PACKAGE_PIN R23 IOSTANDARD LVCMOS33 } [get_ports { JTAG_TMS }]    ; # PMOD1_IO3
set_property -dict { PACKAGE_PIN R26 IOSTANDARD LVCMOS33 } [get_ports { JTAG_TDI }]    ; # PMOD1_IO2
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { JTAG_TDO }]    ; # PMOD1_IO1
set_property -dict { PACKAGE_PIN R25 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { JTAG_TRST_N }] ; # PMOD1_IO5

## JTAG TCK is a clock; constrain it and relax cross-domain timing to it.
create_clock -add -name jtag_tck -period 100.00 [get_ports JTAG_TCK]
set_clock_groups -asynchronous -group [get_clocks jtag_tck]
