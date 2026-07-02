## Copyright lowRISC contributors (OpenTitan project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0
##
## Pin constraints for the wren CW310 (Kintex-7 XC7K410T) build.
##
## Package pins match the reference CW310 pinout so the design lands on the same
## board nets opentitantool drives (RESET = USB_A14 = U22, console UART on the
## SAM3U bridge, JTAG on the USR_DBG debug header). Because wren has no pinmux,
## signals are wired directly.

## ---- Clock -------------------------------------------------------------------
## 100 MHz reference (PLL_CLK2). The CW310 external PLL must be configured to
## 100 MHz (opentitantool does this for the cw310 interface).
set_property -dict { PACKAGE_PIN N21 IOSTANDARD LVCMOS33 } [get_ports { IO_CLK }]

## ---- Reset -------------------------------------------------------------------
## POR_N is the DUT reset opentitantool toggles (config "RESET" -> USB_A14).
set_property -dict { PACKAGE_PIN U22 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { POR_N }]

## ---- UART console (SAM3U USB-serial bridge, opentitantool uart "console") -----
## FPGA RX <- SAM_TXD1 (W24); FPGA TX -> SAM_RXD1 (AA22).
set_property -dict { PACKAGE_PIN W24  IOSTANDARD LVCMOS33 } [get_ports { UART_RX }]
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 } [get_ports { UART_TX }]

## ---- JTAG (rv_dm TAP) on the USR_DBG debug header ----------------------------
## Same physical pins the reference tops route their TAP to; connect a JTAG
## adapter (or hyperdebug) here to load firmware into SRAM and debug.
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { JTAG_TCK }]    ; # USR_DBG_TCK
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { JTAG_TMS }]    ; # USR_DBG_TMS
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { JTAG_TDI }]    ; # USR_DBG_TDI
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { JTAG_TDO }]    ; # USR_DBG_TDO
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { JTAG_TRST_N }] ; # USR_DBG_TDAT1 (nTRST)

## JTAG TCK is a clock; declare it and treat it as asynchronous to the system.
create_clock -add -name jtag_tck -period 100.00 [get_ports JTAG_TCK]
set_clock_groups -asynchronous -group [get_clocks jtag_tck]

## ---- Global configuration ----------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO      [current_design]
