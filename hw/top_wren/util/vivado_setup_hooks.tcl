# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Vivado setup hooks for the wren CW310 build. See Xilinx UG 894.

# fusesoc-generated workroot containing the Vivado project file.
set workroot [pwd]

# Set the USR_ACCESS register (needed by opentitantool) just before the
# bitstream is written. Edalize does not currently invoke
# STEPS.WRITE_BITSTREAM.TCL.PRE through our flow, so - like the reference tops -
# we hook the post-route step instead, which does run.
set_property STEPS.ROUTE_DESIGN.TCL.POST \
  "${workroot}/vivado_hook_write_bitstream_pre.tcl" [get_runs impl_1]
